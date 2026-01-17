/// Metrics collection for TR Payment Hub.
///
/// This library provides metrics collection capabilities for monitoring
/// payment operations, including request counts, timing, error rates,
/// and resilience metrics.
///
/// ## Core Components
///
/// - [MetricsCollector] - Interface for metrics collection
/// - [InMemoryMetricsCollector] - Default in-memory implementation
/// - [MetricEvent] - Individual metric event
/// - [AggregatedMetrics] - Aggregated statistics
/// - [MetricNames] - Predefined metric name constants
///
/// ## Usage Example
///
/// ```dart
/// // Create metrics collector
/// final metrics = InMemoryMetricsCollector(
///   onEvent: (event) => print('Metric: $event'),
/// );
///
/// // Use with provider
/// final provider = IyzicoProvider(metricsCollector: metrics);
/// await provider.initialize(config);
///
/// // After some operations, get aggregated stats
/// final stats = metrics.getAggregated(ProviderType.iyzico);
/// print('Success rate: ${stats?.successRate}%');
/// ```
///
/// ## Custom Metrics Collector
///
/// For production use, implement [MetricsCollector] to send metrics
/// to your monitoring system:
///
/// ```dart
/// class DataDogMetricsCollector implements MetricsCollector {
///   @override
///   void record(MetricEvent event) {
///     // Send to DataDog
///     dataDogClient.gauge(event.name, event.value ?? 0);
///   }
///   // ... implement other methods
/// }
/// ```
library;

export 'payment_metrics.dart';
