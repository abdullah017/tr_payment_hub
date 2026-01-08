import 'dart:convert';
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
/// Test için özel http.Client kullanabilirsiniz:
/// ```dart
/// final mockClient = PaymentMockClient.sipay(shouldSucceed: true);
/// final provider = SipayProvider(httpClient: mockClient);
/// ```
class SipayProvider implements PaymentProvider {
  /// Test için özel http.Client inject edilebilir
  SipayProvider({http.Client? httpClient}) : _customHttpClient = httpClient;

  final http.Client? _customHttpClient;
  late SipayConfig _config;
  late SipayAuth _auth;
  late http.Client _httpClient;
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
    _httpClient = _customHttpClient ?? http.Client();
    _initialized = true;
  }

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();

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

      if (!result.isSuccess) {
        throw SipayErrorMapper.mapError(
          errorCode: result.errorCode ?? 'unknown',
          errorMessage: result.errorMessage ?? 'Bilinmeyen hata',
        );
      }

      return result;
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.sipay,
      );
    }
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();

    if (request.callbackUrl == null || request.callbackUrl!.isEmpty) {
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
      return SipayMapper.from3DSInitResponse(response);
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

    if (callbackData == null) {
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
        throw const PaymentException(
          code: 'invalid_hash',
          message: 'Callback hash doğrulaması başarısız',
          provider: ProviderType.sipay,
        );
      }
    }

    // Status kontrolü
    if (status == 'success' || status == 'completed') {
      return PaymentResult.success(
        transactionId: orderId ?? invoiceId,
        amount: _parseDouble(callbackData['amount']?.toString()),
        paidAmount: _parseDouble(callbackData['total']?.toString()),
        rawResponse: callbackData,
      );
    } else {
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
      return SipayMapper.fromRefundResponse(response);
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

  @override
  void dispose() {
    if (_initialized) {
      _httpClient.close();
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

  /// Generates a unique invoice ID using secure random
  String _generateInvoiceId() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));
    final randomHex =
        randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'SIP${DateTime.now().millisecondsSinceEpoch}_$randomHex';
  }

  String _mapCurrency(Currency currency) {
    switch (currency) {
      case Currency.tryLira:
        return 'TRY';
      case Currency.usd:
        return 'USD';
      case Currency.eur:
        return 'EUR';
      case Currency.gbp:
        return 'GBP';
    }
  }

  double _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0;
    return double.tryParse(value) ?? 0;
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

    final body = {'app_id': _config.apiKey, 'app_secret': _config.secretKey};

    final url = Uri.parse('${_config.baseUrl}${SipayEndpoints.token}');

    final response = await _httpClient
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
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
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _getAccessToken();
    final url = Uri.parse('${_config.baseUrl}$endpoint');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw PaymentException.networkError(
          providerMessage: 'HTTP ${response.statusCode}: ${response.body}',
          provider: ProviderType.sipay,
        );
      }
    } on PaymentException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw PaymentException.timeout(provider: ProviderType.sipay);
      }
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.sipay,
      );
    }
  }
}
