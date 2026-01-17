import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Handles iyzico IYZWSv2 authentication for API requests.
///
/// This class implements the iyzico authentication protocol which uses
/// HMAC-SHA256 signatures with Base64 encoding. Each request requires
/// a unique random key combined with the API path and request body.
///
/// ## Authentication Flow
///
/// 1. Generate a random key (timestamp + random digits)
/// 2. Create payload: `randomKey + uriPath + requestBody`
/// 3. Calculate HMAC-SHA256 signature using the secret key
/// 4. Format auth string: `apiKey:xxx&randomKey:xxx&signature:xxx`
/// 5. Base64 encode and prefix with `IYZWSv2`
///
/// ## Example
///
/// ```dart
/// final auth = IyzicoAuth(
///   apiKey: 'your_api_key',
///   secretKey: 'your_secret_key',
/// );
///
/// final authHeader = auth.generateAuthorizationHeader(
///   '/payment/auth',
///   jsonEncode(requestBody),
/// );
///
/// // Use in HTTP request
/// http.post(url, headers: {'Authorization': authHeader});
/// ```
///
/// ## Security Notes
///
/// * The secret key should never be exposed to client-side code
/// * Each request uses a unique random key for replay attack protection
/// * Random keys are generated using cryptographically secure random
class IyzicoAuth {
  /// Creates a new [IyzicoAuth] instance.
  ///
  /// [apiKey] - The API key provided by iyzico
  /// [secretKey] - The secret key provided by iyzico
  IyzicoAuth({required this.apiKey, required this.secretKey});

  /// The API key used for authentication.
  final String apiKey;

  /// The secret key used for HMAC signature generation.
  final String secretKey;

  String _lastRandomKey = '';

  /// Returns the last generated random key.
  ///
  /// Useful for debugging or logging purposes.
  String get lastRandomKey => _lastRandomKey;

  /// Generates the Authorization header value for an API request.
  ///
  /// [uriPath] - The API endpoint path (e.g., `/payment/auth`)
  /// [requestBody] - The JSON-encoded request body
  ///
  /// Returns the complete Authorization header value including the
  /// `IYZWSv2` prefix, ready to be used in HTTP headers.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final header = auth.generateAuthorizationHeader(
  ///   '/payment/auth',
  ///   '{"amount": 100}',
  /// );
  /// // Returns: "IYZWSv2 YXBpS2V5OnNhbmRib3gtLi4u..."
  /// ```
  String generateAuthorizationHeader(String uriPath, String requestBody) {
    // 1. Random key oluştur
    _lastRandomKey = _generateRandomKey();

    // 2. Payload: randomKey + uriPath + requestBody
    final payload = '$_lastRandomKey$uriPath$requestBody';

    // 3. HMAC-SHA256 signature
    final signature = _calculateHmacSignature(payload);

    // 4. Auth string format: apiKey:xxx&randomKey:xxx&signature:xxx
    final authString =
        'apiKey:$apiKey&randomKey:$_lastRandomKey&signature:$signature';

    // 5. Base64 encode
    final base64Auth = base64.encode(utf8.encode(authString));

    return 'IYZWSv2 $base64Auth';
  }

  /// Random key oluştur (timestamp + random)
  String _generateRandomKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final randomPart = List.generate(8, (_) => random.nextInt(10)).join();
    return '$timestamp$randomPart';
  }

  /// HMAC-SHA256 signature hesapla
  String _calculateHmacSignature(String data) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }
}
