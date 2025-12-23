import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';
import 'package:tr_payment_hub/src/providers/iyzico/iyzico_auth.dart';
import 'package:tr_payment_hub/src/providers/iyzico/iyzico_mapper.dart';
import 'package:tr_payment_hub/src/providers/iyzico/iyzico_error_mapper.dart';

void main() {
  group('IyzicoAuth', () {
    late IyzicoAuth auth;

    setUp(() {
      auth = IyzicoAuth(
        apiKey: 'sandbox-test-api-key',
        secretKey: 'sandbox-test-secret-key',
      );
    });

    test('should generate authorization header', () {
      final body = '{"test": "data"}';
      final header = auth.generateAuthorizationHeader('/payment/auth', body);

      expect(header, startsWith('IYZWSv2 '));
      expect(header.length, greaterThan(20));
    });

    test('should generate different headers for different bodies', () {
      final header1 = auth.generateAuthorizationHeader('/payment/auth', '{"a": 1}');
      final header2 = auth.generateAuthorizationHeader('/payment/auth', '{"b": 2}');

      // Random key nedeniyle her zaman farklı olacak
      expect(header1, isNot(equals(header2)));
    });
  });

  group('IyzicoMapper', () {
    test('should map PaymentRequest to iyzico format', () {
      final request = _createTestRequest();
      final mapped = IyzicoMapper.toPaymentRequest(request, 'conv123');

      expect(mapped['conversationId'], 'conv123');
      expect(mapped['price'], '100.0');
      expect(mapped['paidPrice'], '100.0');
      expect(mapped['currency'], 'TRY');
      expect(mapped['installment'], 1);
      expect(mapped['basketId'], 'ORDER_123');

      // PaymentCard
      final card = mapped['paymentCard'] as Map<String, dynamic>;
      expect(card['cardHolderName'], 'John Doe');
      expect(card['cardNumber'], '5528790000000008');
      expect(card['expireMonth'], '12');
      expect(card['expireYear'], '2030');
      expect(card['cvc'], '123');

      // Buyer
      final buyer = mapped['buyer'] as Map<String, dynamic>;
      expect(buyer['name'], 'John');
      expect(buyer['surname'], 'Doe');
      expect(buyer['email'], 'john@example.com');

      // BasketItems
      final items = mapped['basketItems'] as List;
      expect(items.length, 1);
      expect((items[0] as Map)['name'], 'Test Product');
    });

    test('should map installment request', () {
      final mapped = IyzicoMapper.toInstallmentRequest(
        binNumber: '552879',
        price: 250.0,
        conversationId: 'conv456',
      );

      expect(mapped['binNumber'], '552879');
      expect(mapped['price'], '250.0');
      expect(mapped['conversationId'], 'conv456');
    });

    test('should parse successful payment response', () {
      final response = {
        'status': 'success',
        'paymentId': '12345',
        'price': 100.0,
        'paidPrice': 100.0,
        'installment': 1,
        'cardType': 'CREDIT_CARD',
        'cardAssociation': 'MASTER_CARD',
        'cardFamily': 'Axess',
        'binNumber': '552879',
        'lastFourDigits': '0008',
        'itemTransactions': [
          {'paymentTransactionId': '67890'},
        ],
      };

      final result = IyzicoMapper.fromPaymentResponse(response);

      expect(result.isSuccess, true);
      expect(result.paymentId, '12345');
      expect(result.transactionId, '67890');
      expect(result.amount, 100.0);
      expect(result.cardType, CardType.creditCard);
      expect(result.cardAssociation, CardAssociation.masterCard);
      expect(result.cardFamily, 'Axess');
    });

    test('should parse failed payment response', () {
      final response = {
        'status': 'failure',
        'errorCode': '10051',
        'errorMessage': 'Yetersiz bakiye',
      };

      final result = IyzicoMapper.fromPaymentResponse(response);

      expect(result.isSuccess, false);
      expect(result.errorCode, '10051');
      expect(result.errorMessage, 'Yetersiz bakiye');
    });

    test('should parse 3DS init response', () {
      final response = {
        'status': 'success',
        'threeDSHtmlContent': 'PGh0bWw+PC9odG1sPg==', // base64 of <html></html>
        'paymentId': '12345',
      };

      final result = IyzicoMapper.from3DSInitResponse(response);

      expect(result.status, ThreeDSStatus.pending);
      expect(result.htmlContent, '<html></html>');
      expect(result.transactionId, '12345');
      expect(result.needsWebView, true);
    });

    test('should parse installment response', () {
      final response = {
        'status': 'success',
        'installmentDetails': [
          {
            'binNumber': '552879',
            'price': 100.0,
            'cardType': 'CREDIT_CARD',
            'cardAssociation': 'MASTER_CARD',
            'cardFamilyName': 'Axess',
            'bankName': 'Akbank',
            'bankCode': 46,
            'force3ds': 0,
            'forceCvc': 1,
            'installmentPrices': [
              {
                'installmentNumber': 1,
                'installmentPrice': 100.0,
                'totalPrice': 100.0,
              },
              {
                'installmentNumber': 2,
                'installmentPrice': 51.0,
                'totalPrice': 102.0,
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

      final result = IyzicoMapper.fromInstallmentResponse(response);

      expect(result, isNotNull);
      expect(result!.binNumber, '552879');
      expect(result.cardFamily, 'Axess');
      expect(result.bankName, 'Akbank');
      expect(result.force3DS, false);
      expect(result.forceCVC, true);
      expect(result.options.length, 3);
      expect(result.maxInstallment, 3);
    });
  });

  group('IyzicoErrorMapper', () {
    test('should map insufficient funds error', () {
      final error = IyzicoErrorMapper.mapError(
        errorCode: '10051',
        errorMessage: 'Yetersiz bakiye',
      );

      expect(error.code, 'insufficient_funds');
      expect(error.providerCode, '10051');
      expect(error.provider, ProviderType.iyzico);
    });

    test('should map invalid card error', () {
      final error = IyzicoErrorMapper.mapError(
        errorCode: '12',
        errorMessage: 'Geçersiz kart',
      );

      expect(error.code, 'invalid_card');
    });

    test('should map expired card error', () {
      final error = IyzicoErrorMapper.mapError(
        errorCode: '54',
        errorMessage: 'Kartın süresi dolmuş',
      );

      expect(error.code, 'expired_card');
    });

    test('should map 3DS failed error', () {
      final error = IyzicoErrorMapper.mapError(
        errorCode: '10057',
        errorMessage: '3D Secure başarısız',
      );

      expect(error.code, 'threeds_failed');
    });

    test('should map unknown error', () {
      final error = IyzicoErrorMapper.mapError(
        errorCode: '99999',
        errorMessage: 'Bilinmeyen hata',
      );

      expect(error.code, 'unknown_error');
      expect(error.providerCode, '99999');
    });

    test('should parse card association', () {
      expect(
        IyzicoErrorMapper.parseCardAssociation('VISA'),
        CardAssociation.visa,
      );
      expect(
        IyzicoErrorMapper.parseCardAssociation('MASTER_CARD'),
        CardAssociation.masterCard,
      );
      expect(
        IyzicoErrorMapper.parseCardAssociation('MASTERCARD'),
        CardAssociation.masterCard,
      );
      expect(
        IyzicoErrorMapper.parseCardAssociation('TROY'),
        CardAssociation.troy,
      );
      expect(IyzicoErrorMapper.parseCardAssociation('UNKNOWN'), null);
    });

    test('should parse card type', () {
      expect(
        IyzicoErrorMapper.parseCardType('CREDIT_CARD'),
        CardType.creditCard,
      );
      expect(IyzicoErrorMapper.parseCardType('DEBIT_CARD'), CardType.debitCard);
      expect(
        IyzicoErrorMapper.parseCardType('PREPAID_CARD'),
        CardType.prepaidCard,
      );
      expect(IyzicoErrorMapper.parseCardType('UNKNOWN'), null);
    });
  });

  group('IyzicoProvider', () {
    late IyzicoProvider provider;
    late IyzicoConfig config;

    setUp(() {
      provider = IyzicoProvider();
      config = IyzicoConfig(
        merchantId: 'test_merchant',
        apiKey: 'sandbox-test-api-key',
        secretKey: 'sandbox-test-secret-key',
        isSandbox: true,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('should have correct provider type', () {
      expect(provider.providerType, ProviderType.iyzico);
    });

    test('should initialize with valid config', () async {
      await provider.initialize(config);
      // No exception means success
    });

    test('should throw error with invalid config type', () async {
      final invalidConfig = PayTRConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        successUrl: 'https://example.com/success',
        failUrl: 'https://example.com/fail',
        callbackUrl: 'https://example.com/callback',
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

    test('should require callbackUrl for 3DS payment', () async {
      await provider.initialize(config);

      final request = PaymentRequest(
        orderId: 'ORDER_123',
        amount: 100.0,
        card: CardInfo(
          cardHolderName: 'Test',
          cardNumber: '5528790000000008',
          expireMonth: '12',
          expireYear: '2030',
          cvc: '123',
        ),
        buyer: BuyerInfo(
          id: 'B1',
          name: 'Test',
          surname: 'User',
          email: 'test@test.com',
          phone: '+905551234567',
          ip: '127.0.0.1',
          city: 'Istanbul',
          country: 'Turkey',
          address: 'Test',
        ),
        basketItems: [
          BasketItem(
            id: 'I1',
            name: 'Product',
            category: 'Test',
            price: 100.0,
            itemType: ItemType.physical,
          ),
        ],
        callbackUrl: null, // No callback URL
      );

      expect(
        () => provider.init3DSPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });
  });

  group('IyzicoConfig', () {
    test('should return sandbox URL when isSandbox is true', () {
      final config = IyzicoConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        isSandbox: true,
      );

      expect(config.baseUrl, 'https://sandbox-api.iyzipay.com');
    });

    test('should return production URL when isSandbox is false', () {
      final config = IyzicoConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        isSandbox: false,
      );

      expect(config.baseUrl, 'https://api.iyzipay.com');
    });

    test('should validate config correctly', () {
      final validConfig = IyzicoConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
      );

      final invalidConfig = IyzicoConfig(
        merchantId: '',
        apiKey: 'test',
        secretKey: '',
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
