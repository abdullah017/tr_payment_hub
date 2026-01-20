import 'dart:convert';

import '../../core/enums.dart';
import '../../core/models/basket_item.dart';
import '../../core/models/buyer_info.dart';
import '../../core/models/card_info.dart';
import '../../core/models/installment_info.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/refund_request.dart';
import '../../core/models/saved_card.dart';
import '../../core/models/three_ds_result.dart';
import 'iyzico_error_mapper.dart';

/// Converts between TR Payment Hub models and iyzico API formats.
///
/// This class provides static methods to transform payment requests
/// into iyzico's expected JSON format and parse iyzico responses
/// back into TR Payment Hub's unified models.
///
/// ## Request Mapping
///
/// * [toPaymentRequest] - Non-3DS payment request
/// * [to3DSInitRequest] - 3D Secure initialization request
/// * [toInstallmentRequest] - Installment query request
/// * [toRefundRequest] - Refund request
/// * [toSavedCardPaymentRequest] - Saved card payment request
///
/// ## Response Mapping
///
/// * [fromPaymentResponse] - Payment result
/// * [from3DSInitResponse] - 3DS initialization result
/// * [fromInstallmentResponse] - Installment options
/// * [fromRefundResponse] - Refund result
/// * [fromSavedCardResponse] - Saved card info
///
/// ## Example
///
/// ```dart
/// // Convert payment request to iyzico format
/// final iyzicoRequest = IyzicoMapper.toPaymentRequest(
///   paymentRequest,
///   'conversation_123',
/// );
///
/// // Parse iyzico response
/// final result = IyzicoMapper.fromPaymentResponse(response);
/// ```
///
/// ## iyzico API Reference
///
/// See [iyzico documentation](https://docs.iyzico.com/) for API details.
class IyzicoMapper {
  /// Private constructor - this class only has static methods.
  IyzicoMapper._();

  // ============================================
  // REQUEST MAPPERS
  // ============================================

  /// PaymentRequest'i iyzico formatına çevir (Non-3DS)
  static Map<String, dynamic> toPaymentRequest(
    PaymentRequest request,
    String conversationId,
  ) =>
      {
        'locale': 'tr',
        'conversationId': conversationId,
        'price': request.amount.toString(),
        'paidPrice': request.effectivePaidAmount.toString(),
        'currency': _mapCurrency(request.currency),
        'installment': request.installment,
        'basketId': request.orderId,
        'paymentChannel': 'WEB',
        'paymentGroup': 'PRODUCT',
        'paymentCard': _mapCard(request.card),
        'buyer': _mapBuyer(request.buyer),
        'shippingAddress': _mapAddress(request.buyer, 'shipping'),
        'billingAddress': _mapAddress(request.buyer, 'billing'),
        'basketItems': request.basketItems.map(_mapBasketItem).toList(),
      };

  /// PaymentRequest'i iyzico 3DS formatına çevir
  static Map<String, dynamic> to3DSInitRequest(
    PaymentRequest request,
    String conversationId,
    String callbackUrl,
  ) {
    final baseRequest = toPaymentRequest(request, conversationId);
    baseRequest['callbackUrl'] = callbackUrl;
    return baseRequest;
  }

  /// Taksit sorgulama isteği
  static Map<String, dynamic> toInstallmentRequest({
    required String binNumber,
    required double price,
    String? conversationId,
  }) =>
      {
        'locale': 'tr',
        'conversationId':
            conversationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'binNumber': binNumber,
        'price': price.toString(),
      };

  /// İade isteği
  static Map<String, dynamic> toRefundRequest(
    RefundRequest request,
    String conversationId,
  ) =>
      {
        'locale': 'tr',
        'conversationId': conversationId,
        'paymentTransactionId': request.transactionId,
        'price': request.amount.toString(),
        'currency': _mapCurrency(request.currency),
        'ip': request.ip,
      };

  // ============================================
  // RESPONSE MAPPERS
  // ============================================

  /// iyzico payment response'unu PaymentResult'a çevir
  static PaymentResult fromPaymentResponse(Map<String, dynamic> response) {
    final status = response['status'] as String?;

    if (status == 'success') {
      return PaymentResult.success(
        transactionId: _extractTransactionId(response),
        paymentId: response['paymentId']?.toString(),
        amount: _parseDouble(response['price']) ?? 0,
        paidAmount: _parseDouble(response['paidPrice']),
        installment: response['installment'] as int?,
        cardType: IyzicoErrorMapper.parseCardType(response['cardType']),
        cardAssociation: IyzicoErrorMapper.parseCardAssociation(
          response['cardAssociation'],
        ),
        cardFamily: response['cardFamily'] as String?,
        binNumber: response['binNumber'] as String?,
        lastFourDigits: response['lastFourDigits'] as String?,
        rawResponse: response,
      );
    } else {
      return PaymentResult.failure(
        errorCode: response['errorCode']?.toString() ?? 'unknown',
        errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
        rawResponse: response,
      );
    }
  }

  /// iyzico 3DS init response'unu ThreeDSInitResult'a çevir
  static ThreeDSInitResult from3DSInitResponse(Map<String, dynamic> response) {
    final status = response['status'] as String?;

    if (status == 'success') {
      final htmlContent = response['threeDSHtmlContent'] as String?;

      return ThreeDSInitResult.pending(
        htmlContent: htmlContent != null ? _decodeBase64(htmlContent) : null,
        transactionId: response['paymentId']?.toString(),
      );
    } else {
      return ThreeDSInitResult.failed(
        errorCode: response['errorCode']?.toString() ?? 'unknown',
        errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
      );
    }
  }

  /// iyzico installment response'unu InstallmentInfo'ya çevir
  static InstallmentInfo? fromInstallmentResponse(
    Map<String, dynamic> response,
  ) {
    final status = response['status'] as String?;
    if (status != 'success') return null;

    final details = response['installmentDetails'] as List<dynamic>?;
    if (details == null || details.isEmpty) return null;

    final detail = details.first as Map<String, dynamic>;

    final installmentPrices =
        detail['installmentPrices'] as List<dynamic>? ?? [];

    return InstallmentInfo(
      binNumber: detail['binNumber'] as String?,
      price: _parseDouble(detail['price']) ?? 0,
      cardType: IyzicoErrorMapper.parseCardType(detail['cardType']) ??
          CardType.creditCard,
      cardAssociation:
          IyzicoErrorMapper.parseCardAssociation(detail['cardAssociation']) ??
              CardAssociation.visa,
      cardFamily: detail['cardFamilyName'] as String? ?? '',
      bankName: detail['bankName'] as String? ?? '',
      bankCode: detail['bankCode'] as int? ?? 0,
      force3DS: detail['force3ds'] == 1,
      forceCVC: detail['forceCvc'] == 1,
      options: installmentPrices.map((item) {
        final map = item as Map<String, dynamic>;
        return InstallmentOption(
          installmentNumber: map['installmentNumber'] as int? ?? 1,
          installmentPrice: _parseDouble(map['installmentPrice']) ?? 0,
          totalPrice: _parseDouble(map['totalPrice']) ?? 0,
        );
      }).toList(),
    );
  }

  /// iyzico refund response'unu RefundResult'a çevir
  static RefundResult fromRefundResponse(Map<String, dynamic> response) {
    final status = response['status'] as String?;

    if (status == 'success') {
      return RefundResult.success(
        refundId: response['paymentId']?.toString() ?? '',
        refundedAmount: _parseDouble(response['price']) ?? 0,
      );
    } else {
      return RefundResult.failure(
        errorCode: response['errorCode']?.toString() ?? 'unknown',
        errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
      );
    }
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

  static Map<String, dynamic> _mapCard(CardInfo card) => {
        'cardHolderName': card.cardHolderName,
        'cardNumber': card.cardNumber,
        'expireMonth': card.expireMonth,
        'expireYear': card.expireYear,
        'cvc': card.cvc,
        'registerCard': card.saveCard ? 1 : 0,
      };

  static Map<String, dynamic> _mapBuyer(BuyerInfo buyer) => {
        'id': buyer.id,
        'name': buyer.name,
        'surname': buyer.surname,
        'email': buyer.email,
        'gsmNumber': buyer.phone,
        'identityNumber': buyer.identityNumber ?? '11111111111',
        'registrationAddress': buyer.address,
        'city': buyer.city,
        'country': buyer.country,
        'zipCode': buyer.zipCode ?? '34000',
        'ip': buyer.ip,
      };

  static Map<String, dynamic> _mapAddress(BuyerInfo buyer, String type) => {
        'contactName': buyer.fullName,
        'city': buyer.city,
        'country': buyer.country,
        'address': buyer.address,
        'zipCode': buyer.zipCode ?? '34000',
      };

  static Map<String, dynamic> _mapBasketItem(BasketItem item) => {
        'id': item.id,
        'name': item.name,
        'category1': item.category,
        'itemType': item.itemType == ItemType.physical ? 'PHYSICAL' : 'VIRTUAL',
        'price': item.price.toString(),
      };

  static String _extractTransactionId(Map<String, dynamic> response) {
    // İlk itemTransaction'dan paymentTransactionId al
    final items = response['itemTransactions'] as List<dynamic>?;
    if (items != null && items.isNotEmpty) {
      final first = items.first as Map<String, dynamic>;
      return first['paymentTransactionId']?.toString() ??
          response['paymentId']?.toString() ??
          '';
    }
    return response['paymentId']?.toString() ?? '';
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _decodeBase64(String encoded) {
    try {
      return utf8.decode(base64.decode(encoded));
    } catch (_) {
      return encoded;
    }
  }

  // ============================================
  // SAVED CARD / TOKENIZATION MAPPERS
  // ============================================

  /// Kayıtlı kart ile ödeme için request oluştur.
  static Map<String, dynamic> toSavedCardPaymentRequest({
    required String cardToken,
    required String cardUserKey,
    required String orderId,
    required double amount,
    required BuyerInfo buyer,
    required String conversationId,
    int installment = 1,
    Currency currency = Currency.tryLira,
  }) =>
      {
        'locale': 'tr',
        'conversationId': conversationId,
        'price': amount.toString(),
        'paidPrice': amount.toString(),
        'currency': _mapCurrency(currency),
        'installment': installment,
        'basketId': orderId,
        'paymentChannel': 'WEB',
        'paymentGroup': 'PRODUCT',
        'paymentCard': {'cardToken': cardToken, 'cardUserKey': cardUserKey},
        'buyer': _mapBuyer(buyer),
        'shippingAddress': _mapAddress(buyer, 'shipping'),
        'billingAddress': _mapAddress(buyer, 'billing'),
        'basketItems': [
          {
            'id': 'ITEM_$orderId',
            'name': 'Saved Card Payment',
            'category1': 'Payment',
            'itemType': 'VIRTUAL',
            'price': amount.toString(),
          },
        ],
      };

  /// iyzico kart listesi response'unu SavedCard'a dönüştür.
  static SavedCard fromSavedCardResponse(
    Map<String, dynamic> response,
    String cardUserKey,
  ) =>
      SavedCard(
        cardToken: response['cardToken']?.toString() ?? '',
        cardUserKey: cardUserKey,
        lastFourDigits: response['lastFourDigits']?.toString() ?? '',
        cardAssociation: IyzicoErrorMapper.parseCardAssociation(
          response['cardAssociation'],
        ),
        cardFamily: response['cardFamily']?.toString(),
        cardAlias: response['cardAlias']?.toString(),
        binNumber: response['binNumber']?.toString(),
        bankName: response['cardBankName']?.toString(),
        expiryMonth: response['expireMonth']?.toString(),
        expiryYear: response['expireYear']?.toString(),
      );
}
