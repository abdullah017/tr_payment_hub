import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';

/// iyzico hata kodlarını unified exception'a çevirir
class IyzicoErrorMapper {
  IyzicoErrorMapper._();

  /// iyzico hata kodunu PaymentException'a çevir
  static PaymentException mapError({
    required String errorCode,
    required String errorMessage,
  }) {
    switch (errorCode) {
      // Kart hataları
      case '12':
      case '5007':
        return PaymentException.invalidCard(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );

      case '54':
        return PaymentException.expiredCard(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );

      case '82':
        return PaymentException.invalidCVV(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );

      // Bakiye/Limit hataları
      case '10051':
      case '51':
        return PaymentException.insufficientFunds(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );

      case '10054':
        return PaymentException(
          code: 'limit_exceeded',
          message: 'Kart limiti aşıldı',
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );

      // 3DS hataları
      case '10057':
      case '10058':
        return PaymentException.threeDSFailed(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );

      // Genel red
      case '10005':
      case '05':
        return PaymentException.declined(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );

      // Config/Auth hataları
      case '1':
      case '10001':
        return PaymentException.configError(
          message: errorMessage,
          provider: ProviderType.iyzico,
        );

      // Bilinmeyen hata
      default:
        return PaymentException.unknown(
          providerCode: errorCode,
          providerMessage: errorMessage,
          provider: ProviderType.iyzico,
        );
    }
  }

  /// CardAssociation string'ini enum'a çevir
  static CardAssociation? parseCardAssociation(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'VISA':
        return CardAssociation.visa;
      case 'MASTER_CARD':
      case 'MASTERCARD':
        return CardAssociation.masterCard;
      case 'AMERICAN_EXPRESS':
      case 'AMEX':
        return CardAssociation.amex;
      case 'TROY':
        return CardAssociation.troy;
      default:
        return null;
    }
  }

  /// CardType string'ini enum'a çevir
  static CardType? parseCardType(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'CREDIT_CARD':
        return CardType.creditCard;
      case 'DEBIT_CARD':
        return CardType.debitCard;
      case 'PREPAID_CARD':
        return CardType.prepaidCard;
      default:
        return null;
    }
  }
}
