/// Sipay API endpoint sabitleri
///
/// Sipay REST/JSON tabanlı bir API kullanır.
class SipayEndpoints {
  SipayEndpoints._();

  /// API prefix
  static const String apiPrefix = '/ccpayment/api';

  /// Token endpoint
  static const String token = '$apiPrefix/token';

  /// Ödeme başlatma
  static const String payment = '$apiPrefix/paySmart3D';

  /// Non-3DS ödeme
  static const String paymentDirect = '$apiPrefix/paySmart2D';

  /// 3DS sonuç sorgulama
  static const String completePayment = '$apiPrefix/complete';

  /// Taksit sorgulama
  static const String installment = '$apiPrefix/getpos';

  /// BIN sorgulama
  static const String binCheck = '$apiPrefix/checkBin';

  /// İade işlemi
  static const String refund = '$apiPrefix/refund';

  /// İşlem sorgulama
  static const String status = '$apiPrefix/checkStatus';

  /// Kart kaydetme (tokenization)
  static const String saveCard = '$apiPrefix/saveCard';

  /// Kayıtlı kartları listele
  static const String cardList = '$apiPrefix/getSavedCards';

  /// Kayıtlı kart sil
  static const String deleteCard = '$apiPrefix/deleteCard';

  /// Kayıtlı kart ile ödeme
  static const String payWithSavedCard = '$apiPrefix/payByCardToken';
}
