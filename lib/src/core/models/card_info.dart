import 'package:meta/meta.dart';

/// Card information for payment processing.
///
/// Contains all card details required for processing payments.
/// Includes built-in validation using the Luhn algorithm and
/// secure masking for logging purposes.
///
/// ## Example
///
/// ```dart
/// final card = CardInfo(
///   cardHolderName: 'JOHN DOE',
///   cardNumber: '5528790000000008',
///   expireMonth: '12',
///   expireYear: '2030',
///   cvc: '123',
/// );
///
/// if (card.isValidNumber) {
///   print('Card is valid');
///   print('BIN: ${card.binNumber}'); // 552879
///   print('Masked: ${card.maskedNumber}'); // 552879******0008
/// }
/// ```
///
/// ## Security
///
/// * Always use [maskedNumber] when logging card information
/// * Never log raw [cardNumber] or [cvc] values
/// * Use `LogSanitizer` for automatic sensitive data masking
@immutable
class CardInfo {
  /// Creates a new [CardInfo] instance.
  const CardInfo({
    required this.cardHolderName,
    required this.cardNumber,
    required this.expireMonth,
    required this.expireYear,
    required this.cvc,
    this.saveCard = false,
  });

  /// Creates a [CardInfo] instance from a JSON map.
  ///
  /// Note: Be cautious when deserializing card data from external sources.
  factory CardInfo.fromJson(Map<String, dynamic> json) => CardInfo(
        cardHolderName: json['cardHolderName'] as String,
        cardNumber: json['cardNumber'] as String,
        expireMonth: json['expireMonth'] as String,
        expireYear: json['expireYear'] as String,
        cvc: json['cvc'] as String,
        saveCard: json['saveCard'] as bool? ?? false,
      );

  /// Name as printed on the card.
  ///
  /// Should be in uppercase and match the card exactly.
  final String cardHolderName;

  /// Full card number (PAN).
  ///
  /// Must be 13-19 digits without spaces or dashes.
  final String cardNumber;

  /// Card expiration month.
  ///
  /// Two-digit format (e.g., '01' for January, '12' for December).
  final String expireMonth;

  /// Card expiration year.
  ///
  /// Four-digit format (e.g., '2030').
  final String expireYear;

  /// Card verification code (CVV/CVC).
  ///
  /// 3 digits for Visa/Mastercard, 4 digits for Amex.
  final String cvc;

  /// Whether to save the card for future use.
  ///
  /// When true, the payment provider may tokenize the card
  /// for recurring payments. Defaults to false.
  final bool saveCard;

  /// First 6 digits of the card (BIN/IIN).
  ///
  /// Used for identifying card type, issuing bank, and
  /// querying installment options.
  String get binNumber =>
      cardNumber.length >= 6 ? cardNumber.substring(0, 6) : cardNumber;

  /// Last 4 digits of the card.
  ///
  /// Safe to display to users for card identification.
  String get lastFourDigits => cardNumber.length >= 4
      ? cardNumber.substring(cardNumber.length - 4)
      : cardNumber;

  /// Masked card number for safe logging.
  ///
  /// Format: 552879******0008
  /// Only shows BIN and last 4 digits.
  String get maskedNumber {
    if (cardNumber.length < 10) return '****';
    return '${cardNumber.substring(0, 6)}******${cardNumber.substring(cardNumber.length - 4)}';
  }

  /// Validates the card number using the Luhn algorithm.
  ///
  /// Returns true if the card number passes Luhn check.
  /// Note: A valid Luhn check doesn't guarantee the card is active.
  bool get isValidNumber {
    if (cardNumber.length < 13 || cardNumber.length > 19) return false;

    var sum = 0;
    var alternate = false;

    for (var i = cardNumber.length - 1; i >= 0; i--) {
      var digit = int.tryParse(cardNumber[i]) ?? -1;
      if (digit == -1) return false;

      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Converts this instance to a JSON-compatible map.
  ///
  /// WARNING: Contains sensitive data. Use only for API calls,
  /// never for logging.
  Map<String, dynamic> toJson() => {
        'cardHolderName': cardHolderName,
        'cardNumber': cardNumber,
        'expireMonth': expireMonth,
        'expireYear': expireYear,
        'cvc': cvc,
        'saveCard': saveCard,
      };

  /// Creates a copy of this instance with the given fields replaced.
  CardInfo copyWith({
    String? cardHolderName,
    String? cardNumber,
    String? expireMonth,
    String? expireYear,
    String? cvc,
    bool? saveCard,
  }) =>
      CardInfo(
        cardHolderName: cardHolderName ?? this.cardHolderName,
        cardNumber: cardNumber ?? this.cardNumber,
        expireMonth: expireMonth ?? this.expireMonth,
        expireYear: expireYear ?? this.expireYear,
        cvc: cvc ?? this.cvc,
        saveCard: saveCard ?? this.saveCard,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardInfo &&
          runtimeType == other.runtimeType &&
          cardHolderName == other.cardHolderName &&
          cardNumber == other.cardNumber &&
          expireMonth == other.expireMonth &&
          expireYear == other.expireYear &&
          cvc == other.cvc &&
          saveCard == other.saveCard;

  @override
  int get hashCode => Object.hash(
        cardHolderName,
        cardNumber,
        expireMonth,
        expireYear,
        cvc,
        saveCard,
      );

  @override
  String toString() =>
      'CardInfo(holder: $cardHolderName, card: $maskedNumber, exp: $expireMonth/$expireYear)';
}
