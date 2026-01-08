import 'package:meta/meta.dart';

/// HTTP response from network operations.
///
/// Wraps the response data from HTTP requests in a provider-agnostic format.
///
/// ## Example
///
/// ```dart
/// final response = await networkClient.post(
///   'https://api.example.com/payment',
///   body: jsonEncode(data),
///   headers: {'Content-Type': 'application/json'},
/// );
///
/// if (response.isSuccess) {
///   final data = jsonDecode(response.body);
/// }
/// ```
@immutable
class NetworkResponse {
  /// Creates a new [NetworkResponse] instance.
  const NetworkResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  /// Creates a successful response (200 OK).
  factory NetworkResponse.success(String body) => NetworkResponse(
        statusCode: 200,
        body: body,
      );

  /// Creates an error response.
  factory NetworkResponse.error(int statusCode, String body) => NetworkResponse(
        statusCode: statusCode,
        body: body,
      );

  /// HTTP status code of the response.
  final int statusCode;

  /// Response body as a string.
  final String body;

  /// Response headers.
  final Map<String, String> headers;

  /// Whether the response indicates success (2xx status code).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the response indicates a client error (4xx status code).
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the response indicates a server error (5xx status code).
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  @override
  String toString() => 'NetworkResponse(statusCode: $statusCode, '
      'bodyLength: ${body.length}, isSuccess: $isSuccess)';
}

/// Abstract HTTP client interface for making network requests.
///
/// This interface allows using different HTTP client implementations
/// (http package, Dio, custom implementations) with the payment providers.
///
/// ## Default Implementation
///
/// The package provides [HttpNetworkClient] as the default implementation
/// using the `http` package.
///
/// ## Custom Implementation Example (Dio)
///
/// ```dart
/// class DioNetworkClient implements NetworkClient {
///   DioNetworkClient({Dio? dio}) : _dio = dio ?? Dio();
///   final Dio _dio;
///
///   @override
///   Future<NetworkResponse> post(
///     String url, {
///     Map<String, String>? headers,
///     dynamic body,
///     Duration? timeout,
///   }) async {
///     final response = await _dio.post(
///       url,
///       data: body,
///       options: Options(
///         headers: headers,
///         sendTimeout: timeout,
///         receiveTimeout: timeout,
///       ),
///     );
///     return NetworkResponse(
///       statusCode: response.statusCode ?? 0,
///       body: response.data?.toString() ?? '',
///       headers: response.headers.map.map((k, v) => MapEntry(k, v.join(','))),
///     );
///   }
///
///   // ... implement other methods
/// }
/// ```
///
/// ## Using Custom Client with Providers
///
/// ```dart
/// final dioClient = DioNetworkClient();
/// final provider = IyzicoProvider(networkClient: dioClient);
/// await provider.initialize(config);
/// ```
abstract class NetworkClient {
  /// Performs an HTTP GET request.
  ///
  /// [url] - The full URL to request.
  /// [headers] - Optional HTTP headers.
  /// [timeout] - Optional request timeout.
  ///
  /// Returns a [NetworkResponse] with the result.
  Future<NetworkResponse> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  });

  /// Performs an HTTP POST request.
  ///
  /// [url] - The full URL to request.
  /// [headers] - Optional HTTP headers.
  /// [body] - Request body (will be encoded based on Content-Type).
  /// [timeout] - Optional request timeout.
  ///
  /// Returns a [NetworkResponse] with the result.
  Future<NetworkResponse> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  });

  /// Performs an HTTP PUT request.
  ///
  /// [url] - The full URL to request.
  /// [headers] - Optional HTTP headers.
  /// [body] - Request body (will be encoded based on Content-Type).
  /// [timeout] - Optional request timeout.
  ///
  /// Returns a [NetworkResponse] with the result.
  Future<NetworkResponse> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  });

  /// Performs an HTTP DELETE request.
  ///
  /// [url] - The full URL to request.
  /// [headers] - Optional HTTP headers.
  /// [timeout] - Optional request timeout.
  ///
  /// Returns a [NetworkResponse] with the result.
  Future<NetworkResponse> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  });

  /// Performs an HTTP POST request with form-encoded body.
  ///
  /// This is useful for payment providers that require
  /// application/x-www-form-urlencoded content type.
  ///
  /// [url] - The full URL to request.
  /// [headers] - Optional HTTP headers.
  /// [fields] - Form fields as key-value pairs.
  /// [timeout] - Optional request timeout.
  ///
  /// Returns a [NetworkResponse] with the result.
  Future<NetworkResponse> postForm(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    Duration? timeout,
  });

  /// Releases any resources held by the client.
  ///
  /// After calling dispose, the client should not be used.
  void dispose();
}

/// Exception thrown when a network operation fails.
///
/// This is a low-level exception used by [NetworkClient] implementations.
/// Payment providers typically catch this and throw [PaymentException] instead.
class NetworkException implements Exception {
  /// Creates a new [NetworkException].
  const NetworkException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  /// Creates a timeout exception.
  factory NetworkException.timeout([String? url]) => NetworkException(
        message: 'Request timed out${url != null ? ': $url' : ''}',
      );

  /// Creates a connection exception.
  factory NetworkException.connection([String? message]) => NetworkException(
        message: message ?? 'Connection failed',
      );

  /// Human-readable error message.
  final String message;

  /// HTTP status code if available.
  final int? statusCode;

  /// Original error that caused this exception.
  final Object? originalError;

  @override
  String toString() => 'NetworkException: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
