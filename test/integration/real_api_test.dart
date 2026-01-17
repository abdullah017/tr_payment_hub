@Tags(['integration'])
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  // ============================================
  // iyzico Integration Tests
  // ============================================
  // API keys must be provided via environment variables:
  // IYZICO_MERCHANT_ID, IYZICO_API_KEY, IYZICO_SECRET_KEY
  group('iyzico Integration Tests', () {
    IyzicoProvider? provider;
    IyzicoConfig? config;
    var isConfigured = false;

    setUpAll(() async {
      final merchantId = Platform.environment['IYZICO_MERCHANT_ID'];
      final apiKey = Platform.environment['IYZICO_API_KEY'];
      final secretKey = Platform.environment['IYZICO_SECRET_KEY'];

      if (merchantId == null || apiKey == null || secretKey == null) {
        print(
          'SKIP: iyzico integration tests require IYZICO_MERCHANT_ID, '
          'IYZICO_API_KEY, and IYZICO_SECRET_KEY environment variables',
        );
        return;
      }

      config = IyzicoConfig(
        merchantId: merchantId,
        apiKey: apiKey,
        secretKey: secretKey,
      );

      provider = IyzicoProvider();
      await provider!.initialize(config!);
      isConfigured = true;
    });

    tearDownAll(() {
      provider?.dispose();
    });

    test('should query installments for BIN 552879', () async {
      if (!isConfigured) {
        markTestSkipped('iyzico credentials not configured');
        return;
      }

      final installments = await provider!.getInstallments(
        binNumber: '552879',
        amount: 100,
      );

      expect(installments.binNumber, '552879');
    });

    test('should create successful payment', () async {
      if (!isConfigured) {
        markTestSkipped('iyzico credentials not configured');
        return;
      }

      final request = _createIyzicoRequest();
      final result = await provider!.createPayment(request);

      expect(result.isSuccess, true);
      expect(result.transactionId, isNotEmpty);
    });

    test('should handle insufficient funds', () async {
      if (!isConfigured) {
        markTestSkipped('iyzico credentials not configured');
        return;
      }

      final request = _createIyzicoRequestWithCard(
        cardNumber: '4543590000000006', // Yetersiz bakiye kartı
      );

      expect(
        () => provider!.createPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should init 3DS payment', () async {
      if (!isConfigured) {
        markTestSkipped('iyzico credentials not configured');
        return;
      }

      final request = _createIyzicoRequest().copyWith(
        callbackUrl: 'https://example.com/callback',
      );
      final result = await provider!.init3DSPayment(request);

      expect(result.status, ThreeDSStatus.pending);
      expect(result.htmlContent, isNotNull);
    });

    test('should support capability checks', () async {
      if (!isConfigured) {
        markTestSkipped('iyzico credentials not configured');
        return;
      }

      expect(provider!.supportsSavedCards, isTrue);
      expect(provider!.supportsInstallments, isTrue);
      expect(provider is PaymentSavedCards, isTrue);
      expect(provider is PaymentInstallments, isTrue);
    });
  });

  // ============================================
  // PayTR Integration Tests
  // ============================================
  group('PayTR Integration Tests', () {
    PayTRProvider? provider;
    PayTRConfig? config;
    var isConfigured = false;

    setUpAll(() async {
      final merchantId = Platform.environment['PAYTR_MERCHANT_ID'];
      final apiKey = Platform.environment['PAYTR_API_KEY'];
      final secretKey = Platform.environment['PAYTR_SECRET_KEY'];

      if (merchantId == null || apiKey == null || secretKey == null) {
        print(
          'SKIP: PayTR integration tests require PAYTR_MERCHANT_ID, '
          'PAYTR_API_KEY, and PAYTR_SECRET_KEY environment variables',
        );
        return;
      }

      config = PayTRConfig(
        merchantId: merchantId,
        apiKey: apiKey,
        secretKey: secretKey,
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
      );

      provider = PayTRProvider();
      await provider!.initialize(config!);
      isConfigured = true;
    });

    tearDownAll(() {
      provider?.dispose();
    });

    test('should get iframe token', () async {
      if (!isConfigured) {
        markTestSkipped('PayTR credentials not configured');
        return;
      }

      final request = _createPayTRRequest();
      final result = await provider!.init3DSPayment(request);

      expect(result.redirectUrl, isNotNull);
    });

    test('should query installments', () async {
      if (!isConfigured) {
        markTestSkipped('PayTR credentials not configured');
        return;
      }

      final installments = await provider!.getInstallments(
        binNumber: '435508',
        amount: 100,
      );

      expect(installments.binNumber, '435508');
    });

    test('should NOT support saved cards (iframe only)', () async {
      if (!isConfigured) {
        markTestSkipped('PayTR credentials not configured');
        return;
      }

      // PayTR uses iframe-based checkout, saved cards not supported
      expect(provider!.supportsSavedCards, isTrue); // implements interface
      expect(
        () => provider!.getSavedCards('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ============================================
  // Sipay Integration Tests
  // ============================================
  group('Sipay Integration Tests', () {
    SipayProvider? provider;
    SipayConfig? config;
    var isConfigured = false;

    setUpAll(() async {
      final merchantId = Platform.environment['SIPAY_MERCHANT_ID'];
      final apiKey = Platform.environment['SIPAY_API_KEY'];
      final secretKey = Platform.environment['SIPAY_SECRET_KEY'];
      final merchantKey = Platform.environment['SIPAY_MERCHANT_KEY'];

      if (merchantId == null ||
          apiKey == null ||
          secretKey == null ||
          merchantKey == null) {
        print(
          'SKIP: Sipay integration tests require SIPAY_MERCHANT_ID, '
          'SIPAY_API_KEY, SIPAY_SECRET_KEY, and SIPAY_MERCHANT_KEY environment variables',
        );
        return;
      }

      config = SipayConfig(
        merchantId: merchantId,
        apiKey: apiKey,
        secretKey: secretKey,
        merchantKey: merchantKey,
      );

      provider = SipayProvider();
      await provider!.initialize(config!);
      isConfigured = true;
    });

    tearDownAll(() {
      provider?.dispose();
    });

    test('should query installments', () async {
      if (!isConfigured) {
        markTestSkipped('Sipay credentials not configured');
        return;
      }

      final installments = await provider!.getInstallments(
        binNumber: '552879',
        amount: 100,
      );

      expect(installments.binNumber, '552879');
    });

    test('should create 3DS payment', () async {
      if (!isConfigured) {
        markTestSkipped('Sipay credentials not configured');
        return;
      }

      final request = _createSipayRequest();
      final result = await provider!.init3DSPayment(request);

      expect(result.status, ThreeDSStatus.pending);
      expect(result.htmlContent, isNotNull);
    });

    test('should support saved cards', () async {
      if (!isConfigured) {
        markTestSkipped('Sipay credentials not configured');
        return;
      }

      expect(provider!.supportsSavedCards, isTrue);
      expect(provider is PaymentSavedCards, isTrue);
    });
  });

  // ============================================
  // Param Integration Tests
  // ============================================
  group('Param Integration Tests', () {
    ParamProvider? provider;
    ParamConfig? config;
    var isConfigured = false;

    setUpAll(() async {
      final merchantId = Platform.environment['PARAM_MERCHANT_ID'];
      final apiKey = Platform.environment['PARAM_API_KEY'];
      final secretKey = Platform.environment['PARAM_SECRET_KEY'];
      final guid = Platform.environment['PARAM_GUID'];

      if (merchantId == null ||
          apiKey == null ||
          secretKey == null ||
          guid == null) {
        print(
          'SKIP: Param integration tests require PARAM_MERCHANT_ID, '
          'PARAM_API_KEY, PARAM_SECRET_KEY, and PARAM_GUID '
          'environment variables',
        );
        return;
      }

      config = ParamConfig(
        merchantId: merchantId,
        apiKey: apiKey,
        secretKey: secretKey,
        guid: guid,
      );

      provider = ParamProvider();
      await provider!.initialize(config!);
      isConfigured = true;
    });

    tearDownAll(() {
      provider?.dispose();
    });

    test('should query installments', () async {
      if (!isConfigured) {
        markTestSkipped('Param credentials not configured');
        return;
      }

      final installments = await provider!.getInstallments(
        binNumber: '552879',
        amount: 100,
      );

      expect(installments.binNumber, '552879');
    });

    test('should create 3DS payment', () async {
      if (!isConfigured) {
        markTestSkipped('Param credentials not configured');
        return;
      }

      final request = _createParamRequest();
      final result = await provider!.init3DSPayment(request);

      expect(result.status, ThreeDSStatus.pending);
      expect(result.htmlContent, isNotNull);
    });

    test('should NOT support saved cards', () async {
      if (!isConfigured) {
        markTestSkipped('Param credentials not configured');
        return;
      }

      // Param doesn't support saved cards
      expect(
        () => provider!.getSavedCards('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

// ============================================
// Request Builders
// ============================================

PaymentRequest _createIyzicoRequest() => PaymentRequest(
      orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      amount: 1,
      card: const CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      ),
      buyer: const BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '+905551234567',
        identityNumber: '11111111111',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
        zipCode: '34000',
      ),
      shippingAddress: const AddressInfo(
        contactName: 'John Doe',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      billingAddress: const AddressInfo(
        contactName: 'John Doe',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      basketItems: const [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'Test',
          price: 1,
          itemType: ItemType.physical,
        ),
      ],
    );

PaymentRequest _createIyzicoRequestWithCard({required String cardNumber}) =>
    PaymentRequest(
      orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      amount: 1,
      card: CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: cardNumber,
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      ),
      buyer: const BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '+905551234567',
        identityNumber: '11111111111',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
        zipCode: '34000',
      ),
      shippingAddress: const AddressInfo(
        contactName: 'John Doe',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      billingAddress: const AddressInfo(
        contactName: 'John Doe',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      basketItems: const [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'Test',
          price: 1,
          itemType: ItemType.physical,
        ),
      ],
    );

PaymentRequest _createPayTRRequest() => PaymentRequest(
      orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      amount: 1,
      card: const CardInfo(
        cardHolderName: 'Test User',
        cardNumber: '4355084355084358',
        expireMonth: '12',
        expireYear: '30',
        cvc: '000',
      ),
      buyer: const BuyerInfo(
        id: 'BUYER_1',
        name: 'Test',
        surname: 'User',
        email: 'test@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      basketItems: const [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'Test',
          price: 1,
          itemType: ItemType.physical,
        ),
      ],
    );

PaymentRequest _createSipayRequest() => PaymentRequest(
      orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      amount: 1,
      card: const CardInfo(
        cardHolderName: 'Test User',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      ),
      buyer: const BuyerInfo(
        id: 'BUYER_1',
        name: 'Test',
        surname: 'User',
        email: 'test@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      basketItems: const [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'Test',
          price: 1,
          itemType: ItemType.physical,
        ),
      ],
    );

PaymentRequest _createParamRequest() => PaymentRequest(
      orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      amount: 1,
      card: const CardInfo(
        cardHolderName: 'Test User',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      ),
      buyer: const BuyerInfo(
        id: 'BUYER_1',
        name: 'Test',
        surname: 'User',
        email: 'test@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      basketItems: const [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'Test',
          price: 1,
          itemType: ItemType.physical,
        ),
      ],
    );
