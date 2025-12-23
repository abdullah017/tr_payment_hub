import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Hash ve şifreleme yardımcıları
class HashUtils {
  HashUtils._();

  /// HMAC-SHA256 hash oluştur
  static String hmacSha256(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    return digest.toString();
  }

  /// HMAC-SHA256 hash oluştur ve Base64 encode et
  static String hmacSha256Base64(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    return base64.encode(digest.bytes);
  }

  /// SHA256 hash oluştur
  static String sha256Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Base64 encode
  static String base64Encode(String data) {
    return base64.encode(utf8.encode(data));
  }

  /// Base64 decode
  static String base64Decode(String data) {
    return utf8.decode(base64.decode(data));
  }

  /// Random string oluştur (conversationId vb. için)
  static String generateRandomKey([int length = 32]) {
    final now = DateTime.now();
    final data = '${now.millisecondsSinceEpoch}${now.microsecond}';
    final hash = sha256Hash(data);
    return hash.substring(0, length);
  }
}
