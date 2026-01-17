/// Network utilities for TR Payment Hub.
///
/// This library provides the HTTP client abstraction layer that allows
/// using different HTTP client implementations with payment providers.
///
/// ## Core Components
///
/// - [NetworkClient] - Abstract interface for HTTP operations
/// - [HttpNetworkClient] - Default implementation using `http` package
/// - [NetworkResponse] - Response wrapper
/// - [NetworkException] - Network error exception
///
/// ## Custom HTTP Client Example
///
/// To use Dio instead of the default http package:
///
/// ```dart
/// import 'package:dio/dio.dart';
/// import 'package:tr_payment_hub/tr_payment_hub.dart';
///
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
///     final response = await _dio.post(url, data: body);
///     return NetworkResponse(
///       statusCode: response.statusCode ?? 0,
///       body: response.data?.toString() ?? '',
///     );
///   }
///
///   // ... implement other methods
/// }
///
/// // Use with provider
/// final provider = IyzicoProvider(networkClient: DioNetworkClient());
/// ```
library;

export 'circuit_breaker.dart';
export 'http_network_client.dart';
export 'network_client.dart';
export 'resilient_network_client.dart';
export 'retry_handler.dart';
