import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('RetryConfig', () {
    test('should have correct default values', () {
      const config = RetryConfig();

      expect(config.maxAttempts, 3);
      expect(config.initialDelay, const Duration(milliseconds: 500));
      expect(config.maxDelay, const Duration(seconds: 10));
      expect(config.backoffMultiplier, 2.0);
      expect(config.retryableStatusCodes, contains(503));
    });

    test('noRetry should have maxAttempts of 1', () {
      expect(RetryConfig.noRetry.maxAttempts, 1);
    });

    test('conservative should be suitable for payments', () {
      const config = RetryConfig.conservative;

      expect(config.maxAttempts, 2);
      expect(config.retryableStatusCodes, contains(408)); // Timeout
      expect(config.retryableStatusCodes, contains(429)); // Rate limit
      expect(config.retryableStatusCodes, contains(503)); // Service unavailable
    });

    test('aggressive should have more retries', () {
      const config = RetryConfig.aggressive;

      expect(config.maxAttempts, 3);
      expect(config.backoffMultiplier, 2.5);
    });

    test('toString should return meaningful string', () {
      const config = RetryConfig();

      expect(config.toString(), contains('maxAttempts'));
      expect(config.toString(), contains('backoffMultiplier'));
    });
  });

  group('RetryHandler', () {
    test('should execute operation successfully without retry', () async {
      final handler = RetryHandler();
      var callCount = 0;

      final result = await handler.execute(() async {
        callCount++;
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 1);
    });

    test('should retry on failure and succeed', () async {
      final handler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      var callCount = 0;

      final result = await handler.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw const SocketException('Connection failed');
        }
        return 'success after retry';
      });

      expect(result, 'success after retry');
      expect(callCount, 2);
    });

    test('should fail after max attempts', () async {
      final handler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      var callCount = 0;

      expect(
        () => handler.execute(() async {
          callCount++;
          throw const SocketException('Connection failed');
        }),
        throwsA(isA<SocketException>()),
      );

      // Wait for retries to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(callCount, 3);
    });

    test('should call onRetry callback', () async {
      final handler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      var retryCalled = false;

      await handler.execute(
        () async {
          if (!retryCalled) {
            throw const SocketException('Connection failed');
          }
          return 'success';
        },
        onRetry: (attempt, error, delay) {
          retryCalled = true;
          expect(attempt, 1);
          expect(error, isA<SocketException>());
          expect(delay.inMilliseconds, greaterThan(0));
        },
      );

      expect(retryCalled, true);
    });

    test('should not retry non-retryable exceptions', () async {
      final handler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      var callCount = 0;

      expect(
        () => handler.execute(() async {
          callCount++;
          throw ArgumentError('Invalid argument');
        }),
        throwsA(isA<ArgumentError>()),
      );

      // Wait a bit to ensure no retries happened
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(callCount, 1); // Should not retry
    });

    test('should retry on TimeoutException', () async {
      final handler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      var callCount = 0;

      final result = await handler.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw TimeoutException('Request timed out');
        }
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 2);
    });

    test('should use custom shouldRetry predicate', () async {
      final handler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      var callCount = 0;

      final result = await handler.execute(
        () async {
          callCount++;
          if (callCount < 2) {
            throw Exception('Custom retriable error');
          }
          return 'success';
        },
        shouldRetry: (error) => error.toString().contains('retriable'),
      );

      expect(result, 'success');
      expect(callCount, 2);
    });

    test('should respect noRetry config', () async {
      final handler = RetryHandler(config: RetryConfig.noRetry);
      var callCount = 0;

      expect(
        () => handler.execute(() async {
          callCount++;
          throw const SocketException('Connection failed');
        }),
        throwsA(isA<SocketException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(callCount, 1);
    });

    test('isRetryableStatusCode should return correct values', () {
      final handler = RetryHandler();

      expect(handler.isRetryableStatusCode(200), false);
      expect(handler.isRetryableStatusCode(400), false);
      expect(handler.isRetryableStatusCode(408), true); // Request Timeout
      expect(handler.isRetryableStatusCode(429), true); // Too Many Requests
      expect(handler.isRetryableStatusCode(500), true); // Internal Server Error
      expect(handler.isRetryableStatusCode(502), true); // Bad Gateway
      expect(handler.isRetryableStatusCode(503), true); // Service Unavailable
      expect(handler.isRetryableStatusCode(504), true); // Gateway Timeout
    });
  });

  group('RetryExtension', () {
    test('should add retry capability using RetryHandler', () async {
      final handler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      var callCount = 0;

      final result = await handler.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw const SocketException('Connection failed');
        }
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 2);
    });
  });
}
