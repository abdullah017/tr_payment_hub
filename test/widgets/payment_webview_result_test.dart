import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub/src/widgets/payment_webview_result.dart';

void main() {
  group('PaymentWebViewStatus', () {
    test('should have 4 status values', () {
      expect(PaymentWebViewStatus.values.length, equals(4));
      expect(
          PaymentWebViewStatus.values, contains(PaymentWebViewStatus.success));
      expect(PaymentWebViewStatus.values,
          contains(PaymentWebViewStatus.cancelled));
      expect(
          PaymentWebViewStatus.values, contains(PaymentWebViewStatus.timeout));
      expect(PaymentWebViewStatus.values, contains(PaymentWebViewStatus.error));
    });
  });

  group('PaymentWebViewResult', () {
    group('success', () {
      test('should create success result with callback data', () {
        const callbackData = {'status': 'success', 'transactionId': '123'};
        const result = PaymentWebViewResult.success(callbackData);

        expect(result.status, equals(PaymentWebViewStatus.success));
        expect(result.callbackData, equals(callbackData));
        expect(result.errorMessage, isNull);
      });

      test('isSuccess should return true', () {
        const result = PaymentWebViewResult.success({'key': 'value'});

        expect(result.isSuccess, isTrue);
        expect(result.isCancelled, isFalse);
        expect(result.isTimeout, isFalse);
        expect(result.isError, isFalse);
      });

      test('should handle empty callback data', () {
        const result = PaymentWebViewResult.success({});

        expect(result.isSuccess, isTrue);
        expect(result.callbackData, isEmpty);
      });

      test('toString should include callback data', () {
        const callbackData = {'id': '123'};
        const result = PaymentWebViewResult.success(callbackData);

        expect(result.toString(), contains('success'));
        expect(result.toString(), contains('callbackData'));
      });
    });

    group('cancelled', () {
      test('should create cancelled result', () {
        const result = PaymentWebViewResult.cancelled();

        expect(result.status, equals(PaymentWebViewStatus.cancelled));
        expect(result.callbackData, isNull);
        expect(result.errorMessage, isNull);
      });

      test('isCancelled should return true', () {
        const result = PaymentWebViewResult.cancelled();

        expect(result.isSuccess, isFalse);
        expect(result.isCancelled, isTrue);
        expect(result.isTimeout, isFalse);
        expect(result.isError, isFalse);
      });

      test('toString should indicate cancelled', () {
        const result = PaymentWebViewResult.cancelled();

        expect(result.toString(), contains('cancelled'));
      });
    });

    group('timeout', () {
      test('should create timeout result with default message', () {
        const result = PaymentWebViewResult.timeout();

        expect(result.status, equals(PaymentWebViewStatus.timeout));
        expect(result.callbackData, isNull);
        expect(result.errorMessage, equals('Payment timed out'));
      });

      test('isTimeout should return true', () {
        const result = PaymentWebViewResult.timeout();

        expect(result.isSuccess, isFalse);
        expect(result.isCancelled, isFalse);
        expect(result.isTimeout, isTrue);
        expect(result.isError, isFalse);
      });

      test('toString should indicate timeout', () {
        const result = PaymentWebViewResult.timeout();

        expect(result.toString(), contains('timeout'));
      });
    });

    group('error', () {
      test('should create error result with message', () {
        const errorMessage = 'Network connection failed';
        const result = PaymentWebViewResult.error(errorMessage);

        expect(result.status, equals(PaymentWebViewStatus.error));
        expect(result.callbackData, isNull);
        expect(result.errorMessage, equals(errorMessage));
      });

      test('isError should return true', () {
        const result = PaymentWebViewResult.error('Some error');

        expect(result.isSuccess, isFalse);
        expect(result.isCancelled, isFalse);
        expect(result.isTimeout, isFalse);
        expect(result.isError, isTrue);
      });

      test('toString should include error message', () {
        const result = PaymentWebViewResult.error('Test error');

        expect(result.toString(), contains('error'));
        expect(result.toString(), contains('Test error'));
      });
    });

    group('equality', () {
      test('same success results should be equal', () {
        const result1 = PaymentWebViewResult.success({'key': 'value'});
        const result2 = PaymentWebViewResult.success({'key': 'value'});

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('different success results should not be equal', () {
        const result1 = PaymentWebViewResult.success({'key': 'value1'});
        const result2 = PaymentWebViewResult.success({'key': 'value2'});

        expect(result1, isNot(equals(result2)));
      });

      test('cancelled results should be equal', () {
        const result1 = PaymentWebViewResult.cancelled();
        const result2 = PaymentWebViewResult.cancelled();

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('timeout results should be equal', () {
        const result1 = PaymentWebViewResult.timeout();
        const result2 = PaymentWebViewResult.timeout();

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('error results with same message should be equal', () {
        const result1 = PaymentWebViewResult.error('Same error');
        const result2 = PaymentWebViewResult.error('Same error');

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('error results with different message should not be equal', () {
        const result1 = PaymentWebViewResult.error('Error 1');
        const result2 = PaymentWebViewResult.error('Error 2');

        expect(result1, isNot(equals(result2)));
      });

      test('different status results should not be equal', () {
        const success = PaymentWebViewResult.success({});
        const cancelled = PaymentWebViewResult.cancelled();
        const timeout = PaymentWebViewResult.timeout();
        const error = PaymentWebViewResult.error('error');

        expect(success, isNot(equals(cancelled)));
        expect(success, isNot(equals(timeout)));
        expect(success, isNot(equals(error)));
        expect(cancelled, isNot(equals(timeout)));
        expect(cancelled, isNot(equals(error)));
        expect(timeout, isNot(equals(error)));
      });

      test('identical result should equal itself', () {
        const result = PaymentWebViewResult.success({'test': 'data'});

        expect(result, equals(result));
      });

      test('result should not equal non-PaymentWebViewResult', () {
        const result = PaymentWebViewResult.success({});
        // ignore: unrelated_type_equality_checks
        final equalsString = result == ('not a result' as Object);
        // ignore: unrelated_type_equality_checks
        final equalsInt = result == (123 as Object);
        const Object? nullObj = null;
        const equalsNull = result == nullObj;

        expect(equalsString, isFalse);
        expect(equalsInt, isFalse);
        expect(equalsNull, isFalse);
      });
    });

    group('callback data map equality', () {
      test('should handle null callback data in both', () {
        const result1 = PaymentWebViewResult.cancelled();
        const result2 = PaymentWebViewResult.cancelled();

        expect(result1, equals(result2));
      });

      test('should handle callback data with multiple keys', () {
        const result1 = PaymentWebViewResult.success({
          'key1': 'value1',
          'key2': 'value2',
          'key3': 'value3',
        });
        const result2 = PaymentWebViewResult.success({
          'key1': 'value1',
          'key2': 'value2',
          'key3': 'value3',
        });

        expect(result1, equals(result2));
      });

      test('should detect different map lengths', () {
        const result1 = PaymentWebViewResult.success({'key1': 'value1'});
        const result2 = PaymentWebViewResult.success({
          'key1': 'value1',
          'key2': 'value2',
        });

        expect(result1, isNot(equals(result2)));
      });

      test('should detect different keys', () {
        const result1 = PaymentWebViewResult.success({'keyA': 'value'});
        const result2 = PaymentWebViewResult.success({'keyB': 'value'});

        expect(result1, isNot(equals(result2)));
      });
    });
  });
}
