import 'dart:async';

import 'circuit_breaker.dart';
import 'network_client.dart';
import 'retry_handler.dart';

/// Configuration for resilient network operations.
///
/// Combines retry and circuit breaker configurations for comprehensive
/// fault tolerance in payment operations.
///
/// ## Presets
///
/// * [ResilienceConfig.forPayments] - Conservative settings for payment transactions
/// * [ResilienceConfig.forQueries] - Aggressive settings for read operations
/// * [ResilienceConfig.disabled] - No resilience (direct calls)
///
/// ## Example
///
/// ```dart
/// final config = ResilienceConfig(
///   retryConfig: RetryConfig.conservative,
///   circuitBreakerConfig: CircuitBreakerConfig.strict,
/// );
/// ```
class ResilienceConfig {
  /// Creates a resilience configuration.
  const ResilienceConfig({
    this.retryConfig = const RetryConfig(),
    this.circuitBreakerConfig = const CircuitBreakerConfig(),
    this.enableRetry = true,
    this.enableCircuitBreaker = true,
  });

  /// Retry configuration.
  final RetryConfig retryConfig;

  /// Circuit breaker configuration.
  final CircuitBreakerConfig circuitBreakerConfig;

  /// Whether retry is enabled.
  final bool enableRetry;

  /// Whether circuit breaker is enabled.
  final bool enableCircuitBreaker;

  /// Disabled resilience - direct calls without retry or circuit breaker.
  static const disabled = ResilienceConfig(
    enableRetry: false,
    enableCircuitBreaker: false,
  );

  /// Conservative settings for payment transactions.
  ///
  /// - Limited retries (only timeout/rate limiting)
  /// - Strict circuit breaker (opens quickly on failures)
  static const forPayments = ResilienceConfig(
    retryConfig: RetryConfig.conservative,
    circuitBreakerConfig: CircuitBreakerConfig.strict,
  );

  /// Aggressive settings for read operations (installments, status queries).
  ///
  /// - More retries with shorter delays
  /// - Lenient circuit breaker (more tolerant)
  static const forQueries = ResilienceConfig(
    retryConfig: RetryConfig.aggressive,
    circuitBreakerConfig: CircuitBreakerConfig.lenient,
  );

  @override
  String toString() => 'ResilienceConfig('
      'retry: ${enableRetry ? retryConfig : "disabled"}, '
      'circuitBreaker: ${enableCircuitBreaker ? circuitBreakerConfig : "disabled"})';
}

/// Callback for resilience events (retry, circuit state changes).
typedef ResilienceCallback = void Function(ResilienceEvent event);

/// Event types for resilience operations.
enum ResilienceEventType {
  /// Retry attempt started.
  retryAttempt,

  /// Circuit breaker opened.
  circuitOpened,

  /// Circuit breaker transitioned to half-open.
  circuitHalfOpen,

  /// Circuit breaker closed.
  circuitClosed,

  /// Request succeeded after retry.
  retrySuccess,

  /// Request failed after all retries.
  retryExhausted,
}

/// Resilience event data.
class ResilienceEvent {
  /// Creates a resilience event.
  const ResilienceEvent({
    required this.type,
    required this.circuitName,
    this.attemptNumber,
    this.error,
    this.delay,
  });

  /// Event type.
  final ResilienceEventType type;

  /// Name of the circuit breaker.
  final String circuitName;

  /// Current attempt number (for retry events).
  final int? attemptNumber;

  /// Error that triggered this event.
  final Object? error;

  /// Delay before next retry.
  final Duration? delay;

  @override
  String toString() => 'ResilienceEvent($type, circuit: $circuitName'
      '${attemptNumber != null ? ", attempt: $attemptNumber" : ""}'
      '${error != null ? ", error: $error" : ""})';
}

/// Network client wrapper with retry and circuit breaker support.
///
/// This client wraps any [NetworkClient] implementation and adds
/// fault tolerance capabilities through retry logic and circuit breaker
/// pattern.
///
/// ## Usage
///
/// ```dart
/// final baseClient = HttpNetworkClient();
/// final resilientClient = ResilientNetworkClient(
///   client: baseClient,
///   circuitName: 'iyzico',
///   config: ResilienceConfig.forPayments,
///   onEvent: (event) => print('Resilience: $event'),
/// );
///
/// // Use like any other NetworkClient
/// final response = await resilientClient.post(url, body: data);
/// ```
///
/// ## Circuit Breaker Behavior
///
/// When the circuit is open, requests will immediately fail with
/// [CircuitBreakerOpenException]. This prevents cascading failures
/// when a service is down.
///
/// ## Retry Behavior
///
/// Failed requests are automatically retried based on the configuration.
/// Only retryable errors (timeouts, connection issues) trigger retries.
class ResilientNetworkClient implements NetworkClient {
  /// Creates a resilient network client.
  ///
  /// [client] - The underlying network client to wrap.
  /// [circuitName] - Unique name for the circuit breaker.
  /// [config] - Resilience configuration.
  /// [onEvent] - Optional callback for resilience events.
  ResilientNetworkClient({
    required NetworkClient client,
    required String circuitName,
    ResilienceConfig config = const ResilienceConfig(),
    ResilienceCallback? onEvent,
  })  : _client = client,
        _circuitName = circuitName,
        _config = config,
        _onEvent = onEvent {
    if (_config.enableCircuitBreaker) {
      _circuitBreaker = CircuitBreaker(
        name: circuitName,
        config: _config.circuitBreakerConfig,
      );
    }

    if (_config.enableRetry) {
      _retryHandler = RetryHandler(config: _config.retryConfig);
    }
  }

  final NetworkClient _client;
  final String _circuitName;
  final ResilienceConfig _config;
  final ResilienceCallback? _onEvent;

  CircuitBreaker? _circuitBreaker;
  RetryHandler? _retryHandler;

  /// The underlying network client.
  NetworkClient get client => _client;

  /// The circuit breaker (if enabled).
  CircuitBreaker? get circuitBreaker => _circuitBreaker;

  /// Current circuit breaker state.
  CircuitState? get circuitState => _circuitBreaker?.state;

  /// Whether the circuit is currently open.
  bool get isCircuitOpen => _circuitBreaker?.isOpen ?? false;

  @override
  Future<NetworkResponse> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) =>
      _executeWithResilience(
        () => _client.get(url, headers: headers, timeout: timeout),
      );

  @override
  Future<NetworkResponse> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) =>
      _executeWithResilience(
        () => _client.post(url, headers: headers, body: body, timeout: timeout),
      );

  @override
  Future<NetworkResponse> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) =>
      _executeWithResilience(
        () => _client.put(url, headers: headers, body: body, timeout: timeout),
      );

  @override
  Future<NetworkResponse> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) =>
      _executeWithResilience(
        () => _client.delete(url, headers: headers, timeout: timeout),
      );

  @override
  Future<NetworkResponse> postForm(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    Duration? timeout,
  }) =>
      _executeWithResilience(
        () => _client.postForm(
          url,
          headers: headers,
          fields: fields,
          timeout: timeout,
        ),
      );

  @override
  void dispose() {
    _client.dispose();
  }

  /// Manually reset the circuit breaker.
  void resetCircuit() {
    _circuitBreaker?.reset();
    _emitEvent(ResilienceEventType.circuitClosed);
  }

  /// Force the circuit to open.
  void forceCircuitOpen() {
    _circuitBreaker?.forceOpen();
    _emitEvent(ResilienceEventType.circuitOpened);
  }

  /// Execute an operation with resilience (retry + circuit breaker).
  Future<NetworkResponse> _executeWithResilience(
    Future<NetworkResponse> Function() operation,
  ) async {
    // If no resilience configured, execute directly
    if (!_config.enableRetry && !_config.enableCircuitBreaker) {
      return operation();
    }

    // Track previous circuit state for event emission
    final previousState = _circuitBreaker?.state;

    try {
      // Wrap with circuit breaker if enabled
      if (_config.enableCircuitBreaker && _circuitBreaker != null) {
        return _circuitBreaker!.execute(() async {
          // Wrap with retry if enabled
          if (_config.enableRetry && _retryHandler != null) {
            return _retryHandler!.execute(
              operation,
              onRetry: (attempt, error, delay) {
                _emitEvent(
                  ResilienceEventType.retryAttempt,
                  attemptNumber: attempt,
                  error: error,
                  delay: delay,
                );
              },
            );
          }
          return operation();
        });
      }

      // Only retry, no circuit breaker
      if (_config.enableRetry && _retryHandler != null) {
        return _retryHandler!.execute(
          operation,
          onRetry: (attempt, error, delay) {
            _emitEvent(
              ResilienceEventType.retryAttempt,
              attemptNumber: attempt,
              error: error,
              delay: delay,
            );
          },
        );
      }

      return operation();
    } finally {
      // Emit circuit state change events
      _checkAndEmitCircuitStateChange(previousState);
    }
  }

  /// Check for circuit state changes and emit events.
  void _checkAndEmitCircuitStateChange(CircuitState? previousState) {
    if (_circuitBreaker == null || previousState == null) return;

    final currentState = _circuitBreaker!.state;
    if (currentState == previousState) return;

    switch (currentState) {
      case CircuitState.open:
        _emitEvent(ResilienceEventType.circuitOpened);
      case CircuitState.halfOpen:
        _emitEvent(ResilienceEventType.circuitHalfOpen);
      case CircuitState.closed:
        _emitEvent(ResilienceEventType.circuitClosed);
    }
  }

  /// Emit a resilience event.
  void _emitEvent(
    ResilienceEventType type, {
    int? attemptNumber,
    Object? error,
    Duration? delay,
  }) {
    _onEvent?.call(
      ResilienceEvent(
        type: type,
        circuitName: _circuitName,
        attemptNumber: attemptNumber,
        error: error,
        delay: delay,
      ),
    );
  }
}

/// Extension to easily wrap a NetworkClient with resilience.
extension ResilientNetworkClientExtension on NetworkClient {
  /// Wrap this client with resilience features.
  ///
  /// ```dart
  /// final client = HttpNetworkClient()
  ///     .withResilience(
  ///       circuitName: 'iyzico',
  ///       config: ResilienceConfig.forPayments,
  ///     );
  /// ```
  ResilientNetworkClient withResilience({
    required String circuitName,
    ResilienceConfig config = const ResilienceConfig(),
    ResilienceCallback? onEvent,
  }) =>
      ResilientNetworkClient(
        client: this,
        circuitName: circuitName,
        config: config,
        onEvent: onEvent,
      );
}
