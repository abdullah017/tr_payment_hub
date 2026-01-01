import 'package:test/test.dart';
import 'package:tr_payment_hub/src/providers/param/param_auth.dart';
import 'package:tr_payment_hub/src/providers/param/param_error_mapper.dart';
import 'package:tr_payment_hub/src/providers/param/param_mapper.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('ParamAuth', () {
    late ParamAuth auth;

    setUp(() {
      auth = ParamAuth(
        clientCode: 'TEST_CLIENT',
        clientUsername: 'test_user',
        clientPassword: 'test_pass',
        guid: 'TEST-GUID-123',
      );
    });

    test('should generate payment hash', () {
      final hash = auth.generatePaymentHash(
        amount: '10000',
        orderId: 'ORDER123',
      );

      expect(hash, isNotEmpty);
      expect(hash, isA<String>());
      // SHA1 hash 40 karakter uzunluğunda olmalı (uppercase)
      expect(hash.length, 40);
      expect(hash, matches(RegExp(r'^[A-F0-9]+$')));
    });

    test('should generate refund hash', () {
      final hash = auth.generateRefundHash(orderId: 'ORDER123');

      expect(hash, isNotEmpty);
      expect(hash.length, 40);
    });

    test('should generate query hash', () {
      final hash = auth.generateQueryHash(orderId: 'ORDER123');

      expect(hash, isNotEmpty);
      expect(hash.length, 40);
    });

    test('should generate different hashes for different inputs', () {
      final hash1 = auth.generatePaymentHash(amount: '10000', orderId: 'A');
      final hash2 = auth.generatePaymentHash(amount: '10000', orderId: 'B');

      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('ParamMapper', () {
    test('should create SOAP envelope wrapper', () {
      const body = '<test>content</test>';
      final envelope = ParamMapper.wrapSoapEnvelope(body);

      expect(envelope, contains('<?xml version="1.0"'));
      expect(envelope, contains('soap:Envelope'));
      expect(envelope, contains('soap:Body'));
      expect(envelope, contains(body));
    });

    test('should create payment request XML', () {
      final request = _createTestRequest();
      final xml = ParamMapper.toPaymentRequest(
        request: request,
        clientCode: 'CLIENT123',
        clientUsername: 'user',
        clientPassword: 'pass',
        guid: 'GUID123',
        hash: 'HASH123',
        orderId: 'ORDER123',
      );

      expect(xml, contains('<CLIENT_CODE>CLIENT123</CLIENT_CODE>'));
      expect(xml, contains('<GUID>GUID123</GUID>'));
      expect(xml, contains('<KK_Sahibi>John Doe</KK_Sahibi>'));
      expect(xml, contains('<KK_No>5528790000000008</KK_No>'));
      expect(xml, contains('<Siparis_ID>ORDER123</Siparis_ID>'));
      expect(xml, contains('<Islem_Guvenlik_Tip>NS</Islem_Guvenlik_Tip>'));
    });

    test('should create 3DS init request XML', () {
      final request = _createTestRequest();
      final xml = ParamMapper.to3DSInitRequest(
        request: request,
        clientCode: 'CLIENT123',
        clientUsername: 'user',
        clientPassword: 'pass',
        guid: 'GUID123',
        hash: 'HASH123',
        orderId: 'ORDER123',
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
      );

      expect(xml, contains('<Islem_Guvenlik_Tip>3D</Islem_Guvenlik_Tip>'));
      expect(xml, contains('<Basarili_URL>https://example.com/success'));
      expect(xml, contains('<Hata_URL>https://example.com/fail'));
    });

    test('should create refund request XML', () {
      final xml = ParamMapper.toRefundRequest(
        transactionId: 'TX123',
        amount: 50,
        clientCode: 'CLIENT123',
        clientUsername: 'user',
        clientPassword: 'pass',
        guid: 'GUID123',
        hash: 'HASH123',
      );

      expect(xml, contains('<Siparis_ID>TX123</Siparis_ID>'));
      expect(xml, contains('<Durum>IADE</Durum>'));
      expect(xml, contains('<Tutar>5000</Tutar>')); // 50.0 * 100 = 5000
    });

    test('should create status request XML', () {
      final xml = ParamMapper.toStatusRequest(
        transactionId: 'TX123',
        clientCode: 'CLIENT123',
        clientUsername: 'user',
        clientPassword: 'pass',
        guid: 'GUID123',
      );

      expect(xml, contains('<Siparis_ID>TX123</Siparis_ID>'));
      expect(xml, contains('TP_Islem_Sorgulama'));
    });

    test('should parse successful payment response', () {
      const xmlResponse = '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Response>
      <Sonuc>1</Sonuc>
      <Sonuc_Str>Islem Basarili</Sonuc_Str>
      <Dekont_ID>DK123456</Dekont_ID>
      <Islem_Tutar>10000</Islem_Tutar>
      <Toplam_Tutar>10000</Toplam_Tutar>
    </Response>
  </soap:Body>
</soap:Envelope>
''';

      final result = ParamMapper.fromPaymentResponse(xmlResponse);

      expect(result.isSuccess, true);
      expect(result.transactionId, 'DK123456');
      expect(result.amount, 100.0); // 10000 / 100 = 100
    });

    test('should parse failed payment response', () {
      const xmlResponse = '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Response>
      <Sonuc>0</Sonuc>
      <Sonuc_Str>Yetersiz Bakiye</Sonuc_Str>
    </Response>
  </soap:Body>
</soap:Envelope>
''';

      final result = ParamMapper.fromPaymentResponse(xmlResponse);

      expect(result.isSuccess, false);
      expect(result.errorMessage, 'Yetersiz Bakiye');
    });

    test('should parse 3DS init response with HTML', () {
      const xmlResponse = '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Response>
      <Sonuc>1</Sonuc>
      <UCD_HTML><![CDATA[<html><body>3DS Page</body></html>]]></UCD_HTML>
      <Islem_ID>TX123</Islem_ID>
    </Response>
  </soap:Body>
</soap:Envelope>
''';

      final result = ParamMapper.from3DSInitResponse(xmlResponse);

      expect(result.status, ThreeDSStatus.pending);
      expect(result.htmlContent, contains('3DS Page'));
      expect(result.transactionId, 'TX123');
    });

    test('should parse refund response', () {
      const xmlResponse = '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Response>
      <Sonuc>1</Sonuc>
      <Dekont_ID>REF123</Dekont_ID>
      <Tutar>5000</Tutar>
    </Response>
  </soap:Body>
</soap:Envelope>
''';

      final result = ParamMapper.fromRefundResponse(xmlResponse);

      expect(result.isSuccess, true);
      expect(result.refundId, 'REF123');
      expect(result.refundedAmount, 50.0); // 5000 / 100 = 50
    });

    test('should parse status response', () {
      const successXml = '''
<Response><Islem_Durum>BASARILI</Islem_Durum></Response>
''';
      const failedXml = '''
<Response><Islem_Durum>BASARISIZ</Islem_Durum></Response>
''';
      const pendingXml = '''
<Response><Islem_Durum>BEKLEMEDE</Islem_Durum></Response>
''';

      expect(ParamMapper.fromStatusResponse(successXml), PaymentStatus.success);
      expect(ParamMapper.fromStatusResponse(failedXml), PaymentStatus.failed);
      expect(ParamMapper.fromStatusResponse(pendingXml), PaymentStatus.pending);
    });
  });

  group('ParamErrorMapper', () {
    test('should map invalid card error', () {
      final error = ParamErrorMapper.mapError(
        errorCode: '1001',
        errorMessage: 'Geçersiz kart numarası',
      );

      expect(error.code, 'invalid_card');
      expect(error.provider, ProviderType.param);
    });

    test('should map expired card error', () {
      final error = ParamErrorMapper.mapError(
        errorCode: '1003',
        errorMessage: 'Kartın süresi dolmuş',
      );

      expect(error.code, 'expired_card');
    });

    test('should map insufficient funds error', () {
      final error = ParamErrorMapper.mapError(
        errorCode: '2001',
        errorMessage: 'Yetersiz bakiye',
      );

      expect(error.code, 'insufficient_funds');
    });

    test('should map declined error', () {
      final error = ParamErrorMapper.mapError(
        errorCode: '3001',
        errorMessage: 'İşlem reddedildi',
      );

      expect(error.code, 'declined');
    });

    test('should map 3DS failed error', () {
      final error = ParamErrorMapper.mapError(
        errorCode: '4001',
        errorMessage: '3D Secure doğrulama başarısız',
      );

      expect(error.code, 'threeds_failed');
    });

    test('should map unknown error', () {
      final error = ParamErrorMapper.mapError(
        errorCode: '9999',
        errorMessage: 'Bilinmeyen hata',
      );

      expect(error.code, 'param_error');
      expect(error.providerCode, '9999');
    });

    test('should check success status correctly', () {
      expect(ParamErrorMapper.isSuccess('1'), true);
      expect(ParamErrorMapper.isSuccess('00'), true);
      expect(ParamErrorMapper.isSuccess('0'), false); // 0 tek başına hata
      expect(ParamErrorMapper.isSuccess('2'), false);
      expect(ParamErrorMapper.isSuccess('error'), false);
      expect(ParamErrorMapper.isSuccess(null), false);
    });

    test('should parse card type', () {
      expect(ParamErrorMapper.parseCardType('credit'), CardType.creditCard);
      expect(ParamErrorMapper.parseCardType('kredi'), CardType.creditCard);
      expect(ParamErrorMapper.parseCardType('debit'), CardType.debitCard);
      expect(ParamErrorMapper.parseCardType('banka'), CardType.debitCard);
      expect(ParamErrorMapper.parseCardType(null), null);
    });

    test('should parse card association', () {
      expect(
        ParamErrorMapper.parseCardAssociation('VISA'),
        CardAssociation.visa,
      );
      expect(
        ParamErrorMapper.parseCardAssociation('MASTERCARD'),
        CardAssociation.masterCard,
      );
      expect(
        ParamErrorMapper.parseCardAssociation('AMEX'),
        CardAssociation.amex,
      );
      expect(
        ParamErrorMapper.parseCardAssociation('AMERICAN EXPRESS'),
        CardAssociation.amex,
      );
      expect(
        ParamErrorMapper.parseCardAssociation('TROY'),
        CardAssociation.troy,
      );
      expect(ParamErrorMapper.parseCardAssociation(null), null);
    });
  });

  group('ParamProvider', () {
    late ParamProvider provider;
    late ParamConfig config;

    setUp(() {
      provider = ParamProvider();
      config = const ParamConfig(
        merchantId: 'TEST_CLIENT',
        apiKey: 'test_user',
        secretKey: 'test_pass',
        guid: 'TEST-GUID-123',
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('should have correct provider type', () {
      expect(provider.providerType, ProviderType.param);
    });

    test('should initialize with valid config', () async {
      await provider.initialize(config);
      // No exception means success
    });

    test('should throw error with invalid config type', () async {
      const invalidConfig = IyzicoConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
      );

      expect(
        () => provider.initialize(invalidConfig),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should throw error with empty config', () async {
      const emptyConfig = ParamConfig(
        merchantId: '',
        apiKey: '',
        secretKey: '',
        guid: '',
      );

      expect(
        () => provider.initialize(emptyConfig),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should throw error when not initialized', () async {
      final request = _createTestRequest();

      expect(
        () => provider.createPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should require callback URL for 3DS payment', () async {
      await provider.initialize(config);
      final request = _createTestRequest();

      expect(
        () => provider.init3DSPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should require callback data for complete3DSPayment', () async {
      await provider.initialize(config);

      expect(
        () => provider.complete3DSPayment('TX123'),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should return default installment options', () async {
      await provider.initialize(config);

      final installments = await provider.getInstallments(
        binNumber: '552879',
        amount: 100,
      );

      expect(installments.options.length, greaterThan(0));
      expect(installments.force3DS, true);
    });

    test('should throw on chargeWithSavedCard (not supported)', () async {
      await provider.initialize(config);

      expect(
        () => provider.chargeWithSavedCard(
          cardToken: 'token',
          orderId: 'ORDER1',
          amount: 100,
          buyer: _createTestBuyer(),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw on getSavedCards (not supported)', () async {
      await provider.initialize(config);

      expect(
        () => provider.getSavedCards('user_key'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw on deleteSavedCard (not supported)', () async {
      await provider.initialize(config);

      expect(
        () => provider.deleteSavedCard(cardToken: 'token'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('ParamConfig', () {
    test('should return sandbox URL when isSandbox is true', () {
      const config = ParamConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        guid: 'test-guid',
      );

      expect(config.baseUrl, 'https://test-dmz.param.com.tr');
    });

    test('should return production URL when isSandbox is false', () {
      const config = ParamConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        guid: 'test-guid',
        isSandbox: false,
      );

      expect(config.baseUrl, 'https://dmz.param.com.tr');
    });

    test('should validate config correctly', () {
      const validConfig = ParamConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        guid: 'test-guid',
      );

      const invalidConfig = ParamConfig(
        merchantId: '',
        apiKey: 'test',
        secretKey: '',
        guid: '',
      );

      expect(validConfig.validate(), true);
      expect(invalidConfig.validate(), false);
    });
  });

  group('TrPaymentHub Factory', () {
    test('should create ParamProvider from factory', () {
      final provider = TrPaymentHub.create(ProviderType.param);

      expect(provider, isA<ParamProvider>());
      expect(provider.providerType, ProviderType.param);
    });
  });
}

PaymentRequest _createTestRequest() => const PaymentRequest(
      orderId: 'ORDER_123',
      amount: 100,
      card: CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      ),
      buyer: BuyerInfo(
        id: 'BUYER_123',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      ),
      basketItems: [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'Electronics',
          price: 100,
          itemType: ItemType.physical,
        ),
      ],
    );

BuyerInfo _createTestBuyer() => const BuyerInfo(
      id: 'BUYER_123',
      name: 'John',
      surname: 'Doe',
      email: 'john@example.com',
      phone: '+905551234567',
      ip: '127.0.0.1',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Address',
    );
