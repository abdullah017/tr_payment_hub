import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Retry configuration for payment operations
///
/// Farklı senaryolar için önceden tanımlanmış konfigürasyonlar:
/// - [RetryConfig.noRetry]: Retry yapma
/// - [RetryConfig.conservative]: Ödeme işlemleri için güvenli retry
/// - [RetryConfig.aggressive]: Hızlı retry (sadece okuma işlemleri için)
class RetryConfig {
  /// Creates a retry configuration
  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
    this.retryableExceptions = const [
      'TimeoutException',
      'SocketException',
      'HttpException',
    ],
  });

  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Initial delay before first retry
  final Duration initialDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Multiplier for exponential backoff
  final double backoffMultiplier;

  /// HTTP status codes that should trigger a retry
  final List<int> retryableStatusCodes;

  /// Exception types that should trigger a retry
  final List<String> retryableExceptions;

  /// No retry - execute operation only once
  static const noRetry = RetryConfig(maxAttempts: 1);

  /// Conservative retry for payment operations
  /// - Sadece timeout ve rate limiting durumlarında retry yapar
  /// - Ödeme işlemleri için idempotent olmalı
  static const conservative = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 5),
    retryableStatusCodes: [408, 429, 503, 504],
  );

  /// Aggressive retry for read operations
  /// - Installment sorgulama, durum kontrolü gibi işlemler için
  static const aggressive = RetryConfig(
    initialDelay: Duration(milliseconds: 300),
    maxDelay: Duration(seconds: 8),
    backoffMultiplier: 2.5,
  );

  @override
  String toString() => 'RetryConfig(maxAttempts: $maxAttempts, '
      'initialDelay: ${initialDelay.inMilliseconds}ms, '
      'backoffMultiplier: $backoffMultiplier)';
}

/// Callback type for retry events
typedef RetryCallback = void Function(
  int attempt,
  Object error,
  Duration delay,
);

/// Retry handler with exponential backoff and jitter
///
/// Örnek kullanım:
/// ```dart
/// final handler = RetryHandler(config: RetryConfig.conservative);
///
/// final result = await handler.execute(
///   () async => await makeHttpRequest(),
///   onRetry: (attempt, error, delay) {
///     print('Retry $attempt after $delay: $error');
///   },
/// );
/// ```
class RetryHandler {
  /// Creates a retry handler with the given configuration
  RetryHandler({
    this.config = const RetryConfig(),
  });

  /// Retry configuration
  final RetryConfig config;

  /// Random instance for jitter calculation
  final Random _random = Random();

  /// Execute an operation with retry logic
  ///
  /// [operation] - The async operation to execute
  /// [shouldRetry] - Optional custom retry predicate
  /// [onRetry] - Optional callback called before each retry
  Future<T> execute<T>(
    Future<T> Function() operation, {
    bool Function(Object error)? shouldRetry,
    RetryCallback? onRetry,
  }) async {
    var attempt = 0;
    var delay = config.initialDelay;

    while (true) {
      attempt++;

      try {
        return await operation();
      } catch (e) {
        // Check if we should retry
        final canRetry = shouldRetry?.call(e) ?? _isRetryable(e);

        // If we can't retry or exceeded max attempts, rethrow
        if (!canRetry || attempt >= config.maxAttempts) {
          rethrow;
        }

        // Calculate delay with jitter (0.85-1.15 multiplier)
        final jitter = 0.85 + (_random.nextDouble() * 0.3);
        final actualDelay = Duration(
          milliseconds: (delay.inMilliseconds * jitter).round(),
        );

        // Notify callback before retry
        onRetry?.call(attempt, e, actualDelay);

        // Wait before retry
        await Future<void>.delayed(actualDelay);

        // Calculate next delay with exponential backoff
        final nextDelayMs =
            (delay.inMilliseconds * config.backoffMultiplier).round();
        delay = Duration(
          milliseconds: min(nextDelayMs, config.maxDelay.inMilliseconds),
        );
      }
    }
  }

  /// Check if an error is retryable based on configuration
  bool _isRetryable(Object error) {
    // Check for timeout exceptions
    if (error is TimeoutException) return true;

    // Check for socket exceptions (connection issues)
    if (error is SocketException) return true;

    // Check for HTTP exceptions
    if (error is HttpException) return true;

    // Check error message for common retryable patterns
    final message = error.toString().toLowerCase();
    if (message.contains('timeout') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('socket') ||
        message.contains('network is unreachable')) {
      return true;
    }

    // Check against configured exception types
    final errorType = error.runtimeType.toString();
    if (config.retryableExceptions.contains(errorType)) {
      return true;
    }

    return false;
  }

  /// Check if an HTTP status code is retryable
  bool isRetryableStatusCode(int statusCode) =>
      config.retryableStatusCodes.contains(statusCode);
}

/// Extension for adding retry capability to futures
extension RetryExtension<T> on Future<T> {
  /// Execute this future with retry logic
  Future<T> withRetry({
    RetryConfig config = const RetryConfig(),
    bool Function(Object error)? shouldRetry,
    RetryCallback? onRetry,
  }) {
    final handler = RetryHandler(config: config);
    return handler.execute(
      () => this,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }
}
