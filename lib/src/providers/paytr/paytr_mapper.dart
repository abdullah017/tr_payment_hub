import 'dart:convert';
import '../../core/enums.dart';
import '../../core/models/basket_item.dart';
import '../../core/models/installment_info.dart';
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
  }) =>
      {
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
  }) =>
      {
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
  }) =>
      {
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
  }) =>
      {
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

  /// Taksit oranları sorgusu için request body
  static Map<String, String> toInstallmentRequest({
    required String merchantId,
    required String requestId,
    required String paytrToken,
  }) =>
      {
        'merchant_id': merchantId,
        'request_id': requestId,
        'paytr_token': paytrToken,
      };

  /// Taksit oranları response'unu parse et
  ///
  /// PayTR response formatı:
  /// ```json
  /// {
  ///   "status": "success",
  ///   "request_id": "xxx",
  ///   "max_inst_non_bus": "12",
  ///   "rates": {
  ///     "axess": {"1": "0", "2": "2.5", "3": "3.5", ...},
  ///     "world": {"1": "0", "2": "2.5", ...},
  ///     ...
  ///   }
  /// }
  /// ```
  static InstallmentInfo fromInstallmentResponse({
    required Map<String, dynamic> response,
    required String binNumber,
    required double amount,
    String? cardFamily,
  }) {
    final rawRates = response['rates'];
    final rates = rawRates is Map ? Map<String, dynamic>.from(rawRates) : null;
    final maxInstallment =
        int.tryParse(response['max_inst_non_bus']?.toString() ?? '12') ?? 12;

    // Kart ailesine göre oranları bul
    // Varsayılan olarak tüm oranların ortalamasını kullan
    var selectedRates = <String, dynamic>{};
    var detectedCardFamily = cardFamily ?? 'Unknown';

    if (rates != null) {
      // Kart ailesi belirtilmişse onu kullan
      if (cardFamily != null) {
        final normalizedFamily = cardFamily.toLowerCase();
        final familyRates = rates[normalizedFamily];
        if (familyRates is Map) {
          selectedRates = Map<String, dynamic>.from(familyRates);
        }
      }

      // Bulunamadıysa ilk mevcut oranları kullan
      if (selectedRates.isEmpty && rates.isNotEmpty) {
        final firstKey = rates.keys.first;
        final firstRates = rates[firstKey];
        if (firstRates is Map) {
          selectedRates = Map<String, dynamic>.from(firstRates);
        }
        detectedCardFamily = _formatCardFamily(firstKey);
      }
    }

    // Taksit seçeneklerini oluştur
    final options = <InstallmentOption>[];

    if (selectedRates.isNotEmpty) {
      for (final entry in selectedRates.entries) {
        final installmentNumber = int.tryParse(entry.key);
        if (installmentNumber == null || installmentNumber < 1) continue;
        if (installmentNumber > maxInstallment) continue;

        final ratePercent = double.tryParse(entry.value.toString()) ?? 0;
        final totalPrice = amount * (1 + ratePercent / 100);
        final installmentPrice = totalPrice / installmentNumber;

        options.add(
          InstallmentOption(
            installmentNumber: installmentNumber,
            installmentPrice: installmentPrice,
            totalPrice: totalPrice,
          ),
        );
      }
    }

    // Eğer hiç oran yoksa varsayılan tek çekim ekle
    if (options.isEmpty) {
      options.add(
        InstallmentOption(
          installmentNumber: 1,
          installmentPrice: amount,
          totalPrice: amount,
        ),
      );
    }

    // Taksit sayısına göre sırala
    options.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

    return InstallmentInfo(
      binNumber: binNumber,
      price: amount,
      cardType: CardType.creditCard,
      cardAssociation: _detectCardAssociation(binNumber),
      cardFamily: detectedCardFamily,
      bankName: 'PayTR',
      bankCode: 0,
      force3DS: true, // PayTR genellikle 3DS zorunlu tutar
      forceCVC: true,
      options: options,
    );
  }

  /// Kart ailesi adını formatla
  static String _formatCardFamily(String rawFamily) {
    switch (rawFamily.toLowerCase()) {
      case 'axess':
        return 'Axess';
      case 'world':
        return 'World';
      case 'maximum':
        return 'Maximum';
      case 'cardfinans':
        return 'CardFinans';
      case 'paraf':
        return 'Paraf';
      case 'advantage':
        return 'Advantage';
      case 'combo':
        return 'Combo';
      case 'bonus':
        return 'Bonus';
      default:
        return rawFamily;
    }
  }

  /// BIN numarasından kart birliğini tespit et
  static CardAssociation _detectCardAssociation(String binNumber) {
    if (binNumber.isEmpty) return CardAssociation.visa;

    final firstDigit = binNumber[0];
    final firstTwo = binNumber.length >= 2 ? binNumber.substring(0, 2) : '';
    final firstFour = binNumber.length >= 4 ? binNumber.substring(0, 4) : '';

    // Visa: 4 ile başlar
    if (firstDigit == '4') return CardAssociation.visa;

    // Mastercard: 51-55 veya 2221-2720
    if (firstTwo.isNotEmpty) {
      final twoDigits = int.tryParse(firstTwo);
      if (twoDigits != null && twoDigits >= 51 && twoDigits <= 55) {
        return CardAssociation.masterCard;
      }
    }
    if (firstFour.isNotEmpty) {
      final fourDigits = int.tryParse(firstFour);
      if (fourDigits != null && fourDigits >= 2221 && fourDigits <= 2720) {
        return CardAssociation.masterCard;
      }
    }

    // Amex: 34 veya 37 ile başlar
    if (firstTwo == '34' || firstTwo == '37') {
      return CardAssociation.amex;
    }

    // Troy: 9792 ile başlar (Türk kartları)
    if (firstFour == '9792') return CardAssociation.troy;

    return CardAssociation.visa;
  }
}
