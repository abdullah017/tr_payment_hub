import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Handles Param POS authentication using GUID-based hashing.
///
/// Param uses a GUID-based authentication system where each operation
/// requires a hash computed from the GUID and operation-specific parameters.
/// The API uses SOAP/XML format with SHA1 hashing.
///
/// ## Token Generation
///
/// Hashes are generated using:
/// 1. Concatenate: `GUID + ClientCode + [operation-specific params]`
/// 2. Compute SHA1 hash (uppercase)
///
/// ## Available Hash Types
///
/// * [generatePaymentHash] - Payment transaction hash
/// * [generateRefundHash] - Refund transaction hash
/// * [generateQueryHash] - Status query hash
///
/// ## Example
///
/// ```dart
/// final auth = ParamAuth(
///   clientCode: 'your_client_code',
///   clientUsername: 'your_username',
///   clientPassword: 'your_password',
///   guid: 'your_guid',
/// );
///
/// // Generate payment hash
/// final hash = auth.generatePaymentHash(
///   amount: '10000', // 100.00 TL in kuruş
///   orderId: 'ORDER_123',
/// );
/// ```
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
///
/// ## Param API Reference
///
/// See [Param documentation](https://dev.param.com.tr/) for API details.
class ParamAuth {
  /// Creates a new [ParamAuth] instance.
  ///
  /// [clientCode] - The client code from Param dashboard
  /// [clientUsername] - The client username for API access
  /// [clientPassword] - The client password for API access
  /// [guid] - The GUID for hash generation
  ParamAuth({
    required this.clientCode,
    required this.clientUsername,
    required this.clientPassword,
    required this.guid,
  });

  /// The client code assigned by Param.
  final String clientCode;

  /// The client username for authentication.
  final String clientUsername;

  /// The client password for authentication.
  final String clientPassword;

  /// The GUID used for hash generation.
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
