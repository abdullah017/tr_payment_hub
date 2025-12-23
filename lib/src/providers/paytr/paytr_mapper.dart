import 'dart:convert';
import '../../core/enums.dart';
import '../../core/models/basket_item.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/three_ds_result.dart';

/// PayTR request/response dönüştürücü
class PayTRMapper {
  PayTRMapper._();

  /// PaymentRequest'i PayTR Direct API formatına çevir
  static Map<String, String> toDirectPaymentRequest({
    required PaymentRequest request,
    required String merchantId,
    required String paytrToken,
    required String merchantOid,
    required String successUrl,
    required String failUrl,
    required bool testMode,
  }) => {
    'merchant_id': merchantId,
    'merchant_oid': merchantOid,
    'email': request.buyer.email,
    'payment_amount': _formatAmount(request.effectivePaidAmount),
    'payment_type': 'card',
    'installment_count': request.installment.toString(),
    'currency': _mapCurrency(request.currency),
    'test_mode': testMode ? '1' : '0',
    'non_3d': request.use3DS ? '0' : '1',
    'merchant_ok_url': successUrl,
    'merchant_fail_url': failUrl,
    'user_name': request.buyer.fullName,
    'user_address': request.buyer.address,
    'user_phone': request.buyer.phone,
    'user_ip': request.buyer.ip,
    'user_basket': _encodeBasket(request.basketItems),
    'cc_owner': request.card.cardHolderName,
    'card_number': request.card.cardNumber,
    'expiry_month': request.card.expireMonth,
    'expiry_year': request.card.expireYear.length == 4
        ? request.card.expireYear.substring(2)
        : request.card.expireYear,
    'cvv': request.card.cvc,
    'paytr_token': paytrToken,
    'debug_on': '1',
  };

  /// iFrame token isteği için map
  static Map<String, String> toIframeTokenRequest({
    required PaymentRequest request,
    required String merchantId,
    required String paytrToken,
    required String merchantOid,
    required String successUrl,
    required String failUrl,
    required String callbackUrl,
    required bool testMode,
    int maxInstallment = 12,
  }) => {
    'merchant_id': merchantId,
    'merchant_oid': merchantOid,
    'email': request.buyer.email,
    'payment_amount': _formatAmount(request.effectivePaidAmount),
    'currency': _mapCurrency(request.currency),
    'test_mode': testMode ? '1' : '0',
    'merchant_ok_url': successUrl,
    'merchant_fail_url': failUrl,
    'user_name': request.buyer.fullName,
    'user_address': request.buyer.address,
    'user_phone': request.buyer.phone,
    'user_ip': request.buyer.ip,
    'user_basket': _encodeBasket(request.basketItems),
    'no_installment': request.installment == 1 ? '1' : '0',
    'max_installment': maxInstallment.toString(),
    'paytr_token': paytrToken,
    'debug_on': '1',
  };

  /// Refund isteği
  static Map<String, String> toRefundRequest({
    required String merchantId,
    required String merchantOid,
    required double amount,
    required String paytrToken,
  }) => {
    'merchant_id': merchantId,
    'merchant_oid': merchantOid,
    'return_amount': _formatAmount(amount),
    'paytr_token': paytrToken,
  };

  /// Status sorgusu
  static Map<String, String> toStatusRequest({
    required String merchantId,
    required String merchantOid,
    required String paytrToken,
  }) => {
    'merchant_id': merchantId,
    'merchant_oid': merchantOid,
    'paytr_token': paytrToken,
  };

  /// iFrame token response'unu parse et
  static ThreeDSInitResult fromIframeTokenResponse(
    Map<String, dynamic> response,
  ) {
    final status = response['status'] as String?;

    if (status == 'success') {
      final token = response['token'] as String?;
      if (token != null) {
        final iframeUrl = 'https://www.paytr.com/odeme/guvenli/$token';
        return ThreeDSInitResult.pending(
          redirectUrl: iframeUrl,
          transactionId: token,
        );
      }
    }

    return ThreeDSInitResult.failed(
      errorCode: response['reason']?.toString() ?? 'unknown',
      errorMessage: response['reason']?.toString() ?? 'Token alınamadı',
    );
  }

  /// Callback verilerinden PaymentResult oluştur
  static PaymentResult fromCallbackData(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    final merchantOid = data['merchant_oid'] as String?;
    final totalAmount = data['total_amount']?.toString();

    if (status == 'success') {
      return PaymentResult.success(
        transactionId: merchantOid ?? '',
        amount: totalAmount != null ? double.tryParse(totalAmount) ?? 0 : 0,
        rawResponse: data,
      );
    } else {
      return PaymentResult.failure(
        errorCode: data['failed_reason_code']?.toString() ?? 'unknown',
        errorMessage:
            data['failed_reason_msg']?.toString() ?? 'Ödeme başarısız',
        rawResponse: data,
      );
    }
  }

  /// Refund response parse et
  static RefundResult fromRefundResponse(Map<String, dynamic> response) {
    final status = response['status'] as String?;

    if (status == 'success') {
      return RefundResult.success(
        refundId: response['merchant_oid']?.toString() ?? '',
        refundedAmount:
            double.tryParse(response['return_amount']?.toString() ?? '0') ?? 0,
      );
    } else {
      return RefundResult.failure(
        errorCode: response['err_no']?.toString() ?? 'unknown',
        errorMessage: response['err_msg']?.toString() ?? 'İade başarısız',
      );
    }
  }

  /// Status response parse et
  static PaymentStatus fromStatusResponse(Map<String, dynamic> response) {
    final status = response['status'] as String?;

    if (status == 'success') {
      final paymentStatus = response['payment_status'] as String?;
      switch (paymentStatus) {
        case 'Başarılı':
        case 'success':
          return PaymentStatus.success;
        case 'Başarısız':
        case 'failed':
          return PaymentStatus.failed;
        default:
          return PaymentStatus.pending;
      }
    }
    return PaymentStatus.failed;
  }

  static String _mapCurrency(Currency currency) {
    switch (currency) {
      case Currency.tryLira:
        return 'TL';
      case Currency.usd:
        return 'USD';
      case Currency.eur:
        return 'EUR';
      case Currency.gbp:
        return 'GBP';
    }
  }

  static String _formatAmount(double amount) =>
      (amount * 100).round().toString();

  static String _encodeBasket(List<BasketItem> items) {
    final basketArray = items
        .map(
          (item) => [
            item.name,
            (item.price * 100).round().toString(),
            item.quantity,
          ],
        )
        .toList();

    final jsonString = jsonEncode(basketArray);
    return base64.encode(utf8.encode(jsonString));
  }
}
