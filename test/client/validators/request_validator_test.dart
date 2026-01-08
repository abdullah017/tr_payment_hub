import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('RequestValidator', () {
    group('validate', () {
      test('should return valid for correct request', () {
        final result = RequestValidator.validate(_createValidRequest());

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should reject empty orderId', () {
        final request = _createValidRequest().copyWith(orderId: '');
        final result = RequestValidator.validate(request);

        expect(result.hasError('orderId'), true);
      });

      test('should reject long orderId', () {
        final request = _createValidRequest().copyWith(
          orderId: 'A' * 51,
        );
        final result = RequestValidator.validate(request);

        expect(result.hasError('orderId'), true);
      });

      test('should reject zero amount', () {
        final request = _createValidRequest().copyWith(amount: 0);
        final result = RequestValidator.validate(request);

        expect(result.hasError('amount'), true);
      });

      test('should reject negative amount', () {
        final request = _createValidRequest().copyWith(amount: -100);
        final result = RequestValidator.validate(request);

        expect(result.hasError('amount'), true);
      });

      test('should reject very large amount', () {
        final request = _createValidRequest().copyWith(amount: 9999999.99);
        final result = RequestValidator.validate(request);

        expect(result.hasError('amount'), true);
      });

      test('should reject installment less than 1', () {
        final request = _createValidRequest().copyWith(installment: 0);
        final result = RequestValidator.validate(request);

        expect(result.hasError('installment'), true);
      });

      test('should reject installment greater than 12', () {
        final request = _createValidRequest().copyWith(installment: 13);
        final result = RequestValidator.validate(request);

        expect(result.hasError('installment'), true);
      });

      test('should reject empty basket', () {
        final request = PaymentRequest(
          orderId: 'TEST_ORDER',
          amount: 100,
          card: _createValidCard(),
          buyer: _createValidBuyer(),
          basketItems: const [],
        );
        final result = RequestValidator.validate(request);

        expect(result.hasError('basketItems'), true);
      });

      test('should reject basket total mismatch', () {
        final request = PaymentRequest(
          orderId: 'TEST_ORDER',
          amount: 200, // Mismatch: basket total is 100
          card: _createValidCard(),
          buyer: _createValidBuyer(),
          basketItems: const [
            BasketItem(
              id: 'ITEM_1',
              name: 'Test',
              category: 'Test',
              price: 100,
              itemType: ItemType.physical,
            ),
          ],
        );
        final result = RequestValidator.validate(request);

        expect(result.hasError('basketItems'), true);
        expect(result.getError('basketItems'), contains('uyusmuyor'));
      });

      test('should require callback URL for 3DS', () {
        final request = _createValidRequest().copyWith(use3DS: true);
        final result = RequestValidator.validate(request);

        expect(result.hasError('callbackUrl'), true);
      });

      test('should accept 3DS with callback URL', () {
        final request = _createValidRequest().copyWith(
          use3DS: true,
          callbackUrl: 'https://example.com/callback',
        );
        final result = RequestValidator.validate(request);

        expect(result.hasError('callbackUrl'), false);
      });

      test('should validate basket item fields', () {
        final request = PaymentRequest(
          orderId: 'TEST_ORDER',
          amount: 100,
          card: _createValidCard(),
          buyer: _createValidBuyer(),
          basketItems: const [
            BasketItem(
              id: '', // Invalid
              name: '', // Invalid
              category: 'Test',
              price: 0, // Invalid
              itemType: ItemType.physical,
            ),
          ],
        );
        final result = RequestValidator.validate(request);

        expect(result.hasError('basketItems[0].id'), true);
        expect(result.hasError('basketItems[0].name'), true);
        expect(result.hasError('basketItems[0].price'), true);
      });

      test('should return all errors at once', () {
        final request = PaymentRequest(
          orderId: '',
          amount: -1,
          card: _createValidCard(),
          buyer: const BuyerInfo(
            id: '',
            name: '',
            surname: '',
            email: 'invalid',
            phone: '123',
            ip: 'invalid',
            city: '',
            country: '',
            address: '',
          ),
          basketItems: const [],
        );
        final result = RequestValidator.validate(request);

        expect(result.errors.length, greaterThan(5));
        expect(result.errorCount, greaterThan(5));
      });
    });

    group('validateBuyer', () {
      test('should return empty for valid buyer', () {
        final errors = RequestValidator.validateBuyer(_createValidBuyer());

        expect(errors, isEmpty);
      });

      test('should reject empty id', () {
        final buyer = _createValidBuyer().copyWith(id: '');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.id'), true);
      });

      test('should reject empty name', () {
        final buyer = _createValidBuyer().copyWith(name: '');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.name'), true);
      });

      test('should reject empty surname', () {
        final buyer = _createValidBuyer().copyWith(surname: '');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.surname'), true);
      });

      test('should reject invalid email', () {
        final buyer = _createValidBuyer().copyWith(email: 'invalid-email');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.email'), true);
      });

      test('should accept valid email formats', () {
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(email: 'test@example.com'),
          ).containsKey('buyer.email'),
          false,
        );
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(email: 'test.name@sub.domain.com'),
          ).containsKey('buyer.email'),
          false,
        );
      });

      test('should reject invalid phone', () {
        final buyer = _createValidBuyer().copyWith(phone: '123');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.phone'), true);
      });

      test('should accept valid phone formats', () {
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(phone: '+905551234567'),
          ).containsKey('buyer.phone'),
          false,
        );
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(phone: '05551234567'),
          ).containsKey('buyer.phone'),
          false,
        );
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(phone: '(555) 123-4567'),
          ).containsKey('buyer.phone'),
          false,
        );
      });

      test('should reject invalid IP', () {
        final buyer = _createValidBuyer().copyWith(ip: 'invalid');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.ip'), true);
      });

      test('should accept valid IPv4', () {
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(ip: '192.168.1.1'),
          ).containsKey('buyer.ip'),
          false,
        );
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(ip: '10.0.0.1'),
          ).containsKey('buyer.ip'),
          false,
        );
      });

      test('should accept valid IPv6', () {
        expect(
          RequestValidator.validateBuyer(
            _createValidBuyer().copyWith(ip: '::1'),
          ).containsKey('buyer.ip'),
          false,
        );
      });

      test('should reject empty city', () {
        final buyer = _createValidBuyer().copyWith(city: '');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.city'), true);
      });

      test('should reject empty country', () {
        final buyer = _createValidBuyer().copyWith(country: '');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.country'), true);
      });

      test('should reject empty address', () {
        final buyer = _createValidBuyer().copyWith(address: '');
        final errors = RequestValidator.validateBuyer(buyer);

        expect(errors.containsKey('buyer.address'), true);
      });
    });

    group('RequestValidationResult', () {
      test('should provide helper methods', () {
        final result = RequestValidator.validate(
          _createValidRequest().copyWith(orderId: ''),
        );

        expect(result.hasError('orderId'), true);
        expect(result.getError('orderId'), isNotNull);
        expect(result.allErrors, isNotEmpty);
        expect(result.errorCount, greaterThan(0));
      });

      test('should have meaningful toString', () {
        final validResult = RequestValidator.validate(_createValidRequest());
        expect(validResult.toString(), contains('valid'));

        final invalidResult = RequestValidator.validate(
          _createValidRequest().copyWith(orderId: ''),
        );
        expect(invalidResult.toString(), contains('invalid'));
      });
    });
  });
}

PaymentRequest _createValidRequest() {
  return PaymentRequest(
    orderId: 'TEST_ORDER',
    amount: 100,
    card: _createValidCard(),
    buyer: _createValidBuyer(),
    basketItems: const [
      BasketItem(
        id: 'ITEM_1',
        name: 'Test Product',
        category: 'Test',
        price: 100,
        itemType: ItemType.physical,
      ),
    ],
  );
}

CardInfo _createValidCard() {
  return const CardInfo(
    cardHolderName: 'Test User',
    cardNumber: '5528790000000008',
    expireMonth: '12',
    expireYear: '2030',
    cvc: '123',
  );
}

BuyerInfo _createValidBuyer() {
  return const BuyerInfo(
    id: 'BUYER_1',
    name: 'Test',
    surname: 'User',
    email: 'test@example.com',
    phone: '+905551234567',
    ip: '127.0.0.1',
    city: 'Istanbul',
    country: 'Turkey',
    address: 'Test Address',
  );
}
