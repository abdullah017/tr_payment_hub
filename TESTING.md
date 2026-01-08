# Test Stratejisi / Testing Strategy

Bu doküman `tr_payment_hub` paketinin nasıl test edildiğini ve gerçek ödeme testlerinin nasıl yapılacağını açıklar.

## Test Katmanları

### 1. Unit Tests (245 test) ✅
```bash
dart test
```

**Ne test eder:**
- Hash algoritmaları (HMAC-SHA256, SHA1, Base64)
- Request/Response mapping (JSON, XML dönüşümleri)
- Model validation (Luhn, email, telefon formatı)
- Error mapping (provider hata kodları → standart kodlar)
- CardInfo masking (kart numarası gizleme)
- LogSanitizer (hassas veri temizleme)

**Ne test ETMEZ:**
- ❌ Gerçek API bağlantısı
- ❌ Ödeme işleminin gerçekten geçmesi
- ❌ 3DS yönlendirmesinin çalışması

### 2. Mock Tests ✅
**Ne test eder:**
- Provider logic (initialize, createPayment, refund akışı)
- HTTP response handling
- Timeout ve error senaryoları

```dart
// Mock client ile test
final mockClient = PaymentMockClient.iyzico(shouldSucceed: true);
final provider = IyzicoProvider(httpClient: mockClient);
```

### 3. Integration Tests ⚠️
```bash
# API key'ler gerekli!
export IYZICO_MERCHANT_ID=xxx
export IYZICO_API_KEY=xxx
export IYZICO_SECRET_KEY=xxx
dart test --tags=integration
```

**Ne test eder:**
- ✅ Gerçek API bağlantısı
- ✅ Ödeme işleminin sandbox'ta geçmesi
- ✅ 3DS başlatma
- ✅ Refund işlemi

---

## 🚀 Hızlı Başlangıç: Gerçek Test Yapmak

### Adım 1: iyzico Sandbox Hesabı Aç (5 dakika)

1. [sandbox-merchant.iyzipay.com](https://sandbox-merchant.iyzipay.com) adresine git
2. "Kayıt Ol" butonuna tıkla
3. Email ve şifre ile kayıt ol
4. Email'i doğrula
5. Dashboard'dan API bilgilerini al:
   - Merchant ID
   - API Key
   - Secret Key

### Adım 2: Environment Variables Set Et

```bash
export IYZICO_MERCHANT_ID="sandbox-xxxxx"
export IYZICO_API_KEY="sandbox-xxxxx"
export IYZICO_SECRET_KEY="sandbox-xxxxx"
```

### Adım 3: Test Script'i Çalıştır

```bash
dart scripts/test_real_payment.dart
```

### Beklenen Çıktı

```
╔════════════════════════════════════════════════════════════╗
║       TR Payment Hub - Real Integration Test               ║
╚════════════════════════════════════════════════════════════╝

✓ Environment variables bulundu
✓ Provider initialized

─────────────────────────────────────────
TEST 1: BIN Sorgulama (Taksit bilgisi)
─────────────────────────────────────────
✓ BIN Sorgusu başarılı!
  Banka: Akbank
  Kart Tipi: CardType.creditCard
  Taksit Seçenekleri:
    1x: 100.00 TL
    2x: 102.00 TL
    3x: 103.50 TL

─────────────────────────────────────────
TEST 2: Non-3DS Ödeme (1 TL test)
─────────────────────────────────────────
✓ Ödeme başarılı!
  Transaction ID: 12345678
  Tutar: 1.0 TL

─────────────────────────────────────────
TEST 3: İade (Refund)
─────────────────────────────────────────
✓ İade başarılı!
  Refund ID: 87654321

─────────────────────────────────────────
TEST 4: 3DS Başlatma
─────────────────────────────────────────
✓ 3DS başlatıldı!
  Transaction ID: 99999999
  HTML Content: <html>...

─────────────────────────────────────────
TEST 5: Yetersiz Bakiye Kartı
─────────────────────────────────────────
✓ Beklenen hata yakalandı: insufficient_funds
  Mesaj: Yetersiz bakiye
```

---

## Test Kartları

### iyzico Sandbox

| Kart Numarası | Sonuç | Açıklama |
|---------------|-------|----------|
| 5528790000000008 | ✅ Başarılı | MasterCard |
| 5400010000000004 | ✅ Başarılı | MasterCard |
| 4766620000000001 | ✅ Başarılı | Visa |
| 4543590000000006 | ❌ Başarısız | Yetersiz bakiye |
| 4059030000000009 | 🔄 3DS | 3DS yönlendirme gerekli |

**CVV:** 123
**Son Kullanma:** Gelecek herhangi bir tarih (örn: 12/2030)

### PayTR Sandbox

| Kart Numarası | Sonuç |
|---------------|-------|
| 4355084355084358 | ✅ Başarılı |
| 5571135571135575 | ✅ Başarılı |

**CVV:** 000
**Son Kullanma:** Gelecek tarih

### Sipay Sandbox

| Kart Numarası | Sonuç |
|---------------|-------|
| 4508034508034509 | ✅ Başarılı |
| 5406670000000009 | ✅ Başarılı |

### Param Sandbox

| Kart Numarası | Sonuç |
|---------------|-------|
| 4022774022774026 | ✅ Başarılı |
| 5456165456165454 | ✅ Başarılı |

---

## Provider Bazında Sandbox Bilgileri

### iyzico
- **URL:** sandbox-api.iyzipay.com
- **Panel:** [sandbox-merchant.iyzipay.com](https://sandbox-merchant.iyzipay.com)
- **Kayıt:** Anında (email doğrulama)
- **Dokümantasyon:** [dev.iyzipay.com](https://dev.iyzipay.com)

### PayTR
- **URL:** www.paytr.com (test_mode=1)
- **Panel:** [magaza.paytr.com](https://magaza.paytr.com)
- **Kayıt:** Başvuru gerekli (1-2 iş günü)
- **Dokümantasyon:** [dev.paytr.com](https://dev.paytr.com)

### Sipay
- **URL:** sandbox.sipay.com.tr
- **Panel:** [merchant.sipay.com.tr](https://merchant.sipay.com.tr)
- **Kayıt:** Başvuru gerekli
- **Dokümantasyon:** [apidocs.sipay.com.tr](https://apidocs.sipay.com.tr)

### Param
- **URL:** test-dmz.param.com.tr
- **Kayıt:** Başvuru gerekli
- **Dokümantasyon:** [dev.param.com.tr](https://dev.param.com.tr)

---

## CI/CD Integration Test

GitHub Actions'da integration test çalıştırmak için:

```yaml
# .github/workflows/integration.yml
name: Integration Tests

on:
  workflow_dispatch:  # Manuel tetikleme

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1

      - name: Run Integration Tests
        env:
          IYZICO_MERCHANT_ID: ${{ secrets.IYZICO_MERCHANT_ID }}
          IYZICO_API_KEY: ${{ secrets.IYZICO_API_KEY }}
          IYZICO_SECRET_KEY: ${{ secrets.IYZICO_SECRET_KEY }}
        run: dart test --tags=integration
```

**Not:** Secrets'ları GitHub repository settings → Secrets → Actions'a ekleyin.

---

## Sorun Giderme

### "API Key geçersiz" hatası
- Sandbox mı production mı kontrol edin (`isSandbox: true`)
- API key'leri copy-paste yaparken boşluk olmadığından emin olun

### "IP adresiniz engellendi" hatası
- Sandbox panel'den IP whitelist'e IP'nizi ekleyin

### "3DS callback çalışmıyor"
- `callbackUrl` gerçek bir HTTPS URL olmalı
- Localhost test için ngrok kullanabilirsiniz

### "Ödeme geçti ama para çekilmedi"
- Sandbox'ta gerçek para işlemi olmaz, sadece simülasyon

---

## Özet

| Test | Yapılıyor mu? | Notlar |
|------|---------------|--------|
| Hash hesaplama | ✅ Unit test | Tüm algoritmalar test ediliyor |
| JSON/XML format | ✅ Unit test | Mock response'larla |
| Kart validation | ✅ Unit test | Luhn, expiry, CVV |
| Error handling | ✅ Unit test | Tüm error kodları |
| Gerçek ödeme | ⚠️ Manuel | Sandbox API key gerekli |
| 3DS flow | ⚠️ Manuel | WebView gerekli |
| Production | ❌ | Asla test etmeyin! |

**Önemli:** Production API'lerinde test YAPMAYIN! Her zaman sandbox kullanın.
