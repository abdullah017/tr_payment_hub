import 'package:meta/meta.dart';

import '../enums.dart';

/// Request model for processing refunds.
///
/// Supports both full and partial refunds. The [amount] can be less than
/// or equal to the original transaction amount for partial refunds.
///
/// ## Example
///
/// ```dart
/// // Full refund
/// final fullRefund = RefundRequest(
///   transactionId: 'TXN_123456',
///   amount: 100.0,
///   reason: 'Customer requested cancellation',
/// );
///
/// // Partial refund
/// final partialRefund = RefundRequest(
///   transactionId: 'TXN_123456',
///   amount: 25.0, // Refund only 25 TL of original 100 TL
///   reason: 'Partial return - damaged item',
/// );
///
/// final result = await provider.refund(fullRefund);
/// if (result.isSuccess) {
///   print('Refunded: ${result.refundedAmount}');
/// }
/// ```
///
/// ## Important Notes
///
/// * Refunds can only be processed for successful payments
/// * Multiple partial refunds are allowed until the full amount is refunded
/// * Refund processing time varies by provider (typically 3-10 business days)
@immutable
class RefundRequest {
  /// Creates a new [RefundRequest] instance.
  const RefundRequest({
    required this.transactionId,
    required this.amount,
    this.currency = Currency.tryLira,
    this.ip,
    this.reason,
    this.metadata,
  });

  /// Creates a [RefundRequest] instance from a JSON map.
  factory RefundRequest.fromJson(Map<String, dynamic> json) => RefundRequest(
    transactionId: json['transactionId'] as String,
    amount: (json['amount'] as num).toDouble(),
    currency: Currency.values.firstWhere(
      (e) => e.name == json['currency'],
      orElse: () => Currency.tryLira,
    ),
    ip: json['ip'] as String?,
    reason: json['reason'] as String?,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );

  /// The transaction ID of the original payment.
  ///
  /// This is the `transactionId` from the original PaymentResult.
  /// For iyzico, this is typically the `paymentTransactionId`.
  /// For PayTR, this is the `merchant_oid`.
  final String transactionId;

  /// Amount to refund in the original transaction currency.
  ///
  /// Must be greater than 0 and less than or equal to the remaining
  /// refundable amount of the original transaction.
  final double amount;

  /// Currency of the refund.
  ///
  /// Should match the currency of the original transaction.
  /// Defaults to [Currency.tryLira].
  final Currency currency;

  /// IP address of the user or admin initiating the refund.
  ///
  /// Optional but recommended for audit purposes.
  final String? ip;

  /// Reason for the refund.
  ///
  /// Optional but recommended for record-keeping and customer service.
  /// Will be stored in provider records.
  final String? reason;

  /// Additional metadata for the refund.
  ///
  /// Provider-specific data or custom fields for your records.
  final Map<String, dynamic>? metadata;

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'amount': amount,
    'currency': currency.name,
    if (ip != null) 'ip': ip,
    if (reason != null) 'reason': reason,
    if (metadata != null) 'metadata': metadata,
  };

  /// Creates a copy of this instance with the given fields replaced.
  RefundRequest copyWith({
    String? transactionId,
    double? amount,
    Currency? currency,
    String? ip,
    String? reason,
    Map<String, dynamic>? metadata,
  }) => RefundRequest(
    transactionId: transactionId ?? this.transactionId,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    ip: ip ?? this.ip,
    reason: reason ?? this.reason,
    metadata: metadata ?? this.metadata,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefundRequest &&
          runtimeType == other.runtimeType &&
          transactionId == other.transactionId &&
          amount == other.amount &&
          currency == other.currency &&
          ip == other.ip &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(transactionId, amount, currency, ip, reason);

  @override
  String toString() =>
      'RefundRequest(transactionId: $transactionId, amount: $amount $currency)';
}
