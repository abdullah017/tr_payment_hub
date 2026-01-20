import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';
import '../../core/metrics/payment_metrics.dart';
import '../../core/models/buyer_info.dart';
import '../../core/models/installment_info.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/refund_request.dart';
import '../../core/models/saved_card.dart';
import '../../core/models/three_ds_result.dart';
import '../../core/network/circuit_breaker.dart';
import '../../core/network/http_network_client.dart';
import '../../core/network/network_client.dart';
import '../../core/network/resilient_network_client.dart';
import '../../core/payment_provider.dart';
import 'iyzico_auth.dart';
import 'iyzico_endpoints.dart';
import 'iyzico_error_mapper.dart';
import 'iyzico_mapper.dart';

/// iyzico Payment Provider
///
/// ## Usage with Default HTTP Client
///
/// ```dart
/// final provider = IyzicoProvider();
/// await provider.initialize(config);
/// ```
///
/// ## Usage with Custom NetworkClient (e.g., Dio)
///
/// ```dart
/// final dioClient = DioNetworkClient(); // Your custom implementation
/// final provider = IyzicoProvider(networkClient: dioClient);
/// await provider.initialize(config);
/// ```
///
/// ## Usage with Resilience (Retry + Circuit Breaker)
///
/// ```dart
/// final provider = IyzicoProvider(
///   resilienceConfig: ResilienceConfig.forPayments,
///   onResilienceEvent: (event) => print('Resilience: $event'),
/// );
/// await provider.initialize(config);
/// ```
///
/// ## Usage with Metrics Collection
///
/// ```dart
/// final metrics = InMemoryMetricsCollector();
/// final provider = IyzicoProvider(metricsCollector: metrics);
/// await provider.initialize(config);
///
/// // Later, get aggregated stats
/// final stats = metrics.getAggregated(ProviderType.iyzico);
/// ```
///
/// ## Testing with Mock HTTP Client
///
/// ```dart
/// final mockClient = PaymentMockClient.iyzico(shouldSucceed: true);
/// final provider = IyzicoProvider(httpClient: mockClient);
/// ```
class IyzicoProvider implements PaymentProvider {
  /// Creates an [IyzicoProvider] with optional custom [NetworkClient].
  ///
  /// [networkClient] - Custom network client (Dio, etc.)
  /// [httpClient] - Legacy: http.Client for backward compatibility
  /// [resilienceConfig] - Optional resilience configuration for retry/circuit breaker
  /// [onResilienceEvent] - Optional callback for resilience events
  /// [metricsCollector] - Optional metrics collector for monitoring
  IyzicoProvider({
    NetworkClient? networkClient,
    http.Client? httpClient,
    ResilienceConfig? resilienceConfig,
    ResilienceCallback? onResilienceEvent,
    MetricsCollector? metricsCollector,
  })  : _customNetworkClient = networkClient,
        _customHttpClient = httpClient,
        _resilienceConfig = resilienceConfig,
        _onResilienceEvent = onResilienceEvent,
        _metricsCollector = metricsCollector;

  final NetworkClient? _customNetworkClient;
  final http.Client? _customHttpClient;
  final ResilienceConfig? _resilienceConfig;
  final ResilienceCallback? _onResilienceEvent;
  final MetricsCollector? _metricsCollector;
  late IyzicoConfig _config;
  late IyzicoAuth _auth;
  NetworkClient? _networkClient;
  ResilientNetworkClient? _resilientClient;
  bool _initialized = false;

  @override
  ProviderType get providerType => ProviderType.iyzico;

  @override
  Future<void> initialize(PaymentConfig config) async {
    if (config is! IyzicoConfig) {
      throw PaymentException.configError(
        message: 'IyzicoProvider requires IyzicoConfig',
        provider: ProviderType.iyzico,
      );
    }

    if (!config.validate()) {
      throw PaymentException.configError(
        message: 'Invalid iyzico configuration',
        provider: ProviderType.iyzico,
      );
    }

    _config = config;
    _auth = IyzicoAuth(apiKey: config.apiKey, secretKey: config.secretKey);

    // Priority: custom NetworkClient > legacy http.Client > default
    NetworkClient baseClient;
    if (_customNetworkClient != null) {
      baseClient = _customNetworkClient!;
    } else if (_customHttpClient != null) {
      baseClient = HttpNetworkClient(client: _customHttpClient);
    } else {
      baseClient = HttpNetworkClient();
    }

    // Wrap with resilience if configured
    if (_resilienceConfig != null) {
      _resilientClient = ResilientNetworkClient(
        client: baseClient,
        circuitName: 'iyzico',
        config: _resilienceConfig!,
        onEvent: _onResilienceEvent,
      );
      _networkClient = _resilientClient;
    } else {
      _networkClient = baseClient;
    }

    _initialized = true;
  }

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.paymentAttempt);
    final stopwatch = Stopwatch()..start();

    try {
      final conversationId = _generateConversationId();
      final body = IyzicoMapper.toPaymentRequest(request, conversationId);

      final response = await _post(IyzicoEndpoints.createPayment, body);

      if (response['status'] == 'success') {
        final result = IyzicoMapper.fromPaymentResponse(response);
        stopwatch.stop();
        _recordMetric(
          MetricNames.paymentSuccess,
          value: result.amount,
          duration: stopwatch.elapsed,
        );
        return result;
      } else {
        final errorCode = response['errorCode']?.toString() ?? 'unknown';
        _recordMetric(
          MetricNames.paymentFailed,
          tags: {'error_code': errorCode},
        );
        throw IyzicoErrorMapper.mapError(
          errorCode: errorCode,
          errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
        );
      }
    } catch (e) {
      if (e is! PaymentException) {
        _recordMetric(
          MetricNames.paymentFailed,
          tags: {'error_code': 'exception'},
        );
      }
      rethrow;
    }
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.threeDSInitAttempt);

    if (request.callbackUrl == null || request.callbackUrl!.isEmpty) {
      throw PaymentException.configError(
        message: 'callbackUrl is required for 3DS payment',
        provider: ProviderType.iyzico,
      );
    }

    try {
      final conversationId = _generateConversationId();
      final body = IyzicoMapper.to3DSInitRequest(
        request,
        conversationId,
        request.callbackUrl!,
      );

      final response = await _post(IyzicoEndpoints.init3DS, body);
      final result = IyzicoMapper.from3DSInitResponse(response);

      if (result.isSuccess || result.status == ThreeDSStatus.pending) {
        _recordMetric(MetricNames.threeDSInitSuccess);
      } else {
        _recordMetric(
          MetricNames.threeDSInitFailed,
          tags: {'error_code': result.errorCode ?? 'unknown'},
        );
      }
      return result;
    } catch (e) {
      _recordMetric(
        MetricNames.threeDSInitFailed,
        tags: {'error_code': 'exception'},
      );
      rethrow;
    }
  }

  @override
  Future<PaymentResult> complete3DSPayment(
    String transactionId, {
    Map<String, dynamic>? callbackData,
  }) async {
    _checkInitialized();
    _recordMetric(MetricNames.threeDSCompleteAttempt);
    final stopwatch = Stopwatch()..start();

    try {
      // callbackData'dan paymentId al
      final paymentId = callbackData?['paymentId'] ?? transactionId;

      final body = {
        'locale': 'tr',
        'conversationId': _generateConversationId(),
        'paymentId': paymentId,
      };

      // Eğer callback'ten gelen data varsa, onu kullan
      if (callbackData != null &&
          callbackData.containsKey('conversationData')) {
        body['conversationData'] = callbackData['conversationData'];
      }

      final response = await _post(IyzicoEndpoints.complete3DS, body);

      if (response['status'] == 'success') {
        final result = IyzicoMapper.fromPaymentResponse(response);
        stopwatch.stop();
        _recordMetric(
          MetricNames.threeDSCompleteSuccess,
          value: result.amount,
          duration: stopwatch.elapsed,
        );
        return result;
      } else {
        final errorCode = response['errorCode']?.toString() ?? 'unknown';
        _recordMetric(
          MetricNames.threeDSCompleteFailed,
          tags: {'error_code': errorCode},
        );
        throw IyzicoErrorMapper.mapError(
          errorCode: errorCode,
          errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
        );
      }
    } catch (e) {
      if (e is! PaymentException) {
        _recordMetric(
          MetricNames.threeDSCompleteFailed,
          tags: {'error_code': 'exception'},
        );
      }
      rethrow;
    }
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.refundAttempt);

    try {
      final conversationId = _generateConversationId();
      final body = IyzicoMapper.toRefundRequest(request, conversationId);

      final response = await _post(IyzicoEndpoints.refund, body);
      final result = IyzicoMapper.fromRefundResponse(response);

      if (result.isSuccess) {
        _recordMetric(
          MetricNames.refundSuccess,
          value: result.refundedAmount,
        );
      } else {
        _recordMetric(
          MetricNames.refundFailed,
          tags: {'error_code': result.errorCode ?? 'unknown'},
        );
      }
      return result;
    } catch (e) {
      _recordMetric(
        MetricNames.refundFailed,
        tags: {'error_code': 'exception'},
      );
      rethrow;
    }
  }

  @override
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  }) async {
    _checkInitialized();

    // BIN numarası 6 veya 8 hane olmalı
    if (binNumber.length < 6) {
      throw const PaymentException(
        code: 'invalid_bin',
        message: 'BIN number must be at least 6 digits',
        provider: ProviderType.iyzico,
      );
    }

    final body = IyzicoMapper.toInstallmentRequest(
      binNumber: binNumber.substring(0, 6),
      price: amount,
    );

    final response = await _post(IyzicoEndpoints.installmentInfo, body);

    if (response['status'] != 'success') {
      throw IyzicoErrorMapper.mapError(
        errorCode: response['errorCode']?.toString() ?? 'unknown',
        errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
      );
    }

    final installmentInfo = IyzicoMapper.fromInstallmentResponse(response);

    if (installmentInfo == null) {
      throw const PaymentException(
        code: 'no_installment_info',
        message: 'No installment information found for this card',
        provider: ProviderType.iyzico,
      );
    }

    return installmentInfo;
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String transactionId) async {
    _checkInitialized();

    final body = {
      'locale': 'tr',
      'conversationId': _generateConversationId(),
      'paymentId': transactionId,
    };

    final response = await _post(IyzicoEndpoints.paymentDetail, body);

    if (response['status'] != 'success') {
      return PaymentStatus.failed;
    }

    // paymentStatus değerini kontrol et
    final paymentStatus = response['paymentStatus'];
    switch (paymentStatus) {
      case 'SUCCESS':
        return PaymentStatus.success;
      case 'FAILURE':
        return PaymentStatus.failed;
      case 'INIT_THREEDS':
      case 'CALLBACK_THREEDS':
        return PaymentStatus.pending;
      default:
        // fraudStatus kontrolü
        final fraudStatus = response['fraudStatus'];
        if (fraudStatus == 1) {
          return PaymentStatus.success;
        } else if (fraudStatus == -1) {
          return PaymentStatus.failed;
        }
        return PaymentStatus.pending;
    }
  }

  // ============================================
  // SAVED CARD / TOKENIZATION METHODS
  // ============================================

  @override
  Future<PaymentResult> chargeWithSavedCard({
    required String cardToken,
    required String orderId,
    required double amount,
    required BuyerInfo buyer,
    String? cardUserKey,
    int installment = 1,
    Currency currency = Currency.tryLira,
  }) async {
    _checkInitialized();

    if (cardUserKey == null) {
      throw PaymentException.configError(
        message: 'cardUserKey is required for iyzico saved card payments',
        provider: ProviderType.iyzico,
      );
    }

    final conversationId = _generateConversationId();
    final body = IyzicoMapper.toSavedCardPaymentRequest(
      cardToken: cardToken,
      cardUserKey: cardUserKey,
      orderId: orderId,
      amount: amount,
      buyer: buyer,
      conversationId: conversationId,
      installment: installment,
      currency: currency,
    );

    final response = await _post(IyzicoEndpoints.payment, body);
    return IyzicoMapper.fromPaymentResponse(response);
  }

  @override
  Future<List<SavedCard>> getSavedCards(String cardUserKey) async {
    _checkInitialized();

    final conversationId = _generateConversationId();
    final body = {
      'locale': 'tr',
      'conversationId': conversationId,
      'cardUserKey': cardUserKey,
    };

    final response = await _post(IyzicoEndpoints.cardList, body);

    if (response['status'] != 'success') {
      final errorCode = response['errorCode']?.toString() ?? 'unknown';
      final errorMessage =
          response['errorMessage']?.toString() ?? 'Failed to retrieve cards';
      throw IyzicoErrorMapper.mapError(
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
    }

    final cardDetails = response['cardDetails'] as List<dynamic>?;
    if (cardDetails == null) return [];

    return cardDetails
        .map(
          (card) => IyzicoMapper.fromSavedCardResponse(
            card as Map<String, dynamic>,
            cardUserKey,
          ),
        )
        .toList();
  }

  @override
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  }) async {
    _checkInitialized();

    if (cardUserKey == null) {
      throw PaymentException.configError(
        message: 'cardUserKey is required for iyzico card deletion',
        provider: ProviderType.iyzico,
      );
    }

    final conversationId = _generateConversationId();
    final body = {
      'locale': 'tr',
      'conversationId': conversationId,
      'cardUserKey': cardUserKey,
      'cardToken': cardToken,
    };

    final response = await _post(IyzicoEndpoints.cardDelete, body);

    return response['status'] == 'success';
  }

  // ============================================
  // RESILIENCE METHODS
  // ============================================

  /// Whether resilience (retry/circuit breaker) is enabled.
  bool get isResilienceEnabled => _resilientClient != null;

  /// Current circuit breaker state (null if resilience not enabled).
  CircuitState? get circuitState => _resilientClient?.circuitState;

  /// Whether the circuit is currently open (service unavailable).
  bool get isCircuitOpen => _resilientClient?.isCircuitOpen ?? false;

  /// Manually reset the circuit breaker to closed state.
  ///
  /// Use this when you know the service has recovered.
  void resetCircuit() => _resilientClient?.resetCircuit();

  /// Force the circuit to open state.
  ///
  /// Use this to manually stop requests to the service.
  void forceCircuitOpen() => _resilientClient?.forceCircuitOpen();

  @override
  void dispose() {
    if (_initialized) {
      _networkClient?.dispose();
      _networkClient = null;
      _resilientClient = null;
      _initialized = false;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  void _checkInitialized() {
    if (!_initialized) {
      throw PaymentException.configError(
        message: 'Provider not initialized. Call initialize() first.',
        provider: ProviderType.iyzico,
      );
    }
  }

  /// Records a metric event if metrics collector is configured.
  void _recordMetric(
    String name, {
    double? value,
    Duration? duration,
    Map<String, String> tags = const {},
  }) {
    if (_metricsCollector == null) return;

    if (duration != null) {
      _metricsCollector!.timing(
        name,
        provider: ProviderType.iyzico,
        duration: duration,
        tags: tags,
      );
    } else {
      _metricsCollector!.increment(
        name,
        provider: ProviderType.iyzico,
        value: value ?? 1,
        tags: tags,
      );
    }
  }

  String _generateConversationId() =>
      'TR${DateTime.now().millisecondsSinceEpoch}';

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = '${_config.baseUrl}$endpoint';
    final jsonBody = jsonEncode(body);
    final authHeader = _auth.generateAuthorizationHeader(endpoint, jsonBody);

    try {
      final response = await _networkClient!.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
          'x-iyzi-rnd': _auth.lastRandomKey,
        },
        body: jsonBody,
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw PaymentException.networkError(
          providerMessage: 'HTTP ${response.statusCode}: ${response.body}',
          provider: ProviderType.iyzico,
        );
      }
    } on PaymentException {
      rethrow;
    } on NetworkException catch (e) {
      if (e.message.contains('timeout') || e.message.contains('Timeout')) {
        throw PaymentException.timeout(provider: ProviderType.iyzico);
      }
      throw PaymentException.networkError(
        providerMessage: e.message,
        provider: ProviderType.iyzico,
      );
    } catch (e) {
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.iyzico,
      );
    }
  }
}
