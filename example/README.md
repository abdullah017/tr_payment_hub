# TR Payment Hub - Example App

Realistic Flutter payment integration example.

## Payment Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Payment Form   │────▶│  3DS WebView    │────▶│  Result Screen  │
│  (card details) │     │  (bank verify)  │     │  (success/fail) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Non-3DS:** Form → Result (direct)
**3DS:** Form → WebView → Result

## Features

- Provider selection (Mock/iyzico/PayTR)
- Card details form
- 3D Secure toggle
- WebView for bank verification
- Callback URL interception
- Result display

## Quick Start

```bash
cd example
flutter pub get
flutter run
```

## How It Works

### 1. Payment Form
User enters card details and taps "Pay"

### 2. For 3D Secure
```dart
// Provider returns HTML
final threeDSResult = await provider.init3DSPayment(request);

// Show in WebView
Navigator.push(context, ThreeDSWebViewScreen(
  htmlContent: threeDSResult.htmlContent,
  callbackUrl: 'https://myapp.com/callback',
));
```

### 3. WebView Intercepts Callback
```dart
onNavigationRequest: (request) {
  if (request.url.startsWith(callbackUrl)) {
    final params = Uri.parse(request.url).queryParameters;
    Navigator.pop(context, params); // Return callback data
  }
}
```

### 4. Complete Payment
```dart
final result = await provider.complete3DSPayment(
  transactionId,
  callbackData: callbackParams,
);
```

## Test Card

- **Number:** 5528790000000008
- **Expiry:** 12/30
- **CVV:** 123

## Files

```
lib/main.dart
├── PaymentFormScreen   - Card form, provider selection
├── ThreeDSWebViewScreen - Bank verification WebView
└── ResultScreen        - Payment result display
```

## Notes

- Uses `MockPaymentProvider` - no real API keys needed
- Toggle "Use 3D Secure" to test both flows
- WebView intercepts callback URL and extracts parameters
