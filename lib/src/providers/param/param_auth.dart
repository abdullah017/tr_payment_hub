import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Param POS Authentication
///
/// Param, GUID bazlı authentication kullanır.
/// Her işlem için hash hesaplanır.
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

  /// SHA1 hash hesaplama
  String _sha1Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha1.convert(bytes);
    return digest.toString().toUpperCase();
  }
}
