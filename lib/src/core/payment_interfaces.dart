import 'config.dart';
import 'enums.dart';
import 'models/buyer_info.dart';
import 'models/installment_info.dart';
import 'models/payment_request.dart';
import 'models/payment_result.dart';
import 'models/refund_request.dart';
import 'models/saved_card.dart';
import 'models/three_ds_result.dart';

/// Core payment operations interface.
///
/// This interface defines the essential payment operations that all
/// payment providers must implement.
///
/// ## Methods
///
/// * [initialize] - Initialize the provider with configuration
/// * [createPayment] - Create a non-3DS payment
/// * [init3DSPayment] - Initialize 3D Secure payment flow
/// * [complete3DSPayment] - Complete 3DS payment after verification
/// * [refund] - Process a refund
/// * [getPaymentStatus] - Query payment status
/// * [dispose] - Clean up resources
///
/// ## Example
///
/// ```dart
/// final provider = IyzicoProvider();
/// await provider.initialize(config);
///
/// final result = await provider.createPayment(request);
/// ```
abstract class PaymentCore {
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

  /// İşlem durumu sorgula
  Future<PaymentStatus> getPaymentStatus(String transactionId);

  /// Kaynakları temizle
  void dispose();
}

/// Installment query operations interface.
///
/// This interface defines installment-related operations.
/// Not all providers support installment queries.
///
/// ## Checking Support
///
/// ```dart
/// if (provider is PaymentInstallments) {
///   final info = await provider.getInstallments(
///     binNumber: '552879',
///     amount: 100.0,
///   );
/// }
/// ```
abstract class PaymentInstallments {
  /// Taksit seçeneklerini getir
  ///
  /// [binNumber] - Kartın ilk 6 hanesi (BIN numarası)
  /// [amount] - Ödeme tutarı
  ///
  /// Returns installment options with rates and total amounts.
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  });
}

/// Saved card (tokenization) operations interface.
///
/// This interface defines card storage and tokenization operations.
/// Not all providers support card saving.
///
/// ## Checking Support
///
/// ```dart
/// if (provider is PaymentSavedCards) {
///   final cards = await provider.getSavedCards(cardUserKey);
/// } else {
///   print('This provider does not support saved cards');
/// }
/// ```
///
/// ## Provider Support
///
/// | Provider | Support |
/// |----------|---------|
/// | iyzico   | ✅ Full |
/// | Sipay    | ✅ Full |
/// | PayTR    | ❌ No (hosted checkout only) |
/// | Param    | ❌ No |
abstract class PaymentSavedCards {
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
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  });
}

/// BIN (Bank Identification Number) lookup interface.
///
/// This interface defines BIN lookup operations for getting card
/// information from the first 6-8 digits.
///
/// ## Checking Support
///
/// ```dart
/// if (provider is PaymentBinLookup) {
///   final binInfo = await provider.getBinInfo('552879');
///   print('Card type: ${binInfo.cardType}');
/// }
/// ```
abstract class PaymentBinLookup {
  /// Get card information from BIN number.
  ///
  /// [binNumber] - First 6-8 digits of the card
  ///
  /// Returns card type, bank name, and other BIN-related information.
  Future<BinInfo> getBinInfo(String binNumber);
}

/// BIN information returned from BIN lookup.
class BinInfo {
  /// Creates a new BinInfo instance.
  const BinInfo({
    required this.binNumber,
    required this.cardType,
    required this.cardAssociation,
    this.cardFamily,
    this.bankName,
    this.bankCode,
    this.commercial = false,
    this.force3DS = false,
  });

  /// The BIN number queried
  final String binNumber;

  /// Card type (credit, debit, prepaid)
  final CardType cardType;

  /// Card network (Visa, Mastercard, etc.)
  final CardAssociation cardAssociation;

  /// Card family name (Bonus, Maximum, etc.)
  final String? cardFamily;

  /// Issuing bank name
  final String? bankName;

  /// Issuing bank code
  final int? bankCode;

  /// Whether this is a commercial card
  final bool commercial;

  /// Whether 3DS is required for this card
  final bool force3DS;

  @override
  String toString() => 'BinInfo(bin: $binNumber, type: $cardType, '
      'association: $cardAssociation, bank: $bankName)';
}

/// Extension to check provider capabilities.
///
/// ## Example
///
/// ```dart
/// final provider = IyzicoProvider();
///
/// if (provider.supportsSavedCards) {
///   final cards = await (provider as PaymentSavedCards).getSavedCards(key);
/// }
///
/// if (provider.supportsInstallments) {
///   final info = await (provider as PaymentInstallments).getInstallments(...);
/// }
/// ```
extension PaymentProviderCapabilities on PaymentCore {
  /// Whether this provider supports saved card operations.
  bool get supportsSavedCards => this is PaymentSavedCards;

  /// Whether this provider supports installment queries.
  bool get supportsInstallments => this is PaymentInstallments;

  /// Whether this provider supports BIN lookup.
  bool get supportsBinLookup => this is PaymentBinLookup;
}
