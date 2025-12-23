# TR Payment Hub

[![Pub Version](https://img.shields.io/pub/v/tr_payment_hub)](https://pub.dev/packages/tr_payment_hub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)

**[Türkçe Dokümantasyon](README_TR.md)**

Unified Turkish payment gateway integration for Flutter/Dart applications.

## Supported Providers

| Provider | Status | Non-3DS | 3DS | Installments | Refunds |
|----------|--------|---------|-----|--------------|---------|
| iyzico   | ✅ Stable | Yes | Yes | Yes | Yes |
| PayTR    | ✅ Stable | Yes | Yes | Yes | Yes |
| Param    | 🔜 Planned | - | - | - | - |
| Sipay    | 🔜 Planned | - | - | - | - |

## Features

- **Unified API** - Single interface for all payment providers
- **Type Safe** - Full Dart null safety support
- **Secure** - Automatic sensitive data masking with LogSanitizer
- **Testable** - Built-in MockPaymentProvider for unit testing
- **Cross Platform** - Works on iOS, Android, Web, and Desktop

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  tr_payment_hub: ^1.0.2
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
  // PayTR: Redirect to threeDSResult.redirectUrl
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

## Security Best Practices

- Card numbers are never logged
- Use `LogSanitizer.sanitize()` before logging any payment data
- Always use HTTPS callback URLs
- Store API keys securely (environment variables, secure storage)

```dart
// Safe logging
final safeLog = LogSanitizer.sanitize(sensitiveData);
final safeMap = LogSanitizer.sanitizeMap(requestData);
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

**Note:** This is a community package, not an official iyzico or PayTR product.
