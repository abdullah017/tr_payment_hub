import 'dart:convert';
import 'dart:math';

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
import '../../core/utils/payment_utils.dart';
import 'sipay_auth.dart';
import 'sipay_endpoints.dart';
import 'sipay_error_mapper.dart';
import 'sipay_mapper.dart';

/// Sipay Payment Provider
///
/// REST/JSON tabanlı Sipay entegrasyonu.
/// Bearer token authentication kullanır.
///
/// ## Örnek Kullanım
///
/// ```dart
/// final provider = SipayProvider();
/// await provider.initialize(SipayConfig(
///   merchantId: 'YOUR_MERCHANT_ID',
///   apiKey: 'YOUR_APP_KEY',
///   secretKey: 'YOUR_APP_SECRET',
///   merchantKey: 'YOUR_MERCHANT_KEY',
///   isSandbox: true,
/// ));
///
/// final result = await provider.createPayment(request);
/// ```
///
/// ## Usage with Custom NetworkClient (e.g., Dio)
///
/// ```dart
/// final dioClient = DioNetworkClient(); // Your custom implementation
/// final provider = SipayProvider(networkClient: dioClient);
/// await provider.initialize(config);
/// ```
///
/// ## Usage with Resilience (Retry + Circuit Breaker)
///
/// ```dart
/// final provider = SipayProvider(
///   resilienceConfig: ResilienceConfig.forPayments,
///   onResilienceEvent: (event) => print('Resilience: $event'),
/// );
/// await provider.initialize(config);
/// ```
///
/// ## Testing with Mock HTTP Client
///
/// ```dart
/// final mockClient = PaymentMockClient.sipay(shouldSucceed: true);
/// final provider = SipayProvider(httpClient: mockClient);
/// ```
class SipayProvider implements PaymentProvider {
  /// Creates a [SipayProvider] with optional custom [NetworkClient].
  ///
  /// [networkClient] - Custom network client (Dio, etc.)
  /// [httpClient] - Legacy: http.Client for backward compatibility
  /// [resilienceConfig] - Optional resilience configuration for retry/circuit breaker
  /// [onResilienceEvent] - Optional callback for resilience events
  /// [metricsCollector] - Optional metrics collector for monitoring
  SipayProvider({
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
  late SipayConfig _config;
  late SipayAuth _auth;
  NetworkClient? _networkClient;
  ResilientNetworkClient? _resilientClient;
  bool _initialized = false;
  String? _accessToken;
  DateTime? _tokenExpiry;

  @override
  ProviderType get providerType => ProviderType.sipay;

  @override
  Future<void> initialize(PaymentConfig config) async {
    if (config is! SipayConfig) {
      throw PaymentException.configError(
        message: 'SipayProvider requires SipayConfig',
        provider: ProviderType.sipay,
      );
    }

    if (!config.validate()) {
      throw PaymentException.configError(
        message: 'Invalid Sipay configuration',
        provider: ProviderType.sipay,
      );
    }

    _config = config;
    _auth = SipayAuth(
      appKey: config.apiKey,
      appSecret: config.secretKey,
      merchantKey: config.merchantKey,
    );

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
        circuitName: 'sipay',
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

    final invoiceId = _generateInvoiceId();
    final hashKey = _auth.generatePaymentHash(
      invoiceId: invoiceId,
      amount: request.effectivePaidAmount.toStringAsFixed(2),
      currency: _mapCurrency(request.currency),
    );

    final body = SipayMapper.toPaymentRequest(
      request: request,
      merchantKey: _config.merchantKey,
      invoiceId: invoiceId,
      hashKey: hashKey,
    );

    try {
      final response = await _post(SipayEndpoints.paymentDirect, body);
      final result = SipayMapper.fromPaymentResponse(response);
      stopwatch.stop();

      if (!result.isSuccess) {
        _recordMetric(
          MetricNames.paymentFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': result.errorCode ?? 'unknown'},
        );
        throw SipayErrorMapper.mapError(
          errorCode: result.errorCode ?? 'unknown',
          errorMessage: result.errorMessage ?? 'Bilinmeyen hata',
        );
      }

      _recordMetric(
        MetricNames.paymentSuccess,
        value: request.amount,
        duration: stopwatch.elapsed,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      if (e is PaymentException) {
        _recordMetric(
          MetricNames.paymentFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': e.code},
        );
        rethrow;
      }
      _recordMetric(
        MetricNames.paymentFailed,
        duration: stopwatch.elapsed,
        tags: {'error_code': 'network_error'},
      );
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.sipay,
      );
    }
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.threeDSInitAttempt);
    final stopwatch = Stopwatch()..start();

    if (request.callbackUrl == null || request.callbackUrl!.isEmpty) {
      _recordMetric(
        MetricNames.threeDSInitFailed,
        tags: {'error_code': 'missing_callback_url'},
      );
      throw PaymentException.configError(
        message: 'callbackUrl is required for 3DS payment',
        provider: ProviderType.sipay,
      );
    }

    final invoiceId = _generateInvoiceId();
    final hashKey = _auth.generatePaymentHash(
      invoiceId: invoiceId,
      amount: request.effectivePaidAmount.toStringAsFixed(2),
      currency: _mapCurrency(request.currency),
    );

    final body = SipayMapper.to3DSPaymentRequest(
      request: request,
      merchantKey: _config.merchantKey,
      invoiceId: invoiceId,
      hashKey: hashKey,
      returnUrl: request.callbackUrl!,
      cancelUrl: request.callbackUrl!,
    );

    try {
      final response = await _post(SipayEndpoints.payment, body);
      final result = SipayMapper.from3DSInitResponse(response);
      stopwatch.stop();
      if (result.status == ThreeDSStatus.pending) {
        _recordMetric(
          MetricNames.threeDSInitSuccess,
          duration: stopwatch.elapsed,
        );
      } else {
        _recordMetric(
          MetricNames.threeDSInitFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': result.errorCode ?? 'unknown'},
        );
      }
      return result;
    } catch (e) {
      stopwatch.stop();
      if (e is PaymentException) {
        _recordMetric(
          MetricNames.threeDSInitFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': e.code},
        );
        return ThreeDSInitResult.failed(
          errorCode: e.code,
          errorMessage: e.message,
        );
      }
      _recordMetric(
        MetricNames.threeDSInitFailed,
        duration: stopwatch.elapsed,
        tags: {'error_code': 'network_error'},
      );
      return ThreeDSInitResult.failed(
        errorCode: 'network_error',
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<PaymentResult> complete3DSPayment(
    String transactionId, {
    Map<String, dynamic>? callbackData,
  }) async {
    _checkInitialized();
    _recordMetric(MetricNames.threeDSCompleteAttempt);

    if (callbackData == null) {
      _recordMetric(
        MetricNames.threeDSCompleteFailed,
        tags: {'error_code': 'missing_callback_data'},
      );
      throw const PaymentException(
        code: 'missing_callback_data',
        message: 'Sipay requires callback data to complete 3DS payment',
        provider: ProviderType.sipay,
      );
    }

    // Callback'ten gelen verileri doğrula
    final status = callbackData['status']?.toString() ?? '';
    final invoiceId = callbackData['invoice_id']?.toString() ?? transactionId;
    final orderId = callbackData['order_id']?.toString();
    final receivedHash = callbackData['hash_key']?.toString();

    // Hash doğrulama (opsiyonel)
    if (receivedHash != null && receivedHash.isNotEmpty) {
      final isValid = _auth.verifyCallbackHash(
        invoiceId: invoiceId,
        orderId: orderId ?? '',
        status: status,
        receivedHash: receivedHash,
      );

      if (!isValid) {
        _recordMetric(
          MetricNames.threeDSCompleteFailed,
          tags: {'error_code': 'invalid_hash'},
        );
        throw const PaymentException(
          code: 'invalid_hash',
          message: 'Callback hash doğrulaması başarısız',
          provider: ProviderType.sipay,
        );
      }
    }

    // Status kontrolü
    if (status == 'success' || status == 'completed') {
      final amount = _parseDouble(callbackData['amount']?.toString());
      _recordMetric(MetricNames.threeDSCompleteSuccess, value: amount);
      return PaymentResult.success(
        transactionId: orderId ?? invoiceId,
        amount: amount,
        paidAmount: _parseDouble(callbackData['total']?.toString()),
        rawResponse: callbackData,
      );
    } else {
      _recordMetric(
        MetricNames.threeDSCompleteFailed,
        tags: {
          'error_code': callbackData['error_code']?.toString() ?? 'failed'
        },
      );
      return PaymentResult.failure(
        errorCode: callbackData['error_code']?.toString() ?? 'failed',
        errorMessage:
            callbackData['error_message']?.toString() ?? 'Ödeme başarısız',
        rawResponse: callbackData,
      );
    }
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.refundAttempt);
    final stopwatch = Stopwatch()..start();

    final hashKey = _auth.generateRefundHash(
      invoiceId: request.transactionId,
      amount: request.amount.toStringAsFixed(2),
    );

    final body = SipayMapper.toRefundRequest(
      invoiceId: request.transactionId,
      amount: request.amount,
      merchantKey: _config.merchantKey,
      hashKey: hashKey,
    );

    try {
      final response = await _post(SipayEndpoints.refund, body);
      final result = SipayMapper.fromRefundResponse(response);
      stopwatch.stop();
      if (result.isSuccess) {
        _recordMetric(
          MetricNames.refundSuccess,
          value: request.amount,
          duration: stopwatch.elapsed,
        );
      } else {
        _recordMetric(
          MetricNames.refundFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': result.errorCode ?? 'unknown'},
        );
      }
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordMetric(
        MetricNames.refundFailed,
        duration: stopwatch.elapsed,
        tags: {'error_code': 'network_error'},
      );
      if (e is PaymentException) rethrow;
      return RefundResult.failure(
        errorCode: 'network_error',
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  }) async {
    _checkInitialized();

    if (binNumber.length < 6) {
      throw const PaymentException(
        code: 'invalid_bin',
        message: 'BIN number must be at least 6 digits',
        provider: ProviderType.sipay,
      );
    }

    final body = SipayMapper.toInstallmentRequest(
      creditCard: binNumber.substring(0, 6),
      amount: amount,
      currencyCode: 'TRY',
      merchantKey: _config.merchantKey,
    );

    try {
      final response = await _post(SipayEndpoints.installment, body);
      final info = SipayMapper.fromInstallmentResponse(
        response: response,
        binNumber: binNumber,
        amount: amount,
      );

      if (info != null) {
        return info;
      }

      return _generateDefaultInstallmentInfo(binNumber, amount);
    } catch (_) {
      return _generateDefaultInstallmentInfo(binNumber, amount);
    }
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String transactionId) async {
    _checkInitialized();

    final body = SipayMapper.toStatusRequest(
      invoiceId: transactionId,
      merchantKey: _config.merchantKey,
    );

    try {
      final response = await _post(SipayEndpoints.status, body);
      return SipayMapper.fromStatusResponse(response);
    } catch (_) {
      return PaymentStatus.failed;
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

    final invoiceId = _generateInvoiceId();
    final hashKey = _auth.generatePaymentHash(
      invoiceId: invoiceId,
      amount: amount.toStringAsFixed(2),
      currency: _mapCurrency(currency),
    );

    final body = SipayMapper.toSavedCardPaymentRequest(
      cardToken: cardToken,
      invoiceId: invoiceId,
      amount: amount,
      merchantKey: _config.merchantKey,
      hashKey: hashKey,
      currency: _mapCurrency(currency),
      installment: installment,
    );

    try {
      final response = await _post(SipayEndpoints.payWithSavedCard, body);
      return SipayMapper.fromPaymentResponse(response);
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.sipay,
      );
    }
  }

  @override
  Future<List<SavedCard>> getSavedCards(String cardUserKey) async {
    _checkInitialized();

    final body = {
      'card_user_key': cardUserKey,
      'merchant_key': _config.merchantKey,
    };

    try {
      final response = await _post(SipayEndpoints.cardList, body);
      return SipayMapper.fromSavedCardsResponse(response, cardUserKey);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  }) async {
    _checkInitialized();

    final body = {
      'card_token': cardToken,
      'merchant_key': _config.merchantKey,
      if (cardUserKey != null) 'card_user_key': cardUserKey,
    };

    try {
      final response = await _post(SipayEndpoints.deleteCard, body);
      final statusCode = response['status_code'] as int?;
      return SipayErrorMapper.isSuccess(statusCode);
    } catch (_) {
      return false;
    }
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
  void resetCircuit() => _resilientClient?.resetCircuit();

  /// Force the circuit to open state.
  void forceCircuitOpen() => _resilientClient?.forceCircuitOpen();

  @override
  void dispose() {
    if (_initialized) {
      _networkClient?.dispose();
      _networkClient = null;
      _resilientClient = null;
      _accessToken = null;
      _tokenExpiry = null;
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
        provider: ProviderType.sipay,
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
        provider: ProviderType.sipay,
        duration: duration,
        tags: tags,
      );
    } else {
      _metricsCollector!.increment(
        name,
        provider: ProviderType.sipay,
        value: value ?? 1,
        tags: tags,
      );
    }
  }

  /// Generates a unique invoice ID using secure random
  String _generateInvoiceId() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));
    final randomHex =
        randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'SIP${DateTime.now().millisecondsSinceEpoch}_$randomHex';
  }

  /// Maps currency using shared PaymentUtils
  String _mapCurrency(Currency currency) =>
      PaymentUtils.currencyToIso(currency);

  double _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0;
    return double.tryParse(value) ?? 0;
  }

  /// Uses shared PaymentUtils for default installment info
  InstallmentInfo _generateDefaultInstallmentInfo(
    String binNumber,
    double amount,
  ) =>
      PaymentUtils.generateDefaultInstallmentInfo(binNumber, amount);

  /// Token yenileme gerekli mi kontrol et
  bool _needsTokenRefresh() {
    if (_accessToken == null || _tokenExpiry == null) return true;
    // Token süresinden 5 dakika önce yenile
    return DateTime.now().isAfter(
      _tokenExpiry!.subtract(const Duration(minutes: 5)),
    );
  }

  /// Access token al (veya yenile)
  Future<String> _getAccessToken() async {
    if (!_needsTokenRefresh()) {
      return _accessToken!;
    }

    final body = jsonEncode({
      'app_id': _config.apiKey,
      'app_secret': _config.secretKey,
    });

    final url = '${_config.baseUrl}${SipayEndpoints.token}';

    try {
      final response = await _networkClient!.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken =
            data['data']?['token']?.toString() ?? data['token']?.toString();
        // Token genellikle 1 saat geçerli
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
        return _accessToken!;
      } else {
        throw PaymentException.configError(
          message: 'Token alınamadı: ${response.body}',
          provider: ProviderType.sipay,
        );
      }
    } on NetworkException catch (e) {
      throw PaymentException.networkError(
        providerMessage: e.message,
        provider: ProviderType.sipay,
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _getAccessToken();
    final url = '${_config.baseUrl}$endpoint';

    try {
      final response = await _networkClient!.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw PaymentException.networkError(
          providerMessage: 'HTTP ${response.statusCode}: ${response.body}',
          provider: ProviderType.sipay,
        );
      }
    } on PaymentException {
      rethrow;
    } on NetworkException catch (e) {
      if (e.message.contains('timeout') || e.message.contains('Timeout')) {
        throw PaymentException.timeout(provider: ProviderType.sipay);
      }
      throw PaymentException.networkError(
        providerMessage: e.message,
        provider: ProviderType.sipay,
      );
    } catch (e) {
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.sipay,
      );
    }
  }
}
