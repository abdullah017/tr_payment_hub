import 'dart:math';
import 'dart:typed_data';

/// Security utilities for payment operations.
///
/// This class provides cryptographic and security-related helper functions
/// that are critical for secure payment processing.
///
/// ## Features
///
/// * Constant-time string comparison (timing-attack resistant)
/// * Secure random generation
/// * Safe type casting
///
/// ## Example
///
/// ```dart
/// // Timing-safe hash verification
/// final isValid = SecurityUtils.constantTimeEquals(calculatedHash, receivedHash);
///
/// // Secure random hex
/// final randomKey = SecurityUtils.generateSecureHex(16);
/// ```
class SecurityUtils {
  SecurityUtils._();

  static final _secureRandom = Random.secure();

  /// Performs constant-time string comparison to prevent timing attacks.
  ///
  /// Standard string comparison (==) can leak information about the string
  /// contents through timing differences. This method compares strings in
  /// constant time regardless of where differences occur.
  ///
  /// **Security Note**: Always use this method when comparing:
  /// - API signatures/hashes
  /// - Authentication tokens
  /// - HMAC digests
  /// - Any security-sensitive strings
  ///
  /// Example:
  /// ```dart
  /// // GOOD - timing-safe comparison
  /// if (SecurityUtils.constantTimeEquals(calculatedHash, receivedHash)) {
  ///   // Valid signature
  /// }
  ///
  /// // BAD - vulnerable to timing attacks
  /// if (calculatedHash == receivedHash) { ... }
  /// ```
  static bool constantTimeEquals(String a, String b) {
    // If lengths differ, still perform comparison to maintain constant time
    // but we know the result will be false
    final aBytes = a.codeUnits;
    final bBytes = b.codeUnits;

    // Use the longer length to ensure constant time
    final length =
        aBytes.length > bBytes.length ? aBytes.length : bBytes.length;

    var result = aBytes.length ^ bBytes.length;

    for (var i = 0; i < length; i++) {
      final aChar = i < aBytes.length ? aBytes[i] : 0;
      final bChar = i < bBytes.length ? bBytes[i] : 0;
      result |= aChar ^ bChar;
    }

    return result == 0;
  }

  /// Generates a cryptographically secure random hex string.
  ///
  /// Uses [Random.secure()] which provides cryptographically secure
  /// random numbers suitable for security-sensitive operations.
  ///
  /// Example:
  /// ```dart
  /// final key = SecurityUtils.generateSecureHex(32); // 64 char hex string
  /// final shortKey = SecurityUtils.generateSecureHex(8); // 16 char hex string
  /// ```
  static String generateSecureHex(int byteLength) {
    final bytes = Uint8List(byteLength);
    for (var i = 0; i < byteLength; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates a cryptographically secure random string.
  ///
  /// The string contains alphanumeric characters (a-z, A-Z, 0-9).
  ///
  /// Example:
  /// ```dart
  /// final token = SecurityUtils.generateSecureString(32);
  /// ```
  static String generateSecureString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      length,
      (_) => chars[_secureRandom.nextInt(chars.length)],
    ).join();
  }

  /// Generates a cryptographically secure random integer.
  ///
  /// Example:
  /// ```dart
  /// final randomNum = SecurityUtils.generateSecureInt(1000000);
  /// ```
  static int generateSecureInt(int max) => _secureRandom.nextInt(max);
}
