import '../enums.dart';
import 'card_info.dart';
import 'buyer_info.dart';
import 'basket_item.dart';

/// Adres bilgisi
class AddressInfo {
  final String contactName;
  final String city;
  final String country;
  final String address;
  final String? zipCode;

  const AddressInfo({
    required this.contactName,
    required this.city,
    required this.country,
    required this.address,
    this.zipCode,
  });

  Map<String, dynamic> toJson() => {
    'contactName': contactName,
    'city': city,
    'country': country,
    'address': address,
    if (zipCode != null) 'zipCode': zipCode,
  };
}

/// Ödeme isteği modeli
class PaymentRequest {
  /// Sipariş numarası (unique)
  final String orderId;

  /// Toplam tutar
  final double amount;

  /// İndirimli tutar (opsiyonel)
  final double? paidPrice;

  /// Para birimi
  final Currency currency;

  /// Taksit sayısı (1 = tek çekim)
  final int installment;

  /// Kart bilgileri
  final CardInfo card;

  /// Alıcı bilgileri
  final BuyerInfo buyer;

  /// Sepet ürünleri
  final List<BasketItem> basketItems;

  /// Teslimat adresi (opsiyonel)
  final AddressInfo? shippingAddress;

  /// Fatura adresi (opsiyonel)
  final AddressInfo? billingAddress;

  /// 3DS callback URL'i
  final String? callbackUrl;

  /// 3DS kullanılsın mı?
  final bool use3DS;

  /// Ek parametreler
  final Map<String, dynamic>? metadata;

  const PaymentRequest({
    required this.orderId,
    required this.amount,
    this.paidPrice,
    this.currency = Currency.TRY,
    this.installment = 1,
    required this.card,
    required this.buyer,
    required this.basketItems,
    this.shippingAddress,
    this.billingAddress,
    this.callbackUrl,
    this.use3DS = false,
    this.metadata,
  });

  /// Gerçek ödeme tutarı (indirimli veya normal)
  double get effectivePaidAmount => paidPrice ?? amount;

  /// copyWith metodu
  PaymentRequest copyWith({
    String? orderId,
    double? amount,
    double? paidPrice,
    Currency? currency,
    int? installment,
    CardInfo? card,
    BuyerInfo? buyer,
    List<BasketItem>? basketItems,
    AddressInfo? shippingAddress,
    AddressInfo? billingAddress,
    String? callbackUrl,
    bool? use3DS,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentRequest(
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      paidPrice: paidPrice ?? this.paidPrice,
      currency: currency ?? this.currency,
      installment: installment ?? this.installment,
      card: card ?? this.card,
      buyer: buyer ?? this.buyer,
      basketItems: basketItems ?? this.basketItems,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      billingAddress: billingAddress ?? this.billingAddress,
      callbackUrl: callbackUrl ?? this.callbackUrl,
      use3DS: use3DS ?? this.use3DS,
      metadata: metadata ?? this.metadata,
    );
  }
}
