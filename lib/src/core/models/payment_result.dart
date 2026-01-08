import 'package:meta/meta.dart';

import '../enums.dart';

/// Result of a payment transaction.
///
/// Contains all details about the payment outcome, including transaction
/// identifiers, amounts, and card information.
///
/// ## Example
///
/// ```dart
/// final result = await provider.createPayment(request);
///
/// if (result.isSuccess) {
///   print('Payment successful!');
///   print('Transaction ID: ${result.transactionId}');
///   print('Amount: ${result.amount}');
/// } else {
///   print('Payment failed: ${result.errorMessage}');
///   print('Error code: ${result.errorCode}');
/// }
/// ```
///
/// ## Factory Constructors
///
/// Use the factory constructors for cleaner code:
/// * [PaymentResult.success] - Create a successful result
/// * [PaymentResult.failure] - Create a failed result
@immutable
class PaymentResult {
  /// Creates a new [PaymentResult] instance.
  const PaymentResult({
    required this.isSuccess,
    this.transactionId,
    this.paymentId,
    this.amount,
    this.paidAmount,
    this.installment,
    this.cardType,
    this.cardAssociation,
    this.cardFamily,
    this.binNumber,
    this.lastFourDigits,
    this.cardToken,
    this.cardUserKey,
    this.errorCode,
    this.errorMessage,
    this.rawResponse,
  });

  /// Creates a [PaymentResult] from a JSON map.
  factory PaymentResult.fromJson(Map<String, dynamic> json) => PaymentResult(
        isSuccess: json['success'] as bool? ?? json['isSuccess'] as bool? ?? false,
        transactionId: json['transactionId'] as String?,
        paymentId: json['paymentId'] as String?,
        amount: json['amount'] != null
            ? (json['amount'] as num).toDouble()
            : null,
        paidAmount: json['paidAmount'] != null
            ? (json['paidAmount'] as num).toDouble()
            : null,
        installment: json['installment'] as int?,
        cardType: json['cardType'] != null
            ? CardType.values.firstWhere(
                (c) => c.name == json['cardType'],
                orElse: () => CardType.creditCard,
              )
            : null,
        cardAssociation: json['cardAssociation'] != null
            ? CardAssociation.values.firstWhere(
                (c) => c.name == json['cardAssociation'],
                orElse: () => CardAssociation.visa,
              )
            : null,
        cardFamily: json['cardFamily'] as String?,
        binNumber: json['binNumber'] as String?,
        lastFourDigits: json['lastFourDigits'] as String?,
        cardToken: json['cardToken'] as String?,
        cardUserKey: json['cardUserKey'] as String?,
        errorCode: json['errorCode'] as String?,
        errorMessage: json['errorMessage'] as String?,
        rawResponse: json['rawResponse'] as Map<String, dynamic>?,
      );

  /// Creates a successful payment result.
  factory PaymentResult.success({
    required String transactionId,
    required double amount,
    String? paymentId,
    double? paidAmount,
    int? installment,
    CardType? cardType,
    CardAssociation? cardAssociation,
    String? cardFamily,
    String? binNumber,
    String? lastFourDigits,
    String? cardToken,
    String? cardUserKey,
    Map<String, dynamic>? rawResponse,
  }) =>
      PaymentResult(
        isSuccess: true,
        transactionId: transactionId,
        paymentId: paymentId,
        amount: amount,
        paidAmount: paidAmount ?? amount,
        installment: installment,
        cardType: cardType,
        cardAssociation: cardAssociation,
        cardFamily: cardFamily,
        binNumber: binNumber,
        lastFourDigits: lastFourDigits,
        cardToken: cardToken,
        cardUserKey: cardUserKey,
        rawResponse: rawResponse,
      );

  /// Creates a failed payment result.
  factory PaymentResult.failure({
    required String errorCode,
    required String errorMessage,
    Map<String, dynamic>? rawResponse,
  }) =>
      PaymentResult(
        isSuccess: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
        rawResponse: rawResponse,
      );

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'success': isSuccess,
        if (transactionId != null) 'transactionId': transactionId,
        if (paymentId != null) 'paymentId': paymentId,
        if (amount != null) 'amount': amount,
        if (paidAmount != null) 'paidAmount': paidAmount,
        if (installment != null) 'installment': installment,
        if (cardType != null) 'cardType': cardType!.name,
        if (cardAssociation != null) 'cardAssociation': cardAssociation!.name,
        if (cardFamily != null) 'cardFamily': cardFamily,
        if (binNumber != null) 'binNumber': binNumber,
        if (lastFourDigits != null) 'lastFourDigits': lastFourDigits,
        if (cardToken != null) 'cardToken': cardToken,
        if (cardUserKey != null) 'cardUserKey': cardUserKey,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };

  /// Whether the payment was successful.
  final bool isSuccess;

  /// Unique identifier for this transaction.
  ///
  /// Use this ID for refunds, status queries, and reconciliation.
  final String? transactionId;

  /// Provider-specific payment identifier.
  final String? paymentId;

  /// Original payment amount.
  final double? amount;

  /// Actual amount charged (may differ with installments).
  final double? paidAmount;

  /// Number of installments used.
  final int? installment;

  /// Type of card used (credit, debit, prepaid).
  final CardType? cardType;

  /// Card network (Visa, Mastercard, etc.).
  final CardAssociation? cardAssociation;

  /// Card family name (Bonus, Maximum, etc.).
  final String? cardFamily;

  /// First 6 digits of the card used.
  final String? binNumber;

  /// Last 4 digits of the card used.
  final String? lastFourDigits;

  /// Token for the saved card (if card was saved).
  ///
  /// This token can be used for future charges without requiring
  /// full card details. Only populated when `CardInfo.saveCard = true`.
  final String? cardToken;

  /// Card user key (iyzico specific).
  ///
  /// In iyzico, this identifies the customer and their saved cards.
  /// Required for listing and managing saved cards.
  final String? cardUserKey;

  /// Error code for failed payments.
  final String? errorCode;

  /// Human-readable error message.
  final String? errorMessage;

  /// Raw response from the payment provider.
  ///
  /// Useful for debugging or accessing provider-specific data.
  final Map<String, dynamic>? rawResponse;

  @override
  String toString() => isSuccess
      ? 'PaymentResult.success(transactionId: $transactionId, amount: $amount)'
      : 'PaymentResult.failure(errorCode: $errorCode, message: $errorMessage)';
}

/// Result of a refund operation.
///
/// ## Example
///
/// ```dart
/// final result = await provider.refund(refundRequest);
///
/// if (result.isSuccess) {
///   print('Refunded ${result.refundedAmount}');
/// } else {
///   print('Refund failed: ${result.errorMessage}');
/// }
/// ```
@immutable
class RefundResult {
  /// Creates a new [RefundResult] instance.
  const RefundResult({
    required this.isSuccess,
    this.refundId,
    this.refundedAmount,
    this.errorCode,
    this.errorMessage,
  });

  /// Creates a [RefundResult] from a JSON map.
  factory RefundResult.fromJson(Map<String, dynamic> json) => RefundResult(
        isSuccess: json['success'] as bool? ?? json['isSuccess'] as bool? ?? false,
        refundId: json['refundId'] as String?,
        refundedAmount: json['refundedAmount'] != null
            ? (json['refundedAmount'] as num).toDouble()
            : null,
        errorCode: json['errorCode'] as String?,
        errorMessage: json['errorMessage'] as String?,
      );

  /// Creates a successful refund result.
  factory RefundResult.success({
    required String refundId,
    required double refundedAmount,
  }) =>
      RefundResult(
        isSuccess: true,
        refundId: refundId,
        refundedAmount: refundedAmount,
      );

  /// Creates a failed refund result.
  factory RefundResult.failure({
    required String errorCode,
    required String errorMessage,
  }) =>
      RefundResult(
        isSuccess: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'success': isSuccess,
        if (refundId != null) 'refundId': refundId,
        if (refundedAmount != null) 'refundedAmount': refundedAmount,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };

  /// Whether the refund was successful.
  final bool isSuccess;

  /// Unique identifier for this refund.
  final String? refundId;

  /// Amount that was refunded.
  final double? refundedAmount;

  /// Error code for failed refunds.
  final String? errorCode;

  /// Human-readable error message.
  final String? errorMessage;

  @override
  String toString() => isSuccess
      ? 'RefundResult.success(refundId: $refundId, amount: $refundedAmount)'
      : 'RefundResult.failure(errorCode: $errorCode, message: $errorMessage)';
}
