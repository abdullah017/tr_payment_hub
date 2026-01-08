import 'package:meta/meta.dart';

import '../core/enums.dart';

/// Backend proxy configuration for Flutter + Custom Backend architecture.
///
/// This configuration does NOT contain any API credentials.
/// All sensitive data (API keys, secrets) should be stored in your backend.
///
/// ## Example
///
/// ```dart
/// final config = ProxyConfig(
///   baseUrl: 'https://api.yourbackend.com/payment',
///   defaultProvider: ProviderType.iyzico,
///   authToken: 'user_jwt_token', // Optional user authentication
///   timeout: Duration(seconds: 30),
/// );
///
/// final provider = ProxyPaymentProvider(config: config);
/// await provider.initializeWithProvider(ProviderType.iyzico);
/// ```
@immutable
class ProxyConfig {
  /// Creates a new [ProxyConfig] instance.
  ///
  /// [baseUrl] is required and should point to your backend's payment API.
  /// The provider will append endpoint paths to this URL.
  const ProxyConfig({
    required this.baseUrl,
    this.defaultProvider,
    this.authToken,
    this.headers,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });

  /// Backend API base URL.
  ///
  /// Example: 'https://api.yourbackend.com/payment'
  ///
  /// The proxy provider will append endpoint paths to this URL:
  /// - POST {baseUrl}/create
  /// - POST {baseUrl}/3ds/init
  /// - GET {baseUrl}/installments
  /// - etc.
  final String baseUrl;

  /// Default payment provider type.
  ///
  /// This will be sent to the backend in each request.
  /// Can be overridden per-request or when calling [initializeWithProvider].
  final ProviderType? defaultProvider;

  /// Authorization token (e.g., JWT token).
  ///
  /// If provided, will be sent as `Authorization: Bearer {authToken}` header.
  /// Use this for user authentication with your backend.
  final String? authToken;

  /// Custom HTTP headers to include in all requests.
  ///
  /// These headers are merged with default headers.
  /// Useful for custom authentication schemes or tracking.
  final Map<String, String>? headers;

  /// HTTP request timeout.
  ///
  /// Defaults to 30 seconds. Minimum recommended is 15 seconds
  /// to account for 3DS redirects and bank processing.
  final Duration timeout;

  /// Maximum number of retry attempts for failed requests.
  ///
  /// Only applies to network errors and timeouts.
  /// Payment failures (e.g., declined cards) are not retried.
  /// Defaults to 3.
  final int maxRetries;

  /// Delay between retry attempts.
  ///
  /// Defaults to 1 second. Uses simple fixed delay (not exponential backoff).
  final Duration retryDelay;

  /// Returns all HTTP headers to include in requests.
  ///
  /// Combines default headers with custom headers and auth token.
  Map<String, String> get allHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
        ...?headers,
      };

  /// Validates the configuration.
  ///
  /// Returns true if the configuration is valid, false otherwise.
  ///
  /// Validation rules:
  /// - baseUrl must not be empty
  /// - baseUrl must start with http:// or https://
  /// - timeout must be at least 5 seconds
  /// - maxRetries must be non-negative
  bool validate() {
    if (baseUrl.isEmpty) return false;
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      return false;
    }
    if (timeout.inSeconds < 5) return false;
    if (maxRetries < 0) return false;
    return true;
  }

  /// Returns a list of validation errors, or empty list if valid.
  List<String> get validationErrors {
    final errors = <String>[];
    if (baseUrl.isEmpty) {
      errors.add('baseUrl cannot be empty');
    } else if (!baseUrl.startsWith('http://') &&
        !baseUrl.startsWith('https://')) {
      errors.add('baseUrl must start with http:// or https://');
    }
    if (timeout.inSeconds < 5) {
      errors.add('timeout must be at least 5 seconds');
    }
    if (maxRetries < 0) {
      errors.add('maxRetries cannot be negative');
    }
    return errors;
  }

  /// Creates a copy with the given fields replaced.
  ProxyConfig copyWith({
    String? baseUrl,
    ProviderType? defaultProvider,
    String? authToken,
    Map<String, String>? headers,
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
  }) {
    return ProxyConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      defaultProvider: defaultProvider ?? this.defaultProvider,
      authToken: authToken ?? this.authToken,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProxyConfig &&
          runtimeType == other.runtimeType &&
          baseUrl == other.baseUrl &&
          defaultProvider == other.defaultProvider &&
          authToken == other.authToken &&
          timeout == other.timeout &&
          maxRetries == other.maxRetries &&
          retryDelay == other.retryDelay;

  @override
  int get hashCode => Object.hash(
        baseUrl,
        defaultProvider,
        authToken,
        timeout,
        maxRetries,
        retryDelay,
      );

  @override
  String toString() => 'ProxyConfig(baseUrl: $baseUrl, '
      'provider: ${defaultProvider?.name ?? 'none'}, '
      'timeout: ${timeout.inSeconds}s)';
}
