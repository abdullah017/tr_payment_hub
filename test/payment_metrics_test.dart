import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub/src/core/enums.dart';
import 'package:tr_payment_hub/src/core/metrics/payment_metrics.dart';

void main() {
  group('MetricEvent', () {
    test('should create with required fields', () {
      final event = MetricEvent(
        name: 'test.metric',
        provider: ProviderType.iyzico,
        timestamp: DateTime(2024, 1, 1),
      );

      expect(event.name, equals('test.metric'));
      expect(event.provider, equals(ProviderType.iyzico));
      expect(event.timestamp, equals(DateTime(2024, 1, 1)));
      expect(event.value, isNull);
      expect(event.duration, isNull);
      expect(event.tags, isEmpty);
    });

    test('should create with optional fields', () {
      final event = MetricEvent(
        name: 'test.metric',
        provider: ProviderType.paytr,
        timestamp: DateTime.now(),
        value: 100.0,
        duration: const Duration(seconds: 2),
        tags: {'key': 'value'},
      );

      expect(event.value, equals(100.0));
      expect(event.duration, equals(const Duration(seconds: 2)));
      expect(event.tags['key'], equals('value'));
    });

    test('toString should contain name and provider', () {
      final event = MetricEvent(
        name: 'payment.success',
        provider: ProviderType.iyzico,
        timestamp: DateTime.now(),
      );

      expect(event.toString(), contains('payment.success'));
      expect(event.toString(), contains('iyzico'));
    });
  });

  group('MetricNames', () {
    test('should have payment metrics', () {
      expect(MetricNames.paymentAttempt, equals('payment.attempt'));
      expect(MetricNames.paymentSuccess, equals('payment.success'));
      expect(MetricNames.paymentFailed, equals('payment.failed'));
    });

    test('should have 3DS metrics', () {
      expect(MetricNames.threeDSInitAttempt, equals('3ds.init.attempt'));
      expect(
          MetricNames.threeDSCompleteSuccess, equals('3ds.complete.success'));
    });

    test('should have resilience metrics', () {
      expect(MetricNames.retryAttempt, equals('resilience.retry'));
      expect(MetricNames.circuitOpened, equals('resilience.circuit.opened'));
    });
  });

  group('AggregatedMetrics', () {
    test('should calculate success rate', () {
      final metrics = AggregatedMetrics(
        provider: ProviderType.iyzico,
        periodStart: DateTime.now(),
        periodEnd: DateTime.now(),
        totalRequests: 100,
        successfulRequests: 85,
        failedRequests: 15,
      );

      expect(metrics.successRate, equals(85.0));
      expect(metrics.failureRate, equals(15.0));
    });

    test('should handle zero requests', () {
      final metrics = AggregatedMetrics(
        provider: ProviderType.iyzico,
        periodStart: DateTime.now(),
        periodEnd: DateTime.now(),
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
      );

      expect(metrics.successRate, equals(0.0));
      expect(metrics.failureRate, equals(0.0));
    });
  });

  group('InMemoryMetricsCollector', () {
    late InMemoryMetricsCollector collector;

    setUp(() {
      collector = InMemoryMetricsCollector();
    });

    tearDown(() {
      collector.dispose();
    });

    test('should record metric events', () {
      collector.record(
        MetricEvent(
          name: 'test.metric',
          provider: ProviderType.iyzico,
          timestamp: DateTime.now(),
        ),
      );

      final events = collector.getEvents();
      expect(events.length, equals(1));
      expect(events.first.name, equals('test.metric'));
    });

    test('should increment counters', () {
      collector.increment(
        MetricNames.paymentAttempt,
        provider: ProviderType.iyzico,
      );
      collector.increment(
        MetricNames.paymentAttempt,
        provider: ProviderType.iyzico,
      );

      final events = collector.getEvents(name: MetricNames.paymentAttempt);
      expect(events.length, equals(2));
    });

    test('should record timing', () {
      collector.timing(
        MetricNames.paymentDuration,
        provider: ProviderType.paytr,
        duration: const Duration(milliseconds: 500),
      );

      final events = collector.getEvents();
      expect(events.first.duration?.inMilliseconds, equals(500));
    });

    test('should record gauge values', () {
      collector.gauge(
        'active.sessions',
        provider: ProviderType.sipay,
        value: 42.0,
      );

      final events = collector.getEvents();
      expect(events.first.value, equals(42.0));
    });

    test('should filter events by provider', () {
      collector.increment('test', provider: ProviderType.iyzico);
      collector.increment('test', provider: ProviderType.paytr);
      collector.increment('test', provider: ProviderType.iyzico);

      final iyzicoEvents = collector.getEvents(provider: ProviderType.iyzico);
      expect(iyzicoEvents.length, equals(2));
    });

    test('should filter events by name', () {
      collector.increment('metric.a', provider: ProviderType.iyzico);
      collector.increment('metric.b', provider: ProviderType.iyzico);
      collector.increment('metric.a', provider: ProviderType.iyzico);

      final events = collector.getEvents(name: 'metric.a');
      expect(events.length, equals(2));
    });

    test('should filter events by time', () {
      final now = DateTime.now();

      collector.record(
        MetricEvent(
          name: 'old',
          provider: ProviderType.iyzico,
          timestamp: now.subtract(const Duration(hours: 2)),
        ),
      );
      collector.record(
        MetricEvent(
          name: 'recent',
          provider: ProviderType.iyzico,
          timestamp: now,
        ),
      );

      final recentEvents = collector.getEvents(
        since: now.subtract(const Duration(hours: 1)),
      );
      expect(recentEvents.length, equals(1));
      expect(recentEvents.first.name, equals('recent'));
    });

    test('should respect max events limit', () {
      final collector = InMemoryMetricsCollector(maxEvents: 5);

      for (var i = 0; i < 10; i++) {
        collector.increment('test.$i', provider: ProviderType.iyzico);
      }

      final events = collector.getEvents();
      expect(events.length, equals(5));
      // Should keep the most recent events
      expect(events.first.name, equals('test.5'));
    });

    test('should call onEvent callback', () {
      final receivedEvents = <MetricEvent>[];
      final collector = InMemoryMetricsCollector(
        onEvent: receivedEvents.add,
      );

      collector.increment('test', provider: ProviderType.iyzico);
      collector.increment('test', provider: ProviderType.iyzico);

      expect(receivedEvents.length, equals(2));
    });

    test('should aggregate metrics by provider', () {
      // Payment attempts
      collector.increment(MetricNames.paymentAttempt,
          provider: ProviderType.iyzico);
      collector.increment(MetricNames.paymentAttempt,
          provider: ProviderType.iyzico);
      collector.increment(MetricNames.paymentAttempt,
          provider: ProviderType.iyzico);

      // Successes
      collector.increment(MetricNames.paymentSuccess,
          provider: ProviderType.iyzico, value: 100);
      collector.increment(MetricNames.paymentSuccess,
          provider: ProviderType.iyzico, value: 200);

      // Failure
      collector.increment(
        MetricNames.paymentFailed,
        provider: ProviderType.iyzico,
        tags: {'error_code': 'declined'},
      );

      final aggregated = collector.getAggregated(ProviderType.iyzico);

      expect(aggregated, isNotNull);
      expect(aggregated!.totalRequests, equals(3));
      expect(aggregated.successfulRequests, equals(2));
      expect(aggregated.failedRequests, equals(1));
      expect(aggregated.totalAmount, equals(300.0));
    });

    test('should clear all metrics', () {
      collector.increment('test', provider: ProviderType.iyzico);
      collector.increment('test', provider: ProviderType.paytr);

      collector.clear();

      expect(collector.getEvents(), isEmpty);
      expect(collector.getAggregated(ProviderType.iyzico), isNull);
    });
  });

  group('MetricsTimer', () {
    test('should record duration when stopped', () async {
      final collector = InMemoryMetricsCollector();
      final timer = MetricsTimer(
        collector: collector,
        name: 'operation.duration',
        provider: ProviderType.iyzico,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      timer.stop();

      final events = collector.getEvents();
      expect(events.length, equals(1));
      expect(events.first.duration, isNotNull);
      expect(events.first.duration!.inMilliseconds, greaterThanOrEqualTo(40));
    });

    test('should include additional tags when stopped', () {
      final collector = InMemoryMetricsCollector();
      final timer = MetricsTimer(
        collector: collector,
        name: 'test',
        provider: ProviderType.iyzico,
        tags: {'initial': 'tag'},
      );

      timer.stop(additionalTags: {'status': 'success'});

      final event = collector.getEvents().first;
      expect(event.tags['initial'], equals('tag'));
      expect(event.tags['status'], equals('success'));
    });
  });

  group('MetricsTimingExtension', () {
    test('should record timing for successful future', () async {
      final collector = InMemoryMetricsCollector();

      final result = await Future.value(42).withMetrics(
        collector,
        name: 'async.operation',
        provider: ProviderType.iyzico,
      );

      expect(result, equals(42));
      final events = collector.getEvents();
      expect(events.length, equals(1));
      expect(events.first.tags['error'], isNull);
    });

    test('should record timing for failed future with error tag', () async {
      final collector = InMemoryMetricsCollector();

      try {
        await Future<void>.error('Test error').withMetrics(
          collector,
          name: 'failing.operation',
          provider: ProviderType.iyzico,
        );
        fail('Should have thrown');
      } catch (e) {
        expect(e, equals('Test error'));
      }

      final events = collector.getEvents();
      expect(events.length, equals(1));
      expect(events.first.tags['error'], equals('true'));
    });
  });
}
