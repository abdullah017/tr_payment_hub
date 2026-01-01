/// Test card numbers for sandbox/development environments.
///
/// These cards are for testing purposes only and work with provider
/// sandbox environments.
///
/// ## Example
///
/// ```dart
/// final card = CardInfo(
///   cardNumber: TestCards.iyzicoSuccess,
///   cardHolderName: 'Test User',
///   expireMonth: '12',
///   expireYear: '2030',
///   cvc: '123',
/// );
/// ```
class TestCards {
  TestCards._();

  // ============================================
  // IYZICO SANDBOX CARDS
  // ============================================

  /// Visa card that succeeds on iyzico sandbox.
  static const String iyzicoSuccessVisa = '4054180000000007';

  /// Mastercard that succeeds on iyzico sandbox.
  static const String iyzicoSuccessMastercard = '5528790000000008';

  /// Card that returns insufficient funds error.
  static const String iyzicoInsufficientFunds = '4543590000000006';

  /// Card that fails CVV validation.
  static const String iyzicoInvalidCVV = '5400010000000004';

  /// Card that returns fraud alert.
  static const String iyzicoFraudAlert = '4111111111111129';

  /// Card that requires 3D Secure.
  static const String iyzico3DSRequired = '4059030000000009';

  /// Card that fails 3D Secure verification.
  static const String iyzico3DSFailed = '5400010000000004';

  /// Troy card for testing.
  static const String iyzicoTroy = '9792020000000001';

  /// AMEX card for testing.
  static const String iyzicoAmex = '374427000000003';

  // ============================================
  // PAYTR SANDBOX CARDS
  // ============================================

  /// Card that succeeds on PayTR sandbox.
  static const String paytrSuccess = '4355084355084358';

  /// PayTR card that fails.
  static const String paytrFailed = '4111111111111111';

  // ============================================
  // GENERIC VALID CARD NUMBERS (Luhn Valid)
  // ============================================

  /// Generic Visa card (Luhn valid).
  static const String genericVisa = '4532015112830366';

  /// Generic Mastercard (Luhn valid).
  static const String genericMastercard = '5425233430109903';

  /// Generic AMEX (Luhn valid).
  static const String genericAmex = '378282246310005';

  /// Generic Discover (Luhn valid).
  static const String genericDiscover = '6011111111111117';

  // ============================================
  // INVALID CARD NUMBERS (For Testing Validation)
  // ============================================

  /// Card number that fails Luhn check.
  static const String luhnInvalid = '4111111111111112';

  /// Too short card number.
  static const String tooShort = '411111111111';

  /// Too long card number.
  static const String tooLong = '41111111111111111111';

  /// Card with letters (invalid format).
  static const String invalidFormat = '4111XXXX1111XXXX';

  // ============================================
  // EXPIRED CARD DATA
  // ============================================

  /// Expired month (can be used with any card).
  static const String expiredMonth = '01';

  /// Expired year (past year).
  static const String expiredYear = '2020';

  // ============================================
  // BIN RANGES FOR TESTING
  // ============================================

  /// Visa BIN prefix.
  static const String visaBinPrefix = '4';

  /// Mastercard BIN prefixes (51-55, 2221-2720).
  static const List<String> mastercardBinPrefixes = [
    '51',
    '52',
    '53',
    '54',
    '55',
    '2221',
    '2720',
  ];

  /// AMEX BIN prefixes (34, 37).
  static const List<String> amexBinPrefixes = ['34', '37'];

  /// Troy BIN prefix (Turkish domestic).
  static const String troyBinPrefix = '9792';
}
