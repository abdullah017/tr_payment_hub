import '../../core/enums.dart';
import '../../core/models/installment_info.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/saved_card.dart';
import '../../core/models/three_ds_result.dart';
import 'sipay_error_mapper.dart';

/// Sipay JSON request/response mapper
class SipayMapper {
  SipayMapper._();

  // ============================================
  // REQUEST MAPPERS
  // ============================================

  /// Non-3DS ödeme isteği oluştur
  static Map<String, dynamic> toPaymentRequest({
    required PaymentRequest request,
    required String merchantKey,
    required String invoiceId,
    required String hashKey,
  }) => {
    'cc_holder_name': request.card.cardHolderName,
    'cc_no': request.card.cardNumber,
    'expiry_month': request.card.expireMonth,
    'expiry_year': request.card.expireYear,
    'cvv': request.card.cvc,
    'currency_code': _mapCurrency(request.currency),
    'installments_number': request.installment,
    'invoice_id': invoiceId,
    'invoice_description': request.orderId,
    'name': request.buyer.name,
    'surname': request.buyer.surname,
    'total': request.effectivePaidAmount.toStringAsFixed(2),
    'merchant_key': merchantKey,
    'hash_key': hashKey,
    'items': _mapBasketItems(request),
    'bill_address1': request.buyer.address,
    'bill_city': request.buyer.city,
    'bill_country': request.buyer.country,
    'bill_email': request.buyer.email,
    'bill_phone': request.buyer.phone,
    'ip': request.buyer.ip,
  };

  /// 3DS ödeme isteği oluştur
  static Map<String, dynamic> to3DSPaymentRequest({
    required PaymentRequest request,
    required String merchantKey,
    required String invoiceId,
    required String hashKey,
    required String returnUrl,
    required String cancelUrl,
  }) {
    final baseRequest = toPaymentRequest(
      request: request,
      merchantKey: merchantKey,
      invoiceId: invoiceId,
      hashKey: hashKey,
    );
    baseRequest['return_url'] = returnUrl;
    baseRequest['cancel_url'] = cancelUrl;
    return baseRequest;
  }

  /// Taksit sorgulama isteği
  static Map<String, dynamic> toInstallmentRequest({
    required String creditCard,
    required double amount,
    required String currencyCode,
    required String merchantKey,
  }) => {
    'credit_card': creditCard,
    'amount': amount.toStringAsFixed(2),
    'currency_code': currencyCode,
    'merchant_key': merchantKey,
  };

  /// İade isteği
  static Map<String, dynamic> toRefundRequest({
    required String invoiceId,
    required double amount,
    required String merchantKey,
    required String hashKey,
  }) => {
    'invoice_id': invoiceId,
    'amount': amount.toStringAsFixed(2),
    'merchant_key': merchantKey,
    'hash_key': hashKey,
  };

  /// Status sorgulama isteği
  static Map<String, dynamic> toStatusRequest({
    required String invoiceId,
    required String merchantKey,
  }) => {'invoice_id': invoiceId, 'merchant_key': merchantKey};

  /// Kayıtlı kart ile ödeme isteği
  static Map<String, dynamic> toSavedCardPaymentRequest({
    required String cardToken,
    required String invoiceId,
    required double amount,
    required String merchantKey,
    required String hashKey,
    required String currency,
    int installment = 1,
  }) => {
    'card_token': cardToken,
    'invoice_id': invoiceId,
    'total': amount.toStringAsFixed(2),
    'currency_code': currency,
    'installments_number': installment,
    'merchant_key': merchantKey,
    'hash_key': hashKey,
  };

  // ============================================
  // RESPONSE MAPPERS
  // ============================================

  /// Ödeme response'unu PaymentResult'a çevir
  static PaymentResult fromPaymentResponse(Map<String, dynamic> response) {
    final statusCode = response['status_code'] as int?;

    if (SipayErrorMapper.isSuccess(statusCode)) {
      return PaymentResult.success(
        transactionId:
            response['order_id']?.toString() ??
            response['invoice_id']?.toString() ??
            '',
        paymentId: response['transaction_id']?.toString(),
        amount: _parseDouble(response['amount']) ?? 0,
        paidAmount:
            _parseDouble(response['total']) ?? _parseDouble(response['amount']),
        installment: response['installments_number'] as int?,
        binNumber: response['bin_number']?.toString(),
        lastFourDigits: response['last_four']?.toString(),
        cardToken: response['card_token']?.toString(),
        rawResponse: response,
      );
    } else {
      return PaymentResult.failure(
        errorCode: response['status_code']?.toString() ?? 'unknown',
        errorMessage:
            response['status_description']?.toString() ??
            response['message']?.toString() ??
            'Bilinmeyen hata',
        rawResponse: response,
      );
    }
  }

  /// 3DS init response'unu ThreeDSInitResult'a çevir
  static ThreeDSInitResult from3DSInitResponse(Map<String, dynamic> response) {
    final statusCode = response['status_code'] as int?;

    if (SipayErrorMapper.isSuccess(statusCode)) {
      final redirectUrl =
          response['redirect_url']?.toString() ??
          response['payment_url']?.toString();
      final htmlContent = response['html_content']?.toString();

      return ThreeDSInitResult.pending(
        redirectUrl: redirectUrl,
        htmlContent: htmlContent,
        transactionId:
            response['order_id']?.toString() ??
            response['invoice_id']?.toString(),
      );
    } else {
      return ThreeDSInitResult.failed(
        errorCode: response['status_code']?.toString() ?? 'unknown',
        errorMessage:
            response['status_description']?.toString() ??
            response['message']?.toString() ??
            'Bilinmeyen hata',
      );
    }
  }

  /// İade response'unu RefundResult'a çevir
  static RefundResult fromRefundResponse(Map<String, dynamic> response) {
    final statusCode = response['status_code'] as int?;

    if (SipayErrorMapper.isSuccess(statusCode)) {
      return RefundResult.success(
        refundId:
            response['refund_id']?.toString() ??
            response['invoice_id']?.toString() ??
            '',
        refundedAmount: _parseDouble(response['amount']) ?? 0,
      );
    } else {
      return RefundResult.failure(
        errorCode: response['status_code']?.toString() ?? 'unknown',
        errorMessage:
            response['status_description']?.toString() ??
            response['message']?.toString() ??
            'Bilinmeyen hata',
      );
    }
  }

  /// Status response'unu PaymentStatus'a çevir
  static PaymentStatus fromStatusResponse(Map<String, dynamic> response) {
    final status =
        response['order_status']?.toString() ?? response['status']?.toString();
    return SipayErrorMapper.parsePaymentStatus(status);
  }

  /// Taksit response'unu InstallmentInfo'ya çevir
  static InstallmentInfo? fromInstallmentResponse({
    required Map<String, dynamic> response,
    required String binNumber,
    required double amount,
  }) {
    final statusCode = response['status_code'] as int?;
    if (!SipayErrorMapper.isSuccess(statusCode)) return null;

    final options = <InstallmentOption>[];
    final installments = response['installments'] as List<dynamic>?;

    if (installments != null) {
      for (final item in installments) {
        if (item is Map<String, dynamic>) {
          final number = item['installment_number'] as int? ?? 1;
          final totalPrice = _parseDouble(item['total_amount']) ?? amount;
          final installmentPrice = totalPrice / number;

          options.add(
            InstallmentOption(
              installmentNumber: number,
              installmentPrice: installmentPrice,
              totalPrice: totalPrice,
            ),
          );
        }
      }
    }

    // Varsayılan tek çekim
    if (options.isEmpty) {
      options.add(
        InstallmentOption(
          installmentNumber: 1,
          installmentPrice: amount,
          totalPrice: amount,
        ),
      );
    }

    return InstallmentInfo(
      binNumber: binNumber,
      price: amount,
      cardType:
          SipayErrorMapper.parseCardType(response['card_type']?.toString()) ??
          CardType.creditCard,
      cardAssociation:
          SipayErrorMapper.parseCardAssociation(
            response['card_program']?.toString(),
          ) ??
          _detectCardAssociation(binNumber),
      cardFamily: response['card_family']?.toString() ?? '',
      bankName: response['bank_name']?.toString() ?? '',
      bankCode: response['bank_code'] as int? ?? 0,
      force3DS: response['is_3d'] == true || response['force_3d'] == true,
      forceCVC: true,
      options: options,
    );
  }

  /// Kayıtlı kartları parse et
  static List<SavedCard> fromSavedCardsResponse(
    Map<String, dynamic> response,
    String cardUserKey,
  ) {
    final statusCode = response['status_code'] as int?;
    if (!SipayErrorMapper.isSuccess(statusCode)) return [];

    final cards = response['cards'] as List<dynamic>?;
    if (cards == null) return [];

    return cards
        .whereType<Map<String, dynamic>>()
        .map(
          (card) => SavedCard(
            cardToken: card['card_token']?.toString() ?? '',
            cardUserKey: cardUserKey,
            lastFourDigits: card['last_four']?.toString() ?? '',
            cardAssociation: SipayErrorMapper.parseCardAssociation(
              card['card_program']?.toString(),
            ),
            cardFamily: card['card_family']?.toString(),
            cardAlias: card['card_alias']?.toString(),
            binNumber: card['bin_number']?.toString(),
            bankName: card['bank_name']?.toString(),
          ),
        )
        .toList();
  }

  // ============================================
  // PRIVATE HELPERS
  // ============================================

  static String _mapCurrency(Currency currency) {
    switch (currency) {
      case Currency.tryLira:
        return 'TRY';
      case Currency.usd:
        return 'USD';
      case Currency.eur:
        return 'EUR';
      case Currency.gbp:
        return 'GBP';
    }
  }

  static List<Map<String, dynamic>> _mapBasketItems(PaymentRequest request) =>
      request.basketItems
          .map(
            (item) => {
              'name': item.name,
              'price': item.price.toStringAsFixed(2),
              'quantity': item.quantity,
              'description': item.category,
            },
          )
          .toList();

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static CardAssociation _detectCardAssociation(String binNumber) {
    if (binNumber.isEmpty) return CardAssociation.visa;
    final firstDigit = binNumber[0];
    final firstTwo = binNumber.length >= 2 ? binNumber.substring(0, 2) : '';
    final firstFour = binNumber.length >= 4 ? binNumber.substring(0, 4) : '';

    // Visa: 4 ile başlar
    if (firstDigit == '4') return CardAssociation.visa;

    // Mastercard: 51-55 veya 2221-2720
    if (firstTwo.isNotEmpty) {
      final twoDigits = int.tryParse(firstTwo) ?? 0;
      if (twoDigits >= 51 && twoDigits <= 55) return CardAssociation.masterCard;
    }
    if (firstFour.isNotEmpty) {
      final fourDigits = int.tryParse(firstFour) ?? 0;
      if (fourDigits >= 2221 && fourDigits <= 2720) {
        return CardAssociation.masterCard;
      }
    }

    // Amex: 34 veya 37
    if (firstTwo == '34' || firstTwo == '37') return CardAssociation.amex;

    // Troy: 9792
    if (firstFour == '9792') return CardAssociation.troy;

    return CardAssociation.visa;
  }
}
