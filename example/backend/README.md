# TR Payment Hub - Backend Example

Bu backend, Flutter uygulaması ile ödeme sağlayıcıları arasında güvenli bir proxy görevi görür. API anahtarları sunucuda saklanır ve istemciye asla ifşa edilmez.

## Kurulum

```bash
# Bağımlılıkları yükle
npm install

# .env dosyasını oluştur
cp .env.example .env

# .env dosyasını düzenle ve API anahtarlarını gir
nano .env

# Sunucuyu başlat
npm start
```

## API Endpoints

### Health Check
```
GET /health
```

### Ödeme İşlemleri

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| POST | /api/payment/create | Ödeme oluştur |
| POST | /api/payment/3ds/init | 3DS başlat |
| POST | /api/payment/3ds/complete | 3DS tamamla |
| GET | /api/payment/installments | Taksit sorgula |
| POST | /api/payment/refund | İade işlemi |
| GET | /api/payment/status/:id | Durum sorgula |

### Kayıtlı Kartlar

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | /api/payment/cards | Kart listele |
| POST | /api/payment/cards/charge | Kart ile öde |
| DELETE | /api/payment/cards/:token | Kart sil |

## Flutter Entegrasyonu

Flutter uygulamasında proxy mode kullanmak için:

```dart
final provider = ProxyPaymentProvider(
  config: ProxyConfig(
    baseUrl: 'http://localhost:3000/api/payment',
    authToken: userAuthToken, // Opsiyonel
  ),
);

await provider.initializeWithProvider(ProviderType.iyzico);

final result = await provider.createPayment(request);
```

## Güvenlik Notları

1. **Production'da HTTPS kullanın**
2. **API anahtarlarını asla client'a göndermein**
3. **Rate limiting ekleyin**
4. **Input validation yapın**
5. **Logging ve monitoring ekleyin**

## Test Kartları

### iyzico Sandbox
- Başarılı: 5528790000000008, CVV: 123, Ay/Yıl: 12/30
- Başarısız: 4543590000000006, CVV: 123, Ay/Yıl: 12/30

### PayTR Test
- Test: 4355084355084358, CVV: 000, Ay/Yıl: 12/30

### Sipay Test
- Başarılı: 4508034508034509, CVV: 000, Ay/Yıl: 12/30
