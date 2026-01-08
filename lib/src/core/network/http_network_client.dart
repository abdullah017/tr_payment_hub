import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'network_client.dart';

/// Default [NetworkClient] implementation using the `http` package.
///
/// This is the default HTTP client used by all payment providers when
/// no custom client is specified.
///
/// ## Example Usage
///
/// ```dart
/// // Create with default http.Client
/// final client = HttpNetworkClient();
///
/// // Create with custom http.Client (for testing)
/// final mockHttpClient = MockClient(...);
/// final client = HttpNetworkClient(client: mockHttpClient);
///
/// // Use with provider
/// final provider = IyzicoProvider(networkClient: client);
/// ```
///
/// ## Timeout Handling
///
/// The client supports request-level timeouts. If no timeout is specified,
/// it uses a default of 30 seconds.
///
/// ## Testing
///
/// For testing, you can inject a mock `http.Client`:
///
/// ```dart
/// final mockClient = MockClient((request) async {
///   return http.Response('{"status": "success"}', 200);
/// });
/// final networkClient = HttpNetworkClient(client: mockClient);
/// ```
class HttpNetworkClient implements NetworkClient {
  /// Creates an [HttpNetworkClient] with optional custom [http.Client].
  ///
  /// If no client is provided, a new [http.Client] is created.
  HttpNetworkClient({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  /// Default timeout for requests.
  static const defaultTimeout = Duration(seconds: 30);

  @override
  Future<NetworkResponse> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? defaultTimeout);

      return NetworkResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw _handleError(e, url);
    }
  }

  @override
  Future<NetworkResponse> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(timeout ?? defaultTimeout);

      return NetworkResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw _handleError(e, url);
    }
  }

  @override
  Future<NetworkResponse> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(timeout ?? defaultTimeout);

      return NetworkResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw _handleError(e, url);
    }
  }

  @override
  Future<NetworkResponse> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .delete(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? defaultTimeout);

      return NetworkResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw _handleError(e, url);
    }
  }

  @override
  Future<NetworkResponse> postForm(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    try {
      final mergedHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded',
        ...?headers,
      };

      // Encode form fields
      final encodedBody = fields?.entries
              .map((e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
              .join('&') ??
          '';

      final response = await _client
          .post(
            Uri.parse(url),
            headers: mergedHeaders,
            body: encodedBody,
          )
          .timeout(timeout ?? defaultTimeout);

      return NetworkResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw _handleError(e, url);
    }
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Converts various exceptions to [NetworkException].
  NetworkException _handleError(Object error, String url) {
    if (error is TimeoutException) {
      return NetworkException.timeout(url);
    }

    if (error is SocketException) {
      return NetworkException(
        message: 'Connection failed: ${error.message}',
      );
    }

    if (error is HttpException) {
      return NetworkException(
        message: 'HTTP error: ${error.message}',
        originalError: error,
      );
    }

    if (error is NetworkException) {
      return error;
    }

    return NetworkException(
      message: error.toString(),
      originalError: error,
    );
  }
}
