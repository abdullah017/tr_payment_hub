import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('ValidationException', () {
    test('should create with single error', () {
      final exception = ValidationException.single('Invalid card number');

      expect(exception.message, 'Invalid card number');
      expect(exception.errors, ['Invalid card number']);
      expect(exception.allErrors, 'Invalid card number');
    });

    test('should create with multiple errors', () {
      const exception = ValidationException(
        errors: ['Error 1', 'Error 2', 'Error 3'],
      );

      expect(exception.message, 'Error 1');
      expect(exception.allErrors, 'Error 1; Error 2; Error 3');
      expect(exception.errors.length, 3);
    });

    test('should include field name when provided', () {
      final exception = ValidationException.single(
        'Must be positive',
        field: 'amount',
      );

      expect(exception.field, 'amount');
    });

    test('should handle empty errors list', () {
      const exception = ValidationException(errors: []);

      expect(exception.message, 'Validation failed');
      expect(exception.allErrors, '');
    });

    test('toString should return meaningful message', () {
      final exception = ValidationException.single('Test error');

      expect(exception.toString(), contains('ValidationException'));
    });
  });

  group('CardInfo Validation', () {
    test('should validate valid card', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      // Should not throw
      card.validate();
    });

    test('should reject empty card holder name', () {
      const card = CardInfo(
        cardHolderName: '',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(() => card.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject invalid card number format', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '1234',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(() => card.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject card number failing Luhn check', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '1234567890123456',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(() => card.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject invalid expire month', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '13',
        expireYear: '2030',
        cvc: '123',
      );

      expect(() => card.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject invalid CVC format', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '12',
      );

      expect(() => card.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject expired card', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '01',
        expireYear: '2020',
        cvc: '123',
      );

      expect(() => card.validate(), throwsA(isA<ValidationException>()));
    });

    test('isExpired should return true for expired card', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '01',
        expireYear: '2020',
        cvc: '123',
      );

      expect(card.isExpired, true);
    });

    test('isExpired should return false for valid card', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(card.isExpired, false);
    });
  });

  group('BuyerInfo Validation', () {
    test('should validate valid buyer', () {
      const buyer = BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      );

      buyer.validate();
    });

    test('should reject invalid email', () {
      const buyer = BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'invalid-email',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      );

      expect(() => buyer.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject invalid IP address', () {
      const buyer = BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '+905551234567',
        ip: '999.999.999.999',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      );

      expect(() => buyer.validate(), throwsA(isA<ValidationException>()));
    });

    test('should accept valid Turkish phone formats', () {
      const phones = [
        '+905551234567',
        '05551234567',
        '5551234567',
        '905551234567',
      ];

      for (final phone in phones) {
        final buyer = BuyerInfo(
          id: 'BUYER_1',
          name: 'John',
          surname: 'Doe',
          email: 'john@example.com',
          phone: phone,
          ip: '127.0.0.1',
          city: 'Istanbul',
          country: 'Turkey',
          address: 'Test Address',
        );

        // Should not throw
        buyer.validate();
      }
    });

    test('should reject invalid phone format', () {
      const buyer = BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '12345',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      );

      expect(() => buyer.validate(), throwsA(isA<ValidationException>()));
    });

    test('should validate valid TC Kimlik number', () {
      // Valid TC Kimlik: 10000000146
      const buyer = BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
        identityNumber: '10000000146',
      );

      buyer.validate();
    });

    test('should reject invalid TC Kimlik number', () {
      const buyer = BuyerInfo(
        id: 'BUYER_1',
        name: 'John',
        surname: 'Doe',
        email: 'john@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
        identityNumber: '12345678901',
      );

      expect(() => buyer.validate(), throwsA(isA<ValidationException>()));
    });
  });

  group('PaymentRequest Validation', () {
    test('should validate valid request', () {
      final request = _createValidRequest();
      request.validate();
    });

    test('should reject negative amount', () {
      final request = _createValidRequest().copyWith(amount: -100);

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject zero amount', () {
      final request = _createValidRequest().copyWith(amount: 0);

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject invalid installment', () {
      final request = _createValidRequest().copyWith(installment: 0);

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject installment > 12', () {
      final request = _createValidRequest().copyWith(installment: 13);

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject empty order ID', () {
      final request = _createValidRequest().copyWith(orderId: '');

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should require callbackUrl for 3DS', () {
      final request = _createValidRequest().copyWith(
        use3DS: true,
        callbackUrl: null,
      );

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should validate basket total matches amount', () {
      const request = PaymentRequest(
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
          id: 'BUYER_1',
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
            name: 'Product',
            category: 'Test',
            price: 50,
            itemType: ItemType.physical,
          ),
        ],
      );

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });
  });

  group('RefundRequest Validation', () {
    test('should validate valid refund request', () {
      const request = RefundRequest(
        transactionId: 'TX123456',
        amount: 50,
      );

      request.validate();
    });

    test('should reject empty transaction ID', () {
      const request = RefundRequest(
        transactionId: '',
        amount: 50,
      );

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject negative amount', () {
      const request = RefundRequest(
        transactionId: 'TX123456',
        amount: -50,
      );

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });

    test('should reject zero amount', () {
      const request = RefundRequest(
        transactionId: 'TX123456',
        amount: 0,
      );

      expect(() => request.validate(), throwsA(isA<ValidationException>()));
    });
  });
}

PaymentRequest _createValidRequest() => const PaymentRequest(
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
        id: 'BUYER_1',
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
          category: 'Test',
          price: 100,
          itemType: ItemType.physical,
        ),
      ],
    );
