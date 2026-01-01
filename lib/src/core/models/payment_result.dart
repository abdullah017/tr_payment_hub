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
  }) => PaymentResult(
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
  }) => PaymentResult(
    isSuccess: false,
    errorCode: errorCode,
    errorMessage: errorMessage,
    rawResponse: rawResponse,
  );

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

  /// Creates a successful refund result.
  factory RefundResult.success({
    required String refundId,
    required double refundedAmount,
  }) => RefundResult(
    isSuccess: true,
    refundId: refundId,
    refundedAmount: refundedAmount,
  );

  /// Creates a failed refund result.
  factory RefundResult.failure({
    required String errorCode,
    required String errorMessage,
  }) => RefundResult(
    isSuccess: false,
    errorCode: errorCode,
    errorMessage: errorMessage,
  );

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
