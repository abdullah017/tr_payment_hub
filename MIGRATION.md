# Migration Guide: v1.x to v2.0.0

[Türkçe](#türkçe) | [English](#english)

---

## English

This guide explains the changes required when upgrading `tr_payment_hub` from v1.x to v2.0.0.

### Breaking Changes

#### 1. Validation is Now Mandatory

All model classes now have a `validate()` method that throws `ValidationException` for invalid input.

```dart
// v1.x - No validation
final request = PaymentRequest(amount: -100, ...); // Was allowed

// v2.0.0 - Strict validation
final request = PaymentRequest(amount: -100, ...);
request.validate(); // Throws ValidationException!
```

**Solution:** Call `validate()` before payment operations or use try-catch:

```dart
try {
  request.validate();
  final result = await provider.createPayment(request);
} on ValidationException catch (e) {
  print('Validation error: ${e.allErrors}');
} on PaymentException catch (e) {
  print('Payment error: ${e.message}');
}
```

#### 2. New Config Parameters

All config classes now have `connectionTimeout` and `enableRetry` parameters (optional with defaults).

```dart
// v1.x
final config = IyzicoConfig(
  merchantId: '...',
  apiKey: '...',
  secretKey: '...',
);

// v2.0.0 - New parameters (optional, with defaults)
final config = IyzicoConfig(
  merchantId: '...',
  apiKey: '...',
  secretKey: '...',
  connectionTimeout: Duration(seconds: 30), // Default
  enableRetry: true, // Default
);
```

#### 3. CardInfo.toJson() is Now @internal

The `toJson()` method is marked as `@internal` since it contains sensitive data. Use `toSafeJson()` for logging.

```dart
// v1.x - toJson() was unsafe
print(card.toJson()); // Exposed CVV and full card number!

// v2.0.0 - Use toSafeJson() for logging
print(card.toSafeJson()); // CVV: '***', cardNumber: masked
```

#### 4. New Exception Types

`ValidationException` and `CircuitBreakerOpenException` are now available.

```dart
// v2.0.0 - New exception handling
try {
  request.validate();
  await provider.createPayment(request);
} on ValidationException catch (e) {
  // Input validation error
  print('Invalid data: ${e.allErrors}');
} on CircuitBreakerOpenException catch (e) {
  // Service temporarily unavailable
  print('Retry in ${e.remainingTime.inSeconds} seconds');
} on PaymentException catch (e) {
  // Payment error
  print('Payment error: ${e.message}');
}
```

### New Features

#### 1. Input Validation

Comprehensive validation on all model classes:

```dart
// CardInfo validation
card.validate(); // Luhn check, expiry date, CVC format

// BuyerInfo validation
buyer.validate(); // Email, phone (Turkish format), TC Kimlik

// PaymentRequest validation
request.validate(); // Amount > 0, basket total, 3DS callback

// RefundRequest validation
refund.validate(); // Amount > 0, transaction ID
```

#### 2. RetryHandler - Exponential Backoff

Automatic retry for transient errors:

```dart
final handler = RetryHandler(
  config: RetryConfig.conservative, // Safe for payment operations
);

final result = await handler.execute(
  () => makeHttpRequest(),
  onRetry: (attempt, error, delay) {
    print('Retry $attempt: $error');
  },
);
```

#### 3. CircuitBreaker Pattern

Prevent cascading failures:

```dart
final breaker = CircuitBreaker(
  name: 'payment-service',
  config: CircuitBreakerConfig(
    failureThreshold: 5,
    timeout: Duration(seconds: 30),
  ),
);

try {
  await breaker.execute(() => makePayment());
} on CircuitBreakerOpenException catch (e) {
  print('Service temporarily unavailable');
}
```

#### 4. PaymentLogger - Secure Logging

Automatic sensitive data masking:

```dart
PaymentLogger.initialize(
  logCallback: (entry) => print(entry),
  minLevel: LogLevel.info,
);

PaymentLogger.info('Payment started', data: {
  'orderId': '123',
  'cardNumber': '5528790000000008', // Automatically masked
});
```

#### 5. CardInfo.isExpired

Check card expiration:

```dart
if (card.isExpired) {
  print('Card has expired');
}
```

### Migration Steps

1. **Update pubspec.yaml:**
   ```yaml
   dependencies:
     tr_payment_hub: ^2.0.0
   ```

2. **Run `dart pub get`**

3. **Import ValidationException:**
   ```dart
   import 'package:tr_payment_hub/tr_payment_hub.dart';
   // ValidationException is now included
   ```

4. **Update exception handling:**
   ```dart
   try {
     request.validate();
     await provider.createPayment(request);
   } on ValidationException catch (e) {
     // Handle validation error
   } on PaymentException catch (e) {
     // Handle payment error
   }
   ```

5. **Update logging code:**
   ```dart
   // Old
   print(card.toJson());

   // New
   print(card.toSafeJson());
   ```

6. **Test in sandbox environment**

7. **Deploy to production**

### Backward Compatibility

- Existing `PaymentException` handling is preserved
- Config class existing parameters unchanged
- Provider APIs unchanged (`createPayment`, `refund`, etc.)

---

## Türkçe

Bu rehber, `tr_payment_hub` paketini v1.x'ten v2.0.0'a yükseltirken yapılması gereken değişiklikleri açıklar.

### Breaking Changes

#### 1. Validation Artık Zorunlu

Tüm model sınıflarında `validate()` metodu eklendi ve geçersiz input'larda `ValidationException` fırlatılır.

```dart
// v1.x - Validation yok
final request = PaymentRequest(amount: -100, ...); // İzin veriliyordu

// v2.0.0 - Strict validation
final request = PaymentRequest(amount: -100, ...);
request.validate(); // ValidationException fırlatır!
```

**Çözüm:** Ödeme işlemlerinden önce `validate()` çağırın veya try-catch bloğu kullanın:

```dart
try {
  request.validate();
  final result = await provider.createPayment(request);
} on ValidationException catch (e) {
  print('Validation hatası: ${e.allErrors}');
} on PaymentException catch (e) {
  print('Ödeme hatası: ${e.message}');
}
```

#### 2. Config Sınıflarına Yeni Parametreler Eklendi

Tüm config sınıflarına `connectionTimeout` ve `enableRetry` parametreleri eklendi.

```dart
// v1.x
final config = IyzicoConfig(
  merchantId: '...',
  apiKey: '...',
  secretKey: '...',
);

// v2.0.0 - Yeni parametreler (opsiyonel, varsayılan değerler var)
final config = IyzicoConfig(
  merchantId: '...',
  apiKey: '...',
  secretKey: '...',
  connectionTimeout: Duration(seconds: 30), // Varsayılan
  enableRetry: true, // Varsayılan
);
```

#### 3. CardInfo.toJson() Artık @internal

`toJson()` metodu hassas veri içerdiği için `@internal` olarak işaretlendi. Loglama için `toSafeJson()` kullanın.

```dart
// v1.x - toJson() güvenli değildi
print(card.toJson()); // CVV dahil tüm veriler!

// v2.0.0 - Loglama için toSafeJson() kullanın
print(card.toSafeJson()); // CVV: '***', cardNumber: masked
```

#### 4. Yeni Exception Tipleri

`ValidationException` ve `CircuitBreakerOpenException` eklendi.

```dart
// v2.0.0 - Yeni exception handling
try {
  request.validate();
  await provider.createPayment(request);
} on ValidationException catch (e) {
  // Input validation hatası
  print('Geçersiz veri: ${e.allErrors}');
} on CircuitBreakerOpenException catch (e) {
  // Servis geçici olarak kullanılamıyor
  print('${e.remainingTime.inSeconds} saniye sonra tekrar deneyin');
} on PaymentException catch (e) {
  // Ödeme hatası
  print('Ödeme hatası: ${e.message}');
}
```

### Yeni Özellikler

#### 1. Input Validation

Tüm model sınıflarında kapsamlı validation:

```dart
// CardInfo validation
card.validate(); // Luhn check, expiry date, CVC format

// BuyerInfo validation
buyer.validate(); // Email, phone (Türk format), TC Kimlik

// PaymentRequest validation
request.validate(); // Amount > 0, basket total, 3DS callback

// RefundRequest validation
refund.validate(); // Amount > 0, transaction ID
```

#### 2. RetryHandler - Exponential Backoff

Transient hatalar için otomatik retry:

```dart
final handler = RetryHandler(
  config: RetryConfig.conservative, // Ödeme işlemleri için
);

final result = await handler.execute(
  () => makeHttpRequest(),
  onRetry: (attempt, error, delay) {
    print('Retry $attempt: $error');
  },
);
```

#### 3. CircuitBreaker Pattern

Cascading failure'ları önlemek için circuit breaker:

```dart
final breaker = CircuitBreaker(
  name: 'payment-service',
  config: CircuitBreakerConfig(
    failureThreshold: 5,
    timeout: Duration(seconds: 30),
  ),
);

try {
  await breaker.execute(() => makePayment());
} on CircuitBreakerOpenException catch (e) {
  print('Servis geçici olarak kullanılamıyor');
}
```

#### 4. PaymentLogger - Güvenli Loglama

Otomatik hassas veri maskeleme:

```dart
PaymentLogger.initialize(
  logCallback: (entry) => print(entry),
  minLevel: LogLevel.info,
);

PaymentLogger.info('Payment started', data: {
  'orderId': '123',
  'cardNumber': '5528790000000008', // Otomatik maskelenir
});
```

#### 5. CardInfo.isExpired

Kart son kullanma tarihi kontrolü:

```dart
if (card.isExpired) {
  print('Kart süresi dolmuş');
}
```

### Migration Adımları

1. **pubspec.yaml güncelle:**
   ```yaml
   dependencies:
     tr_payment_hub: ^2.0.0
   ```

2. **`dart pub get` çalıştır**

3. **ValidationException import et:**
   ```dart
   import 'package:tr_payment_hub/tr_payment_hub.dart';
   // ValidationException artık dahil
   ```

4. **Exception handling güncelle:**
   ```dart
   try {
     request.validate();
     await provider.createPayment(request);
   } on ValidationException catch (e) {
     // Handle validation error
   } on PaymentException catch (e) {
     // Handle payment error
   }
   ```

5. **Loglama kodunu güncelle:**
   ```dart
   // Eski
   print(card.toJson());

   // Yeni
   print(card.toSafeJson());
   ```

6. **Test ortamında test et**

7. **Production'a deploy et**

### Geriye Uyumluluk

- Mevcut `PaymentException` handling korundu
- Config sınıflarının mevcut parametreleri aynı
- Provider API'leri değişmedi (`createPayment`, `refund`, vb.)

---

## Help / Yardım

For questions / Sorularınız için:
- GitHub Issues: https://github.com/abdullah017/tr_payment_hub/issues
