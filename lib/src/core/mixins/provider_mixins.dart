import 'package:http/http.dart' as http;

import '../enums.dart';
import '../exceptions/payment_exception.dart';
import '../network/circuit_breaker.dart';
import '../network/http_network_client.dart';
import '../network/network_client.dart';
import '../network/retry_handler.dart';

/// Mixin for network client initialization in payment providers.
///
/// This mixin provides common network client initialization logic
/// that is shared across all payment providers.
///
/// ## Usage
///
/// ```dart
/// class MyProvider with NetworkClientMixin implements PaymentProvider {
///   @override
///   ProviderType get providerType => ProviderType.iyzico;
///
///   Future<void> initialize(PaymentConfig config) async {
///     initializeNetworkClient(
///       customNetworkClient: customClient,
///       customHttpClient: httpClient,
///     );
///   }
/// }
/// ```
mixin NetworkClientMixin {
  /// The network client used for HTTP requests.
  NetworkClient? networkClient;

  /// Initializes the network client with proper priority handling.
  ///
  /// Priority: custom NetworkClient > legacy http.Client > default HttpNetworkClient
  ///
  /// This pattern is consistent across all providers and ensures backward
  /// compatibility while allowing custom implementations.
  void initializeNetworkClient({
    NetworkClient? customNetworkClient,
    http.Client? customHttpClient,
  }) {
    if (customNetworkClient != null) {
      networkClient = customNetworkClient;
    } else if (customHttpClient != null) {
      networkClient = HttpNetworkClient(client: customHttpClient);
    } else {
      networkClient = HttpNetworkClient();
    }
  }

  /// Disposes the network client and releases resources.
  void disposeNetworkClient() {
    networkClient?.dispose();
    networkClient = null;
  }
}

/// Mixin for provider initialization checks.
///
/// This mixin provides the common `_checkInitialized()` pattern
/// used across all payment providers.
///
/// ## Usage
///
/// ```dart
/// class MyProvider with InitializationMixin implements PaymentProvider {
///   @override
///   ProviderType get providerType => ProviderType.iyzico;
///
///   Future<PaymentResult> createPayment(PaymentRequest request) async {
///     checkInitialized();
///     // ... rest of implementation
///   }
/// }
/// ```
mixin InitializationMixin {
  /// Whether this provider has been initialized.
  bool _initialized = false;

  /// Whether this provider has been initialized.
  bool get isInitialized => _initialized;

  /// The provider type for error messages.
  ProviderType get providerType;

  /// Marks the provider as initialized.
  void markInitialized() => _initialized = true;

  /// Marks the provider as disposed/uninitialized.
  void markDisposed() => _initialized = false;

  /// Checks if the provider is initialized.
  ///
  /// Throws [PaymentException] if the provider has not been initialized.
  void checkInitialized() {
    if (!_initialized) {
      throw PaymentException.configError(
        message: 'Provider not initialized. Call initialize() first.',
        provider: providerType,
      );
    }
  }
}

/// Mixin for common error handling patterns in payment providers.
///
/// This mixin provides standardized error handling that converts
/// various exceptions to appropriate [PaymentException] types.
///
/// ## Usage
///
/// ```dart
/// class MyProvider with PaymentErrorHandlerMixin implements PaymentProvider {
///   @override
///   ProviderType get providerType => ProviderType.iyzico;
///
///   Future<PaymentResult> createPayment(PaymentRequest request) async {
///     return handlePaymentOperation(
///       () async {
///         // Your payment logic here
///       },
///     );
///   }
/// }
/// ```
mixin PaymentErrorHandlerMixin {
  /// The provider type for error messages.
  ProviderType get providerType;

  /// Executes a payment operation with standard error handling.
  ///
  /// This method wraps the operation and converts any exceptions
  /// to appropriate [PaymentException] types.
  Future<T> handlePaymentOperation<T>(
    Future<T> Function() operation, {
    String? context,
  }) async {
    try {
      return await operation();
    } on PaymentException {
      rethrow;
    } on NetworkException catch (e) {
      if (e.message.contains('timeout') || e.message.contains('Timeout')) {
        throw PaymentException.timeout(provider: providerType);
      }
      throw PaymentException.networkError(
        providerMessage: e.message,
        provider: providerType,
      );
    } on CircuitBreakerOpenException catch (e) {
      throw PaymentException(
        code: 'circuit_breaker_open',
        message: e.userFriendlyMessage,
        provider: providerType,
      );
    } catch (e) {
      throw PaymentException.networkError(
        providerMessage: context != null ? '$context: $e' : e.toString(),
        provider: providerType,
      );
    }
  }
}

/// Mixin for retry and circuit breaker support in payment providers.
///
/// This mixin provides retry logic and circuit breaker patterns
/// for more resilient payment operations.
///
/// ## Usage
///
/// ```dart
/// class MyProvider with ResiliencePatternsMixin implements PaymentProvider {
///   @override
///   ProviderType get providerType => ProviderType.iyzico;
///
///   Future<PaymentResult> createPayment(PaymentRequest request) async {
///     return executeWithResilience(
///       () async {
///         // Your payment logic here
///       },
///       operationType: 'payment',
///     );
///   }
/// }
/// ```
mixin ResiliencePatternsMixin {
  /// The provider type for error messages and circuit breaker naming.
  ProviderType get providerType;

  /// Retry handler for retryable operations.
  RetryHandler? _retryHandler;

  /// Circuit breaker for this provider.
  CircuitBreaker? _circuitBreaker;

  /// Gets or creates a retry handler with the specified config.
  RetryHandler getRetryHandler({RetryConfig? config}) {
    _retryHandler ??= RetryHandler(config: config ?? RetryConfig.conservative);
    return _retryHandler!;
  }

  /// Gets or creates a circuit breaker for this provider.
  CircuitBreaker getCircuitBreaker({CircuitBreakerConfig? config}) {
    _circuitBreaker ??= CircuitBreakerManager.getBreaker(
      providerType.name,
      config: config ?? const CircuitBreakerConfig(),
    );
    return _circuitBreaker!;
  }

  /// Executes an operation with retry logic.
  ///
  /// Use this for read-only operations that can be safely retried.
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    RetryConfig? config,
    RetryCallback? onRetry,
  }) {
    final handler = getRetryHandler(config: config);
    return handler.execute(operation, onRetry: onRetry);
  }

  /// Executes an operation with circuit breaker protection.
  ///
  /// Use this for operations that should fail fast when the
  /// underlying service is having issues.
  Future<T> executeWithCircuitBreaker<T>(
    Future<T> Function() operation, {
    CircuitBreakerConfig? config,
  }) {
    final breaker = getCircuitBreaker(config: config);
    return breaker.execute(operation);
  }

  /// Executes an operation with both circuit breaker and retry protection.
  ///
  /// The circuit breaker wraps the retry logic, so if the service is
  /// down, requests will fail fast without retrying.
  Future<T> executeWithResilience<T>(
    Future<T> Function() operation, {
    String? operationType,
    RetryConfig? retryConfig,
    CircuitBreakerConfig? circuitBreakerConfig,
    RetryCallback? onRetry,
  }) async {
    final breaker = getCircuitBreaker(config: circuitBreakerConfig);

    return breaker.execute(() async {
      // Only use retry for certain operation types
      if (_isRetryableOperation(operationType)) {
        final handler = getRetryHandler(config: retryConfig);
        return handler.execute(operation, onRetry: onRetry);
      }
      return operation();
    });
  }

  /// Determines if an operation type should be retried.
  ///
  /// Payment creation and charge operations should NOT be retried
  /// to avoid duplicate charges. Query operations CAN be retried.
  bool _isRetryableOperation(String? operationType) {
    if (operationType == null) return false;

    const nonRetryableOperations = [
      'payment',
      'charge',
      'create',
      '3ds_init',
      'refund',
    ];

    const retryableOperations = [
      'installment',
      'status',
      'query',
      'cards',
      'bin',
    ];

    final lower = operationType.toLowerCase();

    // Explicitly non-retryable
    for (final op in nonRetryableOperations) {
      if (lower.contains(op)) return false;
    }

    // Explicitly retryable
    for (final op in retryableOperations) {
      if (lower.contains(op)) return true;
    }

    // Default to non-retryable for safety
    return false;
  }

  /// Resets the circuit breaker for this provider.
  ///
  /// Call this when you know the underlying service has recovered.
  void resetCircuitBreaker() {
    _circuitBreaker?.reset();
  }

  /// Disposes resilience resources.
  void disposeResilienceResources() {
    _retryHandler = null;
    _circuitBreaker = null;
  }
}

/// Combined mixin that includes all common provider functionality.
///
/// Use this mixin for convenience when you need all the standard
/// provider capabilities.
///
/// ## Usage
///
/// ```dart
/// class MyProvider with ProviderMixin implements PaymentProvider {
///   @override
///   ProviderType get providerType => ProviderType.iyzico;
///
///   Future<void> initialize(PaymentConfig config) async {
///     initializeNetworkClient();
///     markInitialized();
///   }
///
///   Future<PaymentResult> createPayment(PaymentRequest request) async {
///     checkInitialized();
///     return handlePaymentOperation(() async {
///       // Your implementation
///     });
///   }
/// }
/// ```
mixin ProviderMixin
    implements
        NetworkClientMixin,
        InitializationMixin,
        PaymentErrorHandlerMixin,
        ResiliencePatternsMixin {
  /// Disposes all provider resources.
  void disposeProvider() {
    disposeNetworkClient();
    disposeResilienceResources();
    markDisposed();
  }
}
