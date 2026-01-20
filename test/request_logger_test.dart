import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub/src/core/logging/payment_logger.dart';
import 'package:tr_payment_hub/src/core/logging/request_logger.dart';

void main() {
  group('RequestLoggerConfig', () {
    test('should have correct defaults', () {
      const config = RequestLoggerConfig();

      expect(config.logRequests, isTrue);
      expect(config.logResponses, isTrue);
      expect(config.logHeaders, isFalse);
      expect(config.logBody, isTrue);
      expect(config.maxBodyLength, equals(1000));
    });

    test('minimal config should not log headers or body', () {
      const config = RequestLoggerConfig.minimal;

      expect(config.logRequests, isTrue);
      expect(config.logResponses, isTrue);
      expect(config.logHeaders, isFalse);
      expect(config.logBody, isFalse);
    });

    test('full config should log everything', () {
      const config = RequestLoggerConfig.full;

      expect(config.logRequests, isTrue);
      expect(config.logResponses, isTrue);
      expect(config.logHeaders, isTrue);
      expect(config.logBody, isTrue);
      expect(config.maxBodyLength, equals(5000));
    });
  });

  group('RequestLogEntry', () {
    test('should create with required fields', () {
      final entry = RequestLogEntry(
        method: 'POST',
        url: 'https://api.example.com/payment',
        timestamp: DateTime.now(),
      );

      expect(entry.method, equals('POST'));
      expect(entry.url, equals('https://api.example.com/payment'));
      expect(entry.statusCode, isNull);
      expect(entry.isSuccess, isFalse);
      expect(entry.isError, isFalse);
    });

    test('should detect success status code', () {
      final entry = RequestLogEntry(
        method: 'POST',
        url: 'https://api.example.com/payment',
        timestamp: DateTime.now(),
        statusCode: 200,
      );

      expect(entry.isSuccess, isTrue);
      expect(entry.isError, isFalse);
    });

    test('should detect error status code', () {
      final entry = RequestLogEntry(
        method: 'POST',
        url: 'https://api.example.com/payment',
        timestamp: DateTime.now(),
        statusCode: 400,
      );

      expect(entry.isSuccess, isFalse);
      expect(entry.isError, isTrue);
    });

    test('should detect error from error field', () {
      final entry = RequestLogEntry(
        method: 'POST',
        url: 'https://api.example.com/payment',
        timestamp: DateTime.now(),
        error: 'Connection timeout',
      );

      expect(entry.isSuccess, isFalse);
      expect(entry.isError, isTrue);
    });

    test('toString should include method and url', () {
      final entry = RequestLogEntry(
        method: 'POST',
        url: 'https://api.example.com/payment',
        timestamp: DateTime.now(),
        statusCode: 200,
        duration: const Duration(milliseconds: 150),
      );

      final str = entry.toString();
      expect(str, contains('POST'));
      expect(str, contains('https://api.example.com/payment'));
      expect(str, contains('200'));
      expect(str, contains('150ms'));
    });

    test('toMap should include all fields', () {
      final timestamp = DateTime.now();
      final entry = RequestLogEntry(
        method: 'POST',
        url: 'https://api.example.com/payment',
        timestamp: timestamp,
        statusCode: 200,
        body: '{"amount": 100}',
        response: '{"success": true}',
        duration: const Duration(milliseconds: 150),
      );

      final map = entry.toMap();
      expect(map['method'], equals('POST'));
      expect(map['url'], equals('https://api.example.com/payment'));
      expect(map['statusCode'], equals(200));
      expect(map['body'], equals('{"amount": 100}'));
      expect(map['response'], equals('{"success": true}'));
      expect(map['durationMs'], equals(150));
    });
  });

  group('RequestLogger', () {
    late RequestLogger logger;
    late List<RequestLogEntry> loggedEntries;

    setUp(() {
      loggedEntries = [];
      logger = RequestLogger(
        onLog: loggedEntries.add,
      );
    });

    test('should log request', () {
      logger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
        body: '{"amount": 100}',
      );

      expect(loggedEntries.length, equals(1));
      expect(loggedEntries.first.method, equals('POST'));
      expect(
          loggedEntries.first.url, equals('https://api.example.com/payment'));
      expect(loggedEntries.first.body, equals('{"amount": 100}'));
    });

    test('should log response', () {
      logger.logResponse(
        method: 'POST',
        url: 'https://api.example.com/payment',
        statusCode: 200,
        body: '{"success": true}',
        duration: const Duration(milliseconds: 150),
      );

      expect(loggedEntries.length, equals(1));
      expect(loggedEntries.first.statusCode, equals(200));
      expect(loggedEntries.first.response, equals('{"success": true}'));
      expect(loggedEntries.first.duration?.inMilliseconds, equals(150));
    });

    test('should log error', () {
      logger.logError(
        method: 'POST',
        url: 'https://api.example.com/payment',
        error: 'Connection timeout',
        duration: const Duration(milliseconds: 5000),
      );

      expect(loggedEntries.length, equals(1));
      expect(loggedEntries.first.error, equals('Connection timeout'));
      expect(loggedEntries.first.isError, isTrue);
    });

    test('should not log when logRequests is false', () {
      final quietLogger = RequestLogger(
        config: const RequestLoggerConfig(logRequests: false),
        onLog: loggedEntries.add,
      );

      quietLogger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
      );

      expect(loggedEntries, isEmpty);
    });

    test('should not log when logResponses is false', () {
      final quietLogger = RequestLogger(
        config: const RequestLoggerConfig(logResponses: false),
        onLog: loggedEntries.add,
      );

      quietLogger.logResponse(
        method: 'POST',
        url: 'https://api.example.com/payment',
        statusCode: 200,
      );

      expect(loggedEntries, isEmpty);
    });

    test('should sanitize sensitive data in body', () {
      logger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
        body: '{"cardNumber": "5528790000000008", "cvv": "123"}',
      );

      // Card number should be masked (LogSanitizer masks middle digits with X)
      expect(loggedEntries.first.body, contains('5528'));
      expect(loggedEntries.first.body, contains('0008'));
      expect(loggedEntries.first.body, isNot(contains('5528790000000008')));
      // CVV should be masked with ***
      expect(loggedEntries.first.body, contains('***'));
    });

    test('should sanitize sensitive headers', () {
      final headerLogger = RequestLogger(
        config: const RequestLoggerConfig(logHeaders: true),
        onLog: loggedEntries.add,
      );

      headerLogger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer secret_token_12345',
        },
      );

      final headers = loggedEntries.first.headers!;
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['Authorization'], contains('MASKED'));
      expect(headers['Authorization'], isNot(contains('secret_token_12345')));
    });

    test('should truncate long body', () {
      final shortLogger = RequestLogger(
        config: const RequestLoggerConfig(maxBodyLength: 50),
        onLog: loggedEntries.add,
      );

      shortLogger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
        body: 'A' * 100,
      );

      expect(loggedEntries.first.body!.length, lessThan(100));
      expect(loggedEntries.first.body, contains('TRUNCATED'));
    });

    test('should not include body when logBody is false', () {
      final noBodyLogger = RequestLogger(
        config: const RequestLoggerConfig(logBody: false),
        onLog: loggedEntries.add,
      );

      noBodyLogger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
        body: '{"amount": 100}',
      );

      expect(loggedEntries.first.body, isNull);
    });

    test('should not include headers when logHeaders is false', () {
      logger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
        headers: {'Content-Type': 'application/json'},
      );

      expect(loggedEntries.first.headers, isNull);
    });
  });

  group('RequestLogger with PaymentLogger', () {
    late List<LogEntry> paymentLogs;

    setUp(() {
      paymentLogs = [];
      PaymentLogger.initialize(
        logCallback: paymentLogs.add,
        minLevel: LogLevel.debug,
      );
    });

    tearDown(() {
      PaymentLogger.reset();
    });

    test('should log to PaymentLogger when initialized', () {
      final logger = RequestLogger();

      logger.logRequest(
        method: 'POST',
        url: 'https://api.example.com/payment',
      );

      expect(paymentLogs.length, equals(1));
      expect(paymentLogs.first.message, contains('HTTP Request'));
      expect(paymentLogs.first.message, contains('POST'));
    });

    test('should log error to PaymentLogger with error level', () {
      final logger = RequestLogger();

      logger.logError(
        method: 'POST',
        url: 'https://api.example.com/payment',
        error: 'Connection timeout',
      );

      expect(paymentLogs.length, equals(1));
      expect(paymentLogs.first.level, equals(LogLevel.error));
    });

    test('should log 4xx/5xx responses as warnings', () {
      final logger = RequestLogger();

      logger.logResponse(
        method: 'POST',
        url: 'https://api.example.com/payment',
        statusCode: 400,
      );

      expect(paymentLogs.length, equals(1));
      expect(paymentLogs.first.level, equals(LogLevel.warning));
    });
  });
}
