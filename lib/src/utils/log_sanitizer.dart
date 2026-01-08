/// Log temizleme - hassas verileri maskeler.
///
/// Bu sınıf, log çıktılarından hassas verileri otomatik olarak maskeler.
/// Kart numaraları, CVV, API anahtarları ve şifreler güvenli şekilde gizlenir.
///
/// ## Örnek
///
/// ```dart
/// final safeLog = LogSanitizer.sanitize('Card: 5528790000000008, CVV: 123');
/// // Output: 'Card: 552879XXXXXX0008, CVV: ***'
/// ```
class LogSanitizer {
  LogSanitizer._();

  /// Kart numarasını maskele: 552879XXXXXX0008
  ///
  /// İlk 6 hane (BIN) ve son 4 hane görünür, aradakiler 'X' ile maskelenir.
  /// 10 haneden kısa kartlar tamamen maskelenir.
  static String maskCardNumber(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\s|-'), '');
    if (cleanNumber.length < 10) return '****';
    final middleLength = cleanNumber.length - 10;
    final mask = 'X' * (middleLength + 6); // At least 6 X's
    return '${cleanNumber.substring(0, 6)}$mask${cleanNumber.substring(cleanNumber.length - 4)}';
  }

  /// CVV'yi maskele
  static String maskCVV(String cvv) => '***';

  /// Genel log temizleme
  ///
  /// Aşağıdaki hassas verileri otomatik olarak maskeler:
  /// * Kart numaraları (13-19 hane)
  /// * CVV/CVC kodları
  /// * API anahtarları
  /// * Secret key'ler
  /// * Token'lar
  /// * Şifreler
  static String sanitize(String input) {
    var output = input;

    // Kart numarası maskeleme (13-19 haneli sayılar)
    // Pattern: 4 digit + 5-11 digit (middle) + 4 digit = 13-19 total
    // Previous pattern was 4+6-12+4 = 14-20, missing 13-digit cards
    output = output.replaceAllMapped(
      RegExp(r'\b(\d{4})(\d{5,11})(\d{4})\b'),
      (m) {
        final middleLength = m[2]!.length;
        final mask = 'X' * middleLength;
        return '${m[1]}$mask${m[3]}';
      },
    );

    // CVV maskeleme (cvv: 123, cvv=123, "cvv": "123" formatları)
    output = output.replaceAllMapped(
      RegExp(r'("?cvv"?\s*[:=]\s*"?)\d{3,4}("?)', caseSensitive: false),
      (m) => '${m[1]}***${m[2]}',
    );

    // CVC maskeleme
    output = output.replaceAllMapped(
      RegExp(r'("?cvc"?\s*[:=]\s*"?)\d{3,4}("?)', caseSensitive: false),
      (m) => '${m[1]}***${m[2]}',
    );

    // API key maskeleme
    output = output.replaceAllMapped(
      RegExp(r'(api[_-]?key\s*[:=]\s*)[^\s,}"]+', caseSensitive: false),
      (m) => '${m[1]}***MASKED***',
    );

    // Secret key maskeleme
    output = output.replaceAllMapped(
      RegExp(r'(secret[_-]?key\s*[:=]\s*)[^\s,}"]+', caseSensitive: false),
      (m) => '${m[1]}***MASKED***',
    );

    // Token maskeleme
    output = output.replaceAllMapped(
      RegExp(r'(token\s*[:=]\s*)[^\s,}"]+', caseSensitive: false),
      (m) => '${m[1]}***MASKED***',
    );

    // Password maskeleme
    output = output.replaceAllMapped(
      RegExp(r'(password\s*[:=]\s*)[^\s,}"]+', caseSensitive: false),
      (m) => '${m[1]}***MASKED***',
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
      'api_key',
      'apiKey',
      'secret_key',
      'secretKey',
      'token',
      'password',
      'secret',
    ];

    for (final key in sensitiveKeys) {
      if (sanitized.containsKey(key)) {
        final value = sanitized[key];
        if (value is String) {
          final lowerKey = key.toLowerCase();
          if (lowerKey.contains('card')) {
            sanitized[key] = maskCardNumber(value);
          } else if (lowerKey.contains('cv')) {
            sanitized[key] = '***';
          } else if (lowerKey.contains('api') ||
              lowerKey.contains('secret') ||
              lowerKey.contains('token') ||
              lowerKey.contains('password')) {
            sanitized[key] = '***MASKED***';
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
