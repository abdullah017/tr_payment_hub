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
  // PAYTR_MERCHANT_ID, PAYTR_API_KEY, PAYTR_SECRET_KEY
  group('iyzico Integration Tests', () {
    late IyzicoProvider provider;
    late IyzicoConfig config;

    setUpAll(() async {
      final merchantId = Platform.environment['IYZICO_MERCHANT_ID'];
      final apiKey = Platform.environment['IYZICO_API_KEY'];
      final secretKey = Platform.environment['IYZICO_SECRET_KEY'];

      if (merchantId == null || apiKey == null || secretKey == null) {
        throw Exception(
          'Integration tests require IYZICO_MERCHANT_ID, IYZICO_API_KEY, '
          'and IYZICO_SECRET_KEY environment variables',
        );
      }

      config = IyzicoConfig(
        merchantId: merchantId,
        apiKey: apiKey,
        secretKey: secretKey,
        isSandbox: true,
      );

      provider = IyzicoProvider();
      await provider.initialize(config);
    });

    tearDownAll(() {
      provider.dispose();
    });

    test('should query installments for BIN 552879', () async {
      final installments = await provider.getInstallments(
        binNumber: '552879',
        amount: 100.0,
      );

      expect(installments.binNumber, '552879');
    });

    test('should create successful payment', () async {
      final request = _createIyzicoRequest();
      final result = await provider.createPayment(request);

      expect(result.isSuccess, true);
      expect(result.transactionId, isNotEmpty);
    });

    test('should handle insufficient funds', () async {
      final request = _createIyzicoRequestWithCard(
        cardNumber: '4543590000000006', // Yetersiz bakiye kartı
      );

      expect(
        () => provider.createPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should init 3DS payment', () async {
      final request = _createIyzicoRequest().copyWith(
        callbackUrl: 'https://example.com/callback',
      );
      final result = await provider.init3DSPayment(request);

      expect(result.status, ThreeDSStatus.pending);
      expect(result.htmlContent, isNotNull);
    });
  });

  // ============================================
  // PayTR Integration Tests
  // ============================================
  group('PayTR Integration Tests', skip: 'PayTR hesabı askıya alındı', () {
    late PayTRProvider provider;
    late PayTRConfig config;

    setUpAll(() async {
      final merchantId = Platform.environment['PAYTR_MERCHANT_ID'];
      final apiKey = Platform.environment['PAYTR_API_KEY'];
      final secretKey = Platform.environment['PAYTR_SECRET_KEY'];

      if (merchantId == null || apiKey == null || secretKey == null) {
        throw Exception(
          'Integration tests require PAYTR_MERCHANT_ID, PAYTR_API_KEY, '
          'and PAYTR_SECRET_KEY environment variables',
        );
      }

      config = PayTRConfig(
        merchantId: merchantId,
        apiKey: apiKey,
        secretKey: secretKey,
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
        isSandbox: true,
      );

      provider = PayTRProvider();
      await provider.initialize(config);
    });

    tearDownAll(() {
      provider.dispose();
    });

    test('should get iframe token', () async {
      final request = _createPayTRRequest();
      final result = await provider.init3DSPayment(request);

      expect(result.redirectUrl, isNotNull);
    });
  });
}

PaymentRequest _createIyzicoRequest() {
  return PaymentRequest(
    orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
    amount: 1.0,
    currency: Currency.tryLira,
    installment: 1,
    card: CardInfo(
      cardHolderName: 'John Doe',
      cardNumber: '5528790000000008',
      expireMonth: '12',
      expireYear: '2030',
      cvc: '123',
    ),
    buyer: BuyerInfo(
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
    shippingAddress: AddressInfo(
      contactName: 'John Doe',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Address No:1',
    ),
    billingAddress: AddressInfo(
      contactName: 'John Doe',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Address No:1',
    ),
    basketItems: [
      BasketItem(
        id: 'ITEM_1',
        name: 'Test Product',
        category: 'Test',
        price: 1.0,
        itemType: ItemType.physical,
      ),
    ],
  );
}

PaymentRequest _createIyzicoRequestWithCard({required String cardNumber}) {
  return PaymentRequest(
    orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
    amount: 1.0,
    currency: Currency.tryLira,
    installment: 1,
    card: CardInfo(
      cardHolderName: 'John Doe',
      cardNumber: cardNumber,
      expireMonth: '12',
      expireYear: '2030',
      cvc: '123',
    ),
    buyer: BuyerInfo(
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
    shippingAddress: AddressInfo(
      contactName: 'John Doe',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Address No:1',
    ),
    billingAddress: AddressInfo(
      contactName: 'John Doe',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Address No:1',
    ),
    basketItems: [
      BasketItem(
        id: 'ITEM_1',
        name: 'Test Product',
        category: 'Test',
        price: 1.0,
        itemType: ItemType.physical,
      ),
    ],
  );
}

PaymentRequest _createPayTRRequest() {
  return PaymentRequest(
    orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
    amount: 1.0,
    currency: Currency.tryLira,
    installment: 1,
    card: CardInfo(
      cardHolderName: 'Test User',
      cardNumber: '4355084355084358',
      expireMonth: '12',
      expireYear: '30',
      cvc: '000',
    ),
    buyer: BuyerInfo(
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
    basketItems: [
      BasketItem(
        id: 'ITEM_1',
        name: 'Test Product',
        category: 'Test',
        price: 1.0,
        itemType: ItemType.physical,
      ),
    ],
  );
}
