import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';

/// Sipay hata kodlarını PaymentException'a dönüştürür
class SipayErrorMapper {
  SipayErrorMapper._();

  /// Sipay hata kodlarını PaymentException'a map'le
  static PaymentException mapError({
    required String errorCode,
    required String errorMessage,
  }) {
    // Sipay hata kodları genellikle status_code veya message içinde gelir
    final code = errorCode.toLowerCase();

    if (code.contains('insufficient') || code.contains('balance')) {
      return PaymentException.insufficientFunds(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    if (code.contains('invalid_card') || code.contains('card_number')) {
      return PaymentException.invalidCard(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    if (code.contains('expired') || code.contains('expire')) {
      return PaymentException.expiredCard(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    if (code.contains('cvv') || code.contains('cvc')) {
      return PaymentException.invalidCVV(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    if (code.contains('declined') || code.contains('rejected')) {
      return PaymentException.declined(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    if (code.contains('3ds') || code.contains('3d_secure')) {
      return PaymentException.threeDSFailed(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    if (code.contains('timeout') || code.contains('connection')) {
      return PaymentException.networkError(
        providerMessage: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    if (code.contains('auth') || code.contains('token')) {
      return PaymentException.configError(
        message: errorMessage,
        provider: ProviderType.sipay,
      );
    }

    // Varsayılan hata
    return PaymentException(
      code: 'sipay_error',
      message: errorMessage.isNotEmpty ? errorMessage : 'Bilinmeyen hata',
      providerCode: errorCode,
      providerMessage: errorMessage,
      provider: ProviderType.sipay,
    );
  }

  /// Sipay status code kontrolü
  static bool isSuccess(int? statusCode) =>
      statusCode == 100 || statusCode == 1;

  /// Sipay response'dan hata durumunu kontrol et
  static bool isError(Map<String, dynamic> response) {
    final statusCode = response['status_code'];
    if (statusCode is int) {
      return statusCode != 100 && statusCode != 1;
    }
    return response['status'] != 'success';
  }

  /// Kart tipini parse et
  static CardType? parseCardType(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'credit':
      case 'credit_card':
        return CardType.creditCard;
      case 'debit':
      case 'debit_card':
        return CardType.debitCard;
      case 'prepaid':
        return CardType.prepaidCard;
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

  /// Payment status parse et
  static PaymentStatus parsePaymentStatus(String? status) {
    if (status == null) return PaymentStatus.pending;
    switch (status.toLowerCase()) {
      case 'success':
      case 'completed':
      case 'approved':
        return PaymentStatus.success;
      case 'failed':
      case 'declined':
      case 'rejected':
        return PaymentStatus.failed;
      case 'pending':
      case 'waiting':
        return PaymentStatus.pending;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'partial_refunded':
        return PaymentStatus.partiallyRefunded;
      default:
        return PaymentStatus.pending;
    }
  }
}
