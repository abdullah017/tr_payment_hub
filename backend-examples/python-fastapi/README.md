# TR Payment Hub - Python FastAPI Backend

Reference implementation for the tr_payment_hub proxy mode backend using Python and FastAPI.

## Prerequisites

- Python 3.10 or higher
- pip
- iyzico merchant account (sandbox for testing)

## Quick Start

1. **Create virtual environment:**
   ```bash
   cd backend-examples/python-fastapi
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure environment:**
   ```bash
   cp .env.example .env
   ```

   Edit `.env` and add your iyzico credentials:
   ```
   IYZICO_API_KEY=your_api_key
   IYZICO_SECRET_KEY=your_secret_key
   IYZICO_BASE_URL=https://sandbox-api.iyzipay.com
   ```

4. **Start the server:**
   ```bash
   uvicorn main:app --reload --port 3000
   # or
   python main.py
   ```

5. **Test the health endpoint:**
   ```bash
   curl http://localhost:3000/health
   ```

6. **View API documentation:**
   Open `http://localhost:3000/docs` for interactive Swagger UI.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/payment/create` | Create a payment |
| POST | `/payment/3ds/init` | Initialize 3DS payment |
| POST | `/payment/3ds/complete` | Complete 3DS payment |
| GET | `/payment/installments` | Query installment options |
| POST | `/payment/refund` | Process refund |
| GET | `/payment/status/{id}` | Get payment status |
| GET | `/payment/cards` | List saved cards |
| POST | `/payment/cards/charge` | Charge saved card |
| DELETE | `/payment/cards/{token}` | Delete saved card |

## Flutter Integration

```dart
import 'package:tr_payment_hub/tr_payment_hub_client.dart';

final provider = TrPaymentHub.createProxy(
  baseUrl: 'http://localhost:3000/payment',
  provider: ProviderType.iyzico,
);

await provider.initializeWithProvider(ProviderType.iyzico);

final result = await provider.createPayment(request);
```

## Request/Response Examples

### Create Payment

**Request:**
```json
POST /payment/create
{
  "orderId": "ORDER_123",
  "amount": 100.0,
  "currency": "tryLira",
  "installment": 1,
  "card": {
    "cardHolderName": "John Doe",
    "cardNumber": "5528790000000008",
    "expireMonth": "12",
    "expireYear": "2030",
    "cvc": "123"
  },
  "buyer": {
    "id": "BUYER_1",
    "name": "John",
    "surname": "Doe",
    "email": "john@example.com",
    "phone": "+905551234567",
    "ip": "127.0.0.1",
    "city": "Istanbul",
    "country": "Turkey",
    "address": "Test Address"
  },
  "basketItems": [
    {
      "id": "ITEM_1",
      "name": "Product",
      "category": "Electronics",
      "price": 100.0,
      "itemType": "physical"
    }
  ]
}
```

**Response (Success):**
```json
{
  "success": true,
  "transactionId": "12345678",
  "paymentId": "12345678",
  "amount": 100.0,
  "paidAmount": 100.0,
  "installment": 1,
  "cardType": "CREDIT_CARD",
  "cardAssociation": "MASTER_CARD",
  "binNumber": "552879",
  "lastFourDigits": "0008"
}
```

**Response (Error):**
```json
{
  "success": false,
  "errorCode": "insufficient_funds",
  "errorMessage": "Insufficient funds"
}
```

### Query Installments

**Request:**
```
GET /payment/installments?binNumber=552879&amount=1000
```

**Response:**
```json
{
  "success": true,
  "binNumber": "552879",
  "bankName": "Garanti Bankasi",
  "bankCode": 62,
  "cardType": "CREDIT_CARD",
  "cardAssociation": "MASTER_CARD",
  "options": [
    {
      "installmentNumber": 1,
      "installmentPrice": 1000.0,
      "totalPrice": 1000.0
    },
    {
      "installmentNumber": 3,
      "installmentPrice": 340.0,
      "totalPrice": 1020.0
    }
  ]
}
```

## Production Deployment

1. **Update environment variables:**
   ```
   IYZICO_BASE_URL=https://api.iyzipay.com
   ```

2. **Add authentication middleware** (not included in this example)

3. **Use a production ASGI server:**
   ```bash
   gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker
   ```

4. **Use HTTPS** (via reverse proxy like nginx)

5. **Store credentials securely** (use secret manager, not .env files)

## Security Considerations

- Never expose API credentials to clients
- Always use HTTPS in production
- Implement proper authentication for your endpoints
- Add rate limiting to prevent abuse
- Log all payment operations for auditing
- Validate all input data (Pydantic handles this)

## Support

For questions about this backend example, please open an issue in the main repository.
