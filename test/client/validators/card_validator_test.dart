import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub_client.dart';

void main() {
  group('CardValidator', () {
    group('isValidCardNumber', () {
      test('should validate correct card numbers (Luhn)', () {
        // Valid test cards
        expect(CardValidator.isValidCardNumber('5528790000000008'), true);
        expect(CardValidator.isValidCardNumber('4532015112830366'), true);
        expect(CardValidator.isValidCardNumber('374245455400126'), true);
        expect(CardValidator.isValidCardNumber('4111111111111111'), true);

        // Invalid cards
        expect(CardValidator.isValidCardNumber('1234567890123456'), false);
        expect(CardValidator.isValidCardNumber('0000000000000000'), false);
        expect(CardValidator.isValidCardNumber('123'), false);
        expect(CardValidator.isValidCardNumber(''), false);
      });

      test('should handle formatted card numbers', () {
        expect(CardValidator.isValidCardNumber('5528 7900 0000 0008'), true);
        expect(CardValidator.isValidCardNumber('5528-7900-0000-0008'), true);
        expect(CardValidator.isValidCardNumber('4111 1111 1111 1111'), true);
      });

      test('should reject cards with invalid length', () {
        expect(CardValidator.isValidCardNumber('411111111111'),
            false); // 12 digits
        expect(CardValidator.isValidCardNumber('41111111111111111111'),
            false); // 20 digits
      });
    });

    group('detectCardBrand', () {
      test('should detect Visa', () {
        expect(
            CardValidator.detectCardBrand('4111111111111111'), CardBrand.visa);
        expect(
            CardValidator.detectCardBrand('4532015112830366'), CardBrand.visa);
        expect(CardValidator.detectCardBrand('4'), CardBrand.visa);
      });

      test('should detect Mastercard (51-55 range)', () {
        expect(CardValidator.detectCardBrand('5528790000000008'),
            CardBrand.mastercard);
        expect(CardValidator.detectCardBrand('5100000000000000'),
            CardBrand.mastercard);
        expect(CardValidator.detectCardBrand('5500000000000000'),
            CardBrand.mastercard);
      });

      test('should detect Mastercard (2221-2720 range)', () {
        expect(CardValidator.detectCardBrand('2221000000000000'),
            CardBrand.mastercard);
        expect(CardValidator.detectCardBrand('2720000000000000'),
            CardBrand.mastercard);
      });

      test('should detect Amex', () {
        expect(
            CardValidator.detectCardBrand('340000000000009'), CardBrand.amex);
        expect(
            CardValidator.detectCardBrand('374245455400126'), CardBrand.amex);
        expect(
            CardValidator.detectCardBrand('370000000000002'), CardBrand.amex);
      });

      test('should detect Troy', () {
        expect(
            CardValidator.detectCardBrand('9792000000000001'), CardBrand.troy);
        expect(CardValidator.detectCardBrand('9792'), CardBrand.troy);
      });

      test('should return unknown for unrecognized cards', () {
        expect(CardValidator.detectCardBrand('6011000000000000'),
            CardBrand.unknown);
        expect(CardValidator.detectCardBrand(''), CardBrand.unknown);
      });
    });

    group('isValidExpiry', () {
      test('should validate future dates', () {
        expect(CardValidator.isValidExpiry('12', '2030'), true);
        expect(CardValidator.isValidExpiry('01', '2030'), true);
        expect(CardValidator.isValidExpiry('6', '2030'), true);
      });

      test('should handle 2-digit year', () {
        expect(CardValidator.isValidExpiry('12', '30'), true);
        expect(CardValidator.isValidExpiry('01', '35'), true);
      });

      test('should reject past dates', () {
        expect(CardValidator.isValidExpiry('01', '2020'), false);
        expect(CardValidator.isValidExpiry('01', '2000'), false);
        expect(CardValidator.isValidExpiry('01', '19'), false);
      });

      test('should reject invalid months', () {
        expect(CardValidator.isValidExpiry('00', '2030'), false);
        expect(CardValidator.isValidExpiry('13', '2030'), false);
        expect(CardValidator.isValidExpiry('99', '2030'), false);
      });

      test('should handle invalid input', () {
        expect(CardValidator.isValidExpiry('', '2030'), false);
        expect(CardValidator.isValidExpiry('12', ''), false);
        expect(CardValidator.isValidExpiry('abc', '2030'), false);
      });
    });

    group('isValidCVV', () {
      test('should validate 3-digit CVV', () {
        expect(CardValidator.isValidCVV('123'), true);
        expect(CardValidator.isValidCVV('000'), true);
        expect(CardValidator.isValidCVV('999'), true);
      });

      test('should validate 4-digit CVV for Amex', () {
        expect(
            CardValidator.isValidCVV('1234', cardBrand: CardBrand.amex), true);
        expect(
            CardValidator.isValidCVV('123', cardBrand: CardBrand.amex), false);
      });

      test('should reject 4-digit CVV for non-Amex', () {
        expect(CardValidator.isValidCVV('1234'), false);
        expect(
            CardValidator.isValidCVV('1234', cardBrand: CardBrand.visa), false);
      });

      test('should reject invalid CVV', () {
        expect(CardValidator.isValidCVV('12'), false);
        expect(CardValidator.isValidCVV('12345'), false);
        expect(CardValidator.isValidCVV(''), false);
        expect(CardValidator.isValidCVV('abc'), false);
      });
    });

    group('isValidHolderName', () {
      test('should validate proper names', () {
        expect(CardValidator.isValidHolderName('John Doe'), true);
        expect(CardValidator.isValidHolderName('Ahmet Yilmaz'), true);
        expect(CardValidator.isValidHolderName('JOHN DOE'), true);
      });

      test('should require at least 2 words', () {
        expect(CardValidator.isValidHolderName('John'), false);
        expect(CardValidator.isValidHolderName('A'), false);
      });

      test('should handle whitespace', () {
        expect(CardValidator.isValidHolderName('  John  Doe  '), true);
        expect(CardValidator.isValidHolderName('John    Doe'), true);
      });

      test('should reject empty or too short names', () {
        expect(CardValidator.isValidHolderName(''), false);
        expect(CardValidator.isValidHolderName('AB'), false);
      });
    });

    group('validate', () {
      test('should return valid for correct card info', () {
        final result = CardValidator.validate(
          cardNumber: '5528790000000008',
          expireMonth: '12',
          expireYear: '2030',
          cvv: '123',
          holderName: 'Ahmet Yilmaz',
        );

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
        expect(result.cardBrand, CardBrand.mastercard);
      });

      test('should return all errors', () {
        final result = CardValidator.validate(
          cardNumber: '1234567890123456',
          expireMonth: '13',
          expireYear: '2020',
          cvv: '12',
          holderName: 'A',
        );

        expect(result.isValid, false);
        expect(result.errors.length, 4);
        expect(result.hasError('cardNumber'), true);
        expect(result.hasError('expiry'), true);
        expect(result.hasError('cvv'), true);
        expect(result.hasError('holderName'), true);
      });

      test('should detect card brand even with errors', () {
        final result = CardValidator.validate(
          cardNumber: '4111111111111112', // Invalid Luhn but starts with 4
          expireMonth: '12',
          expireYear: '2030',
          cvv: '123',
          holderName: 'John Doe',
        );

        expect(result.cardBrand, CardBrand.visa);
        expect(result.hasError('cardNumber'), true);
      });

      test('should require 4-digit CVV for Amex', () {
        final result = CardValidator.validate(
          cardNumber: '374245455400126',
          expireMonth: '12',
          expireYear: '2030',
          cvv: '123', // 3 digits - invalid for Amex
          holderName: 'John Doe',
        );

        expect(result.hasError('cvv'), true);
        expect(result.getError('cvv'), contains('4'));
      });
    });

    group('formatCardNumber', () {
      test('should format card number with spaces', () {
        expect(
          CardValidator.formatCardNumber('5528790000000008'),
          '5528 7900 0000 0008',
        );
        expect(
          CardValidator.formatCardNumber('4111111111111111'),
          '4111 1111 1111 1111',
        );
      });

      test('should handle already formatted input', () {
        expect(
          CardValidator.formatCardNumber('5528 7900 0000 0008'),
          '5528 7900 0000 0008',
        );
      });

      test('should handle partial numbers', () {
        expect(CardValidator.formatCardNumber('5528'), '5528');
        expect(CardValidator.formatCardNumber('55287900'), '5528 7900');
      });
    });

    group('maskCardNumber', () {
      test('should mask middle digits', () {
        expect(
          CardValidator.maskCardNumber('5528790000000008'),
          '552879******0008',
        );
        expect(
          CardValidator.maskCardNumber('4111111111111111'),
          '411111******1111',
        );
      });

      test('should handle short numbers', () {
        expect(CardValidator.maskCardNumber('12345'), '12345');
      });
    });

    group('extractBin', () {
      test('should extract first 6 digits by default', () {
        expect(CardValidator.extractBin('5528790000000008'), '552879');
      });

      test('should extract custom length', () {
        expect(CardValidator.extractBin('5528790000000008', length: 8),
            '55287900');
      });

      test('should handle short numbers', () {
        expect(CardValidator.extractBin('5528'), '5528');
      });
    });

    group('CardBrand', () {
      test('should have display names', () {
        expect(CardBrand.visa.displayName, 'Visa');
        expect(CardBrand.mastercard.displayName, 'Mastercard');
        expect(CardBrand.amex.displayName, 'American Express');
        expect(CardBrand.troy.displayName, 'Troy');
        expect(CardBrand.unknown.displayName, 'Unknown');
      });

      test('should check if known', () {
        expect(CardBrand.visa.isKnown, true);
        expect(CardBrand.unknown.isKnown, false);
      });
    });

    group('CardValidationResult', () {
      test('should provide helper methods', () {
        final result = CardValidator.validate(
          cardNumber: '1234',
          expireMonth: '12',
          expireYear: '2030',
          cvv: '123',
          holderName: 'John Doe',
        );

        expect(result.hasError('cardNumber'), true);
        expect(result.getError('cardNumber'), isNotNull);
        expect(result.allErrors.length, greaterThan(0));
      });
    });
  });
}
