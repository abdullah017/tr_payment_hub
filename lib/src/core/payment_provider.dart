import 'config.dart';
import 'enums.dart';
import 'models/buyer_info.dart';
import 'models/installment_info.dart';
import 'models/payment_request.dart';
import 'models/payment_result.dart';
import 'models/refund_request.dart';
import 'models/saved_card.dart';
import 'models/three_ds_result.dart';
import 'payment_interfaces.dart';

// Re-export interfaces for convenience
export 'payment_interfaces.dart';

/// Ana payment provider interface.
///
/// Bu interface, tüm ödeme sağlayıcılarının uygulaması gereken
/// temel işlemleri tanımlar. Interface segregation prensibi uygulanmıştır:
///
/// - [PaymentCore] - Temel ödeme işlemleri (create, 3DS, refund, status)
/// - [PaymentInstallments] - Taksit sorgulama
/// - [PaymentSavedCards] - Kayıtlı kart işlemleri
///
/// ## Provider Desteği
///
/// | Provider | Core | Installments | Saved Cards |
/// |----------|------|--------------|-------------|
/// | iyzico   | ✅   | ✅           | ✅          |
/// | PayTR    | ✅   | ✅           | ❌          |
/// | Sipay    | ✅   | ✅           | ✅          |
/// | Param    | ✅   | ✅           | ❌          |
///
/// ## Capability Check
///
/// ```dart
/// final provider = IyzicoProvider();
///
/// // Check saved cards support
/// if (provider.supportsSavedCards) {
///   final cards = await provider.getSavedCards(cardUserKey);
/// }
///
/// // Alternative: type check
/// if (provider is PaymentSavedCards) {
///   final cards = await provider.getSavedCards(cardUserKey);
/// }
/// ```
///
/// ## Example
///
/// ```dart
/// final provider = IyzicoProvider();
/// await provider.initialize(config);
///
/// // Create payment
/// final result = await provider.createPayment(request);
///
/// // Get installments
/// final installments = await provider.getInstallments(
///   binNumber: '552879',
///   amount: 100.0,
/// );
/// ```
abstract class PaymentProvider
    implements PaymentCore, PaymentInstallments, PaymentSavedCards {
  /// Provider türü
  @override
  ProviderType get providerType;

  /// Provider'ı başlat ve config'i doğrula
  @override
  Future<void> initialize(PaymentConfig config);

  /// Non-3DS ödeme başlat
  @override
  Future<PaymentResult> createPayment(PaymentRequest request);

  /// 3DS ödeme başlat
  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request);

  /// 3DS ödemeyi tamamla (callback sonrası)
  @override
  Future<PaymentResult> complete3DSPayment(
    String transactionId, {
    Map<String, dynamic>? callbackData,
  });

  /// İade işlemi
  @override
  Future<RefundResult> refund(RefundRequest request);

  /// Taksit seçeneklerini getir
  @override
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  });

  /// İşlem durumu sorgula
  @override
  Future<PaymentStatus> getPaymentStatus(String transactionId);

  // ============================================
  // SAVED CARD / TOKENIZATION METHODS
  // ============================================

  /// Charges a saved card without requiring full card details.
  ///
  /// Use this method for recurring payments or one-click checkout.
  /// Requires a card token obtained from a previous payment where
  /// `CardInfo.saveCard` was set to `true`.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = await provider.chargeWithSavedCard(
  ///   cardToken: 'tok_xxx',
  ///   cardUserKey: 'cuk_xxx', // Required for iyzico
  ///   orderId: 'ORDER_123',
  ///   amount: 100.0,
  ///   buyer: buyerInfo,
  /// );
  /// ```
  ///
  /// Throws [UnsupportedError] if the provider doesn't support card saving.
  @override
  Future<PaymentResult> chargeWithSavedCard({
    required String cardToken,
    required String orderId,
    required double amount,
    required BuyerInfo buyer,
    String? cardUserKey,
    int installment = 1,
    Currency currency = Currency.tryLira,
  });

  /// Retrieves all saved cards for a customer.
  ///
  /// For iyzico, requires the `cardUserKey` returned from a previous
  /// payment with `CardInfo.saveCard = true`.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final cards = await provider.getSavedCards('cuk_xxx');
  /// for (final card in cards) {
  ///   print('${card.displayName}');
  /// }
  /// ```
  ///
  /// Throws [UnsupportedError] if the provider doesn't support card saving.
  @override
  Future<List<SavedCard>> getSavedCards(String cardUserKey);

  /// Deletes a saved card.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final deleted = await provider.deleteSavedCard(
  ///   cardToken: 'tok_xxx',
  ///   cardUserKey: 'cuk_xxx',
  /// );
  /// if (deleted) {
  ///   print('Card deleted successfully');
  /// }
  /// ```
  ///
  /// Throws [UnsupportedError] if the provider doesn't support card saving.
  @override
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  });

  /// Kaynakları temizle
  @override
  void dispose();
}
