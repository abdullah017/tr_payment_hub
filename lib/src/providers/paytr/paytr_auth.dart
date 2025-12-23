import 'dart:convert';
import 'package:crypto/crypto.dart';

/// PayTR Token Authentication
class PayTRAuth {
  PayTRAuth({
    required this.merchantId,
    required this.merchantKey,
    required this.merchantSalt,
  });
  final String merchantId;
  final String merchantKey;
  final String merchantSalt;

  /// iFrame API için token oluştur
  /// Hash string sırası: merchant_id + user_ip + merchant_oid + email + payment_amount + user_basket + no_installment + max_installment + currency + test_mode
  String generateIframeToken({
    required String userIp,
    required String merchantOid,
    required String email,
    required String paymentAmount,
    required String userBasket,
    required String noInstallment,
    required String maxInstallment,
    required String currency,
    required String testMode,
  }) {
    final hashString =
        '$merchantId$userIp$merchantOid$email$paymentAmount$userBasket$noInstallment$maxInstallment$currency$testMode';

    return _generateToken(hashString);
  }

  /// Direct API için paytr_token oluştur
  String generatePaymentToken({
    required String userIp,
    required String merchantOid,
    required String email,
    required String paymentAmount,
    required String paymentType,
    required String installmentCount,
    required String currency,
    required String testMode,
    required String non3d,
  }) {
    final hashString =
        '$merchantId$userIp$merchantOid$email$paymentAmount$paymentType$installmentCount$currency$testMode$non3d';
    return _generateToken(hashString);
  }

  /// Refund için token oluştur
  String generateRefundToken({
    required String merchantOid,
    required String returnAmount,
  }) {
    final hashString = '$merchantId$merchantOid$returnAmount';
    return _generateToken(hashString);
  }

  /// Status sorgusu için token oluştur
  String generateStatusToken({required String merchantOid}) {
    final hashString = '$merchantId$merchantOid';
    return _generateToken(hashString);
  }

  /// Callback hash doğrulama
  bool verifyCallbackHash({
    required String merchantOid,
    required String status,
    required String totalAmount,
    required String receivedHash,
  }) {
    final hashString = '$merchantOid$merchantSalt$status$totalAmount';
    final calculatedHash = _generateToken(hashString);
    return calculatedHash == receivedHash;
  }

  /// Token oluşturma (HMAC-SHA256 + Base64)
  String _generateToken(String hashString) {
    final dataWithSalt = hashString + merchantSalt;
    final key = utf8.encode(merchantKey);
    final data = utf8.encode(dataWithSalt);

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);

    return base64.encode(digest.bytes);
  }
}
