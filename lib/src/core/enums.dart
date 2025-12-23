/// Desteklenen ödeme sağlayıcıları
enum ProviderType {
  iyzico,
  paytr,
  // Gelecekte eklenecekler:
  // param,
  // sipay,
  // hepsipay,
}

/// Para birimleri
enum Currency { TRY, USD, EUR, GBP }

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
