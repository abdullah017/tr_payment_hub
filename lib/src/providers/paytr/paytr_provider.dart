import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';
import '../../core/metrics/payment_metrics.dart';
import '../../core/models/basket_item.dart';
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
import 'paytr_auth.dart';
import 'paytr_endpoints.dart';
import 'paytr_error_mapper.dart';
import 'paytr_mapper.dart';

/// Internal class to track pending payments with timestamps for TTL cleanup.
class _PendingPaymentEntry {
  _PendingPaymentEntry(this.request) : createdAt = DateTime.now();

  final PaymentRequest request;
  final DateTime createdAt;

  /// Check if this entry has expired based on TTL
  bool isExpired(int ttlMinutes) {
    return DateTime.now().difference(createdAt).inMinutes > ttlMinutes;
  }
}

/// PayTR Payment Provider
///
/// ## Usage with Default HTTP Client
///
/// ```dart
/// final provider = PayTRProvider();
/// await provider.initialize(config);
/// ```
///
/// ## Usage with Custom NetworkClient (e.g., Dio)
///
/// ```dart
/// final dioClient = DioNetworkClient(); // Your custom implementation
/// final provider = PayTRProvider(networkClient: dioClient);
/// await provider.initialize(config);
/// ```
///
/// ## Usage with Resilience (Retry + Circuit Breaker)
///
/// ```dart
/// final provider = PayTRProvider(
///   resilienceConfig: ResilienceConfig.forPayments,
///   onResilienceEvent: (event) => print('Resilience: $event'),
/// );
/// await provider.initialize(config);
/// ```
///
/// ## Testing with Mock HTTP Client
///
/// ```dart
/// final mockClient = PaymentMockClient.paytr(shouldSucceed: true);
/// final provider = PayTRProvider(httpClient: mockClient);
/// ```
class PayTRProvider implements PaymentProvider {
  /// Creates a [PayTRProvider] with optional custom [NetworkClient].
  ///
  /// [networkClient] - Custom network client (Dio, etc.)
  /// [httpClient] - Legacy: http.Client for backward compatibility
  /// [resilienceConfig] - Optional resilience configuration for retry/circuit breaker
  /// [onResilienceEvent] - Optional callback for resilience events
  /// [metricsCollector] - Optional metrics collector for monitoring
  PayTRProvider({
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
  late PayTRConfig _config;
  late PayTRAuth _auth;
  NetworkClient? _networkClient;
  ResilientNetworkClient? _resilientClient;
  bool _initialized = false;

  /// Maximum number of pending payments to store (prevents unbounded growth)
  static const _maxPendingPayments = 1000;

  /// TTL for pending payments in minutes (default: 30 minutes)
  static const _pendingPaymentTtlMinutes = 30;

  /// Bekleyen işlemleri takip etmek için (with timestamps for cleanup)
  final Map<String, _PendingPaymentEntry> _pendingPayments = {};

  @override
  ProviderType get providerType => ProviderType.paytr;

  @override
  Future<void> initialize(PaymentConfig config) async {
    if (config is! PayTRConfig) {
      throw PaymentException.configError(
        message: 'PayTRProvider requires PayTRConfig',
        provider: ProviderType.paytr,
      );
    }

    if (!config.validate()) {
      throw PaymentException.configError(
        message: 'Invalid PayTR configuration',
        provider: ProviderType.paytr,
      );
    }

    _config = config;
    _auth = PayTRAuth(
      merchantId: config.merchantId,
      merchantKey: config.apiKey,
      merchantSalt: config.secretKey,
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
        circuitName: 'paytr',
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

    // PayTR Direct API ile non-3DS ödeme
    // NOT: PayTR genellikle 3DS zorunlu tutar, bu yüzden çoğu durumda
    // init3DSPayment kullanılmalı

    final merchantOid = _generateMerchantOid();

    final token = _auth.generatePaymentToken(
      userIp: request.buyer.ip,
      merchantOid: merchantOid,
      email: request.buyer.email,
      paymentAmount: _formatAmount(request.effectivePaidAmount),
      paymentType: 'card',
      installmentCount: request.installment.toString(),
      currency: _mapCurrency(request.currency),
      testMode: _config.isSandbox ? '1' : '0',
      non3d: '1', // Non-3DS
    );

    final body = PayTRMapper.toDirectPaymentRequest(
      request: request,
      merchantId: _config.merchantId,
      paytrToken: token,
      merchantOid: merchantOid,
      successUrl: _config.successUrl,
      failUrl: _config.failUrl,
      testMode: _config.isSandbox,
    );

    try {
      final response = await _postForm(PayTREndpoints.directPayment, body);

      // PayTR direct API senkron yanıt döndürmez
      // Callback beklemek gerekir
      // Bu durumda pending döndürüyoruz
      if (response['status'] == 'success') {
        _addPendingPayment(merchantOid, request);
        stopwatch.stop();
        _recordMetric(
          MetricNames.paymentSuccess,
          value: request.amount,
          duration: stopwatch.elapsed,
        );

        return PaymentResult(
          isSuccess: true,
          transactionId: merchantOid,
          amount: request.amount,
          rawResponse: response,
        );
      } else {
        stopwatch.stop();
        _recordMetric(
          MetricNames.paymentFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': response['reason']?.toString() ?? 'unknown'},
        );
        throw PayTRErrorMapper.mapError(
          errorCode: response['reason']?.toString() ?? 'unknown',
          errorMessage: response['reason']?.toString() ?? 'Ödeme başlatılamadı',
        );
      }
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
        provider: ProviderType.paytr,
      );
    }
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.threeDSInitAttempt);
    final stopwatch = Stopwatch()..start();

    final merchantOid = _generateMerchantOid();
    final paymentAmount = _formatAmount(request.effectivePaidAmount);
    final userBasket = _encodeBasket(request.basketItems);
    final currency = _mapCurrency(request.currency);
    final noInstallment = request.installment == 1 ? '1' : '0';
    const maxInstallment = '12';
    const testMode = '1'; // Sandbox

    // Token için hash string oluştur
    final token = _auth.generateIframeToken(
      userIp: request.buyer.ip,
      merchantOid: merchantOid,
      email: request.buyer.email,
      paymentAmount: paymentAmount,
      userBasket: userBasket,
      noInstallment: noInstallment,
      maxInstallment: maxInstallment,
      currency: currency,
      testMode: testMode,
    );

    final body = <String, String>{
      'merchant_id': _config.merchantId,
      'user_ip': request.buyer.ip,
      'merchant_oid': merchantOid,
      'email': request.buyer.email,
      'payment_amount': paymentAmount,
      'paytr_token': token,
      'user_basket': userBasket,
      'debug_on': _config.isSandbox ? '1' : '0',
      'no_installment': noInstallment,
      'max_installment': maxInstallment,
      'user_name': request.buyer.fullName,
      'user_address': request.buyer.address,
      'user_phone': request.buyer.phone,
      'merchant_ok_url': _config.successUrl,
      'merchant_fail_url': _config.failUrl,
      'timeout_limit': '30',
      'currency': currency,
      'test_mode': testMode,
      'lang': 'tr',
    };

    try {
      final response = await _postForm(PayTREndpoints.iframeToken, body);

      if (response['status'] == 'success' && response['token'] != null) {
        _addPendingPayment(merchantOid, request);
        stopwatch.stop();
        _recordMetric(
          MetricNames.threeDSInitSuccess,
          duration: stopwatch.elapsed,
        );

        final iframeToken = response['token'] as String;
        final iframeUrl = 'https://www.paytr.com/odeme/guvenli/$iframeToken';

        return ThreeDSInitResult.pending(
          redirectUrl: iframeUrl,
          transactionId: merchantOid,
        );
      } else {
        stopwatch.stop();
        _recordMetric(
          MetricNames.threeDSInitFailed,
          duration: stopwatch.elapsed,
          tags: {'error_code': 'token_error'},
        );
        return ThreeDSInitResult.failed(
          errorCode: 'token_error',
          errorMessage: response['reason']?.toString() ?? 'Token alınamadı',
        );
      }
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
        message: 'PayTR requires callback data to complete 3DS payment',
        provider: ProviderType.paytr,
      );
    }

    // Callback hash doğrulama
    final merchantOid =
        callbackData['merchant_oid']?.toString() ?? transactionId;
    final status = callbackData['status']?.toString() ?? '';
    final totalAmount = callbackData['total_amount']?.toString() ?? '';
    final receivedHash = callbackData['hash']?.toString() ?? '';

    if (receivedHash.isNotEmpty) {
      final isValid = _auth.verifyCallbackHash(
        merchantOid: merchantOid,
        status: status,
        totalAmount: totalAmount,
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
          provider: ProviderType.paytr,
        );
      }
    }

    // Pending payment'ı temizle
    _pendingPayments.remove(merchantOid);

    final result = PayTRMapper.fromCallbackData(callbackData);
    if (result.isSuccess) {
      _recordMetric(MetricNames.threeDSCompleteSuccess, value: result.amount);
    } else {
      _recordMetric(
        MetricNames.threeDSCompleteFailed,
        tags: {'error_code': result.errorCode ?? 'unknown'},
      );
    }
    return result;
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();
    _recordMetric(MetricNames.refundAttempt);
    final stopwatch = Stopwatch()..start();

    final token = _auth.generateRefundToken(
      merchantOid: request.transactionId,
      returnAmount: _formatAmount(request.amount),
    );

    final body = PayTRMapper.toRefundRequest(
      merchantId: _config.merchantId,
      merchantOid: request.transactionId,
      amount: request.amount,
      paytrToken: token,
    );

    try {
      final response = await _postForm(PayTREndpoints.refund, body);
      final result = PayTRMapper.fromRefundResponse(response);
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

    final requestId = _generateRequestId();
    final token = _auth.generateInstallmentToken(requestId: requestId);

    final body = PayTRMapper.toInstallmentRequest(
      merchantId: _config.merchantId,
      requestId: requestId,
      paytrToken: token,
    );

    try {
      final response = await _postForm(PayTREndpoints.installmentRates, body);

      if (response['status'] == 'success') {
        return PayTRMapper.fromInstallmentResponse(
          response: response,
          binNumber: binNumber,
          amount: amount,
        );
      } else {
        // API hatası durumunda varsayılan değerler döndür
        return _generateDefaultInstallmentInfo(binNumber, amount);
      }
    } catch (e) {
      // Hata durumunda varsayılan değerler döndür
      return _generateDefaultInstallmentInfo(binNumber, amount);
    }
  }

  /// Varsayılan taksit bilgisi oluştur (API hatası durumunda fallback)
  InstallmentInfo _generateDefaultInstallmentInfo(
    String binNumber,
    double amount,
  ) =>
      InstallmentInfo(
        binNumber: binNumber,
        price: amount,
        cardType: CardType.creditCard,
        cardAssociation: CardAssociation.visa,
        cardFamily: 'Unknown',
        bankName: 'Unknown',
        bankCode: 0,
        force3DS: true,
        forceCVC: true,
        options: _generateDefaultInstallmentOptions(amount),
      );

  @override
  Future<PaymentStatus> getPaymentStatus(String transactionId) async {
    _checkInitialized();

    final token = _auth.generateStatusToken(merchantOid: transactionId);

    final body = PayTRMapper.toStatusRequest(
      merchantId: _config.merchantId,
      merchantOid: transactionId,
      paytrToken: token,
    );

    try {
      final response = await _postForm(PayTREndpoints.statusQuery, body);
      return PayTRMapper.fromStatusResponse(response);
    } catch (e) {
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
    throw UnsupportedError(
      'PayTR Direct API does not support saved card payments. '
      'Use the hosted checkout (iFrame) integration for recurring payments.',
    );
  }

  @override
  Future<List<SavedCard>> getSavedCards(String cardUserKey) async {
    throw UnsupportedError(
      'PayTR Direct API does not support card storage/tokenization. '
      'Use the hosted checkout (iFrame) integration for card management.',
    );
  }

  @override
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  }) async {
    throw UnsupportedError(
      'PayTR Direct API does not support card storage/tokenization. '
      'Use the hosted checkout (iFrame) integration for card management.',
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
      _pendingPayments.clear();
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
        provider: ProviderType.paytr,
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
        provider: ProviderType.paytr,
        duration: duration,
        tags: tags,
      );
    } else {
      _metricsCollector!.increment(
        name,
        provider: ProviderType.paytr,
        value: value ?? 1,
        tags: tags,
      );
    }
  }

  /// Generates a unique merchant order ID using PaymentUtils
  String _generateMerchantOid() => PaymentUtils.generateOrderId(prefix: 'SP');

  /// Generates a unique request ID using PaymentUtils
  String _generateRequestId() =>
      PaymentUtils.generateConversationId(prefix: 'REQ');

  /// Formats amount to cents string using shared utility
  String _formatAmount(double amount) =>
      PaymentUtils.amountToCentsString(amount);

  /// PayTR uses 'TL' instead of 'TRY' for Turkish Lira
  String _mapCurrency(Currency currency) =>
      PaymentUtils.currencyToProviderCode(currency, useTL: true);

  String _encodeBasket(List<BasketItem> items) {
    final basketArray = items
        .map(
          (item) => [
            item.name,
            (item.price * 100).round().toString(),
            item.quantity,
          ],
        )
        .toList();

    final jsonString = jsonEncode(basketArray);
    return base64.encode(utf8.encode(jsonString));
  }

  /// Uses shared PaymentUtils for default installment options
  List<InstallmentOption> _generateDefaultInstallmentOptions(double amount) =>
      PaymentUtils.generateDefaultInstallmentOptions(amount);

  /// Adds a payment to the pending payments map with TTL and size limits.
  ///
  /// This method prevents memory leaks by:
  /// - Cleaning up expired payments before adding new ones
  /// - Enforcing a maximum size limit on the pending payments map
  void _addPendingPayment(String merchantOid, PaymentRequest request) {
    // Clean up expired payments first
    _cleanupExpiredPayments();

    // Enforce size limit - remove oldest entries if at capacity
    if (_pendingPayments.length >= _maxPendingPayments) {
      _removeOldestPayments(_pendingPayments.length - _maxPendingPayments + 1);
    }

    _pendingPayments[merchantOid] = _PendingPaymentEntry(request);
  }

  /// Removes expired pending payments based on TTL.
  void _cleanupExpiredPayments() {
    final expiredKeys = <String>[];
    for (final entry in _pendingPayments.entries) {
      if (entry.value.isExpired(_pendingPaymentTtlMinutes)) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _pendingPayments.remove(key);
    }
  }

  /// Removes the oldest n payments from the map.
  void _removeOldestPayments(int count) {
    if (count <= 0 || _pendingPayments.isEmpty) return;

    // Sort by creation time and remove oldest
    final sortedEntries = _pendingPayments.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

    final toRemove = sortedEntries.take(count).map((e) => e.key).toList();
    for (final key in toRemove) {
      _pendingPayments.remove(key);
    }
  }

  Future<Map<String, dynamic>> _postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    final url = '${PayTREndpoints.baseUrl}$endpoint';

    try {
      final response = await _networkClient!.postForm(
        url,
        fields: body,
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {'status': 'success', 'raw': response.body};
        }
      } else {
        throw PaymentException.networkError(
          providerMessage: 'HTTP ${response.statusCode}: ${response.body}',
          provider: ProviderType.paytr,
        );
      }
    } on PaymentException {
      rethrow;
    } on NetworkException catch (e) {
      if (e.message.contains('timeout') || e.message.contains('Timeout')) {
        throw PaymentException.timeout(provider: ProviderType.paytr);
      }
      throw PaymentException.networkError(
        providerMessage: e.message,
        provider: ProviderType.paytr,
      );
    } catch (e) {
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.paytr,
      );
    }
  }
}
