import 'enums.dart';
import 'config.dart';
import 'models/payment_request.dart';
import 'models/payment_result.dart';
import 'models/installment_info.dart';
import 'models/three_ds_result.dart';
import 'models/refund_request.dart';

/// Ana payment provider interface
abstract class PaymentProvider {
  /// Provider türü
  ProviderType get providerType;

  /// Provider'ı başlat ve config'i doğrula
  Future<void> initialize(PaymentConfig config);

  /// Non-3DS ödeme başlat
  Future<PaymentResult> createPayment(PaymentRequest request);

  /// 3DS ödeme başlat
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request);

  /// 3DS ödemeyi tamamla (callback sonrası)
  Future<PaymentResult> complete3DSPayment(
    String transactionId, {
    Map<String, dynamic>? callbackData,
  });

  /// İade işlemi
  Future<RefundResult> refund(RefundRequest request);

  /// Taksit seçeneklerini getir
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  });

  /// İşlem durumu sorgula
  Future<PaymentStatus> getPaymentStatus(String transactionId);

  /// Kaynakları temizle
  void dispose();
}
