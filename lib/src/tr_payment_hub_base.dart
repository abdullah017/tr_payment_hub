import 'core/enums.dart';
import 'core/exceptions/payment_exception.dart';
import 'core/payment_provider.dart';
import 'providers/iyzico/iyzico_provider.dart';
import 'providers/param/param_provider.dart';
import 'providers/paytr/paytr_provider.dart';
import 'providers/sipay/sipay_provider.dart';
import 'testing/mock_payment_provider.dart';

/// TR Payment Hub - Ana Factory Sınıfı
///
/// Türkiye ödeme sistemleri için unified API.
///
/// Örnek kullanım:
/// ```dart
/// // iyzico provider oluştur
/// final provider = TrPaymentHub.create(ProviderType.iyzico);
/// await provider.initialize(config);
///
/// // Ödeme yap
/// final result = await provider.createPayment(request);
/// ```
class TrPaymentHub {
  TrPaymentHub._();

  /// Belirtilen türde payment provider oluşturur
  static PaymentProvider create(ProviderType type) {
    switch (type) {
      case ProviderType.iyzico:
        return IyzicoProvider();
      case ProviderType.paytr:
        return PayTRProvider();
      case ProviderType.param:
        return ParamProvider();
      case ProviderType.sipay:
        return SipayProvider();
    }
  }

  /// Test için mock provider oluşturur
  ///
  /// [shouldSucceed] - İşlemlerin başarılı olup olmayacağı
  /// [delay] - Simüle edilecek gecikme süresi
  /// [customError] - Özel hata döndürmek için
  static PaymentProvider createMock({
    bool shouldSucceed = true,
    Duration delay = const Duration(milliseconds: 500),
    PaymentException? customError,
  }) => MockPaymentProvider(
    shouldSucceed: shouldSucceed,
    delay: delay,
    customError: customError,
  );

  /// Kütüphane versiyonu
  static const String version = '0.1.0';

  /// Desteklenen provider'lar
  static List<ProviderType> get supportedProviders => ProviderType.values;
}
