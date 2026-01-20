/// TR Payment Hub - Client SDK
///
/// Secure client SDK for Flutter applications.
/// Does NOT contain API credentials - works with backend proxy.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:tr_payment_hub/tr_payment_hub_client.dart';
///
/// // Create proxy provider (no credentials needed!)
/// final provider = TrPaymentHub.createProxy(
///   baseUrl: 'https://api.yourbackend.com/payment',
///   provider: ProviderType.iyzico,
///   authToken: 'user_jwt_token', // Optional
/// );
///
/// await provider.initializeWithProvider(ProviderType.iyzico);
///
/// // Validate card before sending
/// final validation = CardValidator.validate(
///   cardNumber: '5528790000000008',
///   expireMonth: '12',
///   expireYear: '2030',
///   cvv: '123',
///   holderName: 'Ahmet Yilmaz',
/// );
///
/// if (!validation.isValid) {
///   print(validation.errors);
///   return;
/// }
///
/// // Create payment (request goes to your backend)
/// final result = await provider.createPayment(request);
/// ```
///
/// ## What's Included
///
/// * **ProxyPaymentProvider** - Backend proxy provider
/// * **CardValidator** - Client-side card validation
/// * **RequestValidator** - Client-side request validation
/// * **All models** - PaymentRequest, PaymentResult, etc.
/// * **Enums** - Currency, CardType, ProviderType, etc.
/// * **Exceptions** - PaymentException, ValidationException
///
/// ## What's NOT Included
///
/// * Provider implementations (IyzicoProvider, PayTRProvider, etc.)
/// * Config classes with credentials (IyzicoConfig, PayTRConfig, etc.)
///
/// For full SDK with direct provider access, use `tr_payment_hub.dart` instead.
library tr_payment_hub_client;

// Core (credential-free)
export 'src/core/enums.dart';
export 'src/core/exceptions/payment_exception.dart';
export 'src/core/exceptions/validation_exception.dart';
export 'src/core/payment_provider.dart';

// Models (full)
export 'src/core/models/basket_item.dart';
export 'src/core/models/buyer_info.dart';
export 'src/core/models/card_info.dart';
export 'src/core/models/installment_info.dart';
export 'src/core/models/payment_request.dart';
export 'src/core/models/payment_result.dart';
export 'src/core/models/refund_request.dart';
export 'src/core/models/saved_card.dart';
export 'src/core/models/three_ds_result.dart';

// Client (Proxy Mode)
export 'src/client/proxy_config.dart';
export 'src/client/proxy_payment_provider.dart';
export 'src/client/validators/card_validator.dart';
export 'src/client/validators/request_validator.dart';

// Testing utilities
export 'src/testing/mock_payment_provider.dart';

// Utils
export 'src/utils/log_sanitizer.dart';

// Network utilities (for custom NetworkClient implementations)
export 'src/core/network/http_network_client.dart';
export 'src/core/network/network_client.dart';

// Widgets
export 'src/widgets/widgets.dart';

// Factory (only createProxy and createMock exposed via TrPaymentHub)
export 'src/tr_payment_hub_base.dart' show TrPaymentHub;
