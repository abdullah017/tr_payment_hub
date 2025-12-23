import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// iyzico IYZWSv2 Authentication
class IyzicoAuth {
  final String apiKey;
  final String secretKey;

  IyzicoAuth({required this.apiKey, required this.secretKey});

  /// Authorization header değerini oluştur
  String generateAuthorizationHeader(String requestBody) {
    final randomKey = _generateRandomKey();
    final payload = _preparePayload(randomKey, requestBody);
    final signature = _calculateSignature(payload);

    final authString = '$apiKey&$randomKey&$signature';
    final base64Auth = base64.encode(utf8.encode(authString));

    return 'IYZWSv2 $base64Auth';
  }

  /// Random key oluştur
  String _generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Payload hazırla
  String _preparePayload(String randomKey, String requestBody) {
    // SHA256 hash of request body
    final bodyHash = sha256.convert(utf8.encode(requestBody)).toString();
    return '$randomKey$bodyHash';
  }

  /// HMAC-SHA256 signature hesapla
  String _calculateSignature(String payload) {
    final key = utf8.encode(secretKey);
    final data = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return digest.toString();
  }
}
