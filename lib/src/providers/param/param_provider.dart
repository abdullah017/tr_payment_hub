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
import 'param_auth.dart';
import 'param_endpoints.dart';
import 'param_error_mapper.dart';
import 'param_mapper.dart';

/// Param POS Payment Provider
///
/// SOAP/XML tabanlı Param POS entegrasyonu.
///
/// ## Örnek Kullanım
///
/// ```dart
/// final provider = ParamProvider();
/// await provider.initialize(ParamConfig(
///   merchantId: 'CLIENT_CODE',
///   apiKey: 'CLIENT_USERNAME',
///   secretKey: 'CLIENT_PASSWORD',
///   guid: 'YOUR_GUID',
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
/// final provider = ParamProvider(networkClient: dioClient);
/// await provider.initialize(config);
/// ```
///
/// ## Usage with Resilience (Retry + Circuit Breaker)
///
/// ```dart
/// final provider = ParamProvider(
///   resilienceConfig: ResilienceConfig.forPayments,
///   onResilienceEvent: (event) => print('Resilience: $event'),
/// );
/// await provider.initialize(config);
/// ```
///
/// ## Testing with Mock HTTP Client
///
/// ```dart
/// final mockClient = PaymentMockClient.param(shouldSucceed: true);
/// final provider = ParamProvider(httpClient: mockClient);
/// ```
class ParamProvider implements PaymentProvider {
  /// Creates a [ParamProvider] with optional custom [NetworkClient].
  ///
  /// [networkClient] - Custom network client (Dio, etc.)
  /// [httpClient] - Legacy: http.Client for backward compatibility
  /// [resilienceConfig] - Optional resilience configuration for retry/circuit breaker
  /// [onResilienceEvent] - Optional callback for resilience events
  /// [metricsCollector] - Optional metrics collector for monitoring
  ParamProvider({
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
  late ParamConfig _config;
  late ParamAuth _auth;
  NetworkClient? _networkClient;
  ResilientNetworkClient? _resilientClient;
  bool _initialized = false;

  @override
  ProviderType get providerType => ProviderType.param;

  @override
  Future<void> initialize(PaymentConfig config) async {
    if (config is! ParamConfig) {
      throw PaymentException.configError(
        message: 'ParamProvider requires ParamConfig',
        provider: ProviderType.param,
      );
    }

    if (!config.validate()) {
      throw PaymentException.configError(
        message: 'Invalid Param configuration',
        provider: ProviderType.param,
      );
    }

    _config = config;
    _auth = ParamAuth(
      clientCode: config.merchantId,
      clientUsername: config.apiKey,
      clientPassword: config.secretKey,
      guid: config.guid,
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
        circuitName: 'param',
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

    final orderId = _generateOrderId();
    final amount = _formatAmount(request.effectivePaidAmount);
    final hash = _auth.generatePaymentHash(amount: amount, orderId: orderId);

    final soapRequest = ParamMapper.toPaymentRequest(
      request: request,
      clientCode: _config.merchantId,
      clientUsername: _config.apiKey,
      clientPassword: _config.secretKey,
      guid: _config.guid,
      hash: hash,
      orderId: orderId,
    );

    try {
      final response = await _postSoap(
        ParamEndpoints.soapActionPayment,
        soapRequest,
      );

      final result = ParamMapper.fromPaymentResponse(response);
      stopwatch.stop();

      if (!result.isSuccess) {
        _recordMetric(
          MetricNames.paymentFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': result.errorCode ?? 'unknown'},
        );
        throw ParamErrorMapper.mapError(
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
        provider: ProviderType.param,
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
        provider: ProviderType.param,
      );
    }

    final orderId = _generateOrderId();
    final amount = _formatAmount(request.effectivePaidAmount);
    final hash = _auth.generatePaymentHash(amount: amount, orderId: orderId);

    // Param callback URL'leri ayrı ayrı ister
    final successUrl = request.callbackUrl!;
    final failUrl = request.callbackUrl!;

    final soapRequest = ParamMapper.to3DSInitRequest(
      request: request,
      clientCode: _config.merchantId,
      clientUsername: _config.apiKey,
      clientPassword: _config.secretKey,
      guid: _config.guid,
      hash: hash,
      orderId: orderId,
      successUrl: successUrl,
      failUrl: failUrl,
    );

    try {
      final response = await _postSoap(
        ParamEndpoints.soapAction3DSInit,
        soapRequest,
      );

      final result = ParamMapper.from3DSInitResponse(response);
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

    // Param 3DS callback'ten gelen verileri doğrula
    if (callbackData == null) {
      _recordMetric(
        MetricNames.threeDSCompleteFailed,
        tags: {'error_code': 'missing_callback_data'},
      );
      throw const PaymentException(
        code: 'missing_callback_data',
        message: 'Param requires callback data to complete 3DS payment',
        provider: ProviderType.param,
      );
    }

    // Callback'ten gelen sonucu kontrol et
    final status = callbackData['Sonuc']?.toString() ?? '';
    final message = callbackData['Sonuc_Str']?.toString() ?? '';

    if (ParamErrorMapper.isSuccess(status)) {
      final amount = _parseAmount(callbackData['Tutar']?.toString());
      _recordMetric(MetricNames.threeDSCompleteSuccess, value: amount);
      return PaymentResult.success(
        transactionId: callbackData['Dekont_ID']?.toString() ?? transactionId,
        amount: amount,
        rawResponse: callbackData,
      );
    } else {
      _recordMetric(
        MetricNames.threeDSCompleteFailed,
        tags: {'error_code': status},
      );
      return PaymentResult.failure(
        errorCode: status,
        errorMessage: message,
        rawResponse: callbackData,
      );
    }
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.refundAttempt);
    final stopwatch = Stopwatch()..start();

    final hash = _auth.generateRefundHash(orderId: request.transactionId);

    final soapRequest = ParamMapper.toRefundRequest(
      transactionId: request.transactionId,
      amount: request.amount,
      clientCode: _config.merchantId,
      clientUsername: _config.apiKey,
      clientPassword: _config.secretKey,
      guid: _config.guid,
      hash: hash,
    );

    try {
      final response = await _postSoap(
        ParamEndpoints.soapActionRefund,
        soapRequest,
      );

      final result = ParamMapper.fromRefundResponse(response);
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
        provider: ProviderType.param,
      );
    }

    final soapRequest = ParamMapper.toInstallmentRequest(
      binNumber: binNumber.substring(0, 6),
      amount: amount,
      clientCode: _config.merchantId,
      clientUsername: _config.apiKey,
      clientPassword: _config.secretKey,
      guid: _config.guid,
    );

    try {
      final response = await _postSoap(
        ParamEndpoints.soapActionInstallment,
        soapRequest,
      );

      final info = ParamMapper.fromInstallmentResponse(
        xmlResponse: response,
        binNumber: binNumber,
        amount: amount,
      );

      if (info != null) {
        return info;
      }

      // Fallback: varsayılan taksit bilgisi döndür
      return _generateDefaultInstallmentInfo(binNumber, amount);
    } catch (e) {
      // Hata durumunda varsayılan değerler döndür
      return _generateDefaultInstallmentInfo(binNumber, amount);
    }
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String transactionId) async {
    _checkInitialized();

    final soapRequest = ParamMapper.toStatusRequest(
      transactionId: transactionId,
      clientCode: _config.merchantId,
      clientUsername: _config.apiKey,
      clientPassword: _config.secretKey,
      guid: _config.guid,
    );

    try {
      final response = await _postSoap(
        ParamEndpoints.soapActionStatus,
        soapRequest,
      );

      return ParamMapper.fromStatusResponse(response);
    } catch (_) {
      return PaymentStatus.failed;
    }
  }

  // ============================================
  // SAVED CARD / TOKENIZATION METHODS
  // Param bu özellikleri desteklemiyor
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
    throw UnsupportedError(
      'Param POS does not support saved card payments. '
      'Card must be entered for each transaction.',
    );
  }

  @override
  Future<List<SavedCard>> getSavedCards(String cardUserKey) async {
    throw UnsupportedError(
      'Param POS does not support card storage/tokenization.',
    );
  }

  @override
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  }) async {
    throw UnsupportedError(
      'Param POS does not support card storage/tokenization.',
    );
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
        provider: ProviderType.param,
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
        provider: ProviderType.param,
        duration: duration,
        tags: tags,
      );
    } else {
      _metricsCollector!.increment(
        name,
        provider: ProviderType.param,
        value: value ?? 1,
        tags: tags,
      );
    }
  }

  /// Generates a unique order ID using PaymentUtils
  String _generateOrderId() => PaymentUtils.generateOrderId(prefix: 'PARAM');

  /// Formats amount to cents string using PaymentUtils
  String _formatAmount(double amount) =>
      PaymentUtils.amountToCentsString(amount);

  /// Parses cents amount from API response
  double _parseAmount(String? value) {
    if (value == null || value.isEmpty) return 0;
    // Param returns amount in cents, so we parse and divide by 100
    final cents = PaymentUtils.parseAmount(value);
    return cents / 100;
  }

  /// Uses shared PaymentUtils for default installment info
  InstallmentInfo _generateDefaultInstallmentInfo(
    String binNumber,
    double amount,
  ) =>
      PaymentUtils.generateDefaultInstallmentInfo(binNumber, amount);

  Future<String> _postSoap(String soapAction, String body) async {
    final url = '${_config.baseUrl}${ParamEndpoints.servicePath}';

    try {
      final response = await _networkClient!.post(
        url,
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'SOAPAction': soapAction,
        },
        body: body,
        timeout: const Duration(seconds: 15),
      );

      if (response.isSuccess) {
        return response.body;
      } else {
        throw PaymentException.networkError(
          providerMessage: 'HTTP ${response.statusCode}: ${response.body}',
          provider: ProviderType.param,
        );
      }
    } on PaymentException {
      rethrow;
    } on NetworkException catch (e) {
      if (e.message.contains('timeout') || e.message.contains('Timeout')) {
        throw PaymentException.timeout(provider: ProviderType.param);
      }
      throw PaymentException.networkError(
        providerMessage: e.message,
        provider: ProviderType.param,
      );
    } catch (e) {
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.param,
      );
    }
  }
}
