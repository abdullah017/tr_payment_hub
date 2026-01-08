import '../enums.dart';

/// Ödeme hatası.
///
/// Tüm ödeme ile ilgili hataları temsil eder. Factory constructor'lar
/// yaygın hata senaryoları için önceden tanımlanmış mesajlar sunar.
///
/// ## Güvenlik Notu
///
/// [providerMessage] alanı API'den gelen ham hata mesajlarını içerebilir.
/// Bu mesajlar kullanıcı arayüzünde doğrudan gösterilmemeli, bunun yerine
/// [userFriendlyMessage] kullanılmalıdır.
///
/// ## Örnek
///
/// ```dart
/// try {
///   await provider.createPayment(request);
/// } on PaymentException catch (e) {
///   // Kullanıcıya göster
///   showError(e.userFriendlyMessage);
///
///   // Debug için logla
///   print(e.debugInfo);
/// }
/// ```
class PaymentException implements Exception {
  const PaymentException({
    required this.code,
    required this.message,
    this.providerCode,
    this.providerMessage,
    this.provider,
  });

  /// Creates a [PaymentException] from a JSON map.
  factory PaymentException.fromJson(Map<String, dynamic> json) {
    final providerStr = json['provider'] as String?;
    final provider = providerStr != null
        ? ProviderType.values.firstWhere(
            (p) => p.name == providerStr,
            orElse: () => ProviderType.iyzico,
          )
        : null;

    return PaymentException(
      code: json['errorCode'] as String? ?? json['code'] as String? ?? 'unknown',
      message: json['errorMessage'] as String? ?? json['message'] as String? ?? 'Unknown error',
      providerCode: json['providerCode'] as String?,
      providerMessage: json['providerMessage'] as String?,
      provider: provider,
    );
  }

  /// Creates a PaymentException with sanitized provider message.
  ///
  /// Use this factory when the provider message may contain sensitive
  /// information that should be filtered before storage/logging.
  factory PaymentException.withSanitizedMessage({
    required String code,
    required String message,
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: code,
        message: message,
        providerCode: providerCode,
        providerMessage:
            providerMessage != null ? _sanitizeMessage(providerMessage) : null,
        provider: provider,
      );

  // ============================================
  // Factory Constructors - Common Errors
  // ============================================

  factory PaymentException.insufficientFunds({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'insufficient_funds',
        message: 'Yetersiz bakiye',
        providerCode: providerCode,
        providerMessage: providerMessage,
        provider: provider,
      );

  factory PaymentException.invalidCard({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'invalid_card',
        message: 'Geçersiz kart bilgisi',
        providerCode: providerCode,
        providerMessage: providerMessage,
        provider: provider,
      );

  factory PaymentException.expiredCard({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'expired_card',
        message: 'Kartın süresi dolmuş',
        providerCode: providerCode,
        providerMessage: providerMessage,
        provider: provider,
      );

  factory PaymentException.invalidCVV({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'invalid_cvv',
        message: 'Geçersiz CVV',
        providerCode: providerCode,
        providerMessage: providerMessage,
        provider: provider,
      );

  factory PaymentException.declined({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'declined',
        message: 'İşlem reddedildi',
        providerCode: providerCode,
        providerMessage: providerMessage,
        provider: provider,
      );

  factory PaymentException.threeDSFailed({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'threeds_failed',
        message: '3D Secure doğrulaması başarısız',
        providerCode: providerCode,
        providerMessage: providerMessage,
        provider: provider,
      );

  factory PaymentException.networkError({
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'network_error',
        message: 'Bağlantı hatası',
        providerMessage: providerMessage,
        provider: provider,
      );

  factory PaymentException.configError({
    required String message,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'config_error',
        message: message,
        provider: provider,
      );

  factory PaymentException.timeout({ProviderType? provider}) =>
      PaymentException(
        code: 'timeout',
        message: 'İşlem zaman aşımına uğradı',
        provider: provider,
      );

  factory PaymentException.unknown({
    String? providerCode,
    String? providerMessage,
    ProviderType? provider,
  }) =>
      PaymentException(
        code: 'unknown_error',
        message: 'Bilinmeyen bir hata oluştu',
        providerCode: providerCode,
        providerMessage: providerMessage,
        provider: provider,
      );

  /// Converts this exception to a JSON-compatible map.
  ///
  /// Useful for serializing errors to send over network or for logging.
  Map<String, dynamic> toJson() => {
        'errorCode': code,
        'errorMessage': message,
        if (providerCode != null) 'providerCode': providerCode,
        if (providerMessage != null) 'providerMessage': providerMessage,
        if (provider != null) 'provider': provider!.name,
        'success': false,
      };

  final String code;
  final String message;
  final String? providerCode;
  final String? providerMessage;
  final ProviderType? provider;

  @override
  String toString() => 'PaymentException($code): $message';

  /// Kullanıcıya gösterilebilir mesaj.
  ///
  /// Her zaman güvenli, kullanıcı dostu bir mesaj döndürür.
  /// Teknik detaylar veya hassas bilgiler içermez.
  String get userFriendlyMessage => message;

  /// Provider mesajının sanitize edilmiş versiyonu.
  ///
  /// Potansiyel hassas bilgileri (SQL, dosya yolları, stack trace vb.)
  /// filtreler ve güvenli bir mesaj döndürür.
  String? get sanitizedProviderMessage =>
      providerMessage != null ? _sanitizeMessage(providerMessage!) : null;

  /// Debug için detaylı bilgi.
  ///
  /// **UYARI:** Bu metod hassas bilgiler içerebilir.
  /// Sadece geliştirme/debug amaçlı kullanın, production log'larına yazmayın.
  String get debugInfo => 'PaymentException(code: $code, message: $message, '
      'providerCode: $providerCode, providerMessage: $providerMessage, '
      'provider: $provider)';

  /// Sanitizes provider messages to remove potentially sensitive information.
  ///
  /// Removes:
  /// * SQL keywords (SELECT, INSERT, etc.)
  /// * File paths (Unix and Windows)
  /// * Stack trace patterns
  /// * Long messages (truncated to 500 chars)
  static String _sanitizeMessage(String message) {
    var sanitized = message;

    // Remove SQL-like patterns
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|EXEC|EXECUTE)\b',
        caseSensitive: false,
      ),
      '[FILTERED]',
    );

    // Remove file paths (Unix style)
    sanitized = sanitized.replaceAll(
      RegExp(r'/(?:[\w\-./]+)+'),
      '[PATH]',
    );

    // Remove file paths (Windows style)
    sanitized = sanitized.replaceAll(
      RegExp(r'[A-Z]:\\(?:[\w\-\\]+)+', caseSensitive: false),
      '[PATH]',
    );

    // Remove stack trace patterns
    sanitized = sanitized.replaceAll(
      RegExp(r'at\s+[\w.$<>]+\([^)]*\)'),
      '',
    );

    // Remove common sensitive patterns
    sanitized = sanitized.replaceAll(
      RegExp(r'(password|secret|key|token)\s*[=:]\s*\S+', caseSensitive: false),
      r'$1=[REDACTED]',
    );

    // Truncate long messages
    if (sanitized.length > 500) {
      sanitized = '${sanitized.substring(0, 500)}... [truncated]';
    }

    return sanitized.trim();
  }
}
