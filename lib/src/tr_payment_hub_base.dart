import 'client/proxy_config.dart';
import 'client/proxy_payment_provider.dart';
import 'core/enums.dart';
import 'core/exceptions/payment_exception.dart';
import 'core/payment_provider.dart';
import 'providers/iyzico/iyzico_provider.dart';
import 'providers/param/param_provider.dart';
import 'providers/paytr/paytr_provider.dart';
import 'providers/sipay/sipay_provider.dart';
import 'testing/mock_payment_provider.dart';

/// TR Payment Hub - Main Factory Class
///
/// Unified API for Turkish payment systems.
/// Supports both direct mode (Dart backend) and proxy mode (Flutter + any backend).
///
/// ## Direct Mode (Dart Backend)
///
/// ```dart
/// final provider = TrPaymentHub.create(ProviderType.iyzico);
/// await provider.initialize(IyzicoConfig(
///   apiKey: 'xxx',
///   secretKey: 'xxx',
///   merchantId: 'xxx',
/// ));
/// final result = await provider.createPayment(request);
/// ```
///
/// ## Proxy Mode (Flutter + Custom Backend) - RECOMMENDED
///
/// ```dart
/// final provider = TrPaymentHub.createProxy(
///   baseUrl: 'https://api.yourbackend.com/payment',
///   provider: ProviderType.iyzico,
///   authToken: 'user_jwt_token', // Optional
/// );
/// await provider.initializeWithProvider(ProviderType.iyzico);
/// final result = await provider.createPayment(request);
/// ```
class TrPaymentHub {
  TrPaymentHub._();

  /// Creates a direct payment provider (for Dart backend use).
  ///
  /// **Warning:** This method requires API credentials to be passed during
  /// initialization. Do NOT use this in Flutter client apps as it exposes
  /// sensitive credentials. Use [createProxy] instead for Flutter apps.
  ///
  /// ```dart
  /// final provider = TrPaymentHub.create(ProviderType.iyzico);
  /// await provider.initialize(IyzicoConfig(
  ///   apiKey: 'xxx',
  ///   secretKey: 'xxx',
  ///   merchantId: 'xxx',
  /// ));
  /// ```
  static PaymentProvider create(ProviderType type) {
    switch (type) {
      case ProviderType.iyzico:
        return IyzicoProvider();
      case ProviderType.paytr:
        return PayTRProvider();
      case ProviderType.param:
        return ParamProvider();
      case ProviderType.sipay:
        return SipayProvider();
    }
  }

  /// Creates a proxy payment provider (for Flutter + Custom Backend).
  ///
  /// This is the **RECOMMENDED** method for Flutter applications.
  /// No API credentials are needed - all sensitive data stays on your backend.
  ///
  /// Your backend can be written in any language (Node.js, Python, Go, PHP, etc.)
  /// and should implement the payment API endpoints.
  ///
  /// [baseUrl] - Your backend's payment API URL (e.g., 'https://api.yourbackend.com/payment')
  /// [provider] - Default payment provider type
  /// [authToken] - Optional JWT token for user authentication
  /// [headers] - Optional custom HTTP headers
  /// [timeout] - Request timeout (default: 30 seconds)
  /// [maxRetries] - Max retry attempts for network errors (default: 3)
  ///
  /// ```dart
  /// final provider = TrPaymentHub.createProxy(
  ///   baseUrl: 'https://api.yourbackend.com/payment',
  ///   provider: ProviderType.iyzico,
  ///   authToken: 'user_jwt_token',
  /// );
  ///
  /// await provider.initializeWithProvider(ProviderType.iyzico);
  /// final result = await provider.createPayment(request);
  /// ```
  static ProxyPaymentProvider createProxy({
    required String baseUrl,
    ProviderType? provider,
    String? authToken,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
  }) {
    return ProxyPaymentProvider(
      config: ProxyConfig(
        baseUrl: baseUrl,
        defaultProvider: provider,
        authToken: authToken,
        headers: headers,
        timeout: timeout,
        maxRetries: maxRetries,
      ),
    );
  }

  /// Creates a mock provider for testing.
  ///
  /// [shouldSucceed] - Whether operations should succeed
  /// [delay] - Simulated delay for operations
  /// [customError] - Custom error to return on failure
  static PaymentProvider createMock({
    bool shouldSucceed = true,
    Duration delay = const Duration(milliseconds: 500),
    PaymentException? customError,
  }) =>
      MockPaymentProvider(
        shouldSucceed: shouldSucceed,
        delay: delay,
        customError: customError,
      );

  /// Library version
  static const String version = '3.0.0';

  /// Supported payment providers
  static List<ProviderType> get supportedProviders => ProviderType.values;
}
