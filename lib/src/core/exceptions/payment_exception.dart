import '../enums.dart';

/// Ödeme hatası
class PaymentException implements Exception {
  final String code;
  final String message;
  final String? providerCode;
  final String? providerMessage;
  final ProviderType? provider;

  const PaymentException({
    required this.code,
    required this.message,
    this.providerCode,
    this.providerMessage,
    this.provider,
  });

  // ============================================
  // Factory Constructors - Common Errors
  // ============================================

  factory PaymentException.insufficientFunds({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'insufficient_funds',
    message: 'Yetersiz bakiye',
    providerCode: providerCode,
    providerMessage: providerMessage,
    provider: provider,
  );

  factory PaymentException.invalidCard({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'invalid_card',
    message: 'Geçersiz kart bilgisi',
    providerCode: providerCode,
    providerMessage: providerMessage,
    provider: provider,
  );

  factory PaymentException.expiredCard({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'expired_card',
    message: 'Kartın süresi dolmuş',
    providerCode: providerCode,
    providerMessage: providerMessage,
    provider: provider,
  );

  factory PaymentException.invalidCVV({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'invalid_cvv',
    message: 'Geçersiz CVV',
    providerCode: providerCode,
    providerMessage: providerMessage,
    provider: provider,
  );

  factory PaymentException.declined({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'declined',
    message: 'İşlem reddedildi',
    providerCode: providerCode,
    providerMessage: providerMessage,
    provider: provider,
  );

  factory PaymentException.threeDSFailed({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'threeds_failed',
    message: '3D Secure doğrulaması başarısız',
    providerCode: providerCode,
    providerMessage: providerMessage,
    provider: provider,
  );

  factory PaymentException.networkError({
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'network_error',
    message: 'Bağlantı hatası',
    providerMessage: providerMessage,
    provider: provider,
  );

  factory PaymentException.configError({
    required String message,
    ProviderType? provider,
  }) => PaymentException(
    code: 'config_error',
    message: message,
    provider: provider,
  );

  factory PaymentException.timeout({ProviderType? provider}) =>
      PaymentException(
        code: 'timeout',
        message: 'İşlem zaman aşımına uğradı',
        provider: provider,
      );

  factory PaymentException.unknown({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) => PaymentException(
    code: 'unknown_error',
    message: 'Bilinmeyen bir hata oluştu',
    providerCode: providerCode,
    providerMessage: providerMessage,
    provider: provider,
  );

  @override
  String toString() => 'PaymentException($code): $message';

  /// Kullanıcıya gösterilebilir mesaj
  String get userFriendlyMessage => message;

  /// Debug için detaylı bilgi
  String get debugInfo =>
      'PaymentException(code: $code, message: $message, '
      'providerCode: $providerCode, providerMessage: $providerMessage, '
      'provider: $provider)';
}
