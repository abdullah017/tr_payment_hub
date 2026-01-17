import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hash ve şifreleme yardımcıları
class HashUtils {
  HashUtils._();

  /// Secure random instance for cryptographic operations
  static final _secureRandom = Random.secure();

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
  static String base64Encode(String data) => base64.encode(utf8.encode(data));

  /// Base64 decode
  static String base64Decode(String data) => utf8.decode(base64.decode(data));

  /// Generates a cryptographically secure random hex string.
  ///
  /// **IMPORTANT**: This method uses [Random.secure()] for cryptographic
  /// randomness. The previous implementation using timestamps was predictable
  /// and should not be used for security-sensitive operations.
  ///
  /// Example:
  /// ```dart
  /// final key = HashUtils.generateRandomKey(32); // 32-char hex string
  /// ```
  ///
  /// For most use cases, prefer [PaymentUtils.generateSecureHex()] instead.
  static String generateRandomKey([int length = 32]) {
    // Calculate bytes needed (2 hex chars per byte)
    final bytesNeeded = (length / 2).ceil();
    final bytes = List<int>.generate(
      bytesNeeded,
      (_) => _secureRandom.nextInt(256),
    );
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hex.substring(0, length);
  }

  /// Generates a secure random string with alphanumeric characters.
  ///
  /// This method generates a random string using [Random.secure()]
  /// containing characters a-z, A-Z, and 0-9.
  ///
  /// Example:
  /// ```dart
  /// final token = HashUtils.generateSecureToken(24);
  /// ```
  static String generateSecureToken([int length = 24]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      length,
      (_) => chars[_secureRandom.nextInt(chars.length)],
    ).join();
  }
}
