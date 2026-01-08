import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('CircuitBreakerConfig', () {
    test('should have correct default values', () {
      const config = CircuitBreakerConfig();

      expect(config.failureThreshold, 5);
      expect(config.successThreshold, 2);
      expect(config.timeout, const Duration(seconds: 30));
    });

    test('should allow custom values', () {
      const config = CircuitBreakerConfig(
        failureThreshold: 3,
        successThreshold: 1,
        timeout: Duration(seconds: 60),
      );

      expect(config.failureThreshold, 3);
      expect(config.successThreshold, 1);
      expect(config.timeout, const Duration(seconds: 60));
    });

    test('strict config should have lower threshold', () {
      expect(CircuitBreakerConfig.strict.failureThreshold, 3);
    });

    test('lenient config should have higher threshold', () {
      expect(CircuitBreakerConfig.lenient.failureThreshold, 10);
    });
  });

  group('CircuitState', () {
    test('should have all expected states', () {
      expect(CircuitState.values, contains(CircuitState.closed));
      expect(CircuitState.values, contains(CircuitState.open));
      expect(CircuitState.values, contains(CircuitState.halfOpen));
    });
  });

  group('CircuitBreaker', () {
    test('should start in closed state', () {
      final breaker = CircuitBreaker(name: 'test');

      expect(breaker.state, CircuitState.closed);
      expect(breaker.isClosed, true);
      expect(breaker.isOpen, false);
      expect(breaker.name, 'test');
    });

    test('should execute operation successfully when closed', () async {
      final breaker = CircuitBreaker(name: 'test');

      final result = await breaker.execute(() async => 'success');

      expect(result, 'success');
      expect(breaker.state, CircuitState.closed);
    });

    test('should open after failure threshold', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(failureThreshold: 2),
      );

      // First failure
      try {
        await breaker.execute(() async => throw Exception('Error 1'));
      } catch (_) {}

      expect(breaker.state, CircuitState.closed);

      // Second failure - should open
      try {
        await breaker.execute(() async => throw Exception('Error 2'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);
      expect(breaker.isOpen, true);
    });

    test('should throw CircuitBreakerOpenException when open', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 1,
          timeout: Duration(seconds: 60),
        ),
      );

      // Trigger open state
      try {
        await breaker.execute(() async => throw Exception('Error'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);

      // Should throw CircuitBreakerOpenException
      expect(
        () => breaker.execute(() async => 'success'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('CircuitBreakerOpenException should have remaining time', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 1,
          timeout: Duration(seconds: 30),
        ),
      );

      // Trigger open state
      try {
        await breaker.execute(() async => throw Exception('Error'));
      } catch (_) {}

      try {
        await breaker.execute(() async => 'success');
      } on CircuitBreakerOpenException catch (e) {
        expect(e.remainingTime.inSeconds, greaterThan(0));
        expect(e.remainingTime.inSeconds, lessThanOrEqualTo(30));
        expect(e.circuitName, 'test');
        expect(e.userFriendlyMessage, contains('saniye'));
      }
    });

    test('should transition to half-open after timeout', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 1,
          successThreshold: 1,
          timeout: Duration(milliseconds: 50),
        ),
      );

      // Trigger open state
      try {
        await breaker.execute(() async => throw Exception('Error'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);

      // Wait for timeout
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Next call should be allowed (half-open) and close the breaker after success
      final result = await breaker.execute(() async => 'success');

      expect(result, 'success');
      expect(breaker.state, CircuitState.closed);
    });

    test('should close after success in half-open state', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 1,
          successThreshold: 1,
          timeout: Duration(milliseconds: 50),
        ),
      );

      // Trigger open state
      try {
        await breaker.execute(() async => throw Exception('Error'));
      } catch (_) {}

      // Wait for timeout to transition to half-open
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Success should close the breaker
      await breaker.execute(() async => 'success');

      expect(breaker.state, CircuitState.closed);
      expect(breaker.isClosed, true);
    });

    test('should re-open if failure in half-open state', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 1,
          timeout: Duration(milliseconds: 50),
        ),
      );

      // Trigger open state
      try {
        await breaker.execute(() async => throw Exception('Error 1'));
      } catch (_) {}

      // Wait for timeout
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Fail again in half-open state
      try {
        await breaker.execute(() async => throw Exception('Error 2'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);
    });

    test('should reset failure count on success', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(failureThreshold: 3),
      );

      // Two failures
      try {
        await breaker.execute(() async => throw Exception('Error 1'));
      } catch (_) {}
      try {
        await breaker.execute(() async => throw Exception('Error 2'));
      } catch (_) {}

      expect(breaker.failureCount, 2);

      // One success - should reset
      await breaker.execute(() async => 'success');

      expect(breaker.failureCount, 0);

      // Two more failures shouldn't open it
      try {
        await breaker.execute(() async => throw Exception('Error 3'));
      } catch (_) {}
      try {
        await breaker.execute(() async => throw Exception('Error 4'));
      } catch (_) {}

      expect(breaker.state, CircuitState.closed);
    });

    test('reset should close the breaker', () async {
      final breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(failureThreshold: 1),
      );

      // Trigger open state
      try {
        await breaker.execute(() async => throw Exception('Error'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);

      breaker.reset();

      expect(breaker.state, CircuitState.closed);
    });

    test('forceOpen should open the breaker', () {
      final breaker = CircuitBreaker(name: 'test');

      expect(breaker.state, CircuitState.closed);

      breaker.forceOpen();

      expect(breaker.state, CircuitState.open);
    });

    test('toString should return meaningful string', () {
      final breaker = CircuitBreaker(name: 'payment-service');

      expect(breaker.toString(), contains('payment-service'));
      expect(breaker.toString(), contains('closed'));
    });
  });

  group('CircuitBreakerOpenException', () {
    test('should have correct properties', () {
      const exception = CircuitBreakerOpenException(
        circuitName: 'payment-service',
        remainingTime: Duration(seconds: 25),
      );

      expect(exception.circuitName, 'payment-service');
      expect(exception.remainingTime, const Duration(seconds: 25));
    });

    test('toString should contain circuit name', () {
      const exception = CircuitBreakerOpenException(
        circuitName: 'test',
        remainingTime: Duration(seconds: 10),
      );

      expect(exception.toString(), contains('test'));
      expect(exception.toString(), contains('10'));
    });

    test('userFriendlyMessage should be Turkish', () {
      const exception = CircuitBreakerOpenException(
        circuitName: 'test',
        remainingTime: Duration(seconds: 10),
      );

      expect(exception.userFriendlyMessage, contains('saniye'));
    });
  });

  group('CircuitBreakerManager', () {
    setUp(() {
      // Clean up before each test
      CircuitBreakerManager.remove('test1');
      CircuitBreakerManager.remove('test2');
    });

    test('should create and return same breaker', () {
      final breaker1 = CircuitBreakerManager.getBreaker('test1');
      final breaker2 = CircuitBreakerManager.getBreaker('test1');

      expect(identical(breaker1, breaker2), true);
    });

    test('should get existing breaker', () {
      CircuitBreakerManager.getBreaker('test1');
      final breaker = CircuitBreakerManager.get('test1');

      expect(breaker, isNotNull);
      expect(breaker!.name, 'test1');
    });

    test('should return null for non-existing breaker', () {
      final breaker = CircuitBreakerManager.get('non-existing');

      expect(breaker, isNull);
    });

    test('should reset all breakers', () async {
      final breaker1 = CircuitBreakerManager.getBreaker(
        'test1',
        config: const CircuitBreakerConfig(failureThreshold: 1),
      );
      final breaker2 = CircuitBreakerManager.getBreaker(
        'test2',
        config: const CircuitBreakerConfig(failureThreshold: 1),
      );

      // Open both
      try {
        await breaker1.execute(() async => throw Exception('Error'));
      } catch (_) {}
      try {
        await breaker2.execute(() async => throw Exception('Error'));
      } catch (_) {}

      expect(breaker1.isOpen, true);
      expect(breaker2.isOpen, true);

      CircuitBreakerManager.resetAll();

      expect(breaker1.isClosed, true);
      expect(breaker2.isClosed, true);
    });

    test('should get status of all breakers', () {
      CircuitBreakerManager.getBreaker('test1');
      CircuitBreakerManager.getBreaker('test2');

      final status = CircuitBreakerManager.status;

      expect(status['test1'], CircuitState.closed);
      expect(status['test2'], CircuitState.closed);
    });

    test('should remove breaker', () {
      CircuitBreakerManager.getBreaker('test1');
      expect(CircuitBreakerManager.get('test1'), isNotNull);

      CircuitBreakerManager.remove('test1');
      expect(CircuitBreakerManager.get('test1'), isNull);
    });
  });
}
