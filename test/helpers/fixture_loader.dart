import 'dart:convert';
import 'dart:io';

/// Test fixture dosyalarını yüklemek için yardımcı sınıf
class TestFixtures {
  static const String _basePath = 'test/fixtures';

  /// Fixture dosyasını string olarak yükler
  static Future<String> load(String path) async {
    final file = File('$_basePath/$path');
    if (!file.existsSync()) {
      throw Exception('Fixture file not found: $_basePath/$path');
    }
    return file.readAsString();
  }

  /// Fixture dosyasını senkron olarak yükler
  static String loadSync(String path) {
    final file = File('$_basePath/$path');
    if (!file.existsSync()) {
      throw Exception('Fixture file not found: $_basePath/$path');
    }
    return file.readAsStringSync();
  }

  /// JSON fixture dosyasını Map olarak yükler
  static Future<Map<String, dynamic>> loadJson(String path) async {
    final content = await load(path);
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// JSON fixture dosyasını senkron olarak Map olarak yükler
  static Map<String, dynamic> loadJsonSync(String path) {
    final content = loadSync(path);
    return jsonDecode(content) as Map<String, dynamic>;
  }

  // ============================================
  // IYZICO FIXTURES
  // ============================================

  static Future<Map<String, dynamic>> iyzicoPaymentSuccess() =>
      loadJson('iyzico/payment_success.json');

  static Future<Map<String, dynamic>> iyzicoPaymentFailedInsufficientFunds() =>
      loadJson('iyzico/payment_failed_insufficient_funds.json');

  static Future<Map<String, dynamic>> iyzicoThreeDSInitSuccess() =>
      loadJson('iyzico/threeds_init_success.json');

  static Future<Map<String, dynamic>> iyzicoInstallmentsResponse() =>
      loadJson('iyzico/installments_response.json');

  static Future<Map<String, dynamic>> iyzicoRefundSuccess() =>
      loadJson('iyzico/refund_success.json');

  // ============================================
  // PAYTR FIXTURES
  // ============================================

  static Future<Map<String, dynamic>> paytrIframeTokenSuccess() =>
      loadJson('paytr/iframe_token_success.json');

  static Future<Map<String, dynamic>> paytrPaymentCallbackSuccess() =>
      loadJson('paytr/payment_callback_success.json');

  static Future<Map<String, dynamic>> paytrInstallmentsResponse() =>
      loadJson('paytr/installments_response.json');

  static Future<Map<String, dynamic>> paytrRefundSuccess() =>
      loadJson('paytr/refund_success.json');

  // ============================================
  // PARAM FIXTURES (XML)
  // ============================================

  static Future<String> paramPaymentSuccess() =>
      load('param/payment_success.xml');

  static Future<String> paramPaymentFailed() =>
      load('param/payment_failed.xml');

  static Future<String> paramThreeDSInit() => load('param/threeds_init.xml');

  static Future<String> paramRefundSuccess() =>
      load('param/refund_success.xml');

  // ============================================
  // SIPAY FIXTURES
  // ============================================

  static Future<Map<String, dynamic>> sipayTokenResponse() =>
      loadJson('sipay/token_response.json');

  static Future<Map<String, dynamic>> sipayPaymentSuccess() =>
      loadJson('sipay/payment_success.json');

  static Future<Map<String, dynamic>> sipayPaymentFailed() =>
      loadJson('sipay/payment_failed.json');

  static Future<Map<String, dynamic>> sipayThreeDSInit() =>
      loadJson('sipay/threeds_init.json');

  static Future<Map<String, dynamic>> sipayInstallmentsResponse() =>
      loadJson('sipay/installments_response.json');

  static Future<Map<String, dynamic>> sipayRefundSuccess() =>
      loadJson('sipay/refund_success.json');
}
