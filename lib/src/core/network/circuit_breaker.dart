import 'dart:async';

/// Circuit breaker states
enum CircuitState {
  /// Circuit is closed - normal operation
  closed,

  /// Circuit is open - rejecting all requests
  open,

  /// Circuit is half-open - allowing test requests
  halfOpen,
}

/// Circuit breaker configuration
class CircuitBreakerConfig {
  /// Creates a circuit breaker configuration
  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.successThreshold = 2,
    this.timeout = const Duration(seconds: 30),
    this.halfOpenMaxCalls = 3,
  });

  /// Number of failures before opening the circuit
  final int failureThreshold;

  /// Number of successes in half-open state to close the circuit
  final int successThreshold;

  /// Time to wait before transitioning from open to half-open
  final Duration timeout;

  /// Maximum concurrent calls allowed in half-open state
  final int halfOpenMaxCalls;

  /// Strict configuration - opens circuit faster
  static const strict = CircuitBreakerConfig(
    failureThreshold: 3,
    timeout: Duration(seconds: 60),
  );

  /// Lenient configuration - more tolerant to failures
  static const lenient = CircuitBreakerConfig(
    failureThreshold: 10,
    successThreshold: 1,
    timeout: Duration(seconds: 15),
  );

  @override
  String toString() =>
      'CircuitBreakerConfig(failureThreshold: $failureThreshold, '
      'timeout: ${timeout.inSeconds}s)';
}

/// Exception thrown when circuit breaker is open
class CircuitBreakerOpenException implements Exception {
  /// Creates a circuit breaker open exception
  const CircuitBreakerOpenException({
    required this.circuitName,
    required this.remainingTime,
  });

  /// Name of the circuit that is open
  final String circuitName;

  /// Remaining time until the circuit transitions to half-open
  final Duration remainingTime;

  @override
  String toString() =>
      'CircuitBreakerOpenException: Circuit "$circuitName" is open. '
      'Try again in ${remainingTime.inSeconds} seconds.';

  /// User-friendly message
  String get userFriendlyMessage => 'Servis geçici olarak kullanılamıyor. '
      '${remainingTime.inSeconds} saniye sonra tekrar deneyin.';
}

/// Circuit breaker implementation for fault tolerance
///
/// Circuit breaker pattern, bir servisin sürekli hata vermesi durumunda
/// isteklerin tamamen reddedilmesini sağlar. Bu sayede:
/// - Kaynak tüketimi azalır
/// - Hatalı servise gereksiz istek yapılmaz
/// - Servis toparlanmak için zaman kazanır
///
/// Örnek kullanım:
/// ```dart
/// final breaker = CircuitBreaker(name: 'iyzico');
///
/// try {
///   final result = await breaker.execute(() => makePayment());
/// } on CircuitBreakerOpenException catch (e) {
///   print('Service unavailable: ${e.userFriendlyMessage}');
/// }
/// ```
class CircuitBreaker {
  /// Creates a circuit breaker with the given name and configuration
  CircuitBreaker({
    required this.name,
    this.config = const CircuitBreakerConfig(),
  });

  /// Name of this circuit breaker (for logging/identification)
  final String name;

  /// Circuit breaker configuration
  final CircuitBreakerConfig config;

  /// Current state of the circuit
  CircuitState _state = CircuitState.closed;

  /// Number of consecutive failures
  int _failureCount = 0;

  /// Number of successes in half-open state
  int _successCount = 0;

  /// Number of concurrent calls in half-open state
  int _halfOpenCalls = 0;

  /// Time of the last failure
  DateTime? _lastFailureTime;

  /// Current state of the circuit
  CircuitState get state => _state;

  /// Whether the circuit is open
  bool get isOpen => _state == CircuitState.open;

  /// Whether the circuit is closed (normal operation)
  bool get isClosed => _state == CircuitState.closed;

  /// Whether the circuit is half-open (testing)
  bool get isHalfOpen => _state == CircuitState.halfOpen;

  /// Current failure count
  int get failureCount => _failureCount;

  /// Execute an operation with circuit breaker protection
  ///
  /// Throws [CircuitBreakerOpenException] if the circuit is open.
  Future<T> execute<T>(Future<T> Function() operation) async {
    // Check and potentially update state
    _checkState();

    // Reject if circuit is open
    if (_state == CircuitState.open) {
      throw CircuitBreakerOpenException(
        circuitName: name,
        remainingTime: _getRemainingTimeout(),
      );
    }

    // Limit concurrent calls in half-open state
    if (_state == CircuitState.halfOpen) {
      if (_halfOpenCalls >= config.halfOpenMaxCalls) {
        throw CircuitBreakerOpenException(
          circuitName: name,
          remainingTime: Duration.zero,
        );
      }
      _halfOpenCalls++;
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  /// Check state and potentially transition from open to half-open
  void _checkState() {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed >= config.timeout) {
        _state = CircuitState.halfOpen;
        _halfOpenCalls = 0;
        _successCount = 0;
      }
    }
  }

  /// Handle successful operation
  void _onSuccess() {
    if (_state == CircuitState.halfOpen) {
      _successCount++;
      _halfOpenCalls--;
      if (_successCount >= config.successThreshold) {
        _reset();
      }
    } else if (_state == CircuitState.closed) {
      // Reset failure count on success
      _failureCount = 0;
    }
  }

  /// Handle failed operation
  void _onFailure() {
    _lastFailureTime = DateTime.now();
    _failureCount++;

    if (_state == CircuitState.halfOpen) {
      // Any failure in half-open state reopens the circuit
      _state = CircuitState.open;
      _halfOpenCalls = 0;
    } else if (_failureCount >= config.failureThreshold) {
      // Threshold reached - open the circuit
      _state = CircuitState.open;
    }
  }

  /// Reset the circuit breaker to closed state
  void _reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _successCount = 0;
    _halfOpenCalls = 0;
  }

  /// Get remaining time until transition from open to half-open
  Duration _getRemainingTimeout() {
    if (_lastFailureTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastFailureTime!);
    final remaining = config.timeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Manually reset the circuit breaker to closed state
  ///
  /// Use this when you know the underlying service has recovered.
  void reset() => _reset();

  /// Force the circuit to open state
  ///
  /// Use this when you want to manually stop requests to a service.
  void forceOpen() {
    _state = CircuitState.open;
    _lastFailureTime = DateTime.now();
  }

  @override
  String toString() => 'CircuitBreaker(name: $name, state: $_state, '
      'failures: $_failureCount/${config.failureThreshold})';
}

/// Manager for multiple circuit breakers
class CircuitBreakerManager {
  CircuitBreakerManager._();

  static final _breakers = <String, CircuitBreaker>{};

  /// Get or create a circuit breaker with the given name
  static CircuitBreaker getBreaker(
    String name, {
    CircuitBreakerConfig config = const CircuitBreakerConfig(),
  }) =>
      _breakers.putIfAbsent(
        name,
        () => CircuitBreaker(name: name, config: config),
      );

  /// Get an existing circuit breaker
  static CircuitBreaker? get(String name) => _breakers[name];

  /// Reset all circuit breakers
  static void resetAll() {
    for (final breaker in _breakers.values) {
      breaker.reset();
    }
  }

  /// Get status of all circuit breakers
  static Map<String, CircuitState> get status =>
      _breakers.map((name, breaker) => MapEntry(name, breaker.state));

  /// Remove a circuit breaker
  static void remove(String name) => _breakers.remove(name);
}
