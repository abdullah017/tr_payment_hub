import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/enums.dart';
import '../core/exceptions/payment_exception.dart';
import '../core/models/buyer_info.dart';
import '../core/models/installment_info.dart';
import '../core/models/payment_request.dart';
import '../core/models/payment_result.dart';
import '../core/models/refund_request.dart';
import '../core/models/saved_card.dart';
import '../core/models/three_ds_result.dart';
import '../core/network/http_network_client.dart';
import '../core/network/network_client.dart';
import '../core/payment_provider.dart';
import 'proxy_config.dart';

/// Backend proxy payment provider for Flutter + Custom Backend architecture.
///
/// This provider does NOT contain any API credentials.
/// All requests are sent to your backend, which handles the actual
/// payment provider integration (iyzico, PayTR, Param, Sipay).
///
/// ## Benefits
///
/// * **Security**: API keys stay on your backend, never exposed in Flutter app
/// * **Flexibility**: Backend can be any language (Node.js, Python, Go, PHP)
/// * **Unified API**: Same Flutter code works with any payment provider
///
/// ## Usage
///
/// ```dart
/// // Create provider
/// final provider = ProxyPaymentProvider(
///   config: ProxyConfig(
///     baseUrl: 'https://api.yourbackend.com/payment',
///     authToken: 'user_jwt_token', // Optional
///   ),
/// );
///
/// // Initialize with provider type
/// await provider.initializeWithProvider(ProviderType.iyzico);
///
/// // Create payment (request goes to your backend)
/// final result = await provider.createPayment(request);
/// ```
///
/// ## Backend Endpoints
///
/// Your backend should implement these endpoints:
///
/// | Method | Endpoint | Description |
/// |--------|----------|-------------|
/// | POST | /create | Create payment |
/// | POST | /3ds/init | Init 3DS |
/// | POST | /3ds/complete | Complete 3DS |
/// | GET | /installments | Query installments |
/// | POST | /refund | Process refund |
/// | GET | /status/{id} | Get payment status |
/// | GET | /cards | List saved cards |
/// | POST | /cards/charge | Charge saved card |
/// | DELETE | /cards/{token} | Delete saved card |
class ProxyPaymentProvider implements PaymentProvider {
  /// Creates a new [ProxyPaymentProvider] instance.
  ///
  /// [config] - Proxy configuration (baseUrl, auth token, etc.)
  /// [networkClient] - Optional custom network client (Dio, etc.)
  /// [httpClient] - Legacy: Optional http.Client for testing
  ProxyPaymentProvider({
    required ProxyConfig config,
    NetworkClient? networkClient,
    http.Client? httpClient,
  })  : _config = config,
        _customNetworkClient = networkClient,
        _customHttpClient = httpClient;

  final ProxyConfig _config;
  final NetworkClient? _customNetworkClient;
  final http.Client? _customHttpClient;
  NetworkClient? _networkClient;

  bool _initialized = false;
  ProviderType? _providerType;

  @override
  ProviderType get providerType =>
      _providerType ?? _config.defaultProvider ?? ProviderType.iyzico;

  /// Whether the provider has been initialized.
  bool get isInitialized => _initialized;

  // ==================== Initialization ====================

  /// Initializes the provider with a [PaymentConfig].
  ///
  /// This method is provided for backward compatibility with [PaymentProvider].
  /// For proxy mode, prefer using [initializeWithProvider] instead.
  @override
  Future<void> initialize(PaymentConfig config) async {
    if (!_config.validate()) {
      throw PaymentException.configError(
        message:
            'Invalid proxy configuration: ${_config.validationErrors.join(", ")}',
      );
    }

    // Extract provider type from config
    if (config is IyzicoConfig) {
      _providerType = ProviderType.iyzico;
    } else if (config is PayTRConfig) {
      _providerType = ProviderType.paytr;
    } else if (config is ParamConfig) {
      _providerType = ProviderType.param;
    } else if (config is SipayConfig) {
      _providerType = ProviderType.sipay;
    } else {
      _providerType = _config.defaultProvider;
    }

    _initializeNetworkClient();
    _initialized = true;
  }

  /// Initializes the provider with a specific [ProviderType].
  ///
  /// This is the recommended initialization method for proxy mode.
  ///
  /// ```dart
  /// await provider.initializeWithProvider(ProviderType.iyzico);
  /// ```
  Future<void> initializeWithProvider(ProviderType provider) async {
    if (!_config.validate()) {
      throw PaymentException.configError(
        message:
            'Invalid proxy configuration: ${_config.validationErrors.join(", ")}',
      );
    }
    _providerType = provider;
    _initializeNetworkClient();
    _initialized = true;
  }

  void _initializeNetworkClient() {
    // Priority: custom NetworkClient > legacy http.Client > default
    if (_customNetworkClient != null) {
      _networkClient = _customNetworkClient;
    } else if (_customHttpClient != null) {
      _networkClient = HttpNetworkClient(client: _customHttpClient);
    } else {
      _networkClient = HttpNetworkClient();
    }
  }

  // ==================== Payment Operations ====================

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();

    final response = await _post('/create', {
      'provider': _providerType?.name,
      ...request.toJson(),
    });

    return PaymentResult.fromJson(response);
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();

    final response = await _post('/3ds/init', {
      'provider': _providerType?.name,
      ...request.toJson(),
    });

    return ThreeDSInitResult.fromJson(response);
  }

  @override
  Future<PaymentResult> complete3DSPayment(
    String transactionId, {
    Map<String, dynamic>? callbackData,
  }) async {
    _checkInitialized();

    final response = await _post('/3ds/complete', {
      'provider': _providerType?.name,
      'transactionId': transactionId,
      if (callbackData != null) 'callbackData': callbackData,
    });

    return PaymentResult.fromJson(response);
  }

  @override
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  }) async {
    _checkInitialized();

    final response = await _get('/installments', {
      'provider': _providerType?.name ?? '',
      'bin': binNumber,
      'amount': amount.toString(),
    });

    return InstallmentInfo.fromJson(response);
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();

    final response = await _post('/refund', {
      'provider': _providerType?.name,
      ...request.toJson(),
    });

    return RefundResult.fromJson(response);
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String transactionId) async {
    _checkInitialized();

    final response = await _get('/status/$transactionId', {
      'provider': _providerType?.name ?? '',
    });

    final statusStr = response['status'] as String?;
    return PaymentStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => PaymentStatus.pending,
    );
  }

  // ==================== Saved Card Operations ====================

  @override
  Future<List<SavedCard>> getSavedCards(String cardUserKey) async {
    _checkInitialized();

    final response = await _get('/cards', {
      'provider': _providerType?.name ?? '',
      'userKey': cardUserKey,
    });

    final cards = response['cards'] as List<dynamic>? ?? [];
    return cards
        .map((c) => SavedCard.fromJson(c as Map<String, dynamic>))
        .toList();
  }

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

    final response = await _post('/cards/charge', {
      'provider': _providerType?.name,
      'cardToken': cardToken,
      'orderId': orderId,
      'amount': amount,
      'installment': installment,
      'currency': currency.name,
      'buyer': buyer.toJson(),
      if (cardUserKey != null) 'userKey': cardUserKey,
    });

    return PaymentResult.fromJson(response);
  }

  @override
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  }) async {
    _checkInitialized();

    await _delete('/cards/$cardToken', {
      'provider': _providerType?.name ?? '',
      if (cardUserKey != null) 'userKey': cardUserKey,
    });

    return true;
  }

  @override
  void dispose() {
    _networkClient?.dispose();
    _networkClient = null;
    _initialized = false;
  }

  // ==================== Private Methods ====================

  void _checkInitialized() {
    if (!_initialized) {
      throw PaymentException.configError(
        message:
            'Provider not initialized. Call initialize() or initializeWithProvider() first.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _request('POST', endpoint, body: body);
  }

  Future<Map<String, dynamic>> _get(
    String endpoint,
    Map<String, String> queryParams,
  ) async {
    return _request('GET', endpoint, queryParams: queryParams);
  }

  Future<Map<String, dynamic>> _delete(
    String endpoint,
    Map<String, String> queryParams,
  ) async {
    return _request('DELETE', endpoint, queryParams: queryParams);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    var url = '${_config.baseUrl}$endpoint';

    if (queryParams != null && queryParams.isNotEmpty) {
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      url = uri.toString();
    }

    var retryCount = 0;

    while (true) {
      try {
        NetworkResponse response;

        switch (method) {
          case 'POST':
            response = await _networkClient!.post(
              url,
              headers: _config.allHeaders,
              body: jsonEncode(body),
              timeout: _config.timeout,
            );
          case 'GET':
            response = await _networkClient!.get(
              url,
              headers: _config.allHeaders,
              timeout: _config.timeout,
            );
          case 'DELETE':
            response = await _networkClient!.delete(
              url,
              headers: _config.allHeaders,
              timeout: _config.timeout,
            );
          default:
            throw PaymentException(
              code: 'invalid_method',
              message: 'Invalid HTTP method: $method',
            );
        }

        return _handleResponse(response);
      } on NetworkException catch (e) {
        if (e.message.contains('timeout') || e.message.contains('Timeout')) {
          if (retryCount >= _config.maxRetries) {
            throw PaymentException.timeout(provider: _providerType);
          }
          retryCount++;
          await Future<void>.delayed(_config.retryDelay);
        } else {
          if (retryCount >= _config.maxRetries) {
            throw PaymentException.networkError(
              providerMessage: e.message,
              provider: _providerType,
            );
          }
          retryCount++;
          await Future<void>.delayed(_config.retryDelay);
        }
      } on PaymentException {
        rethrow;
      } catch (e) {
        throw PaymentException(
          code: 'unknown_error',
          message: e.toString(),
          provider: _providerType,
        );
      }
    }
  }

  Map<String, dynamic> _handleResponse(NetworkResponse response) {
    Map<String, dynamic> body;

    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PaymentException(
        code: 'invalid_response',
        message: 'Invalid JSON response from backend',
        providerMessage: response.body.length > 200
            ? '${response.body.substring(0, 200)}...'
            : response.body,
        provider: _providerType,
      );
    }

    if (response.isSuccess) {
      if (body['success'] == false) {
        throw PaymentException(
          code: body['errorCode']?.toString() ?? 'backend_error',
          message: body['errorMessage']?.toString() ?? 'Backend error',
          providerCode: body['providerCode']?.toString(),
          providerMessage: body['providerMessage']?.toString(),
          provider: _providerType,
        );
      }
      return body;
    }

    // HTTP error
    throw PaymentException(
      code: body['errorCode']?.toString() ?? 'http_${response.statusCode}',
      message: body['errorMessage']?.toString() ?? 'HTTP ${response.statusCode}',
      providerCode: body['providerCode']?.toString(),
      providerMessage: body['providerMessage']?.toString(),
      provider: _providerType,
    );
  }
}
