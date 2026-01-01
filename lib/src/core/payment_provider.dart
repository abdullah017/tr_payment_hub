import 'config.dart';
import 'enums.dart';
import 'models/buyer_info.dart';
import 'models/installment_info.dart';
import 'models/payment_request.dart';
import 'models/payment_result.dart';
import 'models/refund_request.dart';
import 'models/saved_card.dart';
import 'models/three_ds_result.dart';

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
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  });

  /// Kaynakları temizle
  void dispose();
}
