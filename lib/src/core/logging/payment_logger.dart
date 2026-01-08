import '../../utils/log_sanitizer.dart';

/// Log level enumeration
enum LogLevel {
  /// Debug level - detailed information for debugging
  debug,

  /// Info level - general operational information
  info,

  /// Warning level - potential issues
  warning,

  /// Error level - error conditions
  error,
}

/// Log entry structure
class LogEntry {
  /// Creates a log entry
  const LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.data,
    this.error,
    this.stackTrace,
  });

  /// Log level
  final LogLevel level;

  /// Log message (already sanitized)
  final String message;

  /// Timestamp of the log entry
  final DateTime timestamp;

  /// Additional data (already sanitized)
  final Map<String, dynamic>? data;

  /// Error object if any
  final Object? error;

  /// Stack trace if any
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('[${timestamp.toIso8601String()}] ')
      ..write('[${level.name.toUpperCase()}] ')
      ..write(message);

    if (data != null && data!.isNotEmpty) {
      buffer.write(' | Data: $data');
    }

    if (error != null) {
      buffer.write(' | Error: $error');
    }

    return buffer.toString();
  }
}

/// Callback type for log handlers
typedef LogCallback = void Function(LogEntry entry);

/// Secure payment logger with automatic sanitization
///
/// Bu logger, hassas verileri otomatik olarak maskeler.
/// Kullanmadan önce [initialize] metodunu çağırarak
/// log callback'ini ayarlamanız gerekir.
///
/// Örnek kullanım:
/// ```dart
/// PaymentLogger.initialize(
///   logCallback: (entry) => print(entry),
///   minLevel: LogLevel.info,
/// );
///
/// PaymentLogger.info('Payment processed', data: {'orderId': '123'});
/// PaymentLogger.error('Payment failed', error: e, stackTrace: st);
/// ```
class PaymentLogger {
  PaymentLogger._();

  static LogCallback? _logCallback;
  static LogLevel _minLevel = LogLevel.info;
  static bool _initialized = false;

  /// Whether the logger is initialized
  static bool get isInitialized => _initialized;

  /// Current minimum log level
  static LogLevel get minLevel => _minLevel;

  /// Set minimum log level
  static set minLevel(LogLevel level) => _minLevel = level;

  /// Initialize the payment logger
  ///
  /// [logCallback] - Function to handle log entries
  /// [minLevel] - Minimum log level to process (default: info)
  static void initialize({
    required LogCallback logCallback,
    LogLevel minLevel = LogLevel.info,
  }) {
    _logCallback = logCallback;
    _minLevel = minLevel;
    _initialized = true;
  }

  /// Initialize with a simple print callback
  static void initializeWithPrint({LogLevel minLevel = LogLevel.info}) {
    initialize(
      logCallback: _defaultPrintCallback,
      minLevel: minLevel,
    );
  }

  // ignore: avoid_print
  static void _defaultPrintCallback(LogEntry entry) => print(entry);

  /// Reset the logger (useful for testing)
  static void reset() {
    _logCallback = null;
    _minLevel = LogLevel.info;
    _initialized = false;
  }

  /// Log a debug message
  static void debug(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.debug, message, data: data);
  }

  /// Log an info message
  static void info(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.info, message, data: data);
  }

  /// Log a warning message
  static void warning(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.warning, message, data: data);
  }

  /// Log an error message
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    _log(
      LogLevel.error,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Internal log method
  static void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Skip if not initialized or below minimum level
    if (!_initialized || _logCallback == null) return;
    if (level.index < _minLevel.index) return;

    // Sanitize message
    final sanitizedMessage = LogSanitizer.sanitize(message);

    // Sanitize data
    final sanitizedData = data != null ? LogSanitizer.sanitizeMap(data) : null;

    // Sanitize error message
    final sanitizedError =
        error != null ? LogSanitizer.sanitize(error.toString()) : null;

    // Create log entry
    final entry = LogEntry(
      level: level,
      message: sanitizedMessage,
      timestamp: DateTime.now(),
      data: sanitizedData,
      error: sanitizedError,
      stackTrace: stackTrace,
    );

    // Call the registered callback
    _logCallback!(entry);
  }

  /// Log a payment operation start
  static void logPaymentStart({
    required String provider,
    required String orderId,
    required double amount,
  }) {
    info(
      'Payment started',
      data: {
        'provider': provider,
        'orderId': orderId,
        'amount': amount,
      },
    );
  }

  /// Log a payment operation success
  static void logPaymentSuccess({
    required String provider,
    required String orderId,
    required String transactionId,
  }) {
    info(
      'Payment successful',
      data: {
        'provider': provider,
        'orderId': orderId,
        'transactionId': transactionId,
      },
    );
  }

  /// Log a payment operation failure
  static void logPaymentFailure({
    required String provider,
    required String orderId,
    required String errorCode,
    String? errorMessage,
  }) {
    warning(
      'Payment failed',
      data: {
        'provider': provider,
        'orderId': orderId,
        'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      },
    );
  }

  /// Log a 3DS operation
  static void log3DSEvent({
    required String provider,
    required String orderId,
    required String event,
    Map<String, dynamic>? additionalData,
  }) {
    info(
      '3DS event: $event',
      data: {
        'provider': provider,
        'orderId': orderId,
        ...?additionalData,
      },
    );
  }

  /// Log a refund operation
  static void logRefund({
    required String provider,
    required String transactionId,
    required double amount,
    required bool success,
  }) {
    final message = success ? 'Refund successful' : 'Refund failed';
    final logMethod = success ? info : warning;
    logMethod(
      message,
      data: {
        'provider': provider,
        'transactionId': transactionId,
        'amount': amount,
      },
    );
  }
}
