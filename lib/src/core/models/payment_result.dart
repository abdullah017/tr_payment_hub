import '../enums.dart';

/// Ödeme sonucu
class PaymentResult {
  final bool isSuccess;
  final String? transactionId;
  final String? paymentId;
  final double? amount;
  final double? paidAmount;
  final int? installment;
  final CardType? cardType;
  final CardAssociation? cardAssociation;
  final String? cardFamily;
  final String? binNumber;
  final String? lastFourDigits;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? rawResponse;

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
    this.errorCode,
    this.errorMessage,
    this.rawResponse,
  });

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
    Map<String, dynamic>? rawResponse,
  }) {
    return PaymentResult(
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
      rawResponse: rawResponse,
    );
  }

  factory PaymentResult.failure({
    required String errorCode,
    required String errorMessage,
    Map<String, dynamic>? rawResponse,
  }) {
    return PaymentResult(
      isSuccess: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
      rawResponse: rawResponse,
    );
  }
}

/// İade sonucu
class RefundResult {
  final bool isSuccess;
  final String? refundId;
  final double? refundedAmount;
  final String? errorCode;
  final String? errorMessage;

  const RefundResult({
    required this.isSuccess,
    this.refundId,
    this.refundedAmount,
    this.errorCode,
    this.errorMessage,
  });

  factory RefundResult.success({
    required String refundId,
    required double refundedAmount,
  }) {
    return RefundResult(
      isSuccess: true,
      refundId: refundId,
      refundedAmount: refundedAmount,
    );
  }

  factory RefundResult.failure({
    required String errorCode,
    required String errorMessage,
  }) {
    return RefundResult(
      isSuccess: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}
