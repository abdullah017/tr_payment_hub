/// Turkish Payment Gateway Integration Library
///
/// A unified API for Turkish payment providers including iyzico and PayTR.
/// This library provides a consistent interface for payment operations
/// across different Turkish payment gateways.
///
/// ## Features
///
/// * **Unified API** - Single interface for all supported providers
/// * **3D Secure** - Full 3DS payment support for secure transactions
/// * **Installments** - Query installment options by card BIN number
/// * **Refunds** - Process full or partial refunds
/// * **Testing** - Built-in mock provider for unit testing
/// * **Security** - Automatic card masking and log sanitization
///
/// ## Quick Start
///
/// ```dart
/// import 'package:tr_payment_hub/tr_payment_hub.dart';
///
/// // Create provider
/// final provider = TrPaymentHub.create(ProviderType.iyzico);
///
/// // Initialize with config
/// await provider.initialize(IyzicoConfig(
///   merchantId: 'your_merchant_id',
///   apiKey: 'your_api_key',
///   secretKey: 'your_secret_key',
///   isSandbox: true,
/// ));
///
/// // Create payment request
/// final request = PaymentRequest(
///   orderId: 'ORDER_123',
///   amount: 100.0,
///   currency: Currency.tryLira,
///   card: CardInfo(
///     cardHolderName: 'JOHN DOE',
///     cardNumber: '5528790000000008',
///     expireMonth: '12',
///     expireYear: '2030',
///     cvc: '123',
///   ),
///   buyer: BuyerInfo(
///     id: 'BUYER_1',
///     name: 'John',
///     surname: 'Doe',
///     email: 'john@example.com',
///     phone: '+905551234567',
///     ip: '127.0.0.1',
///     city: 'Istanbul',
///     country: 'Turkey',
///     address: 'Test Address',
///   ),
///   basketItems: [
///     BasketItem(
///       id: 'ITEM_1',
///       name: 'Product',
///       category: 'Category',
///       price: 100.0,
///       itemType: ItemType.physical,
///     ),
///   ],
/// );
///
/// // Process payment
/// final result = await provider.createPayment(request);
/// if (result.isSuccess) {
///   print('Payment successful: ${result.transactionId}');
/// }
/// ```
///
/// ## Supported Providers
///
/// | Provider | Non-3DS | 3DS | Installments | Refunds |
/// |----------|---------|-----|--------------|---------|
/// | iyzico   | Yes     | Yes | Yes          | Yes     |
/// | PayTR    | Yes     | Yes | Yes          | Yes     |
///
/// ## 3D Secure Payments
///
/// ```dart
/// // Initialize 3DS payment
/// final threeDSResult = await provider.init3DSPayment(
///   request.copyWith(callbackUrl: 'https://yoursite.com/callback'),
/// );
///
/// if (threeDSResult.needsWebView) {
///   // Display WebView with htmlContent (iyzico) or redirectUrl (PayTR)
/// }
///
/// // After user completes verification
/// final result = await provider.complete3DSPayment(
///   threeDSResult.transactionId!,
///   callbackData: callbackData,
/// );
/// ```
///
/// ## Error Handling
///
/// All payment operations throw `PaymentException` on errors:
///
/// ```dart
/// try {
///   await provider.createPayment(request);
/// } on PaymentException catch (e) {
///   print('Error: ${e.code} - ${e.message}');
/// }
/// ```
///
/// ## Testing
///
/// Use `MockPaymentProvider` for unit testing:
///
/// ```dart
/// final mockProvider = TrPaymentHub.createMock(shouldSucceed: true);
/// ```
///
/// ## Security
///
/// * Card numbers are automatically masked in logs
/// * Use `LogSanitizer` for safe logging of payment data
/// * Never log raw card numbers or CVV values
library;

// Client (Proxy Mode)
export 'src/client/proxy_config.dart';
export 'src/client/proxy_payment_provider.dart';
export 'src/client/validators/card_validator.dart';
export 'src/client/validators/request_validator.dart';
// Core
export 'src/core/config.dart';
export 'src/core/enums.dart';
export 'src/core/exceptions/payment_exception.dart';
export 'src/core/exceptions/validation_exception.dart';
// Logging
export 'src/core/logging/payment_logger.dart';
export 'src/core/models/basket_item.dart';
export 'src/core/models/buyer_info.dart';
export 'src/core/models/card_info.dart';
export 'src/core/models/installment_info.dart';
export 'src/core/models/payment_request.dart';
export 'src/core/models/payment_result.dart';
export 'src/core/models/refund_request.dart';
export 'src/core/models/saved_card.dart';
export 'src/core/models/three_ds_result.dart';
// Network utilities
export 'src/core/network/circuit_breaker.dart';
export 'src/core/network/http_network_client.dart';
export 'src/core/network/network_client.dart';
export 'src/core/network/retry_handler.dart';
export 'src/core/payment_provider.dart';
// Providers
export 'src/providers/iyzico/iyzico_provider.dart';
export 'src/providers/param/param_provider.dart';
export 'src/providers/paytr/paytr_provider.dart';
export 'src/providers/sipay/sipay_provider.dart';
// Testing
export 'src/testing/fake_data.dart';
export 'src/testing/mock_http_client.dart';
export 'src/testing/mock_payment_provider.dart';
export 'src/testing/test_cards.dart';
// Factory
export 'src/tr_payment_hub_base.dart';
// Utils
export 'src/core/utils/payment_utils.dart';
export 'src/utils/hash_utils.dart';
export 'src/utils/log_sanitizer.dart';
// Widgets
export 'src/widgets/widgets.dart';
