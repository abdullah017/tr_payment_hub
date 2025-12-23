import '../enums.dart';
import 'card_info.dart';
import 'buyer_info.dart';
import 'basket_item.dart';

/// Ödeme isteği
class PaymentRequest {
  final String orderId;
  final double amount;
  final double? paidAmount;
  final Currency currency;
  final int installment;
  final CardInfo card;
  final BuyerInfo buyer;
  final List<BasketItem> basketItems;
  final bool use3DS;
  final String? callbackUrl;

  const PaymentRequest({
    required this.orderId,
    required this.amount,
    this.paidAmount,
    this.currency = Currency.TRY,
    this.installment = 1,
    required this.card,
    required this.buyer,
    required this.basketItems,
    this.use3DS = true,
    this.callbackUrl,
  });

  /// paidAmount belirtilmemişse amount kullanılır
  double get effectivePaidAmount => paidAmount ?? amount;

  /// Sepet toplam tutarı doğrulama
  bool validateBasketTotal() {
    final basketTotal = basketItems.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    return (basketTotal - amount).abs() < 0.01;
  }
}

/// İade isteği
class RefundRequest {
  final String transactionId;
  final double amount;
  final Currency currency;
  final String? reason;
  final String ip;

  const RefundRequest({
    required this.transactionId,
    required this.amount,
    this.currency = Currency.TRY,
    this.reason,
    required this.ip,
  });
}
