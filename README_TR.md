# TR Payment Hub

[![Pub Version](https://img.shields.io/pub/v/tr_payment_hub)](https://pub.dev/packages/tr_payment_hub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Türkiye ödeme sistemleri için birleşik Flutter/Dart kütüphanesi.

**Desteklenen Sağlayıcılar:**
- ✅ iyzico
- ✅ PayTR
- 🔜 Param (yakında)
- 🔜 Sipay (yakında)

## Özellikler

- 🔄 **Unified API** - Tek interface ile tüm sağlayıcılara erişim
- 🔒 **Güvenli** - Hassas verilerin otomatik maskelenmesi
- 🧪 **Test Desteği** - Mock provider ile kolay test
- 📱 **Platform Bağımsız** - Web, iOS, Android, Desktop
- 💳 **3D Secure** - Tüm sağlayıcılarda 3DS desteği
- 💰 **Taksit** - Taksit sorgulama ve ödeme

## Kurulum
```yaml
dependencies:
  tr_payment_hub: ^1.0.2
```
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

// Test için Mock
final provider = TrPaymentHub.createMock(shouldSucceed: true);
```

### 2. Konfigürasyon
```dart
// iyzico Config
final config = IyzicoConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_API_KEY',
  secretKey: 'YOUR_SECRET_KEY',
  isSandbox: true, // Production için false
);

// PayTR Config
final config = PayTRConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_MERCHANT_KEY',
  secretKey: 'YOUR_MERCHANT_SALT',
  successUrl: 'https://yoursite.com/success',
  failUrl: 'https://yoursite.com/fail',
  callbackUrl: 'https://yoursite.com/callback',
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
// 3DS başlat
final threeDSResult = await provider.init3DSPayment(
  request.copyWith(callbackUrl: 'https://yoursite.com/3ds-callback'),
);

if (threeDSResult.needsWebView) {
  // WebView'da göster
  // iyzico: threeDSResult.htmlContent
  // PayTR: threeDSResult.redirectUrl
}

// Callback sonrası tamamla
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
  ip: '127.0.0.1',
));

if (refundResult.isSuccess) {
  print('İade başarılı!');
}
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
```dart
// Mock provider ile test
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

## Güvenlik

- 🔐 Kart bilgileri asla loglanmaz
- 🛡️ `LogSanitizer` ile hassas veri maskeleme
- ✅ PCI-DSS uyumlu yapı
```dart
// Log temizleme
final safeLog = LogSanitizer.sanitize(sensitiveData);

// Map temizleme
final safeMap = LogSanitizer.sanitizeMap(requestData);
```

## ⚠️ Flutter Web Kullanıcıları

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

**Not:** Bu paket resmi iyzico veya PayTR paketi değildir. Topluluk tarafından geliştirilmiştir.
