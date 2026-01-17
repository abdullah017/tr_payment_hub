import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../utils/security_utils.dart';

/// Handles Sipay Bearer token authentication for API requests.
///
/// Sipay uses a Bearer token-based authentication system where tokens
/// are computed using HMAC-SHA256 and Base64 encoding. Each API request
/// requires a fresh token or a pre-obtained token from the `/api/token` endpoint.
///
/// ## Authentication Flow
///
/// 1. Generate hash from: `appKey + appSecret + randomKey`
/// 2. Compute HMAC-SHA256 using the app secret
/// 3. Base64 encode the result
/// 4. Use as Bearer token in Authorization header
///
/// ## Token Types
///
/// * [generateToken] - Bearer token for API authentication
/// * [generatePaymentHash] - Payment transaction hash
/// * [generateRefundHash] - Refund transaction hash
///
/// ## Example
///
/// ```dart
/// final auth = SipayAuth(
///   appKey: 'your_app_key',
///   appSecret: 'your_app_secret',
///   merchantKey: 'your_merchant_key',
/// );
///
/// // Generate Bearer token
/// final token = auth.generateToken();
///
/// // Use in HTTP request
/// http.post(url, headers: {'Authorization': 'Bearer $token'});
///
/// // Generate payment hash for transaction
/// final paymentHash = auth.generatePaymentHash(
///   invoiceId: 'INV_123',
///   amount: '10000', // 100.00 TL in kuruş
///   currency: 'TRY',
/// );
/// ```
///
/// ## Callback Verification
///
/// ```dart
/// final isValid = auth.verifyCallbackHash(
///   invoiceId: 'INV_123',
///   orderId: 'ORDER_456',
///   status: 'success',
///   receivedHash: callbackData['hash_key'],
/// );
/// ```
///
/// ## Security Notes
///
/// * App credentials must never be exposed to clients
/// * Callback verification uses timing-safe comparison
/// * Each hash is operation-specific
///
/// ## Sipay API Reference
///
/// See [Sipay documentation](https://apidocs.sipay.com.tr/) for API details.
class SipayAuth {
  /// Creates a new SipayAuth instance.
  SipayAuth({
    required this.appKey,
    required this.appSecret,
    required this.merchantKey,
  });

  /// App key (API key)
  final String appKey;

  /// App secret (Secret key)
  final String appSecret;

  /// Merchant key
  final String merchantKey;

  /// Bearer token oluştur
  ///
  /// Sipay için hash string: app_id + app_secret + random_key
  /// HMAC-SHA256 ile imzalanır.
  String generateToken({String? randomKey}) {
    final random =
        randomKey ?? DateTime.now().millisecondsSinceEpoch.toString();
    final hashString = '$appKey$appSecret$random';
    return _generateHmacSha256(hashString);
  }

  /// İşlem hash'i oluştur
  ///
  /// Hash formatı: merchant_key + invoice_id + amount + currency
  String generatePaymentHash({
    required String invoiceId,
    required String amount,
    required String currency,
  }) {
    final hashString = '$merchantKey$invoiceId$amount$currency';
    return _generateHmacSha256(hashString);
  }

  /// İade işlemi hash'i oluştur
  String generateRefundHash({
    required String invoiceId,
    required String amount,
  }) {
    final hashString = '$merchantKey$invoiceId$amount';
    return _generateHmacSha256(hashString);
  }

  /// Callback hash doğrulama
  ///
  /// Uses constant-time comparison to prevent timing attacks.
  /// This is critical for security - standard string comparison
  /// can leak information through timing differences.
  bool verifyCallbackHash({
    required String invoiceId,
    required String orderId,
    required String status,
    required String receivedHash,
  }) {
    final hashString = '$merchantKey$invoiceId$orderId$status';
    final calculatedHash = _generateHmacSha256(hashString);
    // Use constant-time comparison to prevent timing attacks
    return SecurityUtils.constantTimeEquals(calculatedHash, receivedHash);
  }

  /// HMAC-SHA256 hash hesaplama
  String _generateHmacSha256(String data) {
    final key = utf8.encode(appSecret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64.encode(digest.bytes);
  }
}
