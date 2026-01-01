/// Temel config sınıfı
abstract class PaymentConfig {
  String get merchantId;
  String get apiKey;
  String get secretKey;
  String get baseUrl;
  bool get isSandbox;

  /// Config doğrulama
  bool validate();
}

/// iyzico için config
class IyzicoConfig implements PaymentConfig {
  const IyzicoConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    this.isSandbox = true,
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
  String get baseUrl =>
      isSandbox ? 'https://sandbox-api.iyzipay.com' : 'https://api.iyzipay.com';

  @override
  bool validate() =>
      merchantId.isNotEmpty && apiKey.isNotEmpty && secretKey.isNotEmpty;
}

/// PayTR için config
class PayTRConfig implements PaymentConfig {
  const PayTRConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    required this.successUrl,
    required this.failUrl,
    required this.callbackUrl,
    this.isSandbox = true,
  });
  @override
  final String merchantId;

  @override
  final String apiKey; // merchant_key

  @override
  final String secretKey; // merchant_salt

  final String successUrl;
  final String failUrl;
  final String callbackUrl;

  @override
  final bool isSandbox;

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
  const ParamConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    required this.guid,
    this.isSandbox = true,
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
  const SipayConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    required this.merchantKey,
    this.isSandbox = true,
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
  String get baseUrl =>
      isSandbox ? 'https://sandbox.sipay.com.tr' : 'https://app.sipay.com.tr';

  @override
  bool validate() =>
      merchantId.isNotEmpty &&
      apiKey.isNotEmpty &&
      secretKey.isNotEmpty &&
      merchantKey.isNotEmpty;
}
