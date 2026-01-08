import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Param POS Authentication
///
/// Param, GUID bazlı authentication kullanır.
/// Her işlem için hash hesaplanır.
///
/// ## Security Notice
///
/// **WARNING:** This class uses SHA1 for hash calculations, which is required
/// by the Param POS API. SHA1 is considered cryptographically weak and has
/// known collision vulnerabilities (see: SHAttered attack, 2017).
///
/// This is a **known limitation** of the Param integration, not a bug in this library.
/// The SHA1 requirement is imposed by Param's API specification and cannot be
/// changed without Param updating their backend.
///
/// ### Recommendations:
/// * Contact Param to request SHA256 support for future API versions
/// * Monitor Param's documentation for security updates
/// * Implement additional security measures at the application level
///
/// ### References:
/// * [SHAttered Attack](https://shattered.io/)
/// * [NIST SHA1 Deprecation](https://csrc.nist.gov/projects/hash-functions)
class ParamAuth {
  ParamAuth({
    required this.clientCode,
    required this.clientUsername,
    required this.clientPassword,
    required this.guid,
  });

  final String clientCode;
  final String clientUsername;
  final String clientPassword;
  final String guid;

  /// Ödeme işlemi için hash oluştur
  ///
  /// Hash formatı: SHA1(GUID + ClientCode + Amount + SiparisID)
  String generatePaymentHash({
    required String amount,
    required String orderId,
  }) {
    final hashString = '$guid$clientCode$amount$orderId';
    return _sha1Hash(hashString);
  }

  /// İade işlemi için hash oluştur
  ///
  /// Hash formatı: SHA1(GUID + ClientCode + OrderID)
  String generateRefundHash({required String orderId}) {
    final hashString = '$guid$clientCode$orderId';
    return _sha1Hash(hashString);
  }

  /// Sorgulama işlemi için hash oluştur
  String generateQueryHash({required String orderId}) {
    final hashString = '$guid$clientCode$orderId';
    return _sha1Hash(hashString);
  }

  /// SHA1 hash calculation.
  ///
  /// **SECURITY WARNING:** SHA1 is cryptographically weak but required by Param API.
  /// This is a known limitation - see class documentation for details.
  ///
  /// DO NOT use this method for any other purpose outside of Param API communication.
  String _sha1Hash(String data) {
    // Note: SHA1 is deprecated for security purposes but required by Param's API.
    // When Param supports SHA256, this should be updated.
    final bytes = utf8.encode(data);
    final digest = sha1.convert(bytes);
    return digest.toString().toUpperCase();
  }
}
