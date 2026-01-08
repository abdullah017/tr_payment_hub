import 'package:meta/meta.dart';

import '../exceptions/validation_exception.dart';

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

  /// Returns true if the card has expired.
  ///
  /// Checks expiry date against current date.
  bool get isExpired {
    final month = int.tryParse(expireMonth);
    final year = int.tryParse(expireYear);

    if (month == null || year == null) return true;

    final now = DateTime.now();
    final expiryDate = DateTime(year, month + 1, 0); // Last day of expiry month

    return now.isAfter(expiryDate);
  }

  /// Validates the card information and throws [ValidationException] if invalid.
  ///
  /// Checks:
  /// * Card holder name is not empty and has at least 3 characters
  /// * Card number passes Luhn validation
  /// * Expiry month is between 01 and 12
  /// * Expiry year is valid and not expired
  /// * CVC is 3 or 4 digits
  ///
  /// Throws [ValidationException] with all validation errors.
  void validate() {
    final errors = <String>[];

    // Card holder name validation
    if (cardHolderName.isEmpty) {
      errors.add('cardHolderName cannot be empty');
    } else if (cardHolderName.trim().length < 3) {
      errors.add('cardHolderName must be at least 3 characters');
    }

    // Card number validation
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\s|-'), '');

    if (cleanNumber.isEmpty) {
      errors.add('cardNumber cannot be empty');
    } else {
      if (cleanNumber.length < 13 || cleanNumber.length > 19) {
        errors.add('cardNumber must be 13-19 digits');
      }

      if (!RegExp(r'^\d+$').hasMatch(cleanNumber)) {
        errors.add('cardNumber must contain only digits');
      }

      if (!isValidNumber) {
        errors.add('cardNumber failed Luhn validation');
      }
    }

    // Expiry month validation
    final month = int.tryParse(expireMonth);
    if (month == null || month < 1 || month > 12) {
      errors.add('expireMonth must be between 01 and 12');
    }

    // Expiry year validation
    final year = int.tryParse(expireYear);
    final currentYear = DateTime.now().year;

    if (year == null) {
      errors.add('expireYear must be a valid year');
    } else {
      // Handle both 2-digit and 4-digit year formats
      final fullYear = year < 100 ? 2000 + year : year;

      if (fullYear < currentYear) {
        errors.add('card has expired (year)');
      } else if (fullYear > currentYear + 20) {
        errors.add('expireYear is too far in the future');
      }

      // Check if card is expired (same year, past month)
      if (month != null && fullYear == currentYear) {
        final currentMonth = DateTime.now().month;
        if (month < currentMonth) {
          errors.add('card has expired');
        }
      }
    }

    // CVC validation
    if (cvc.isEmpty) {
      errors.add('cvc cannot be empty');
    } else if (!RegExp(r'^\d{3,4}$').hasMatch(cvc)) {
      errors.add('cvc must be 3 or 4 digits');
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors: errors);
    }
  }

  /// Converts this instance to a JSON-compatible map for API calls.
  ///
  /// **WARNING: Contains sensitive data (full card number and CVV).**
  ///
  /// This method should ONLY be used internally for payment API requests.
  /// **NEVER** use this for:
  /// * Logging (use [toSafeJson] instead)
  /// * Debugging output
  /// * Error messages
  /// * Analytics or telemetry
  ///
  /// For any logging or display purposes, always use [toSafeJson] which
  /// properly masks sensitive card data.
  ///
  /// See also:
  /// * [toSafeJson] - Safe alternative for logging
  /// * [maskedNumber] - Masked card number for display
  @internal
  @Deprecated(
    'Avoid direct use. For logging use toSafeJson(). '
    'This method exposes raw card data and should only be used internally for API calls.',
  )
  Map<String, dynamic> toJson() => {
        'cardHolderName': cardHolderName,
        'cardNumber': cardNumber,
        'expireMonth': expireMonth,
        'expireYear': expireYear,
        'cvc': cvc,
        'saveCard': saveCard,
      };

  /// Safe JSON representation for logging.
  ///
  /// Masks sensitive data (card number and CVC) for secure logging.
  /// Use this instead of [toJson] when logging card information.
  Map<String, dynamic> toSafeJson() => {
        'cardHolderName': cardHolderName,
        'cardNumber': maskedNumber,
        'expireMonth': expireMonth,
        'expireYear': expireYear,
        'cvc': '***',
        'saveCard': saveCard,
        'binNumber': binNumber,
        'lastFourDigits': lastFourDigits,
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
