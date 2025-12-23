/// Log temizleme - hassas verileri maskeler
class LogSanitizer {
  LogSanitizer._();

  /// Kart numarasını maskele: 4532XXXXXXXX1234
  static String maskCardNumber(String cardNumber) {
    if (cardNumber.length < 10) return '****';
    return '${cardNumber.substring(0, 6)}XXXXXX${cardNumber.substring(cardNumber.length - 4)}';
  }

  /// CVV'yi maskele
  static String maskCVV(String cvv) => '***';

  /// Genel log temizleme
  static String sanitize(String input) {
    var output = input;

    // Kart numarası maskeleme (13-19 haneli sayılar)
    output = output.replaceAllMapped(
      RegExp(r'\b(\d{4})(\d{6,12})(\d{4})\b'),
      (m) => '${m[1]}XXXXXX${m[3]}',
    );

    // CVV maskeleme ("cvv": "123" formatı)
    output = output.replaceAllMapped(
      RegExp(r'(cvv\s*[:=]\s*)\d{3,4}'),
      (m) => '${m[1]}***',
    );

    // CVC maskeleme
    output = output.replaceAllMapped(
      RegExp(r'(cvc\s*[:=]\s*)\d{3,4}'),
      (m) => '${m[1]}***',
    );

    return output;
  }

  /// JSON map'ten hassas verileri temizle
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);

    final sensitiveKeys = [
      'cardNumber',
      'card_number',
      'cvv',
      'cvc',
      'expireMonth',
      'expireYear',
      'expire_month',
      'expire_year',
      'expiry_month',
      'expiry_year',
    ];

    for (final key in sensitiveKeys) {
      if (sanitized.containsKey(key)) {
        final value = sanitized[key];
        if (value is String) {
          if (key.toLowerCase().contains('card')) {
            sanitized[key] = maskCardNumber(value);
          } else if (key.toLowerCase().contains('cv')) {
            sanitized[key] = '***';
          } else {
            sanitized[key] = '**';
          }
        }
      }
    }

    // Nested map'leri de temizle
    for (final entry in sanitized.entries) {
      if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = sanitizeMap(entry.value);
      }
    }

    return sanitized;
  }
}
