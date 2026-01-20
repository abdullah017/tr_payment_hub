import 'dart:async';

import '../enums.dart';

/// Represents a single metric event.
class MetricEvent {
  /// Creates a metric event.
  MetricEvent({
    required this.name,
    required this.provider,
    required this.timestamp,
    this.value,
    this.tags = const {},
    this.duration,
  });

  /// Metric name (e.g., 'payment.success', 'payment.failed').
  final String name;

  /// Provider that generated this metric.
  final ProviderType provider;

  /// When this event occurred.
  final DateTime timestamp;

  /// Numeric value (e.g., amount, count).
  final double? value;

  /// Additional tags for filtering/grouping.
  final Map<String, String> tags;

  /// Duration if this is a timing metric.
  final Duration? duration;

  @override
  String toString() => 'MetricEvent($name, provider: $provider, '
      'value: $value, duration: ${duration?.inMilliseconds}ms)';
}

/// Predefined metric names for payment operations.
class MetricNames {
  MetricNames._();

  // Payment metrics
  static const paymentAttempt = 'payment.attempt';
  static const paymentSuccess = 'payment.success';
  static const paymentFailed = 'payment.failed';
  static const paymentDuration = 'payment.duration';

  // 3DS metrics
  static const threeDSInitAttempt = '3ds.init.attempt';
  static const threeDSInitSuccess = '3ds.init.success';
  static const threeDSInitFailed = '3ds.init.failed';
  static const threeDSCompleteAttempt = '3ds.complete.attempt';
  static const threeDSCompleteSuccess = '3ds.complete.success';
  static const threeDSCompleteFailed = '3ds.complete.failed';

  // Refund metrics
  static const refundAttempt = 'refund.attempt';
  static const refundSuccess = 'refund.success';
  static const refundFailed = 'refund.failed';

  // Installment query metrics
  static const installmentQuery = 'installment.query';
  static const installmentQueryFailed = 'installment.query.failed';

  // Network metrics
  static const networkRequest = 'network.request';
  static const networkError = 'network.error';
  static const networkTimeout = 'network.timeout';

  // Resilience metrics
  static const retryAttempt = 'resilience.retry';
  static const circuitOpened = 'resilience.circuit.opened';
  static const circuitClosed = 'resilience.circuit.closed';
  static const circuitRejected = 'resilience.circuit.rejected';

  // Saved card metrics
  static const savedCardCharge = 'savedcard.charge';
  static const savedCardList = 'savedcard.list';
  static const savedCardDelete = 'savedcard.delete';
}

/// Aggregated metrics for a time period.
class AggregatedMetrics {
  /// Creates aggregated metrics.
  AggregatedMetrics({
    required this.provider,
    required this.periodStart,
    required this.periodEnd,
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.totalAmount = 0,
    this.averageDuration = Duration.zero,
    this.errorsByType = const {},
  });

  /// Provider these metrics are for.
  final ProviderType provider;

  /// Start of the aggregation period.
  final DateTime periodStart;

  /// End of the aggregation period.
  final DateTime periodEnd;

  /// Total number of requests.
  final int totalRequests;

  /// Number of successful requests.
  final int successfulRequests;

  /// Number of failed requests.
  final int failedRequests;

  /// Total amount processed.
  final double totalAmount;

  /// Average request duration.
  final Duration averageDuration;

  /// Error counts by type.
  final Map<String, int> errorsByType;

  /// Success rate as a percentage (0-100).
  double get successRate =>
      totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0;

  /// Failure rate as a percentage (0-100).
  double get failureRate =>
      totalRequests > 0 ? (failedRequests / totalRequests) * 100 : 0;

  @override
  String toString() => 'AggregatedMetrics($provider, '
      'requests: $totalRequests, success: ${successRate.toStringAsFixed(1)}%, '
      'avgDuration: ${averageDuration.inMilliseconds}ms)';
}

/// Callback type for metric events.
typedef MetricCallback = void Function(MetricEvent event);

/// Interface for metrics collection.
///
/// Implement this to send metrics to your monitoring system
/// (e.g., Prometheus, DataDog, CloudWatch).
abstract class MetricsCollector {
  /// Record a metric event.
  void record(MetricEvent event);

  /// Record a counter increment.
  void increment(
    String name, {
    required ProviderType provider,
    double value = 1,
    Map<String, String> tags = const {},
  });

  /// Record a timing/duration metric.
  void timing(
    String name, {
    required ProviderType provider,
    required Duration duration,
    Map<String, String> tags = const {},
  });

  /// Record a gauge value.
  void gauge(
    String name, {
    required ProviderType provider,
    required double value,
    Map<String, String> tags = const {},
  });

  /// Get aggregated metrics for a provider.
  AggregatedMetrics? getAggregated(ProviderType provider);

  /// Get all recorded events (for debugging/testing).
  List<MetricEvent> getEvents({
    ProviderType? provider,
    String? name,
    DateTime? since,
  });

  /// Clear all recorded metrics.
  void clear();

  /// Dispose resources.
  void dispose();
}

/// Default in-memory metrics collector.
///
/// Stores metrics in memory with optional size limits and callbacks.
/// Useful for development, testing, and simple monitoring needs.
///
/// For production, consider implementing a custom [MetricsCollector]
/// that sends metrics to your monitoring infrastructure.
///
/// ## Example
///
/// ```dart
/// final metrics = InMemoryMetricsCollector(
///   maxEvents: 10000,
///   onEvent: (event) {
///     print('Metric: ${event.name} = ${event.value}');
///   },
/// );
///
/// // Use with provider
/// final provider = IyzicoProvider(metricsCollector: metrics);
/// ```
class InMemoryMetricsCollector implements MetricsCollector {
  /// Creates an in-memory metrics collector.
  ///
  /// [maxEvents] - Maximum events to keep (oldest are removed).
  /// [onEvent] - Optional callback for each event.
  InMemoryMetricsCollector({
    this.maxEvents = 10000,
    this.onEvent,
  });

  /// Maximum number of events to store.
  final int maxEvents;

  /// Optional callback for each event.
  final MetricCallback? onEvent;

  final List<MetricEvent> _events = [];
  final Map<ProviderType, _ProviderStats> _stats = {};

  @override
  void record(MetricEvent event) {
    _events.add(event);
    _updateStats(event);
    onEvent?.call(event);

    // Enforce size limit
    if (_events.length > maxEvents) {
      _events.removeAt(0);
    }
  }

  @override
  void increment(
    String name, {
    required ProviderType provider,
    double value = 1,
    Map<String, String> tags = const {},
  }) {
    record(
      MetricEvent(
        name: name,
        provider: provider,
        timestamp: DateTime.now(),
        value: value,
        tags: tags,
      ),
    );
  }

  @override
  void timing(
    String name, {
    required ProviderType provider,
    required Duration duration,
    Map<String, String> tags = const {},
  }) {
    record(
      MetricEvent(
        name: name,
        provider: provider,
        timestamp: DateTime.now(),
        duration: duration,
        tags: tags,
      ),
    );
  }

  @override
  void gauge(
    String name, {
    required ProviderType provider,
    required double value,
    Map<String, String> tags = const {},
  }) {
    record(
      MetricEvent(
        name: name,
        provider: provider,
        timestamp: DateTime.now(),
        value: value,
        tags: tags,
      ),
    );
  }

  @override
  AggregatedMetrics? getAggregated(ProviderType provider) {
    final stats = _stats[provider];
    if (stats == null) return null;

    return AggregatedMetrics(
      provider: provider,
      periodStart: stats.firstEventTime ?? DateTime.now(),
      periodEnd: DateTime.now(),
      totalRequests: stats.totalRequests,
      successfulRequests: stats.successfulRequests,
      failedRequests: stats.failedRequests,
      totalAmount: stats.totalAmount,
      averageDuration: stats.averageDuration,
      errorsByType: Map.from(stats.errorsByType),
    );
  }

  @override
  List<MetricEvent> getEvents({
    ProviderType? provider,
    String? name,
    DateTime? since,
  }) {
    var result = _events.toList();

    if (provider != null) {
      result = result.where((e) => e.provider == provider).toList();
    }
    if (name != null) {
      result = result.where((e) => e.name == name).toList();
    }
    if (since != null) {
      result = result.where((e) => e.timestamp.isAfter(since)).toList();
    }

    return result;
  }

  @override
  void clear() {
    _events.clear();
    _stats.clear();
  }

  @override
  void dispose() {
    clear();
  }

  void _updateStats(MetricEvent event) {
    final stats = _stats.putIfAbsent(
      event.provider,
      () => _ProviderStats(),
    );

    stats.firstEventTime ??= event.timestamp;

    // Update based on metric name
    if (event.name == MetricNames.paymentAttempt ||
        event.name == MetricNames.threeDSInitAttempt ||
        event.name == MetricNames.refundAttempt) {
      stats.totalRequests++;
    }

    if (event.name == MetricNames.paymentSuccess ||
        event.name == MetricNames.threeDSCompleteSuccess ||
        event.name == MetricNames.refundSuccess) {
      stats.successfulRequests++;
      if (event.value != null) {
        stats.totalAmount += event.value!;
      }
    }

    if (event.name == MetricNames.paymentFailed ||
        event.name == MetricNames.threeDSInitFailed ||
        event.name == MetricNames.threeDSCompleteFailed ||
        event.name == MetricNames.refundFailed) {
      stats.failedRequests++;
      final errorType = event.tags['error_code'] ?? 'unknown';
      stats.errorsByType[errorType] = (stats.errorsByType[errorType] ?? 0) + 1;
    }

    if (event.duration != null) {
      stats.addDuration(event.duration!);
    }
  }
}

/// Internal class to track per-provider statistics.
class _ProviderStats {
  DateTime? firstEventTime;
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  double totalAmount = 0;
  final Map<String, int> errorsByType = {};

  int _durationCount = 0;
  int _totalDurationMs = 0;

  Duration get averageDuration => _durationCount > 0
      ? Duration(milliseconds: _totalDurationMs ~/ _durationCount)
      : Duration.zero;

  void addDuration(Duration duration) {
    _durationCount++;
    _totalDurationMs += duration.inMilliseconds;
  }
}

/// Extension to measure operation duration and record metrics.
extension MetricsTimingExtension<T> on Future<T> {
  /// Execute this future and record timing metrics.
  Future<T> withMetrics(
    MetricsCollector collector, {
    required String name,
    required ProviderType provider,
    Map<String, String> tags = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await this;
      stopwatch.stop();
      collector.timing(
        name,
        provider: provider,
        duration: stopwatch.elapsed,
        tags: tags,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      collector.timing(
        name,
        provider: provider,
        duration: stopwatch.elapsed,
        tags: {...tags, 'error': 'true'},
      );
      rethrow;
    }
  }
}

/// Helper class for timing operations.
class MetricsTimer {
  /// Creates a timer that will record metrics when stopped.
  MetricsTimer({
    required this.collector,
    required this.name,
    required this.provider,
    this.tags = const {},
  }) : _stopwatch = Stopwatch()..start();

  final MetricsCollector collector;
  final String name;
  final ProviderType provider;
  final Map<String, String> tags;
  final Stopwatch _stopwatch;

  /// Stop the timer and record the duration.
  void stop({Map<String, String>? additionalTags}) {
    _stopwatch.stop();
    collector.timing(
      name,
      provider: provider,
      duration: _stopwatch.elapsed,
      tags: {...tags, ...?additionalTags},
    );
  }

  /// Get elapsed time without stopping.
  Duration get elapsed => _stopwatch.elapsed;
}
