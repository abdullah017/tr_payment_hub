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
  @override
  final String merchantId;

  @override
  final String apiKey;

  @override
  final String secretKey;

  @override
  final bool isSandbox;

  const IyzicoConfig({
    required this.merchantId,
    required this.apiKey,
    required this.secretKey,
    this.isSandbox = true,
  });

  @override
  String get baseUrl =>
      isSandbox ? 'https://sandbox-api.iyzipay.com' : 'https://api.iyzipay.com';

  @override
  bool validate() {
    return merchantId.isNotEmpty && apiKey.isNotEmpty && secretKey.isNotEmpty;
  }
}

/// PayTR için config
class PayTRConfig implements PaymentConfig {
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
  String get baseUrl => 'https://www.paytr.com';

  @override
  bool validate() {
    return merchantId.isNotEmpty &&
        apiKey.isNotEmpty &&
        secretKey.isNotEmpty &&
        successUrl.isNotEmpty &&
        failUrl.isNotEmpty;
  }
}
