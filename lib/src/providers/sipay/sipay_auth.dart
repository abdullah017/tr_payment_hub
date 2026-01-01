import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Sipay Bearer Token Authentication
///
/// Sipay, Bearer token tabanlı authentication kullanır.
/// Token her istek için hesaplanmalıdır.
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
  bool verifyCallbackHash({
    required String invoiceId,
    required String orderId,
    required String status,
    required String receivedHash,
  }) {
    final hashString = '$merchantKey$invoiceId$orderId$status';
    final calculatedHash = _generateHmacSha256(hashString);
    return calculatedHash == receivedHash;
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
