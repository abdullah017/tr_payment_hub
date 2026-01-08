# TR Payment Hub - Example App

Realistic Flutter payment integration example with built-in 3DS WebView.

## What's New in v3.1.0

- **PaymentWebView** - Built-in 3D Secure WebView widget
- **No more custom WebView code** - Just call `PaymentWebView.show()`
- **Automatic callback detection** - Handles both iyzico HTML and PayTR iframe
- **Customizable theme** - Colors, loading text, timeout

## Payment Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Payment Form   │────▶│ PaymentWebView  │────▶│  Result Screen  │
│  (card details) │     │ (built-in 3DS)  │     │  (success/fail) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Non-3DS:** Form → Result (direct)
**3DS:** Form → PaymentWebView → Result

## Features

- Provider selection (Mock/iyzico/PayTR/Param/Sipay)
- Card details form with validation
- 3D Secure toggle
- **Built-in PaymentWebView** for bank verification (NEW in v3.1.0)
- Automatic callback URL interception
- Result display with transaction details
- HTTP mocking for testing without real API credentials

## Quick Start

```bash
cd example
flutter pub get
flutter run
```

## How It Works

### 1. Payment Form
User enters card details and taps "Pay"

### 2. For 3D Secure (Using Built-in PaymentWebView)

```dart
// Initialize 3DS
final threeDSResult = await provider.init3DSPayment(request);

// Show built-in PaymentWebView - handles everything automatically!
final webViewResult = await PaymentWebView.show(
  context: context,
  threeDSResult: threeDSResult,
  callbackUrl: 'https://myapp.com/callback',
  // Optional: Customize appearance
  theme: PaymentWebViewTheme(
    appBarTitle: '3D Secure Doğrulama',
    loadingText: 'Banka sayfası yükleniyor...',
    progressColor: Colors.blue,
  ),
  timeout: Duration(minutes: 5),
);

// Handle result
if (webViewResult.isSuccess) {
  final result = await provider.complete3DSPayment(
    threeDSResult.transactionId!,
    callbackData: webViewResult.callbackData!,
  );
} else if (webViewResult.isCancelled) {
  // User cancelled
} else if (webViewResult.isTimeout) {
  // Timed out
} else if (webViewResult.isError) {
  // Error: webViewResult.errorMessage
}
```

### 3. Alternative: Bottom Sheet Display

```dart
final result = await PaymentWebView.showBottomSheet(
  context: context,
  threeDSResult: threeDSResult,
  callbackUrl: 'https://myapp.com/callback',
);
```

## PaymentWebViewTheme Options

```dart
PaymentWebViewTheme(
  backgroundColor: Colors.white,
  progressColor: Colors.blue,
  loadingText: 'Loading...',
  loadingTextStyle: TextStyle(fontSize: 14),
  appBarColor: Colors.white,
  appBarTitle: '3D Secure',
  appBarTitleStyle: TextStyle(color: Colors.black),
  showCloseButton: true,
  closeButtonIcon: Icons.close,
)
```

## PaymentWebViewResult Status

| Status | Description |
|--------|-------------|
| `success` | 3DS completed, callbackData available |
| `cancelled` | User closed the WebView |
| `timeout` | Exceeded timeout duration |
| `error` | WebView error occurred |

## Test Cards

### iyzico
- **Number:** 5528790000000008
- **Expiry:** 12/30
- **CVV:** 123

### PayTR
- **Number:** 4355084355084358
- **Expiry:** 12/30
- **CVV:** 000

### Sipay
- **Number:** 4508034508034509
- **Expiry:** 12/30
- **CVV:** 000

### Param
- **Number:** 4022774022774026
- **Expiry:** 12/30
- **CVV:** 000

## Files

```
lib/main.dart
├── PaymentFormScreen  - Card form, provider selection
└── ResultScreen       - Payment result display

Note: ThreeDSWebViewScreen is no longer needed!
      Use PaymentWebView.show() instead.
```

## Notes

- Uses `MockPaymentProvider` - no real API keys needed
- Toggle "Use 3D Secure" to test both flows
- PaymentWebView automatically detects callback URL and extracts parameters
- Supports both iyzico HTML content and PayTR iframe URLs

## Migration from Custom WebView

### Before (v3.0.x)
```dart
// You had to create your own WebView screen
final callbackData = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ThreeDSWebViewScreen(  // Custom code!
      htmlContent: result.htmlContent,
      redirectUrl: result.redirectUrl,
      callbackUrl: callbackUrl,
    ),
  ),
);
```

### After (v3.1.0+)
```dart
// Just use the built-in widget
final result = await PaymentWebView.show(
  context: context,
  threeDSResult: threeDSResult,
  callbackUrl: callbackUrl,
);
```

## Testing with Mock HTTP Client

For unit testing without real API credentials:

```dart
import 'package:tr_payment_hub/tr_payment_hub.dart';

// Create mock client
final mockClient = PaymentMockClient.iyzico(shouldSucceed: true);
final provider = IyzicoProvider(httpClient: mockClient);

// Initialize and use as normal
await provider.initialize(config);
final result = await provider.createPayment(request);
```

Available mock clients:
- `PaymentMockClient.iyzico()`
- `PaymentMockClient.paytr()`
- `PaymentMockClient.param()`
- `PaymentMockClient.sipay()`
