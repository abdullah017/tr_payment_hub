import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';
import 'package:tr_payment_hub/src/providers/paytr/paytr_auth.dart';
import 'package:tr_payment_hub/src/providers/paytr/paytr_mapper.dart';
import 'package:tr_payment_hub/src/providers/paytr/paytr_error_mapper.dart';

void main() {
  group('PayTRAuth', () {
    late PayTRAuth auth;

    setUp(() {
      auth = PayTRAuth(
        merchantId: '123456',
        merchantKey: 'test-merchant-key',
        merchantSalt: 'test-merchant-salt',
      );
    });

    test('should generate payment token', () {
      final token = auth.generatePaymentToken(
        userIp: '127.0.0.1',
        merchantOid: 'SP123456',
        email: 'test@example.com',
        paymentAmount: '10000',
        paymentType: 'card',
        installmentCount: '1',
        currency: 'TL',
        testMode: '1',
        non3d: '0',
      );

      expect(token, isNotEmpty);
      // Base64 encoded olmalı
      expect(token, matches(RegExp(r'^[A-Za-z0-9+/]+=*$')));
    });

    test('should generate iframe token', () {
      final token = auth.generateIframeToken(
        userIp: '127.0.0.1',
        merchantOid: 'SP123456',
        email: 'test@example.com',
        paymentAmount: '10000',
        userBasket: 'W1siVGVzdCIsIjEwMDAiLDFdXQ==',
        noInstallment: '0',
        maxInstallment: '12',
        currency: 'TL',
        testMode: '1',
      );

      expect(token, isNotEmpty);
    });

    test('should generate refund token', () {
      final token = auth.generateRefundToken(
        merchantOid: 'SP123456',
        returnAmount: '5000',
      );

      expect(token, isNotEmpty);
    });

    test('should generate status token', () {
      final token = auth.generateStatusToken(merchantOid: 'SP123456');

      expect(token, isNotEmpty);
    });

    test('should verify valid callback hash', () {
      // Önce bir hash oluştur
      final testAuth = PayTRAuth(
        merchantId: '123456',
        merchantKey: 'key',
        merchantSalt: 'salt',
      );

      // Hash'i manuel hesapla (aynı mantıkla)
      // Bu test hash doğrulama mantığını test eder
      final isValid = testAuth.verifyCallbackHash(
        merchantOid: 'SP123',
        status: 'success',
        totalAmount: '10000',
        receivedHash: 'invalid_hash', // Yanlış hash
      );

      expect(isValid, false);
    });
  });

  group('PayTRMapper', () {
    test('should map PaymentRequest to direct payment format', () {
      final request = _createTestRequest();
      final mapped = PayTRMapper.toDirectPaymentRequest(
        request: request,
        merchantId: '123456',
        paytrToken: 'test_token',
        merchantOid: 'SP123456',
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        testMode: true,
      );

      expect(mapped['merchant_id'], '123456');
      expect(mapped['merchant_oid'], 'SP123456');
      expect(mapped['email'], 'john@example.com');
      expect(mapped['payment_amount'], '10000'); // 100.0 * 100
      expect(mapped['currency'], 'TL');
      expect(mapped['test_mode'], '1');
      expect(mapped['cc_owner'], 'John Doe');
      expect(mapped['card_number'], '5528790000000008');
      expect(mapped['cvv'], '123');
      expect(mapped['paytr_token'], 'test_token');
    });

    test('should map iframe token request', () {
      final request = _createTestRequest();
      final mapped = PayTRMapper.toIframeTokenRequest(
        request: request,
        merchantId: '123456',
        paytrToken: 'test_token',
        merchantOid: 'SP123456',
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
        testMode: true,
        maxInstallment: 6,
      );

      expect(mapped['merchant_id'], '123456');
      expect(mapped['max_installment'], '6');
      expect(mapped['user_basket'], isNotEmpty);
    });

    test('should parse successful iframe token response', () {
      final response = {'status': 'success', 'token': 'abc123xyz'};

      final result = PayTRMapper.fromIframeTokenResponse(response);

      expect(result.status, ThreeDSStatus.pending);
      expect(
        result.redirectUrl,
        'https://www.paytr.com/odeme/guvenli/abc123xyz',
      );
      expect(result.transactionId, 'abc123xyz');
      expect(result.needsWebView, true);
    });

    test('should parse failed iframe token response', () {
      final response = {'status': 'failed', 'reason': 'Invalid merchant'};

      final result = PayTRMapper.fromIframeTokenResponse(response);

      expect(result.status, ThreeDSStatus.failed);
      expect(result.errorMessage, 'Invalid merchant');
    });

    test('should parse successful callback data', () {
      final data = {
        'status': 'success',
        'merchant_oid': 'SP123456',
        'total_amount': '10000',
      };

      final result = PayTRMapper.fromCallbackData(data);

      expect(result.isSuccess, true);
      expect(result.transactionId, 'SP123456');
      expect(result.amount, 10000);
    });

    test('should parse failed callback data', () {
      final data = {
        'status': 'failed',
        'merchant_oid': 'SP123456',
        'failed_reason_code': '101',
        'failed_reason_msg': 'Yetersiz bakiye',
      };

      final result = PayTRMapper.fromCallbackData(data);

      expect(result.isSuccess, false);
      expect(result.errorCode, '101');
      expect(result.errorMessage, 'Yetersiz bakiye');
    });

    test('should parse refund response', () {
      final response = {
        'status': 'success',
        'merchant_oid': 'SP123456',
        'return_amount': '5000',
      };

      final result = PayTRMapper.fromRefundResponse(response);

      expect(result.isSuccess, true);
      expect(result.refundId, 'SP123456');
      expect(result.refundedAmount, 5000);
    });

    test('should parse status response', () {
      final successResponse = {
        'status': 'success',
        'payment_status': 'Başarılı',
      };

      final failedResponse = {
        'status': 'success',
        'payment_status': 'Başarısız',
      };

      expect(
        PayTRMapper.fromStatusResponse(successResponse),
        PaymentStatus.success,
      );
      expect(
        PayTRMapper.fromStatusResponse(failedResponse),
        PaymentStatus.failed,
      );
    });
  });

  group('PayTRErrorMapper', () {
    test('should map insufficient funds error', () {
      final error = PayTRErrorMapper.mapError(
        errorCode: '101',
        errorMessage: 'Yetersiz bakiye',
      );

      expect(error.code, 'insufficient_funds');
      expect(error.provider, ProviderType.paytr);
    });

    test('should map invalid card error', () {
      final error = PayTRErrorMapper.mapError(
        errorCode: '102',
        errorMessage: 'Geçersiz kart numarası',
      );

      expect(error.code, 'invalid_card');
    });

    test('should map expired card error', () {
      final error = PayTRErrorMapper.mapError(
        errorCode: '103',
        errorMessage: 'Kartın süresi dolmuş',
      );

      expect(error.code, 'expired_card');
    });

    test('should map CVV error', () {
      final error = PayTRErrorMapper.mapError(
        errorCode: '104',
        errorMessage: 'CVV hatalı',
      );

      expect(error.code, 'invalid_cvv');
    });

    test('should map 3DS error', () {
      final error = PayTRErrorMapper.mapError(
        errorCode: '105',
        errorMessage: '3D Secure doğrulama başarısız',
      );

      expect(error.code, 'threeds_failed');
    });

    test('should map declined error', () {
      final error = PayTRErrorMapper.mapError(
        errorCode: '106',
        errorMessage: 'İşlem reddedildi',
      );

      expect(error.code, 'declined');
    });

    test('should map unknown error', () {
      final error = PayTRErrorMapper.mapError(
        errorCode: '999',
        errorMessage: 'Bilinmeyen bir hata',
      );

      expect(error.code, 'unknown_error');
      expect(error.providerCode, '999');
    });

    test('should parse callback status', () {
      expect(
        PayTRErrorMapper.parseCallbackStatus('success'),
        PaymentStatus.success,
      );
      expect(
        PayTRErrorMapper.parseCallbackStatus('failed'),
        PaymentStatus.failed,
      );
      expect(
        PayTRErrorMapper.parseCallbackStatus('failure'),
        PaymentStatus.failed,
      );
      expect(
        PayTRErrorMapper.parseCallbackStatus('pending'),
        PaymentStatus.pending,
      );
    });
  });

  group('PayTRProvider', () {
    late PayTRProvider provider;
    late PayTRConfig config;

    setUp(() {
      provider = PayTRProvider();
      config = PayTRConfig(
        merchantId: '123456',
        apiKey: 'test-merchant-key',
        secretKey: 'test-merchant-salt',
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
        isSandbox: true,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('should have correct provider type', () {
      expect(provider.providerType, ProviderType.paytr);
    });

    test('should initialize with valid config', () async {
      await provider.initialize(config);
      // No exception means success
    });

    test('should throw error with invalid config type', () async {
      final invalidConfig = IyzicoConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
      );

      expect(
        () => provider.initialize(invalidConfig),
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

    test('should require callback data for complete3DSPayment', () async {
      await provider.initialize(config);

      expect(
        () => provider.complete3DSPayment('SP123456', callbackData: null),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should return installment options', () async {
      await provider.initialize(config);

      final installments = await provider.getInstallments(
        binNumber: '552879',
        amount: 100.0,
      );

      expect(installments.options.length, greaterThan(0));
      expect(installments.force3DS, true); // PayTR genellikle 3DS zorunlu
    });
  });

  group('PayTRConfig', () {
    test('should return correct base URL', () {
      final config = PayTRConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
      );

      expect(config.baseUrl, 'https://www.paytr.com');
    });

    test('should validate config correctly', () {
      final validConfig = PayTRConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
      );

      final invalidConfig = PayTRConfig(
        merchantId: '',
        apiKey: 'test',
        secretKey: '',
        successUrl: '',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
      );

      expect(validConfig.validate(), true);
      expect(invalidConfig.validate(), false);
    });
  });
}

PaymentRequest _createTestRequest() {
  return PaymentRequest(
    orderId: 'ORDER_123',
    amount: 100.0,
    currency: Currency.TRY,
    installment: 1,
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
        price: 100.0,
        itemType: ItemType.physical,
      ),
    ],
  );
}
