import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/enums.dart';
import '../../core/config.dart';
import '../../core/payment_provider.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/installment_info.dart';
import '../../core/models/three_ds_result.dart';
import '../../core/exceptions/payment_exception.dart';
import 'iyzico_endpoints.dart';
import 'iyzico_auth.dart';
import 'iyzico_mapper.dart';
import 'iyzico_error_mapper.dart';

/// iyzico Payment Provider
class IyzicoProvider implements PaymentProvider {
  late IyzicoConfig _config;
  late IyzicoAuth _auth;
  late http.Client _httpClient;
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
    _httpClient = http.Client();
    _initialized = true;
  }

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();

    final conversationId = _generateConversationId();
    final body = IyzicoMapper.toPaymentRequest(request, conversationId);

    final response = await _post(IyzicoEndpoints.createPayment, body);

    if (response['status'] == 'success') {
      return IyzicoMapper.fromPaymentResponse(response);
    } else {
      throw IyzicoErrorMapper.mapError(
        errorCode: response['errorCode']?.toString() ?? 'unknown',
        errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
      );
    }
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();

    if (request.callbackUrl == null || request.callbackUrl!.isEmpty) {
      throw PaymentException.configError(
        message: 'callbackUrl is required for 3DS payment',
        provider: ProviderType.iyzico,
      );
    }

    final conversationId = _generateConversationId();
    final body = IyzicoMapper.to3DSInitRequest(
      request,
      conversationId,
      request.callbackUrl!,
    );

    final response = await _post(IyzicoEndpoints.init3DS, body);

    return IyzicoMapper.from3DSInitResponse(response);
  }

  @override
  Future<PaymentResult> complete3DSPayment(
    String transactionId, {
    Map<String, dynamic>? callbackData,
  }) async {
    _checkInitialized();

    // callbackData'dan paymentId al
    final paymentId = callbackData?['paymentId'] ?? transactionId;

    final body = {
      'locale': 'tr',
      'conversationId': _generateConversationId(),
      'paymentId': paymentId,
    };

    // Eğer callback'ten gelen data varsa, onu kullan
    if (callbackData != null && callbackData.containsKey('conversationData')) {
      body['conversationData'] = callbackData['conversationData'];
    }

    final response = await _post(IyzicoEndpoints.complete3DS, body);

    if (response['status'] == 'success') {
      return IyzicoMapper.fromPaymentResponse(response);
    } else {
      throw IyzicoErrorMapper.mapError(
        errorCode: response['errorCode']?.toString() ?? 'unknown',
        errorMessage: response['errorMessage']?.toString() ?? 'Unknown error',
      );
    }
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();

    final conversationId = _generateConversationId();
    final body = IyzicoMapper.toRefundRequest(request, conversationId);

    final response = await _post(IyzicoEndpoints.refund, body);

    return IyzicoMapper.fromRefundResponse(response);
  }

  @override
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  }) async {
    _checkInitialized();

    // BIN numarası 6 veya 8 hane olmalı
    if (binNumber.length < 6) {
      throw PaymentException(
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
      throw PaymentException(
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

  @override
  void dispose() {
    if (_initialized) {
      _httpClient.close();
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

  String _generateConversationId() {
    return 'TR${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${_config.baseUrl}$endpoint');
    final jsonBody = jsonEncode(body);
    final authHeader = _auth.generateAuthorizationHeader(jsonBody);

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': authHeader,
            },
            body: jsonBody,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw PaymentException.networkError(
          providerMessage: 'HTTP ${response.statusCode}: ${response.body}',
          provider: ProviderType.iyzico,
        );
      }
    } on PaymentException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw PaymentException.timeout(provider: ProviderType.iyzico);
      }
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.iyzico,
      );
    }
  }
}
