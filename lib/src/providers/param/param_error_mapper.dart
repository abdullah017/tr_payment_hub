import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';

/// Param hata kodlarını PaymentException'a dönüştürür
class ParamErrorMapper {
  ParamErrorMapper._();

  /// Param hata kodlarını PaymentException'a map'le
  static PaymentException mapError({
    required String errorCode,
    required String errorMessage,
  }) {
    switch (errorCode) {
      // Kart hataları
      case '1001':
      case '1002':
        return PaymentException.invalidCard(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );

      case '1003':
      case '1004':
        return PaymentException.expiredCard(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );

      case '1005':
        return PaymentException.invalidCVV(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );

      // Bakiye hataları
      case '2001':
      case '2002':
        return PaymentException.insufficientFunds(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );

      // Red
      case '3001':
      case '3002':
      case '3003':
        return PaymentException.declined(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );

      // 3DS hataları
      case '4001':
      case '4002':
      case '4003':
        return PaymentException.threeDSFailed(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );

      // Sistem hataları
      case '5001':
      case '5002':
        return PaymentException.networkError(
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );

      // Config hataları
      case '6001':
      case '6002':
        return PaymentException.configError(
          message: errorMessage,
          provider: ProviderType.param,
        );

      default:
        return PaymentException(
          code: 'param_error',
          message: errorMessage.isNotEmpty ? errorMessage : 'Bilinmeyen hata',
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.param,
        );
    }
  }

  /// Param response'dan hata durumunu kontrol et
  ///
  /// Param'da başarılı sonuçlar genellikle `1` veya pozitif değerlerdir.
  /// `0` değeri hata anlamına gelir.
  static bool isSuccess(String? resultCode) {
    if (resultCode == null) return false;
    // 1, 00 (bazı durumlarda), veya pozitif sonuçlar başarılıdır
    // 0 tek başına genellikle hata anlamına gelir
    return resultCode == '1' || resultCode == '00';
  }

  /// Kart tipini parse et
  static CardType? parseCardType(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'credit':
      case 'kredi':
        return CardType.creditCard;
      case 'debit':
      case 'banka':
        return CardType.debitCard;
      default:
        return CardType.creditCard;
    }
  }

  /// Kart markasını parse et
  static CardAssociation? parseCardAssociation(String? value) {
    if (value == null) return null;
    final v = value.toUpperCase();
    if (v.contains('VISA')) return CardAssociation.visa;
    if (v.contains('MASTER')) return CardAssociation.masterCard;
    if (v.contains('AMEX') || v.contains('AMERICAN')) {
      return CardAssociation.amex;
    }
    if (v.contains('TROY')) return CardAssociation.troy;
    return null;
  }
}
