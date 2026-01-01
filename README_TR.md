# TR Payment Hub

[![Pub Version](https://img.shields.io/pub/v/tr_payment_hub)](https://pub.dev/packages/tr_payment_hub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![CI](https://github.com/abdullah017/tr_payment_hub/actions/workflows/ci.yml/badge.svg)](https://github.com/abdullah017/tr_payment_hub/actions)

Türkiye ödeme sistemleri için birleşik Flutter/Dart kütüphanesi.

## Desteklenen Sağlayıcılar

| Sağlayıcı | Durum | Non-3DS | 3DS | Taksit | İade | Kayıtlı Kart |
|-----------|-------|---------|-----|--------|------|--------------|
| iyzico    | ✅ Stabil | Evet | Evet | Evet | Evet | Evet |
| PayTR     | ✅ Stabil | Evet | Evet | Evet | Evet | Hayır |
| Param     | ✅ Stabil | Evet | Evet | Evet | Evet | Hayır |
| Sipay     | ✅ Stabil | Evet | Evet | Evet | Evet | Evet |

## Özellikler

- **Unified API** - Tek interface ile tüm sağlayıcılara erişim
- **Type Safe** - Tam Dart null safety desteği
- **Güvenli** - Hassas verilerin otomatik maskelenmesi (LogSanitizer)
- **Test Desteği** - Yerleşik MockPaymentProvider ile kolay test
- **Platform Bağımsız** - iOS, Android, Web ve Desktop desteği
- **Kayıtlı Kart** - Kart tokenization desteği (iyzico, Sipay)

## Kurulum

`pubspec.yaml` dosyanıza ekleyin:

```yaml
dependencies:
  tr_payment_hub: ^1.0.3
```

Ardından:

```bash
dart pub get
```

## Hızlı Başlangıç

### 1. Provider Oluşturma

```dart
import 'package:tr_payment_hub/tr_payment_hub.dart';

// iyzico
final provider = TrPaymentHub.create(ProviderType.iyzico);

// PayTR
final provider = TrPaymentHub.create(ProviderType.paytr);

// Param
final provider = TrPaymentHub.create(ProviderType.param);

// Sipay
final provider = TrPaymentHub.create(ProviderType.sipay);

// Test için Mock
final provider = TrPaymentHub.createMock(shouldSucceed: true);
```

### 2. Konfigürasyon

```dart
// iyzico Konfigürasyonu
final config = IyzicoConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_API_KEY',
  secretKey: 'YOUR_SECRET_KEY',
  isSandbox: true, // Production için false
);

// PayTR Konfigürasyonu
final config = PayTRConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_MERCHANT_KEY',
  secretKey: 'YOUR_MERCHANT_SALT',
  successUrl: 'https://yoursite.com/success',
  failUrl: 'https://yoursite.com/fail',
  callbackUrl: 'https://yoursite.com/callback',
  isSandbox: true,
);

// Param Konfigürasyonu
final config = ParamConfig(
  merchantId: 'YOUR_CLIENT_CODE',
  apiKey: 'YOUR_CLIENT_USERNAME',
  secretKey: 'YOUR_CLIENT_PASSWORD',
  guid: 'YOUR_GUID',
  isSandbox: true,
);

// Sipay Konfigürasyonu
final config = SipayConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_APP_KEY',
  secretKey: 'YOUR_APP_SECRET',
  merchantKey: 'YOUR_MERCHANT_KEY',
  isSandbox: true,
);

await provider.initialize(config);
```

### 3. Ödeme Yapma

```dart
final request = PaymentRequest(
  orderId: 'ORDER_123',
  amount: 100.0,
  currency: Currency.tryLira,
  installment: 1,
  card: CardInfo(
    cardHolderName: 'John Doe',
    cardNumber: '5528790000000008',
    expireMonth: '12',
    expireYear: '2030',
    cvc: '123',
  ),
  buyer: BuyerInfo(
    id: 'BUYER_1',
    name: 'John',
    surname: 'Doe',
    email: 'john@example.com',
    phone: '+905551234567',
    ip: '127.0.0.1',
    city: 'Istanbul',
    country: 'Turkey',
    address: 'Test Address',
  ),
  basketItems: [
    BasketItem(
      id: 'ITEM_1',
      name: 'Product',
      category: 'Category',
      price: 100.0,
      itemType: ItemType.physical,
    ),
  ],
);

try {
  final result = await provider.createPayment(request);
  if (result.isSuccess) {
    print('Ödeme başarılı! ID: ${result.transactionId}');
  }
} on PaymentException catch (e) {
  print('Hata: ${e.message}');
}
```

### 4. 3D Secure Ödeme

```dart
// Adım 1: 3DS başlat
final threeDSResult = await provider.init3DSPayment(
  request.copyWith(callbackUrl: 'https://yoursite.com/3ds-callback'),
);

if (threeDSResult.needsWebView) {
  // Adım 2: WebView'da göster
  // iyzico: threeDSResult.htmlContent kullan
  // PayTR/Sipay: threeDSResult.redirectUrl'e yönlendir
}

// Adım 3: Callback sonrası tamamla
final result = await provider.complete3DSPayment(
  threeDSResult.transactionId!,
  callbackData: callbackData,
);
```

### 5. Taksit Sorgulama

```dart
final installments = await provider.getInstallments(
  binNumber: '552879', // Kartın ilk 6 hanesi
  amount: 1000.0,
);

print('Banka: ${installments.bankName}');
print('Kart: ${installments.cardFamily}');

for (final option in installments.options) {
  print('${option.installmentNumber} taksit: ${option.totalPrice} TL');
}
```

### 6. İade

```dart
final refundResult = await provider.refund(RefundRequest(
  transactionId: 'TRANSACTION_ID',
  amount: 50.0, // Kısmi iade
));

if (refundResult.isSuccess) {
  print('İade başarılı!');
}
```

### 7. Kayıtlı Kartlar (iyzico & Sipay)

```dart
// Kayıtlı kartları getir
final cards = await provider.getSavedCards('user_card_key');

// Kayıtlı kart ile ödeme
final result = await provider.chargeWithSavedCard(
  cardToken: cards.first.cardToken,
  orderId: 'ORDER_456',
  amount: 50.0,
  buyer: buyerInfo,
);

// Kayıtlı kartı sil
await provider.deleteSavedCard(cardToken: 'card_token');
```

## Hata Yönetimi

```dart
try {
  await provider.createPayment(request);
} on PaymentException catch (e) {
  switch (e.code) {
    case 'insufficient_funds':
      print('Yetersiz bakiye');
      break;
    case 'invalid_card':
      print('Geçersiz kart');
      break;
    case 'expired_card':
      print('Kartın süresi dolmuş');
      break;
    case 'threeds_failed':
      print('3D Secure doğrulaması başarısız');
      break;
    default:
      print('Hata: ${e.message}');
  }
}
```

## Test

### Mock Provider ile Unit Test

```dart
// Mock provider oluştur
final mockProvider = TrPaymentHub.createMock(
  shouldSucceed: true,
  delay: Duration(milliseconds: 100),
);

// Başarısız senaryo testi
final failingProvider = TrPaymentHub.createMock(
  shouldSucceed: false,
  customError: PaymentException.insufficientFunds(),
);
```

### Testleri Çalıştırma

```bash
# Tüm unit testleri çalıştır
dart test

# Coverage ile çalıştır
dart test --coverage=coverage

# Integration testleri çalıştır (credential gerektirir)
export IYZICO_MERCHANT_ID=xxx
export IYZICO_API_KEY=xxx
export IYZICO_SECRET_KEY=xxx
dart test --tags=integration
```

## Test Kartları

Sandbox ortamlarında bu test kart numaralarını kullanın:

| Sağlayıcı | Kart Numarası | Senaryo |
|-----------|---------------|---------|
| iyzico | 5528790000000008 | Başarılı (MasterCard) |
| iyzico | 5400010000000004 | Başarılı (MasterCard) |
| iyzico | 4543590000000006 | Yetersiz Bakiye |
| iyzico | 4059030000000009 | 3DS Gerekli |
| PayTR | 4355084355084358 | Başarılı |
| PayTR | 5571135571135575 | Başarılı (MasterCard) |
| Sipay | 4508034508034509 | Başarılı |
| Param | 4022774022774026 | Başarılı |

**Test CVV:** 000 veya 123
**Test Son Kullanma:** Gelecek bir tarih (örn. 12/2030)

## Sandbox Ortamları

| Sağlayıcı | Sandbox URL | Dokümantasyon |
|-----------|-------------|---------------|
| iyzico | sandbox-api.iyzipay.com | [dev.iyzipay.com](https://dev.iyzipay.com) |
| PayTR | www.paytr.com | [dev.paytr.com](https://dev.paytr.com) |
| Sipay | sandbox.sipay.com.tr | [apidocs.sipay.com.tr](https://apidocs.sipay.com.tr) |
| Param | test-dmz.param.com.tr | [dev.param.com.tr](https://dev.param.com.tr) |

## Güvenlik

- Kart bilgileri asla loglanmaz
- `LogSanitizer.sanitize()` ile hassas veri maskeleme
- Her zaman HTTPS callback URL'leri kullanın
- API key'leri güvenli saklayın (environment variables, secure storage)

```dart
// Güvenli loglama
final safeLog = LogSanitizer.sanitize(sensitiveData);
final safeMap = LogSanitizer.sanitizeMap(requestData);
```

## Flutter Web Uyarısı

Türkiye'deki ödeme API'leri CORS kısıtlamalarına sahiptir. Flutter Web'de:

1. Backend proxy kullanın (önerilen)
2. Cloud Functions üzerinden yönlendirin
3. Sadece mobil platformlarda kullanın

## API Referansı

| Metod | Açıklama |
|-------|----------|
| `initialize(config)` | Provider'ı başlatır |
| `createPayment(request)` | Non-3DS ödeme yapar |
| `init3DSPayment(request)` | 3DS ödeme başlatır |
| `complete3DSPayment(id)` | 3DS ödemeyi tamamlar |
| `getInstallments(bin, amount)` | Taksit seçeneklerini getirir |
| `refund(request)` | İade işlemi yapar |
| `getPaymentStatus(id)` | Ödeme durumunu sorgular |
| `chargeWithSavedCard(...)` | Kayıtlı kart ile ödeme |
| `getSavedCards(userKey)` | Kayıtlı kartları listeler |
| `deleteSavedCard(token)` | Kayıtlı kartı siler |
| `dispose()` | Kaynakları temizler |

## Katkıda Bulunma

1. Fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing`)
3. Commit edin (`git commit -m 'Add amazing feature'`)
4. Push edin (`git push origin feature/amazing`)
5. Pull Request açın

## Lisans

MIT License - detaylar için [LICENSE](LICENSE) dosyasına bakın.

## İletişim

- GitHub Issues: [Sorun Bildir](https://github.com/abdullah017/tr_payment_hub/issues)
- Email: dev.abdullahtas@gmail.com

---

**Not:** Bu paket resmi iyzico, PayTR, Param veya Sipay paketi değildir. Topluluk tarafından geliştirilmiştir.
