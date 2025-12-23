import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// iyzico IYZWSv2 Authentication
class IyzicoAuth {
  final String apiKey;
  final String secretKey;
  String _lastRandomKey = '';

  IyzicoAuth({required this.apiKey, required this.secretKey});

  String get lastRandomKey => _lastRandomKey;

  /// Authorization header değerini oluştur
  /// [uriPath] - API endpoint path (örn: /payment/bin/check)
  /// [requestBody] - JSON request body
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
