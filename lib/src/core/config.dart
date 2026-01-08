import 'enums.dart';
import 'exceptions/payment_exception.dart';

/// Temel config sınıfı
abstract class PaymentConfig {
  /// Merchant ID provided by the payment provider.
  String get merchantId;

  /// API key for authentication.
  String get apiKey;

  /// Secret key for signing requests.
  String get secretKey;

  /// Base URL for API requests.
  String get baseUrl;

  /// Whether to use sandbox/test environment.
  bool get isSandbox;

  /// Connection timeout for HTTP requests.
  ///
  /// Default: 15 seconds. This is intentionally conservative to prevent
  /// resource exhaustion attacks and ensure responsive error handling.
  Duration get connectionTimeout;

  /// Whether to enable retry for transient failures.
  bool get enableRetry;

  /// Config doğrulama
  bool validate();
}

/// Production validation utilities for payment configurations.
///
/// Provides methods to validate configurations before production deployment.
extension PaymentConfigProductionValidation on PaymentConfig {
  /// Validates that this configuration is appropriate for production use.
  ///
  /// Returns a list of warnings if there are potential issues.
  /// Empty list means configuration appears safe for production.
  ///
  /// Checks:
  /// * Sandbox mode is disabled
  /// * Base URL doesn't contain test/sandbox indicators
  ///
  /// Example:
  /// ```dart
  /// final warnings = config.validateForProduction();
  /// if (warnings.isNotEmpty) {
  ///   for (final warning in warnings) {
  ///     print('WARNING: $warning');
  ///   }
  /// }
  /// ```
  List<String> validateForProduction() {
    final warnings = <String>[];

    if (isSandbox) {
      warnings.add(
        'Sandbox mode is enabled. This should not be used in production.',
      );
    }

    final testIndicators = ['sandbox', 'test', 'dev', 'staging', 'demo'];
    final lowerUrl = baseUrl.toLowerCase();

    for (final indicator in testIndicators) {
      if (lowerUrl.contains(indicator)) {
        warnings.add(
          'Base URL contains "$indicator" which suggests a non-production environment: $baseUrl',
        );
        break;
      }
    }

    return warnings;
  }

  /// Throws [PaymentException] if sandbox mode is enabled.
  ///
  /// Use this in production initialization to fail fast and prevent
  /// accidental use of sandbox configuration in production.
  ///
  /// Example:
  /// ```dart
  /// void initializePayment(PaymentConfig config) {
  ///   // Fail fast if sandbox is accidentally enabled
  ///   config.assertProduction();
  ///
  ///   // Continue with initialization...
  /// }
  /// ```
  ///
  /// Throws [PaymentException] with code 'config_error' if sandbox is enabled.
  void assertProduction() {
    if (isSandbox) {
      throw PaymentException.configError(
        message:
            'Sandbox mode cannot be used in production. Set isSandbox: false in configuration.',
        provider: _inferProviderType(),
      );
    }
  }

  /// Infers provider type from config class name for error reporting.
  ProviderType? _inferProviderType() {
    final className = runtimeType.toString().toLowerCase();
    if (className.contains('iyzico')) return ProviderType.iyzico;
    if (className.contains('paytr')) return ProviderType.paytr;
    if (className.contains('param')) return ProviderType.param;
    if (className.contains('sipay')) return ProviderType.sipay;
    return null;
  }
}

/// Default timeout duration.
///
/// Set to 15 seconds to balance between:
/// - Allowing sufficient time for payment processing
/// - Preventing resource exhaustion from slow connections
/// - Ensuring responsive error feedback to users
///
/// For 3D Secure flows that require user interaction, consider
/// using a longer timeout at the application level.
const _defaultTimeout = Duration(seconds: 15);

/// Whether retry is enabled by default
const _defaultEnableRetry = true;

/// iyzico için config
class IyzicoConfig implements PaymentConfig {
  const IyzicoConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    this.isSandbox = true,
    this.connectionTimeout = _defaultTimeout,
    this.enableRetry = _defaultEnableRetry,
  });

  @override
  final String merchantId;

  @override
  final String apiKey;

  @override
  final String secretKey;

  @override
  final bool isSandbox;

  @override
  final Duration connectionTimeout;

  @override
  final bool enableRetry;

  @override
  String get baseUrl =>
      isSandbox ? 'https://sandbox-api.iyzipay.com' : 'https://api.iyzipay.com';

  @override
  bool validate() =>
      merchantId.isNotEmpty && apiKey.isNotEmpty && secretKey.isNotEmpty;
}

/// PayTR için config
class PayTRConfig implements PaymentConfig {
  /// Creates a PayTR configuration
  const PayTRConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    required this.successUrl,
    required this.failUrl,
    required this.callbackUrl,
    this.isSandbox = true,
    this.connectionTimeout = _defaultTimeout,
    this.enableRetry = _defaultEnableRetry,
  });

  @override
  final String merchantId;

  @override
  final String apiKey; // merchant_key

  @override
  final String secretKey; // merchant_salt

  /// URL to redirect on successful payment
  final String successUrl;

  /// URL to redirect on failed payment
  final String failUrl;

  /// URL for server-to-server callbacks
  final String callbackUrl;

  @override
  final bool isSandbox;

  @override
  final Duration connectionTimeout;

  @override
  final bool enableRetry;

  @override
  String get baseUrl => 'https://www.paytr.com';

  @override
  bool validate() =>
      merchantId.isNotEmpty &&
      apiKey.isNotEmpty &&
      secretKey.isNotEmpty &&
      successUrl.isNotEmpty &&
      failUrl.isNotEmpty;
}

/// Param için config
///
/// Param POS SOAP/XML tabanlı bir API kullanır.
/// Test modu için https://test-dmz.param.com.tr kullanılır.
///
/// ## Örnek Kullanım
///
/// ```dart
/// final config = ParamConfig(
///   merchantId: 'CLIENT_CODE',
///   apiKey: 'CLIENT_USERNAME',
///   secretKey: 'CLIENT_PASSWORD',
///   guid: 'YOUR_GUID',
///   isSandbox: true,
/// );
/// ```
class ParamConfig implements PaymentConfig {
  /// Creates a Param configuration
  const ParamConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    required this.guid,
    this.isSandbox = true,
    this.connectionTimeout = _defaultTimeout,
    this.enableRetry = _defaultEnableRetry,
  });

  /// Client code
  @override
  final String merchantId;

  /// Client username
  @override
  final String apiKey;

  /// Client password
  @override
  final String secretKey;

  /// GUID - Param tarafından verilen benzersiz kimlik
  final String guid;

  @override
  final bool isSandbox;

  @override
  final Duration connectionTimeout;

  @override
  final bool enableRetry;

  @override
  String get baseUrl =>
      isSandbox ? 'https://test-dmz.param.com.tr' : 'https://dmz.param.com.tr';

  @override
  bool validate() =>
      merchantId.isNotEmpty &&
      apiKey.isNotEmpty &&
      secretKey.isNotEmpty &&
      guid.isNotEmpty;
}

/// Sipay için config
///
/// Sipay REST/JSON tabanlı bir API kullanır.
/// Bearer token authentication ile çalışır.
///
/// ## Örnek Kullanım
///
/// ```dart
/// final config = SipayConfig(
///   merchantId: 'YOUR_MERCHANT_ID',
///   apiKey: 'YOUR_APP_KEY',
///   secretKey: 'YOUR_APP_SECRET',
///   merchantKey: 'YOUR_MERCHANT_KEY',
///   isSandbox: true,
/// );
/// ```
class SipayConfig implements PaymentConfig {
  /// Creates a Sipay configuration
  const SipayConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    required this.merchantKey,
    this.isSandbox = true,
    this.connectionTimeout = _defaultTimeout,
    this.enableRetry = _defaultEnableRetry,
  });

  @override
  final String merchantId;

  /// App key (sipay tarafından verilen)
  @override
  final String apiKey;

  /// App secret (sipay tarafından verilen)
  @override
  final String secretKey;

  /// Merchant key (sipay tarafından verilen)
  final String merchantKey;

  @override
  final bool isSandbox;

  @override
  final Duration connectionTimeout;

  @override
  final bool enableRetry;

  @override
  String get baseUrl =>
      isSandbox ? 'https://sandbox.sipay.com.tr' : 'https://app.sipay.com.tr';

  @override
  bool validate() =>
      merchantId.isNotEmpty &&
      apiKey.isNotEmpty &&
      secretKey.isNotEmpty &&
      merchantKey.isNotEmpty;
}
