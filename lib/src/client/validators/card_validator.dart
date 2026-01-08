import 'package:meta/meta.dart';

/// Client-side card validation utilities.
///
/// This class provides static methods for validating card information
/// before sending to the backend. No network calls are made.
///
/// ## Example
///
/// ```dart
/// // Validate a single field
/// if (!CardValidator.isValidCardNumber(cardNumber)) {
///   showError('Invalid card number');
/// }
///
/// // Validate all fields at once
/// final result = CardValidator.validate(
///   cardNumber: '5528790000000008',
///   expireMonth: '12',
///   expireYear: '2030',
///   cvv: '123',
///   holderName: 'Ahmet Yilmaz',
/// );
///
/// if (!result.isValid) {
///   print(result.errors); // {'cardNumber': 'Invalid card number'}
/// }
///
/// // Detect card brand
/// final brand = CardValidator.detectCardBrand('4111111111111111');
/// print(brand.displayName); // 'Visa'
/// ```
class CardValidator {
  CardValidator._();

  /// Validates a card number using the Luhn algorithm.
  ///
  /// Returns true if the card number passes Luhn check and has valid length.
  /// Accepts formatted numbers (with spaces or dashes).
  static bool isValidCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');

    // Valid card numbers are 13-19 digits
    if (cleaned.length < 13 || cleaned.length > 19) {
      return false;
    }

    // Reject all-zeros card numbers (technically passes Luhn but not real)
    if (cleaned.replaceAll('0', '').isEmpty) {
      return false;
    }

    // Luhn algorithm
    var sum = 0;
    var alternate = false;

    for (var i = cleaned.length - 1; i >= 0; i--) {
      var digit = int.parse(cleaned[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Validates the card expiry date.
  ///
  /// [month] - 1-12 or "01"-"12"
  /// [year] - 2 or 4 digit year (e.g., "25" or "2025")
  ///
  /// Returns true if the expiry date is in the future.
  static bool isValidExpiry(String month, String year) {
    try {
      final m = int.parse(month);
      var y = int.parse(year);

      if (m < 1 || m > 12) return false;

      // Convert 2-digit year to 4-digit
      if (y < 100) y += 2000;

      final now = DateTime.now();
      // Last day of the expiry month
      final expiry = DateTime(y, m + 1, 0, 23, 59, 59);

      return expiry.isAfter(now);
    } catch (_) {
      return false;
    }
  }

  /// Validates a CVV/CVC code.
  ///
  /// [cvv] - 3 or 4 digit security code
  /// [cardBrand] - Optional card brand (Amex requires 4 digits)
  ///
  /// Returns true if CVV has correct length for the card type.
  static bool isValidCVV(String cvv, {CardBrand? cardBrand}) {
    final cleaned = cvv.replaceAll(RegExp(r'\D'), '');

    // Amex uses 4-digit CVV
    if (cardBrand == CardBrand.amex) {
      return cleaned.length == 4;
    }

    // All other cards use 3-digit CVV
    return cleaned.length == 3;
  }

  /// Validates the card holder name.
  ///
  /// Returns true if name has at least 2 words and reasonable length.
  static bool isValidHolderName(String name) {
    final trimmed = name.trim();

    if (trimmed.length < 3) return false;
    if (trimmed.length > 100) return false;

    // Should have at least 2 words (first and last name)
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.length >= 2;
  }

  /// Detects the card brand from the card number.
  ///
  /// Supports Visa, Mastercard, American Express, and Troy.
  static CardBrand detectCardBrand(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');

    if (cleaned.isEmpty) return CardBrand.unknown;

    // Visa: starts with 4
    if (cleaned.startsWith('4')) {
      return CardBrand.visa;
    }

    // Mastercard: 51-55 or 2221-2720
    if (cleaned.length >= 2) {
      final firstTwo = int.tryParse(cleaned.substring(0, 2)) ?? 0;
      if (firstTwo >= 51 && firstTwo <= 55) {
        return CardBrand.mastercard;
      }
    }
    if (cleaned.length >= 4) {
      final firstFour = int.tryParse(cleaned.substring(0, 4)) ?? 0;
      if (firstFour >= 2221 && firstFour <= 2720) {
        return CardBrand.mastercard;
      }
    }

    // Amex: starts with 34 or 37
    if (cleaned.startsWith('34') || cleaned.startsWith('37')) {
      return CardBrand.amex;
    }

    // Troy: starts with 9792
    if (cleaned.startsWith('9792')) {
      return CardBrand.troy;
    }

    return CardBrand.unknown;
  }

  /// Formats a card number with spaces for display.
  ///
  /// Example: "5528790000000008" → "5528 7900 0000 0008"
  static String formatCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(cleaned[i]);
    }

    return buffer.toString();
  }

  /// Masks a card number for display, showing only BIN and last 4 digits.
  ///
  /// Example: "5528790000000008" → "552879******0008"
  static String maskCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 10) return cleaned;

    final first6 = cleaned.substring(0, 6);
    final last4 = cleaned.substring(cleaned.length - 4);
    final masked = '*' * (cleaned.length - 10);

    return '$first6$masked$last4';
  }

  /// Extracts the BIN (Bank Identification Number) from a card number.
  ///
  /// [length] - Number of digits to extract (default: 6)
  static String extractBin(String cardNumber, {int length = 6}) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < length) return cleaned;
    return cleaned.substring(0, length);
  }

  /// Validates all card information at once.
  ///
  /// Returns a [CardValidationResult] with validation status and any errors.
  static CardValidationResult validate({
    required String cardNumber,
    required String expireMonth,
    required String expireYear,
    required String cvv,
    required String holderName,
  }) {
    final errors = <String, String>{};
    final cardBrand = detectCardBrand(cardNumber);

    if (!isValidCardNumber(cardNumber)) {
      errors['cardNumber'] = 'Gecersiz kart numarasi';
    }

    if (!isValidExpiry(expireMonth, expireYear)) {
      errors['expiry'] = 'Gecersiz veya gecmis son kullanma tarihi';
    }

    if (!isValidCVV(cvv, cardBrand: cardBrand)) {
      final expectedLength = cardBrand == CardBrand.amex ? '4' : '3';
      errors['cvv'] = 'CVV $expectedLength haneli olmalidir';
    }

    if (!isValidHolderName(holderName)) {
      errors['holderName'] = 'Gecersiz kart sahibi adi';
    }

    return CardValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      cardBrand: cardBrand,
    );
  }
}

/// Card brand/network identifier.
enum CardBrand {
  /// Visa cards (starts with 4)
  visa,

  /// Mastercard (51-55 or 2221-2720)
  mastercard,

  /// American Express (34 or 37)
  amex,

  /// Turkish Troy network (9792)
  troy,

  /// Unknown or unsupported card brand
  unknown;

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case CardBrand.visa:
        return 'Visa';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.amex:
        return 'American Express';
      case CardBrand.troy:
        return 'Troy';
      case CardBrand.unknown:
        return 'Unknown';
    }
  }

  /// Returns true if this brand is a valid, known brand.
  bool get isKnown => this != CardBrand.unknown;
}

/// Result of card validation.
@immutable
class CardValidationResult {
  /// Creates a new [CardValidationResult] instance.
  const CardValidationResult({
    required this.isValid,
    required this.errors,
    required this.cardBrand,
  });

  /// Whether all validation checks passed.
  final bool isValid;

  /// Map of field names to error messages.
  ///
  /// Empty if [isValid] is true.
  final Map<String, String> errors;

  /// Detected card brand.
  final CardBrand cardBrand;

  /// Returns true if the specified field has an error.
  bool hasError(String field) => errors.containsKey(field);

  /// Returns the error message for the specified field, or null if no error.
  String? getError(String field) => errors[field];

  /// Returns all error messages as a list.
  List<String> get allErrors => errors.values.toList();

  @override
  String toString() => isValid
      ? 'CardValidationResult.valid(brand: ${cardBrand.displayName})'
      : 'CardValidationResult.invalid(errors: $errors)';
}
