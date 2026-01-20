import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub/src/core/network/circuit_breaker.dart';
import 'package:tr_payment_hub/src/core/network/network_client.dart';
import 'package:tr_payment_hub/src/core/network/resilient_network_client.dart';
import 'package:tr_payment_hub/src/core/network/retry_handler.dart';

/// Mock NetworkClient for testing
class MockNetworkClient implements NetworkClient {
  int callCount = 0;
  bool shouldFail = false;
  int failUntilAttempt = 0;
  Exception? exception;

  @override
  Future<NetworkResponse> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    callCount++;
    if (shouldFail || (failUntilAttempt > 0 && callCount < failUntilAttempt)) {
      throw exception ?? TimeoutException('Mock timeout');
    }
    return NetworkResponse.success('{"status": "ok"}');
  }

  @override
  Future<NetworkResponse> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    callCount++;
    if (shouldFail || (failUntilAttempt > 0 && callCount < failUntilAttempt)) {
      throw exception ?? TimeoutException('Mock timeout');
    }
    return NetworkResponse.success('{"status": "ok"}');
  }

  @override
  Future<NetworkResponse> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    callCount++;
    if (shouldFail || (failUntilAttempt > 0 && callCount < failUntilAttempt)) {
      throw exception ?? TimeoutException('Mock timeout');
    }
    return NetworkResponse.success('{"status": "ok"}');
  }

  @override
  Future<NetworkResponse> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    callCount++;
    if (shouldFail || (failUntilAttempt > 0 && callCount < failUntilAttempt)) {
      throw exception ?? TimeoutException('Mock timeout');
    }
    return NetworkResponse.success('{"status": "ok"}');
  }

  @override
  Future<NetworkResponse> postForm(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    callCount++;
    if (shouldFail || (failUntilAttempt > 0 && callCount < failUntilAttempt)) {
      throw exception ?? TimeoutException('Mock timeout');
    }
    return NetworkResponse.success('{"status": "ok"}');
  }

  @override
  void dispose() {}

  void reset() {
    callCount = 0;
    shouldFail = false;
    failUntilAttempt = 0;
    exception = null;
  }
}

void main() {
  group('ResilienceConfig', () {
    test('should have correct defaults', () {
      const config = ResilienceConfig();
      expect(config.enableRetry, isTrue);
      expect(config.enableCircuitBreaker, isTrue);
    });

    test('disabled should disable both retry and circuit breaker', () {
      const config = ResilienceConfig.disabled;
      expect(config.enableRetry, isFalse);
      expect(config.enableCircuitBreaker, isFalse);
    });

    test('forPayments should use conservative retry', () {
      const config = ResilienceConfig.forPayments;
      expect(config.retryConfig.maxAttempts, equals(2));
      expect(config.circuitBreakerConfig.failureThreshold, equals(3));
    });

    test('forQueries should use aggressive retry', () {
      const config = ResilienceConfig.forQueries;
      expect(config.retryConfig.initialDelay.inMilliseconds, equals(300));
      expect(config.circuitBreakerConfig.failureThreshold, equals(10));
    });
  });

  group('ResilienceEvent', () {
    test('should contain correct data', () {
      const event = ResilienceEvent(
        type: ResilienceEventType.retryAttempt,
        circuitName: 'test',
        attemptNumber: 1,
        error: 'Test error',
        delay: Duration(seconds: 1),
      );

      expect(event.type, equals(ResilienceEventType.retryAttempt));
      expect(event.circuitName, equals('test'));
      expect(event.attemptNumber, equals(1));
      expect(event.error, equals('Test error'));
      expect(event.delay, equals(const Duration(seconds: 1)));
    });

    test('toString should include relevant info', () {
      const event = ResilienceEvent(
        type: ResilienceEventType.circuitOpened,
        circuitName: 'iyzico',
      );

      expect(event.toString(), contains('circuitOpened'));
      expect(event.toString(), contains('iyzico'));
    });
  });

  group('ResilientNetworkClient', () {
    late MockNetworkClient mockClient;

    setUp(() {
      mockClient = MockNetworkClient();
    });

    tearDown(() {
      mockClient.reset();
    });

    test('should pass through successful requests', () async {
      final resilientClient = ResilientNetworkClient(
        client: mockClient,
        circuitName: 'test',
      );

      final response = await resilientClient.post('https://api.test.com');

      expect(response.isSuccess, isTrue);
      expect(mockClient.callCount, equals(1));
    });

    test('should retry on failure with retry enabled', () async {
      mockClient.failUntilAttempt = 2; // Fail first, succeed second

      final resilientClient = ResilientNetworkClient(
        client: mockClient,
        circuitName: 'test',
        config: ResilienceConfig(
          retryConfig: const RetryConfig(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 1), // Fast for tests
          ),
          enableCircuitBreaker: false, // Disable for this test
        ),
      );

      final response = await resilientClient.post('https://api.test.com');

      expect(response.isSuccess, isTrue);
      expect(mockClient.callCount, equals(2)); // First failed, second succeeded
    });

    test('should emit retry events', () async {
      mockClient.failUntilAttempt = 2;
      final events = <ResilienceEvent>[];

      final resilientClient = ResilientNetworkClient(
        client: mockClient,
        circuitName: 'test',
        config: ResilienceConfig(
          retryConfig: const RetryConfig(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 1),
          ),
          enableCircuitBreaker: false,
        ),
        onEvent: events.add,
      );

      await resilientClient.post('https://api.test.com');

      expect(events.length, equals(1));
      expect(events.first.type, equals(ResilienceEventType.retryAttempt));
      expect(events.first.attemptNumber, equals(1));
    });

    test('should respect circuit breaker state', () async {
      mockClient.shouldFail = true;

      final resilientClient = ResilientNetworkClient(
        client: mockClient,
        circuitName: 'test_circuit',
        config: ResilienceConfig(
          enableRetry: false, // Disable retry for this test
          circuitBreakerConfig: const CircuitBreakerConfig(
            failureThreshold: 3,
            timeout: Duration(seconds: 10),
          ),
        ),
      );

      // Trigger failures to open circuit
      for (var i = 0; i < 3; i++) {
        try {
          await resilientClient.post('https://api.test.com');
        } catch (_) {}
      }

      expect(resilientClient.isCircuitOpen, isTrue);
      expect(resilientClient.circuitState, equals(CircuitState.open));

      // Next call should throw CircuitBreakerOpenException
      expect(
        () => resilientClient.post('https://api.test.com'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('should allow manual circuit reset', () async {
      mockClient.shouldFail = true;

      final resilientClient = ResilientNetworkClient(
        client: mockClient,
        circuitName: 'reset_test',
        config: ResilienceConfig(
          enableRetry: false,
          circuitBreakerConfig: const CircuitBreakerConfig(failureThreshold: 2),
        ),
      );

      // Trigger failures to open circuit
      for (var i = 0; i < 2; i++) {
        try {
          await resilientClient.post('https://api.test.com');
        } catch (_) {}
      }

      expect(resilientClient.isCircuitOpen, isTrue);

      // Reset the circuit
      resilientClient.resetCircuit();

      expect(resilientClient.isCircuitOpen, isFalse);
      expect(resilientClient.circuitState, equals(CircuitState.closed));
    });

    test('should allow force opening circuit', () async {
      final resilientClient = ResilientNetworkClient(
        client: mockClient,
        circuitName: 'force_test',
      );

      expect(resilientClient.isCircuitOpen, isFalse);

      resilientClient.forceCircuitOpen();

      expect(resilientClient.isCircuitOpen, isTrue);
    });

    test('should work without resilience when disabled', () async {
      final resilientClient = ResilientNetworkClient(
        client: mockClient,
        circuitName: 'disabled_test',
        config: ResilienceConfig.disabled,
      );

      expect(resilientClient.circuitState, isNull);

      final response = await resilientClient.post('https://api.test.com');
      expect(response.isSuccess, isTrue);
    });
  });

  group('ResilientNetworkClientExtension', () {
    test('withResilience should wrap client correctly', () {
      final mockClient = MockNetworkClient();
      final resilientClient = mockClient.withResilience(
        circuitName: 'extension_test',
        config: ResilienceConfig.forPayments,
      );

      expect(resilientClient, isA<ResilientNetworkClient>());
      expect(resilientClient.client, equals(mockClient));
    });
  });
}
