import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';

/// PayTR hata kodlarını unified exception'a çevirir
class PayTRErrorMapper {
  PayTRErrorMapper._();

  /// PayTR hata mesajını PaymentException'a çevir
  static PaymentException mapError({
    required String errorCode,
    required String errorMessage,
  }) {
    final lowerMessage = errorMessage.toLowerCase();

    if (lowerMessage.contains('yetersiz') ||
        lowerMessage.contains('insufficient')) {
      return PaymentException.insufficientFunds(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.paytr,
      );
    }

    if (lowerMessage.contains('geçersiz kart') ||
        lowerMessage.contains('invalid card')) {
      return PaymentException.invalidCard(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.paytr,
      );
    }

    if (lowerMessage.contains('süresi') || lowerMessage.contains('expired')) {
      return PaymentException.expiredCard(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.paytr,
      );
    }

    if (lowerMessage.contains('cvv') || lowerMessage.contains('cvc')) {
      return PaymentException.invalidCVV(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.paytr,
      );
    }

    if (lowerMessage.contains('3d') || lowerMessage.contains('secure')) {
      return PaymentException.threeDSFailed(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.paytr,
      );
    }

    if (lowerMessage.contains('reddedildi') ||
        lowerMessage.contains('declined')) {
      return PaymentException.declined(
        providerCode: errorCode,
        providerMessage: errorMessage,
        provider: ProviderType.paytr,
      );
    }

    return PaymentException.unknown(
      providerCode: errorCode,
      providerMessage: errorMessage,
      provider: ProviderType.paytr,
    );
  }

  /// Callback status'unu PaymentStatus'a çevir
  static PaymentStatus parseCallbackStatus(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return PaymentStatus.success;
      case 'failed':
      case 'failure':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }
}
