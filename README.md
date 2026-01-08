# TR Payment Hub

[![Pub Version](https://img.shields.io/pub/v/tr_payment_hub)](https://pub.dev/packages/tr_payment_hub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![CI](https://github.com/abdullah017/tr_payment_hub/actions/workflows/ci.yml/badge.svg)](https://github.com/abdullah017/tr_payment_hub/actions)

**[Türkçe Dokümantasyon](README_TR.md)**

Unified Turkish payment gateway integration for Flutter/Dart applications.

## Supported Providers

| Provider | Status | Non-3DS | 3DS | Installments | Refunds | Saved Cards |
|----------|--------|---------|-----|--------------|---------|-------------|
| iyzico   | ✅ Stable | Yes | Yes | Yes | Yes | Yes |
| PayTR    | ✅ Stable | Yes | Yes | Yes | Yes | No |
| Param    | ✅ Stable | Yes | Yes | Yes | Yes | No |
| Sipay    | ✅ Stable | Yes | Yes | Yes | Yes | Yes |

## Features

- **Unified API** - Single interface for all payment providers
- **Proxy Mode** - Secure Flutter + Custom Backend architecture (v3.0+)
- **Type Safe** - Full Dart null safety support
- **Secure** - Automatic sensitive data masking with LogSanitizer
- **Testable** - Built-in MockPaymentProvider for unit testing
- **Cross Platform** - Works on iOS, Android, Web, and Desktop
- **Saved Cards** - Card tokenization support (iyzico, Sipay)
- **Client Validation** - CardValidator and RequestValidator for client-side validation

## Usage Modes

TR Payment Hub supports two usage modes:

### Proxy Mode (Recommended for Flutter Apps)

Use this mode when your backend is written in **any language** (Node.js, Python, Go, PHP, etc.).
API credentials stay secure on your backend - never exposed in the Flutter app.

```dart
import 'package:tr_payment_hub/tr_payment_hub_client.dart';

// Create proxy provider (no credentials needed!)
final provider = TrPaymentHub.createProxy(
  baseUrl: 'https://api.yourbackend.com/payment',
  provider: ProviderType.iyzico,
  authToken: 'user_jwt_token', // Optional
);

await provider.initializeWithProvider(ProviderType.iyzico);

// Payment request goes to YOUR backend
final result = await provider.createPayment(request);
```

**Benefits:**
- API keys stay on your secure backend
- Backend can be any language
- Unified Flutter code regardless of provider
- Client-side validation before sending

### Direct Mode (Dart Backend Only)

Use this mode only when your backend is written in **Dart** (serverpod, dart_frog, shelf).
Credentials are passed during initialization.

```dart
import 'package:tr_payment_hub/tr_payment_hub.dart';

final provider = TrPaymentHub.create(ProviderType.iyzico);
await provider.initialize(IyzicoConfig(
  apiKey: 'xxx',
  secretKey: 'xxx',
  merchantId: 'xxx',
));
```

## Client-Side Validation

Validate card information before sending to backend:

```dart
import 'package:tr_payment_hub/tr_payment_hub_client.dart';

final validation = CardValidator.validate(
  cardNumber: '5528790000000008',
  expireMonth: '12',
  expireYear: '2030',
  cvv: '123',
  holderName: 'Ahmet Yilmaz',
);

if (!validation.isValid) {
  print(validation.errors); // {'cardNumber': 'Invalid card number'}
  return;
}

print('Card brand: ${validation.cardBrand.displayName}'); // Mastercard

// Now safe to send to backend
await provider.createPayment(request);
```

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  tr_payment_hub: ^2.0.1
```

Then run:

```bash
dart pub get
```

## Quick Start

### 1. Create Provider

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

// Mock (for testing)
final provider = TrPaymentHub.createMock(shouldSucceed: true);
```

### 2. Initialize with Config

```dart
// iyzico Configuration
final config = IyzicoConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_API_KEY',
  secretKey: 'YOUR_SECRET_KEY',
  isSandbox: true, // false for production
);

// PayTR Configuration
final config = PayTRConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_MERCHANT_KEY',
  secretKey: 'YOUR_MERCHANT_SALT',
  successUrl: 'https://yoursite.com/success',
  failUrl: 'https://yoursite.com/fail',
  callbackUrl: 'https://yoursite.com/callback',
  isSandbox: true,
);

// Param Configuration
final config = ParamConfig(
  merchantId: 'YOUR_CLIENT_CODE',
  apiKey: 'YOUR_CLIENT_USERNAME',
  secretKey: 'YOUR_CLIENT_PASSWORD',
  guid: 'YOUR_GUID',
  isSandbox: true,
);

// Sipay Configuration
final config = SipayConfig(
  merchantId: 'YOUR_MERCHANT_ID',
  apiKey: 'YOUR_APP_KEY',
  secretKey: 'YOUR_APP_SECRET',
  merchantKey: 'YOUR_MERCHANT_KEY',
  isSandbox: true,
);

await provider.initialize(config);
```

### 3. Create Payment

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
    print('Payment successful! ID: ${result.transactionId}');
  }
} on PaymentException catch (e) {
  print('Payment failed: ${e.message}');
}
```

### 4. 3D Secure Payment

```dart
// Step 1: Initialize 3DS
final threeDSResult = await provider.init3DSPayment(
  request.copyWith(callbackUrl: 'https://yoursite.com/3ds-callback'),
);

if (threeDSResult.needsWebView) {
  // Step 2: Display in WebView
  // iyzico: Use threeDSResult.htmlContent
  // PayTR/Sipay: Redirect to threeDSResult.redirectUrl
}

// Step 3: Complete after callback
final result = await provider.complete3DSPayment(
  threeDSResult.transactionId!,
  callbackData: receivedCallbackData,
);
```

### 5. Query Installments

```dart
final installments = await provider.getInstallments(
  binNumber: '552879', // First 6 digits of card
  amount: 1000.0,
);

print('Bank: ${installments.bankName}');
for (final option in installments.options) {
  print('${option.installmentNumber}x: ${option.totalPrice} TL');
}
```

### 6. Process Refund

```dart
final refundResult = await provider.refund(RefundRequest(
  transactionId: 'ORIGINAL_TRANSACTION_ID',
  amount: 50.0, // Partial refund
));

if (refundResult.isSuccess) {
  print('Refund successful!');
}
```

### 7. Saved Cards (iyzico & Sipay)

```dart
// Get saved cards
final cards = await provider.getSavedCards('user_card_key');

// Charge with saved card
final result = await provider.chargeWithSavedCard(
  cardToken: cards.first.cardToken,
  orderId: 'ORDER_456',
  amount: 50.0,
  buyer: buyerInfo,
);

// Delete saved card
await provider.deleteSavedCard(cardToken: 'card_token');
```

## Error Handling

```dart
try {
  await provider.createPayment(request);
} on PaymentException catch (e) {
  switch (e.code) {
    case 'insufficient_funds':
      // Handle insufficient balance
      break;
    case 'invalid_card':
      // Handle invalid card
      break;
    case 'expired_card':
      // Handle expired card
      break;
    case 'threeds_failed':
      // Handle 3DS failure
      break;
    default:
      print('Error: ${e.message}');
  }
}
```

## Testing

### Unit Tests with Mock Provider

```dart
// Create mock provider
final mockProvider = TrPaymentHub.createMock(
  shouldSucceed: true,
  delay: Duration(milliseconds: 100),
);

// Test failure scenarios
final failingProvider = TrPaymentHub.createMock(
  shouldSucceed: false,
  customError: PaymentException.insufficientFunds(),
);
```

### Running Tests

```bash
# Run all unit tests (245 tests)
dart test

# Run with coverage
dart test --coverage=coverage

# Run integration tests (requires sandbox credentials)
export IYZICO_MERCHANT_ID=xxx
export IYZICO_API_KEY=xxx
export IYZICO_SECRET_KEY=xxx
dart test --tags=integration

# Quick real payment test
dart scripts/test_real_payment.dart
```

> 📖 **Full Testing Guide:** See [TESTING.md](TESTING.md) for sandbox setup and integration testing.

## Test Cards

Use these test card numbers in sandbox environments:

| Provider | Card Number | Scenario |
|----------|-------------|----------|
| iyzico | 5528790000000008 | Success (MasterCard) |
| iyzico | 5400010000000004 | Success (MasterCard) |
| iyzico | 4543590000000006 | Insufficient Funds |
| iyzico | 4059030000000009 | 3DS Required |
| PayTR | 4355084355084358 | Success |
| PayTR | 5571135571135575 | Success (MasterCard) |
| Sipay | 4508034508034509 | Success |
| Param | 4022774022774026 | Success |

**Test CVV:** 000 or 123
**Test Expiry:** Any future date (e.g., 12/2030)

## Sandbox Environments

| Provider | Sandbox URL | Documentation |
|----------|-------------|---------------|
| iyzico | sandbox-api.iyzipay.com | [dev.iyzipay.com](https://dev.iyzipay.com) |
| PayTR | www.paytr.com | [dev.paytr.com](https://dev.paytr.com) |
| Sipay | sandbox.sipay.com.tr | [apidocs.sipay.com.tr](https://apidocs.sipay.com.tr) |
| Param | test-dmz.param.com.tr | [dev.param.com.tr](https://dev.param.com.tr) |

## Security Best Practices

- Card numbers are never logged
- Use `LogSanitizer.sanitize()` before logging any payment data
- Always use HTTPS callback URLs
- Store API keys securely (environment variables, secure storage)
- Use `CardInfo.toSafeJson()` instead of `toJson()` for logging
- Validate production config before deployment

```dart
// Safe logging
final safeLog = LogSanitizer.sanitize(sensitiveData);
final safeMap = LogSanitizer.sanitizeMap(requestData);

// Safe card JSON (masks card number and CVV)
final safeCard = cardInfo.toSafeJson();

// Production validation
final issues = config.validateForProduction();
if (issues.isNotEmpty) {
  print('Warning: $issues');
}
config.assertProduction(); // Throws if sandbox mode
```

## v2.0 Features

### Input Validation
All models now have `validate()` methods that throw `ValidationException`:

```dart
try {
  cardInfo.validate(); // Luhn check, expiry date, CVV format
  buyerInfo.validate(); // Email, phone (TR format), TC Kimlik
  paymentRequest.validate(); // Amount, installment range, basket total
} on ValidationException catch (e) {
  print('Validation errors: ${e.allErrors}');
}
```

### Retry & Circuit Breaker
Built-in fault tolerance patterns:

```dart
// Retry with exponential backoff
final handler = RetryHandler(config: RetryConfig.conservative);
final result = await handler.execute(() => provider.createPayment(request));

// Circuit breaker for cascading failure prevention
final breaker = CircuitBreaker(name: 'payment');
final result = await breaker.execute(() => provider.createPayment(request));
```

### PaymentLogger
Secure logging with automatic sanitization:

```dart
final logger = PaymentLogger(minLevel: LogLevel.info);
logger.logPaymentRequest(request); // Auto-masks sensitive data
logger.logPaymentResponse(result);
```

## Flutter Web Notice

Turkish payment APIs have CORS restrictions. For Flutter Web:

1. Use a backend proxy (recommended)
2. Route through Cloud Functions
3. Or use mobile platforms only

## API Reference

| Method | Description |
|--------|-------------|
| `initialize(config)` | Initialize the provider |
| `createPayment(request)` | Process non-3DS payment |
| `init3DSPayment(request)` | Start 3DS payment flow |
| `complete3DSPayment(id)` | Complete 3DS payment |
| `getInstallments(bin, amount)` | Get installment options |
| `refund(request)` | Process refund |
| `getPaymentStatus(id)` | Check payment status |
| `chargeWithSavedCard(...)` | Pay with saved card |
| `getSavedCards(userKey)` | List saved cards |
| `deleteSavedCard(token)` | Remove saved card |
| `dispose()` | Clean up resources |

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contact

- GitHub Issues: [Report Issue](https://github.com/abdullah017/tr_payment_hub/issues)
- Email: dev.abdullahtas@gmail.com

---

**Note:** This is a community package, not an official iyzico, PayTR, Param, or Sipay product.
