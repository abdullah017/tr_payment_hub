# TR Payment Hub - Example App

A comprehensive Flutter example app demonstrating all features of the `tr_payment_hub` package.

## Features

- **Payment Processing** - Credit/debit card payments with all providers
- **3D Secure** - Built-in WebView for bank verification
- **Installments** - Query and select installment options
- **Saved Cards** - Store and charge saved cards (iyzico, Sipay)
- **Refunds** - Process full or partial refunds
- **Transaction Status** - Check payment status
- **Request Logging** - View all HTTP requests/responses
- **Two Connection Modes** - Direct API or Proxy (Backend) mode

## Supported Providers

| Provider | Direct Mode | Proxy Mode | Saved Cards | 3DS |
|----------|-------------|------------|-------------|-----|
| Mock (Demo) | ✅ | - | ✅ | ✅ |
| iyzico | ✅ | ✅ | ✅ | ✅ |
| PayTR | ✅ | ✅ | ❌ | ✅ |
| Sipay | ✅ | ✅ | ✅ | ✅ |
| Param | ✅ | ✅ | ❌ | ✅ |

## Quick Start

```bash
cd example
flutter pub get
flutter run
```

The app starts with **Mock Provider** - no API keys needed for testing.

---

## Connection Modes

### Mode 1: Direct Mode (Default)

API keys are stored in the app and calls go directly to payment providers.

```
┌─────────────┐     ┌─────────────────┐
│  Flutter    │────▶│ Payment Provider│
│    App      │◀────│   (iyzico etc)  │
└─────────────┘     └─────────────────┘
```

**Setup:**
1. Open the app → Settings
2. Select a provider (e.g., iyzico)
3. Tap the settings icon ⚙️
4. Enter your API credentials
5. Tap "Save & Activate"

**Required Credentials by Provider:**

| Provider | Required Fields |
|----------|-----------------|
| iyzico | merchantId, apiKey, secretKey |
| PayTR | merchantId, apiKey, secretKey, successUrl, failUrl, callbackUrl |
| Sipay | merchantId, apiKey, secretKey, merchantKey |
| Param | merchantId, apiKey, secretKey, guid |

### Mode 2: Proxy Mode (Recommended for Production)

API keys stay on your backend server - more secure!

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│  Flutter    │────▶│  Your       │────▶│ Payment Provider│
│    App      │◀────│  Backend    │◀────│   (iyzico etc)  │
└─────────────┘     └─────────────┘     └─────────────────┘
```

**Setup:**
1. Start the backend server (see Backend Setup below)
2. Open the app → Settings
3. Enable "Proxy Mode (Backend)"
4. Enter your Backend URL (e.g., `http://localhost:3000/api/payment`)
5. Optionally add Auth Token
6. Select a provider and use normally

---

## Backend Setup (for Proxy Mode)

### 1. Configure Environment

```bash
cd example/backend
cp .env.example .env
```

Edit `.env` with your API credentials:

```env
PORT=3000

# iyzico
IYZICO_API_KEY=your_api_key
IYZICO_SECRET_KEY=your_secret_key
IYZICO_SANDBOX=true

# PayTR
PAYTR_MERCHANT_ID=your_merchant_id
PAYTR_MERCHANT_KEY=your_merchant_key
PAYTR_MERCHANT_SALT=your_merchant_salt

# Sipay
SIPAY_MERCHANT_ID=your_merchant_id
SIPAY_API_KEY=your_api_key
SIPAY_SECRET_KEY=your_secret_key
SIPAY_MERCHANT_KEY=your_merchant_key

# Param
PARAM_CLIENT_CODE=your_client_code
PARAM_CLIENT_USERNAME=your_username
PARAM_CLIENT_PASSWORD=your_password
PARAM_GUID=your_guid
```

### 2. Start the Server

```bash
npm install
npm start
```

Server runs at `http://localhost:3000`

### 3. API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /health | Health check |
| POST | /api/payment/create | Create payment |
| POST | /api/payment/3ds/init | Initialize 3DS |
| POST | /api/payment/3ds/complete | Complete 3DS |
| GET | /api/payment/installments | Get installments |
| POST | /api/payment/refund | Process refund |
| GET | /api/payment/status/:id | Check status |
| GET | /api/payment/cards | List saved cards |
| POST | /api/payment/cards/charge | Charge saved card |
| DELETE | /api/payment/cards/:token | Delete saved card |

---

## App Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── providers/
│   │   └── app_state.dart       # State management
│   ├── services/
│   │   ├── payment_service.dart # Payment operations
│   │   └── storage_service.dart # Persistent storage
│   └── theme/
│       └── app_theme.dart       # Material 3 theming
├── features/
│   ├── home/
│   │   └── home_screen.dart     # Dashboard
│   ├── payment/
│   │   ├── payment_screen.dart  # Payment form
│   │   └── payment_result_screen.dart
│   ├── installments/
│   │   └── installments_screen.dart
│   ├── saved_cards/
│   │   └── saved_cards_screen.dart
│   ├── refund/
│   │   └── refund_screen.dart
│   ├── transaction_status/
│   │   └── transaction_status_screen.dart
│   ├── logs/
│   │   └── logs_screen.dart     # HTTP request viewer
│   └── settings/
│       └── settings_screen.dart # Provider & app config
└── widgets/
    ├── info_card.dart           # Info/warning cards
    └── loading_overlay.dart     # Loading indicator
```

---

## Payment Flow

### Non-3DS Payment

```
┌─────────────────┐     ┌─────────────────┐
│  Payment Form   │────▶│  Result Screen  │
│  (card details) │     │  (success/fail) │
└─────────────────┘     └─────────────────┘
```

### 3DS Payment (Built-in WebView)

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Payment Form   │────▶│ PaymentWebView  │────▶│  Result Screen  │
│  (card details) │     │ (built-in 3DS)  │     │  (success/fail) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Code Example

```dart
// Initialize provider
final provider = context.read<AppState>().paymentService.provider;

// Create payment request
final request = PaymentRequest(
  card: CardInfo(
    cardNumber: '5528790000000008',
    expireMonth: '12',
    expireYear: '2030',
    cvv: '123',
    cardHolderName: 'John Doe',
  ),
  amount: 100.0,
  currency: 'TRY',
  orderId: 'ORDER_123',
  customer: CustomerInfo(
    firstName: 'John',
    lastName: 'Doe',
    email: 'john@example.com',
    phone: '5551234567',
  ),
);

// For 3DS payment
final threeDSResult = await provider.init3DSPayment(request);

// Show built-in WebView
final webViewResult = await PaymentWebView.show(
  context: context,
  threeDSResult: threeDSResult,
  callbackUrl: 'https://myapp.com/callback',
  theme: PaymentWebViewTheme(
    appBarTitle: '3D Secure',
    loadingText: 'Loading bank page...',
  ),
);

// Complete payment
if (webViewResult.isSuccess) {
  final result = await provider.complete3DSPayment(
    threeDSResult.transactionId!,
    callbackData: webViewResult.callbackData!,
  );
}
```

---

## Test Cards

### iyzico Sandbox
| Type | Number | Expiry | CVV | Result |
|------|--------|--------|-----|--------|
| Success | 5528790000000008 | 12/30 | 123 | Approved |
| Fail | 4543590000000006 | 12/30 | 123 | Declined |

### PayTR Test
| Number | Expiry | CVV |
|--------|--------|-----|
| 4355084355084358 | 12/30 | 000 |

### Sipay Test
| Number | Expiry | CVV |
|--------|--------|-----|
| 4508034508034509 | 12/30 | 000 |

### Param Test
| Number | Expiry | CVV |
|--------|--------|-----|
| 4022774022774026 | 12/30 | 000 |

---

## Settings Options

### Payment Settings
- **Sandbox Mode** - Use test environment
- **3D Secure by Default** - Enable 3DS verification
- **Request Logging** - Log HTTP requests/responses

### Connection Mode
- **Direct Mode** - API keys in app (default)
- **Proxy Mode** - API keys on backend server

### Appearance
- System / Light / Dark theme

### Data Management
- Clear logs
- Clear transaction history
- Reset all settings

---

## Security Notes

### Direct Mode
- API keys stored locally on device
- Suitable for development/testing
- **Not recommended for production**

### Proxy Mode (Recommended)
- API keys stay on your server
- App only sends payment data
- Add rate limiting to your backend
- Use HTTPS in production
- Implement proper authentication

---

## Troubleshooting

### "Provider configuration not found"
→ Go to Settings → Select provider → Enter API credentials

### "Connection refused" in Proxy Mode
→ Check backend is running: `curl http://localhost:3000/health`

### 3DS WebView not loading
→ Check internet connection and provider sandbox status

### Payment fails with valid card
→ Ensure sandbox mode matches your API credentials (sandbox vs production)

---

## Version

- **Example App**: 3.2.0
- **tr_payment_hub**: ^3.2.0

## License

MIT License - See main package for details.
