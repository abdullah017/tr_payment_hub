import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';
import '../../core/models/buyer_info.dart';
import '../../core/models/installment_info.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/refund_request.dart';
import '../../core/models/saved_card.dart';
import '../../core/models/three_ds_result.dart';
import '../../core/payment_provider.dart';
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
/// Test için özel http.Client kullanabilirsiniz:
/// ```dart
/// final mockClient = PaymentMockClient.param(shouldSucceed: true);
/// final provider = ParamProvider(httpClient: mockClient);
/// ```
class ParamProvider implements PaymentProvider {
  /// Test için özel http.Client inject edilebilir
  ParamProvider({http.Client? httpClient}) : _customHttpClient = httpClient;

  final http.Client? _customHttpClient;
  late ParamConfig _config;
  late ParamAuth _auth;
  late http.Client _httpClient;
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
    _httpClient = _customHttpClient ?? http.Client();
    _initialized = true;
  }

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();

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

      if (!result.isSuccess) {
        throw ParamErrorMapper.mapError(
          errorCode: result.errorCode ?? 'unknown',
          errorMessage: result.errorMessage ?? 'Bilinmeyen hata',
        );
      }

      return result;
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.param,
      );
    }
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();

    if (request.callbackUrl == null || request.callbackUrl!.isEmpty) {
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

      return ParamMapper.from3DSInitResponse(response);
    } catch (e) {
      if (e is PaymentException) {
        return ThreeDSInitResult.failed(
          errorCode: e.code,
          errorMessage: e.message,
        );
      }
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

    // Param 3DS callback'ten gelen verileri doğrula
    if (callbackData == null) {
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
      return PaymentResult.success(
        transactionId: callbackData['Dekont_ID']?.toString() ?? transactionId,
        amount: _parseAmount(callbackData['Tutar']?.toString()),
        rawResponse: callbackData,
      );
    } else {
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

      return ParamMapper.fromRefundResponse(response);
    } catch (e) {
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
        provider: ProviderType.param,
      );
    }
  }

  /// Generates a unique order ID using secure random
  String _generateOrderId() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(6, (_) => random.nextInt(256));
    final randomHex =
        randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'PARAM${DateTime.now().millisecondsSinceEpoch}_$randomHex';
  }

  String _formatAmount(double amount) => (amount * 100).round().toString();

  double _parseAmount(String? value) {
    if (value == null || value.isEmpty) return 0;
    final cents = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return cents / 100;
  }

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

  List<InstallmentOption> _generateDefaultInstallmentOptions(double amount) => [
        InstallmentOption(
          installmentNumber: 1,
          installmentPrice: amount,
          totalPrice: amount,
        ),
        InstallmentOption(
          installmentNumber: 2,
          installmentPrice: amount / 2 * 1.02,
          totalPrice: amount * 1.02,
        ),
        InstallmentOption(
          installmentNumber: 3,
          installmentPrice: amount / 3 * 1.03,
          totalPrice: amount * 1.03,
        ),
        InstallmentOption(
          installmentNumber: 6,
          installmentPrice: amount / 6 * 1.05,
          totalPrice: amount * 1.05,
        ),
        InstallmentOption(
          installmentNumber: 9,
          installmentPrice: amount / 9 * 1.07,
          totalPrice: amount * 1.07,
        ),
        InstallmentOption(
          installmentNumber: 12,
          installmentPrice: amount / 12 * 1.10,
          totalPrice: amount * 1.10,
        ),
      ];

  Future<String> _postSoap(String soapAction, String body) async {
    final url = Uri.parse('${_config.baseUrl}${ParamEndpoints.servicePath}');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'text/xml; charset=utf-8',
              'SOAPAction': soapAction,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw PaymentException.networkError(
          providerMessage: 'HTTP ${response.statusCode}: ${response.body}',
          provider: ProviderType.param,
        );
      }
    } on PaymentException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw PaymentException.timeout(provider: ProviderType.param);
      }
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.param,
      );
    }
  }
}
