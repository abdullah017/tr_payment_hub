/// Turkish Payment Gateway Integration Library
///
/// Unified API for Turkish payment providers (iyzico, PayTR, etc.)
///
/// ## Quick Start
///
/// ```dart
/// import 'package:tr_payment_hub/tr_payment_hub.dart';
///
/// // Provider oluştur
/// final provider = TrPaymentHub.create(ProviderType.iyzico);
///
/// // Config ile başlat
/// await provider.initialize(IyzicoConfig(
///   merchantId: 'your_merchant_id',
///   apiKey: 'your_api_key',
///   secretKey: 'your_secret_key',
/// ));
///
/// // Ödeme yap
/// final result = await provider.createPayment(request);
/// ```
library;

// Factory
export 'src/tr_payment_hub_base.dart';

// Core
export 'src/core/enums.dart';
export 'src/core/config.dart';
export 'src/core/payment_provider.dart';
export 'src/core/exceptions/payment_exception.dart';

// Models
export 'src/core/models/card_info.dart';
export 'src/core/models/buyer_info.dart';
export 'src/core/models/basket_item.dart';
export 'src/core/models/payment_request.dart';
export 'src/core/models/payment_result.dart';
export 'src/core/models/installment_info.dart';
export 'src/core/models/three_ds_result.dart';

// Utils
export 'src/utils/hash_utils.dart';
export 'src/utils/log_sanitizer.dart';

// Testing
export 'src/testing/mock_payment_provider.dart';

// Providers
export 'src/providers/iyzico/iyzico_provider.dart';
export 'src/providers/paytr/paytr_provider.dart';

export 'src/core/models/refund_request.dart';
