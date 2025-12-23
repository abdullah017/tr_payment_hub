/// Kart bilgisi
class CardInfo {
  final String cardHolderName;
  final String cardNumber;
  final String expireMonth;
  final String expireYear;
  final String cvc;
  final bool saveCard;

  const CardInfo({
    required this.cardHolderName,
    required this.cardNumber,
    required this.expireMonth,
    required this.expireYear,
    required this.cvc,
    this.saveCard = false,
  });

  /// İlk 6/8 hane (BIN)
  String get binNumber =>
      cardNumber.length >= 6 ? cardNumber.substring(0, 6) : cardNumber;

  /// Son 4 hane
  String get lastFourDigits => cardNumber.length >= 4
      ? cardNumber.substring(cardNumber.length - 4)
      : cardNumber;

  /// Maskelenmiş kart numarası (loglama için güvenli)
  String get maskedNumber {
    if (cardNumber.length < 10) return '****';
    return '${cardNumber.substring(0, 6)}******${cardNumber.substring(cardNumber.length - 4)}';
  }

  /// Kart numarası geçerli mi (Luhn algoritması)
  bool get isValidNumber {
    if (cardNumber.length < 13 || cardNumber.length > 19) return false;

    int sum = 0;
    bool alternate = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.tryParse(cardNumber[i]) ?? -1;
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
}
