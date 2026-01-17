import '../../utils/log_sanitizer.dart';
import 'payment_logger.dart';

/// Configuration for request/response logging.
class RequestLoggerConfig {
  /// Creates a request logger configuration.
  const RequestLoggerConfig({
    this.logRequests = true,
    this.logResponses = true,
    this.logHeaders = false,
    this.logBody = true,
    this.maxBodyLength = 1000,
  });

  /// Default configuration that logs requests and responses with body.
  static const RequestLoggerConfig defaults = RequestLoggerConfig();

  /// Minimal configuration that only logs URLs and status codes.
  static const RequestLoggerConfig minimal = RequestLoggerConfig(
    logHeaders: false,
    logBody: false,
  );

  /// Full configuration that logs everything including headers.
  static const RequestLoggerConfig full = RequestLoggerConfig(
    logHeaders: true,
    logBody: true,
    maxBodyLength: 5000,
  );

  /// Whether to log outgoing requests.
  final bool logRequests;

  /// Whether to log incoming responses.
  final bool logResponses;

  /// Whether to log headers (automatically sanitized).
  final bool logHeaders;

  /// Whether to log request/response body (automatically sanitized).
  final bool logBody;

  /// Maximum body length to log (truncated if longer).
  final int maxBodyLength;
}

/// Callback type for request logging.
typedef RequestLogCallback = void Function(RequestLogEntry entry);

/// Represents a logged HTTP request.
class RequestLogEntry {
  /// Creates a request log entry.
  const RequestLogEntry({
    required this.method,
    required this.url,
    required this.timestamp,
    this.headers,
    this.body,
    this.response,
    this.statusCode,
    this.duration,
    this.error,
  });

  /// HTTP method (GET, POST, etc.)
  final String method;

  /// Request URL (may be sanitized if contains sensitive params).
  final String url;

  /// Timestamp when the request was made.
  final DateTime timestamp;

  /// Request headers (sanitized).
  final Map<String, String>? headers;

  /// Request body (sanitized and possibly truncated).
  final String? body;

  /// Response body (sanitized and possibly truncated).
  final String? response;

  /// HTTP status code of the response.
  final int? statusCode;

  /// Duration of the request.
  final Duration? duration;

  /// Error message if the request failed.
  final String? error;

  /// Whether this is a successful request (2xx status code).
  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// Whether this request resulted in an error.
  bool get isError =>
      error != null || (statusCode != null && statusCode! >= 400);

  @override
  String toString() {
    final buffer = StringBuffer()..write('[$method] $url');

    if (statusCode != null) {
      buffer.write(' -> $statusCode');
    }

    if (duration != null) {
      buffer.write(' (${duration!.inMilliseconds}ms)');
    }

    if (error != null) {
      buffer.write(' ERROR: $error');
    }

    return buffer.toString();
  }

  /// Converts to a map representation for logging.
  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'url': url,
      'timestamp': timestamp.toIso8601String(),
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (response != null) 'response': response,
      if (statusCode != null) 'statusCode': statusCode,
      if (duration != null) 'durationMs': duration!.inMilliseconds,
      if (error != null) 'error': error,
    };
  }
}

/// Request/response logger for payment operations.
///
/// This logger automatically sanitizes sensitive data before logging
/// and integrates with the [PaymentLogger] for consistent output.
///
/// ## Usage
///
/// ```dart
/// // Create a request logger
/// final logger = RequestLogger(
///   config: RequestLoggerConfig.defaults,
///   onLog: (entry) => print(entry),
/// );
///
/// // Log a request before sending
/// logger.logRequest(
///   method: 'POST',
///   url: 'https://api.example.com/payment',
///   body: '{"amount": 100}',
/// );
///
/// // Log the response after receiving
/// logger.logResponse(
///   method: 'POST',
///   url: 'https://api.example.com/payment',
///   statusCode: 200,
///   body: '{"success": true}',
///   duration: Duration(milliseconds: 150),
/// );
/// ```
class RequestLogger {
  /// Creates a request logger with optional configuration and callback.
  RequestLogger({
    this.config = const RequestLoggerConfig(),
    this.onLog,
  });

  /// Logger configuration.
  final RequestLoggerConfig config;

  /// Optional callback for custom log handling.
  final RequestLogCallback? onLog;

  /// Log an outgoing HTTP request.
  void logRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) {
    if (!config.logRequests) return;

    final sanitizedHeaders =
        config.logHeaders && headers != null ? _sanitizeHeaders(headers) : null;

    final sanitizedBody =
        config.logBody && body != null ? _sanitizeAndTruncate(body) : null;

    final entry = RequestLogEntry(
      method: method,
      url: _sanitizeUrl(url),
      timestamp: DateTime.now(),
      headers: sanitizedHeaders,
      body: sanitizedBody,
    );

    _emitLog(entry, isRequest: true);
  }

  /// Log an incoming HTTP response.
  void logResponse({
    required String method,
    required String url,
    required int statusCode,
    String? body,
    Duration? duration,
  }) {
    if (!config.logResponses) return;

    final sanitizedBody =
        config.logBody && body != null ? _sanitizeAndTruncate(body) : null;

    final entry = RequestLogEntry(
      method: method,
      url: _sanitizeUrl(url),
      timestamp: DateTime.now(),
      statusCode: statusCode,
      response: sanitizedBody,
      duration: duration,
    );

    _emitLog(entry, isRequest: false);
  }

  /// Log a failed HTTP request.
  void logError({
    required String method,
    required String url,
    required String error,
    Duration? duration,
  }) {
    final entry = RequestLogEntry(
      method: method,
      url: _sanitizeUrl(url),
      timestamp: DateTime.now(),
      error: LogSanitizer.sanitize(error),
      duration: duration,
    );

    _emitLog(entry, isRequest: false, isError: true);
  }

  /// Emit the log entry through callback and PaymentLogger.
  void _emitLog(
    RequestLogEntry entry, {
    required bool isRequest,
    bool isError = false,
  }) {
    // Call custom callback if provided
    onLog?.call(entry);

    // Also log through PaymentLogger if initialized
    if (PaymentLogger.isInitialized) {
      final prefix = isRequest ? 'HTTP Request' : 'HTTP Response';

      if (isError) {
        PaymentLogger.error(
          '$prefix: ${entry.method} ${entry.url}',
          error: entry.error,
          data: entry.toMap(),
        );
      } else if (entry.isError) {
        PaymentLogger.warning(
          '$prefix: ${entry.method} ${entry.url} -> ${entry.statusCode}',
          data: entry.toMap(),
        );
      } else {
        PaymentLogger.debug(
          '$prefix: ${entry.method} ${entry.url}${entry.statusCode != null ? ' -> ${entry.statusCode}' : ''}',
          data: entry.toMap(),
        );
      }
    }
  }

  /// Sanitize a URL by removing sensitive query parameters.
  String _sanitizeUrl(String url) {
    // Sanitize any sensitive data that might be in the URL
    return LogSanitizer.sanitize(url);
  }

  /// Sanitize headers by masking sensitive values.
  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    const sensitiveHeaders = [
      'authorization',
      'x-api-key',
      'x-auth-token',
      'cookie',
      'set-cookie',
    ];

    for (final entry in headers.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (sensitiveHeaders.contains(lowerKey)) {
        // Show only first few characters for debugging
        final value = entry.value;
        if (value.length > 10) {
          sanitized[entry.key] = '${value.substring(0, 6)}...***MASKED***';
        } else {
          sanitized[entry.key] = '***MASKED***';
        }
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }

  /// Sanitize and truncate body content.
  String _sanitizeAndTruncate(String body) {
    var sanitized = LogSanitizer.sanitize(body);

    if (sanitized.length > config.maxBodyLength) {
      sanitized =
          '${sanitized.substring(0, config.maxBodyLength)}... [TRUNCATED]';
    }

    return sanitized;
  }
}
