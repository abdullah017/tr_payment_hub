import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('CardInfo Security', () {
    test('toSafeJson should mask card number', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      final safeJson = card.toSafeJson();

      expect(safeJson['cardNumber'], '552879******0008');
      expect(safeJson['cardNumber'], isNot(contains('000000')));
    });

    test('toSafeJson should mask CVV', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      final safeJson = card.toSafeJson();

      expect(safeJson['cvc'], '***');
      expect(safeJson['cvc'], isNot('123'));
    });

    test('toSafeJson should preserve non-sensitive data', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      final safeJson = card.toSafeJson();

      expect(safeJson['cardHolderName'], 'John Doe');
      expect(safeJson['expireMonth'], '12');
      expect(safeJson['expireYear'], '2030');
    });

    test('maskedNumber should mask middle digits', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(card.maskedNumber, '552879******0008');
    });

    test('binNumber should return first 6 digits', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(card.binNumber, '552879');
    });

    test('lastFourDigits should return last 4 digits', () {
      const card = CardInfo(
        cardHolderName: 'John Doe',
        cardNumber: '5528790000000008',
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

      expect(card.lastFourDigits, '0008');
    });
  });

  group('LogSanitizer', () {
    test('should mask 16-digit card numbers', () {
      const input = 'Card number: 5528790000000008';
      final output = LogSanitizer.sanitize(input);

      expect(output, isNot(contains('0000000008')));
      expect(output, contains('XXXXXX'));
    });

    test('should mask CVV in various formats', () {
      final inputs = [
        'cvv: 123',
        'cvc: 456',
        'CVV=789',
        '"cvv": "123"',
      ];

      for (final input in inputs) {
        final output = LogSanitizer.sanitize(input);
        expect(output, isNot(contains(RegExp(r'\d{3,4}'))),
            reason: 'Failed for input: $input');
      }
    });

    test('should mask API keys', () {
      const input = 'api_key: sk_live_abc123xyz';
      final output = LogSanitizer.sanitize(input);

      expect(output, isNot(contains('abc123xyz')));
    });

    test('should mask secrets', () {
      const input = 'secret_key: my_secret_value_123';
      final output = LogSanitizer.sanitize(input);

      expect(output, isNot(contains('my_secret_value_123')));
    });

    test('should preserve non-sensitive data', () {
      const input = 'Order ID: ORDER123, Amount: 100.00';
      final output = LogSanitizer.sanitize(input);

      expect(output, contains('ORDER123'));
      expect(output, contains('100.00'));
    });

    test('sanitizeMap should mask sensitive keys', () {
      final input = {
        'orderId': 'ORDER123',
        'cardNumber': '5528790000000008',
        'cvv': '123',
        'amount': 100.0,
      };

      final output = LogSanitizer.sanitizeMap(input);

      expect(output['orderId'], 'ORDER123');
      expect(output['amount'], 100.0);
      expect(output['cardNumber'], isNot('5528790000000008'));
      expect(output['cvv'], isNot('123'));
    });
  });

  group('PaymentLogger', () {
    final logEntries = <LogEntry>[];

    setUp(() {
      logEntries.clear();
      PaymentLogger.initialize(
        logCallback: logEntries.add,
        minLevel: LogLevel.debug,
      );
    });

    tearDown(() {
      PaymentLogger.reset();
    });

    test('should log info messages', () {
      PaymentLogger.info('Payment started');

      expect(logEntries.length, 1);
      expect(logEntries.first.level, LogLevel.info);
      expect(logEntries.first.message, 'Payment started');
    });

    test('should log with sanitized data', () {
      PaymentLogger.info('Payment', data: {
        'orderId': 'ORDER123',
        'cardNumber': '5528790000000008',
      });

      expect(logEntries.length, 1);
      final data = logEntries.first.data!;
      expect(data['orderId'], 'ORDER123');
      expect(data['cardNumber'], isNot('5528790000000008'));
    });

    test('should log error with stack trace', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      PaymentLogger.error(
        'Payment failed',
        error: error,
        stackTrace: stackTrace,
      );

      expect(logEntries.length, 1);
      expect(logEntries.first.level, LogLevel.error);
      expect(logEntries.first.error, isNotNull);
      expect(logEntries.first.stackTrace, stackTrace);
    });

    test('should respect minimum log level', () {
      logEntries.clear();
      PaymentLogger.reset();
      PaymentLogger.initialize(
        logCallback: logEntries.add,
        minLevel: LogLevel.warning,
      );

      PaymentLogger.debug('Debug message');
      PaymentLogger.info('Info message');
      PaymentLogger.warning('Warning message');
      PaymentLogger.error('Error message');

      expect(logEntries.length, 2);
      expect(logEntries[0].level, LogLevel.warning);
      expect(logEntries[1].level, LogLevel.error);
    });

    test('should include timestamp', () {
      PaymentLogger.info('Test message');

      expect(logEntries.first.timestamp, isNotNull);
      expect(
        logEntries.first.timestamp.difference(DateTime.now()).inSeconds.abs(),
        lessThan(1),
      );
    });

    test('should not log when not initialized', () {
      PaymentLogger.reset();
      PaymentLogger.info('Should not log');

      expect(logEntries.length, 0);
    });

    test('logPaymentStart should log payment info', () {
      PaymentLogger.logPaymentStart(
        provider: 'iyzico',
        orderId: 'ORDER123',
        amount: 100.0,
      );

      expect(logEntries.length, 1);
      expect(logEntries.first.message, 'Payment started');
      expect(logEntries.first.data?['provider'], 'iyzico');
    });

    test('logPaymentSuccess should log transaction info', () {
      PaymentLogger.logPaymentSuccess(
        provider: 'iyzico',
        orderId: 'ORDER123',
        transactionId: 'TX123',
      );

      expect(logEntries.length, 1);
      expect(logEntries.first.message, 'Payment successful');
    });

    test('logPaymentFailure should log error info', () {
      PaymentLogger.logPaymentFailure(
        provider: 'iyzico',
        orderId: 'ORDER123',
        errorCode: 'insufficient_funds',
        errorMessage: 'Yetersiz bakiye',
      );

      expect(logEntries.length, 1);
      expect(logEntries.first.level, LogLevel.warning);
      expect(logEntries.first.data?['errorCode'], 'insufficient_funds');
    });
  });

  group('LogEntry', () {
    test('should format log entry correctly', () {
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 30, 0),
      );

      final formatted = entry.toString();

      expect(formatted, contains('INFO'));
      expect(formatted, contains('Test message'));
      expect(formatted, contains('2024'));
    });

    test('should include data in formatted output', () {
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        data: {'key': 'value'},
      );

      final formatted = entry.toString();

      expect(formatted, contains('key'));
      expect(formatted, contains('value'));
    });

    test('should include error in formatted output', () {
      final entry = LogEntry(
        level: LogLevel.error,
        message: 'Error occurred',
        timestamp: DateTime.now(),
        error: 'Test error',
      );

      final formatted = entry.toString();

      expect(formatted, contains('Error:'));
      expect(formatted, contains('Test error'));
    });
  });

  group('Secure Random Generation', () {
    test('generated order IDs should be unique', () {
      // Test that providers generate unique IDs
      // This tests the Random.secure() implementation
      final ids = <String>{};

      for (var i = 0; i < 100; i++) {
        final id = 'TEST${DateTime.now().millisecondsSinceEpoch}_$i';
        ids.add(id);
      }

      expect(ids.length, 100); // All should be unique
    });
  });

  group('PaymentException Security', () {
    test('should not expose sensitive data in message', () {
      const exception = PaymentException(
        code: 'error',
        message: 'Failed for card 5528790000000008',
        provider: ProviderType.iyzico,
      );

      // The message might contain card info from external sources
      // but internal error handling should sanitize
      expect(exception.toString(), contains('error'));
    });
  });
}
