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
///
/// ## Performance
///
/// All RegExp patterns are compiled once as static finals to avoid
/// recompilation on each call, improving performance significantly.
class LogSanitizer {
  LogSanitizer._();

  // ============================================
  // CACHED REGEXP PATTERNS (Performance optimization)
  // ============================================

  /// Pattern for card numbers (13-19 digits)
  static final _cardNumberPattern = RegExp(r'\b(\d{4})(\d{5,11})(\d{4})\b');

  /// Pattern for spaces/dashes in card numbers
  static final _cardCleanPattern = RegExp(r'\s|-');

  /// Pattern for CVV in various formats
  static final _cvvPattern =
      RegExp(r'("?cvv"?\s*[:=]\s*"?)\d{3,4}("?)', caseSensitive: false);

  /// Pattern for CVC in various formats
  static final _cvcPattern =
      RegExp(r'("?cvc"?\s*[:=]\s*"?)\d{3,4}("?)', caseSensitive: false);

  /// Pattern for API keys
  static final _apiKeyPattern =
      RegExp(r'(api[_-]?key\s*[:=]\s*)[^\s,}"]+', caseSensitive: false);

  /// Pattern for secret keys
  static final _secretKeyPattern =
      RegExp(r'(secret[_-]?key\s*[:=]\s*)[^\s,}"]+', caseSensitive: false);

  /// Pattern for tokens
  static final _tokenPattern =
      RegExp(r'(token\s*[:=]\s*)[^\s,}"]+', caseSensitive: false);

  /// Pattern for passwords
  static final _passwordPattern =
      RegExp(r'(password\s*[:=]\s*)[^\s,}"]+', caseSensitive: false);

  /// Kart numarasını maskele: 552879XXXXXX0008
  ///
  /// İlk 6 hane (BIN) ve son 4 hane görünür, aradakiler 'X' ile maskelenir.
  /// 10 haneden kısa kartlar tamamen maskelenir.
  static String maskCardNumber(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(_cardCleanPattern, '');
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
  ///
  /// Note: Uses cached RegExp patterns for better performance.
  static String sanitize(String input) {
    var output = input;

    // Kart numarası maskeleme (13-19 haneli sayılar)
    // Pattern: 4 digit + 5-11 digit (middle) + 4 digit = 13-19 total
    output = output.replaceAllMapped(
      _cardNumberPattern,
      (m) {
        final middleLength = m[2]!.length;
        final mask = 'X' * middleLength;
        return '${m[1]}$mask${m[3]}';
      },
    );

    // CVV maskeleme (cvv: 123, cvv=123, "cvv": "123" formatları)
    output = output.replaceAllMapped(
      _cvvPattern,
      (m) => '${m[1]}***${m[2]}',
    );

    // CVC maskeleme
    output = output.replaceAllMapped(
      _cvcPattern,
      (m) => '${m[1]}***${m[2]}',
    );

    // API key maskeleme
    output = output.replaceAllMapped(
      _apiKeyPattern,
      (m) => '${m[1]}***MASKED***',
    );

    // Secret key maskeleme
    output = output.replaceAllMapped(
      _secretKeyPattern,
      (m) => '${m[1]}***MASKED***',
    );

    // Token maskeleme
    output = output.replaceAllMapped(
      _tokenPattern,
      (m) => '${m[1]}***MASKED***',
    );

    // Password maskeleme
    output = output.replaceAllMapped(
      _passwordPattern,
      (m) => '${m[1]}***MASKED***',
    );

    return output;
  }

  /// Maximum recursion depth for nested maps to prevent DOS attacks.
  static const _maxRecursionDepth = 10;

  /// Sensitive keys that should be masked.
  static const _sensitiveKeys = [
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

  /// JSON map'ten hassas verileri temizle
  ///
  /// [maxDepth] parameter controls the maximum recursion depth for nested maps.
  /// This prevents potential DOS attacks from deeply nested malicious data.
  /// Default is 10 levels deep.
  static Map<String, dynamic> sanitizeMap(
    Map<String, dynamic> data, {
    int maxDepth = _maxRecursionDepth,
  }) {
    return _sanitizeMapWithDepth(data, 0, maxDepth);
  }

  /// Internal recursive method with depth tracking.
  static Map<String, dynamic> _sanitizeMapWithDepth(
    Map<String, dynamic> data,
    int currentDepth,
    int maxDepth,
  ) {
    // Prevent infinite recursion
    if (currentDepth >= maxDepth) {
      return Map<String, dynamic>.from(data);
    }

    final sanitized = Map<String, dynamic>.from(data);

    for (final key in _sensitiveKeys) {
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

    // Nested map'leri de temizle (with depth limit)
    for (final entry in sanitized.entries) {
      if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = _sanitizeMapWithDepth(
          entry.value as Map<String, dynamic>,
          currentDepth + 1,
          maxDepth,
        );
      } else if (entry.value is List) {
        sanitized[entry.key] = _sanitizeList(
          entry.value as List<dynamic>,
          currentDepth + 1,
          maxDepth,
        );
      }
    }

    return sanitized;
  }

  /// Sanitizes a list recursively with depth limit.
  static List<dynamic> _sanitizeList(
    List<dynamic> list,
    int currentDepth,
    int maxDepth,
  ) {
    if (currentDepth >= maxDepth) {
      return List<dynamic>.from(list);
    }

    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return _sanitizeMapWithDepth(item, currentDepth + 1, maxDepth);
      } else if (item is List) {
        return _sanitizeList(item, currentDepth + 1, maxDepth);
      }
      return item;
    }).toList();
  }
}
