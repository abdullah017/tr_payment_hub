import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('MockPaymentProvider', () {
    late MockPaymentProvider provider;
    late IyzicoConfig config;

    setUp(() {
      provider = MockPaymentProvider();
      config = const IyzicoConfig(
        merchantId: 'test_merchant',
        apiKey: 'test_api_key',
        secretKey: 'test_secret_key',
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('should initialize successfully', () async {
      await provider.initialize(config);
      // No exception means success
    });

    test('should fail with invalid config', () async {
      const invalidConfig = IyzicoConfig(
        merchantId: '',
        apiKey: '',
        secretKey: '',
      );

      expect(
        () => provider.initialize(invalidConfig),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should create payment successfully', () async {
      await provider.initialize(config);

      final request = _createTestRequest();
      final result = await provider.createPayment(request);

      expect(result.isSuccess, true);
      expect(result.transactionId, isNotNull);
      expect(result.amount, 100.0);
    });

    test('should fail payment when shouldSucceed is false', () async {
      final failingProvider = MockPaymentProvider(shouldSucceed: false);
      await failingProvider.initialize(config);

      final request = _createTestRequest();

      expect(
        () => failingProvider.createPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should return installment options', () async {
      await provider.initialize(config);

      final installments = await provider.getInstallments(
        binNumber: '552879',
        amount: 100,
      );

      expect(installments.options.length, greaterThan(0));
      expect(installments.cardFamily, 'Axess');
      expect(installments.maxInstallment, 12);
    });
  });

  group('CardInfo', () {
    test('should mask card number correctly', () {
      const card = CardInfo(
        cardHolderName: 'Test',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(card.maskedNumber, '552879******0008');
      expect(card.binNumber, '552879');
      expect(card.lastFourDigits, '0008');
    });

    test('should validate card number with Luhn algorithm', () {
      const validCard = CardInfo(
        cardHolderName: 'Test',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      const invalidCard = CardInfo(
        cardHolderName: 'Test',
        cardNumber: '1234567890123456',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(validCard.isValidNumber, true);
      expect(invalidCard.isValidNumber, false);
    });
  });

  group('HashUtils', () {
    test('should generate SHA256 hash', () {
      final hash = HashUtils.sha256Hash('test');
      expect(hash, isNotEmpty);
      expect(hash.length, 64); // SHA256 = 64 hex chars
    });

    test('should generate HMAC-SHA256', () {
      final hmac = HashUtils.hmacSha256('data', 'key');
      expect(hmac, isNotEmpty);
    });

    test('should encode/decode Base64', () {
      const original = 'Hello World';
      final encoded = HashUtils.base64Encode(original);
      final decoded = HashUtils.base64Decode(encoded);

      expect(decoded, original);
    });
  });

  group('LogSanitizer', () {
    test('should mask card number in string', () {
      const input = 'Card: 5528790000000008';
      final output = LogSanitizer.sanitize(input);

      expect(output, contains('XXXXXX'));
      expect(output, isNot(contains('0000000008')));
    });

    test('should mask CVV in string', () {
      const input = 'cvv: 123';
      final output = LogSanitizer.sanitize(input);

      expect(output, contains('***'));
      expect(output, isNot(contains('123')));
    });
  });
}

PaymentRequest _createTestRequest() => const PaymentRequest(
      orderId: 'TEST_ORDER',
      amount: 100,
      card: CardInfo(
        cardHolderName: 'Test User',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
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
        address: 'Test Address',
      ),
      basketItems: [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'Test',
          price: 100,
          itemType: ItemType.physical,
        ),
      ],
    );
