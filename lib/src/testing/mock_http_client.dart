import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Provider testleri için HTTP response'ları simüle eden mock client factory
///
/// Örnek kullanım:
/// ```dart
/// final mockClient = PaymentMockClient.iyzico(shouldSucceed: true);
/// final provider = IyzicoProvider(httpClient: mockClient);
/// ```
class PaymentMockClient {
  PaymentMockClient._();

  // ============================================
  // IYZICO MOCK CLIENT
  // ============================================

  /// iyzico API için mock client oluşturur
  static MockClient iyzico({
    bool shouldSucceed = true,
    Map<String, dynamic>? customResponse,
    int statusCode = 200,
  }) => MockClient((request) async {
    final path = request.url.path;

    Map<String, dynamic> response;

    if (customResponse != null) {
      response = customResponse;
    } else if (shouldSucceed) {
      response = _iyzicoSuccessResponse(path);
    } else {
      response = _iyzicoFailureResponse();
    }

    return http.Response(
      jsonEncode(response),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });

  static Map<String, dynamic> _iyzicoSuccessResponse(String path) {
    if (path.contains('installment')) {
      return {
        'status': 'success',
        'installmentDetails': [
          {
            'binNumber': '552879',
            'price': 100.0,
            'cardType': 'CREDIT_CARD',
            'cardAssociation': 'MASTER_CARD',
            'cardFamilyName': 'Bonus',
            'force3ds': 0,
            'bankCode': 62,
            'bankName': 'Garanti BBVA',
            'installmentPrices': [
              {
                'installmentNumber': 1,
                'installmentPrice': 100.0,
                'totalPrice': 100.0,
              },
              {
                'installmentNumber': 3,
                'installmentPrice': 34.33,
                'totalPrice': 103.0,
              },
            ],
          },
        ],
      };
    }

    if (path.contains('threeds/initialize')) {
      return {
        'status': 'success',
        'threeDSHtmlContent': 'PGh0bWw+PC9odG1sPg==',
        'paymentId': 'MOCK_PAYMENT_123',
      };
    }

    if (path.contains('refund')) {
      return {
        'status': 'success',
        'paymentId': 'MOCK_PAYMENT_123',
        'paymentTransactionId': 'MOCK_TX_123',
        'price': 50.0,
      };
    }

    // Default: payment response
    return {
      'status': 'success',
      'paymentId': 'MOCK_PAYMENT_123',
      'price': 100.0,
      'paidPrice': 100.0,
      'currency': 'TRY',
      'installment': 1,
      'basketId': 'ORDER_123',
      'cardType': 'CREDIT_CARD',
      'cardAssociation': 'MASTER_CARD',
      'cardFamily': 'Bonus',
      'binNumber': '552879',
      'lastFourDigits': '0008',
    };
  }

  static Map<String, dynamic> _iyzicoFailureResponse() => {
    'status': 'failure',
    'errorCode': '10051',
    'errorMessage': 'Kart limiti yetersiz, yetersiz bakiye',
  };

  // ============================================
  // PAYTR MOCK CLIENT
  // ============================================

  /// PayTR API için mock client oluşturur
  static MockClient paytr({
    bool shouldSucceed = true,
    Map<String, dynamic>? customResponse,
    int statusCode = 200,
  }) => MockClient((request) async {
    final path = request.url.path;

    Map<String, dynamic> response;

    if (customResponse != null) {
      response = customResponse;
    } else if (shouldSucceed) {
      response = _paytrSuccessResponse(path);
    } else {
      response = _paytrFailureResponse();
    }

    return http.Response(
      jsonEncode(response),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });

  static Map<String, dynamic> _paytrSuccessResponse(String path) {
    if (path.contains('taksit')) {
      return {
        'status': 'success',
        'installments': [
          {
            'installment_count': 1,
            'installment_amount': 100.0,
            'total_amount': 100.0,
          },
          {
            'installment_count': 3,
            'installment_amount': 34.33,
            'total_amount': 103.0,
          },
        ],
      };
    }

    if (path.contains('iade')) {
      return {
        'status': 'success',
        'merchant_oid': 'ORDER_123',
        'return_amount': 5000,
      };
    }

    // Default: iframe token
    return {'status': 'success', 'token': 'MOCK_TOKEN_123456'};
  }

  static Map<String, dynamic> _paytrFailureResponse() => {
    'status': 'failed',
    'reason': 'Yetersiz bakiye',
  };

  // ============================================
  // PARAM MOCK CLIENT
  // ============================================

  /// Param API için mock client oluşturur (SOAP/XML)
  static MockClient param({
    bool shouldSucceed = true,
    String? customResponse,
    int statusCode = 200,
  }) => MockClient((request) async {
    final body = request.body;

    String response;

    if (customResponse != null) {
      response = customResponse;
    } else if (shouldSucceed) {
      response = _paramSuccessResponse(body);
    } else {
      response = _paramFailureResponse();
    }

    return http.Response(
      response,
      statusCode,
      headers: {'content-type': 'text/xml; charset=utf-8'},
    );
  });

  static String _paramSuccessResponse(String requestBody) {
    if (requestBody.contains('TP_Islem_Iptal_Iade')) {
      return '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <TP_Islem_Iptal_IadeResponse xmlns="https://turkpos.com.tr/">
      <TP_Islem_Iptal_IadeResult>
        <Sonuc>1</Sonuc>
        <Sonuc_Str>İade başarılı</Sonuc_Str>
        <Dekont_ID>REF123</Dekont_ID>
        <Iade_Tutari>50.00</Iade_Tutari>
      </TP_Islem_Iptal_IadeResult>
    </TP_Islem_Iptal_IadeResponse>
  </soap:Body>
</soap:Envelope>''';
    }

    if (requestBody.contains('TP_WMD_UCD')) {
      return '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <TP_WMD_UCD_Response xmlns="https://turkpos.com.tr/">
      <TP_WMD_UCD_Result>
        <Sonuc>1</Sonuc>
        <Sonuc_Str>Başarılı</Sonuc_Str>
        <UCD_URL>https://3dsecure.param.com.tr/</UCD_URL>
        <UCD_MD>MOCK_MD_123</UCD_MD>
        <Islem_GUID>MOCK_GUID_123</Islem_GUID>
      </TP_WMD_UCD_Result>
    </TP_WMD_UCD_Response>
  </soap:Body>
</soap:Envelope>''';
    }

    // Default: payment
    return '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <TP_WMD_PayResponse xmlns="https://turkpos.com.tr/">
      <TP_WMD_PayResult>
        <Sonuc>1</Sonuc>
        <Sonuc_Str>Başarılı</Sonuc_Str>
        <Dekont_ID>MOCK_DEKONT_123</Dekont_ID>
        <Tahsilat_Tutari>100.00</Tahsilat_Tutari>
        <Siparis_ID>ORDER_123</Siparis_ID>
        <Islem_ID>TX123</Islem_ID>
      </TP_WMD_PayResult>
    </TP_WMD_PayResponse>
  </soap:Body>
</soap:Envelope>''';
  }

  static String _paramFailureResponse() => '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <TP_WMD_PayResponse xmlns="https://turkpos.com.tr/">
      <TP_WMD_PayResult>
        <Sonuc>0</Sonuc>
        <Sonuc_Str>Yetersiz Bakiye</Sonuc_Str>
        <Banka_Sonuc_Kod>51</Banka_Sonuc_Kod>
      </TP_WMD_PayResult>
    </TP_WMD_PayResponse>
  </soap:Body>
</soap:Envelope>''';

  // ============================================
  // SIPAY MOCK CLIENT
  // ============================================

  /// Sipay API için mock client oluşturur
  static MockClient sipay({
    bool shouldSucceed = true,
    Map<String, dynamic>? customResponse,
    int statusCode = 200,
  }) => MockClient((request) async {
    final path = request.url.path;

    Map<String, dynamic> response;

    if (customResponse != null) {
      response = customResponse;
    } else if (path.contains('token')) {
      // Token endpoint always succeeds
      response = {
        'status_code': 100,
        'data': {'token': 'MOCK_BEARER_TOKEN_123'},
      };
    } else if (shouldSucceed) {
      response = _sipaySuccessResponse(path);
    } else {
      response = _sipayFailureResponse();
    }

    return http.Response(
      jsonEncode(response),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });

  static Map<String, dynamic> _sipaySuccessResponse(String path) {
    if (path.contains('installment')) {
      return {
        'status_code': 100,
        'installments': [
          {'installment_number': 1, 'total_amount': 100.0},
          {'installment_number': 3, 'total_amount': 103.0},
        ],
      };
    }

    if (path.contains('refund')) {
      return {'status_code': 100, 'refund_id': 'REF_MOCK_123', 'amount': 50.0};
    }

    if (path.contains('paySmart3D') || path.contains('payment')) {
      if (path.contains('3D') || path.contains('3d')) {
        return {
          'status_code': 100,
          'redirect_url': 'https://3dsecure.sipay.com.tr/mock',
          'order_id': 'MOCK_ORDER_123',
        };
      }
    }

    // Default: payment
    return {
      'status_code': 100,
      'order_id': 'MOCK_ORDER_123',
      'transaction_id': 'MOCK_TX_123',
      'amount': 100.0,
      'total': 100.0,
    };
  }

  static Map<String, dynamic> _sipayFailureResponse() => {
    'status_code': 0,
    'status_description': 'Yetersiz bakiye',
    'error_code': 'insufficient_balance',
  };

  // ============================================
  // GENERIC HELPERS
  // ============================================

  /// Her zaman hata dönen mock client oluşturur
  static MockClient alwaysFails({
    int statusCode = 500,
    String body = 'Internal Server Error',
  }) => MockClient((request) async => http.Response(body, statusCode));

  /// Network timeout simüle eden mock client oluşturur
  static MockClient timeout({Duration delay = const Duration(seconds: 35)}) =>
      MockClient((request) async {
        await Future.delayed(delay);
        throw Exception('Connection timeout');
      });

  /// Özel response dönen mock client oluşturur
  static MockClient custom(
    Future<http.Response> Function(http.Request request) handler,
  ) => MockClient(handler);
}
