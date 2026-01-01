/// Desteklenen ödeme sağlayıcıları
enum ProviderType {
  /// iyzico ödeme sağlayıcısı
  iyzico,

  /// PayTR ödeme sağlayıcısı
  paytr,

  /// Param POS ödeme sağlayıcısı
  param,

  /// Sipay ödeme sağlayıcısı
  sipay,
  // Gelecekte eklenecekler:
  // hepsipay,
}

/// Para birimleri
enum Currency { tryLira, usd, eur, gbp }

/// Kart tipleri
enum CardType { creditCard, debitCard, prepaidCard }

/// Kart şeması
enum CardAssociation { visa, masterCard, amex, troy }

/// Ödeme durumu
enum PaymentStatus { pending, success, failed, refunded, partiallyRefunded }

/// 3DS durumu
enum ThreeDSStatus { notRequired, pending, completed, failed }

/// Ürün tipi
enum ItemType { physical, virtual }
