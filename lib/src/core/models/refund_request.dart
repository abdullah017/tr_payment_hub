import '../enums.dart';

/// İade isteği modeli
class RefundRequest {
  /// Orijinal işlem ID'si
  final String transactionId;

  /// İade tutarı
  final double amount;

  /// Para birimi
  final Currency currency;

  /// İade yapan IP adresi
  final String? ip;

  /// İade açıklaması
  final String? reason;

  /// Ek parametreler
  final Map<String, dynamic>? metadata;

  const RefundRequest({
    required this.transactionId,
    required this.amount,
    this.currency = Currency.TRY,
    this.ip,
    this.reason,
    this.metadata,
  });
}
