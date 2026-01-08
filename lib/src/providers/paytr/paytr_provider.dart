import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/enums.dart';
import '../../core/exceptions/payment_exception.dart';
import '../../core/models/basket_item.dart';
import '../../core/models/buyer_info.dart';
import '../../core/models/installment_info.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/refund_request.dart';
import '../../core/models/saved_card.dart';
import '../../core/models/three_ds_result.dart';
import '../../core/payment_provider.dart';
import 'paytr_auth.dart';
import 'paytr_endpoints.dart';
import 'paytr_error_mapper.dart';
import 'paytr_mapper.dart';

/// PayTR Payment Provider
///
/// Test için özel http.Client kullanabilirsiniz:
/// ```dart
/// final mockClient = PaymentMockClient.paytr(shouldSucceed: true);
/// final provider = PayTRProvider(httpClient: mockClient);
/// ```
class PayTRProvider implements PaymentProvider {
  /// Test için özel http.Client inject edilebilir
  PayTRProvider({http.Client? httpClient}) : _customHttpClient = httpClient;

  final http.Client? _customHttpClient;
  late PayTRConfig _config;
  late PayTRAuth _auth;
  late http.Client _httpClient;
  bool _initialized = false;

  // Bekleyen işlemleri takip etmek için
  final Map<String, PaymentRequest> _pendingPayments = {};

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
    _httpClient = _customHttpClient ?? http.Client();
    _initialized = true;
  }

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();

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
        _pendingPayments[merchantOid] = request;

        return PaymentResult(
          isSuccess: true,
          transactionId: merchantOid,
          amount: request.amount,
          rawResponse: response,
        );
      } else {
        throw PayTRErrorMapper.mapError(
          errorCode: response['reason']?.toString() ?? 'unknown',
          errorMessage: response['reason']?.toString() ?? 'Ödeme başlatılamadı',
        );
      }
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.paytr,
      );
    }
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();

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
        _pendingPayments[merchantOid] = request;

        final iframeToken = response['token'] as String;
        final iframeUrl = 'https://www.paytr.com/odeme/guvenli/$iframeToken';

        return ThreeDSInitResult.pending(
          redirectUrl: iframeUrl,
          transactionId: merchantOid,
        );
      } else {
        return ThreeDSInitResult.failed(
          errorCode: 'token_error',
          errorMessage: response['reason']?.toString() ?? 'Token alınamadı',
        );
      }
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
        throw const PaymentException(
          code: 'invalid_hash',
          message: 'Callback hash doğrulaması başarısız',
          provider: ProviderType.paytr,
        );
      }
    }

    // Pending payment'ı temizle
    _pendingPayments.remove(merchantOid);

    return PayTRMapper.fromCallbackData(callbackData);
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();

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
      return PayTRMapper.fromRefundResponse(response);
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

  @override
  void dispose() {
    if (_initialized) {
      _httpClient.close();
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

  /// Generates a unique merchant order ID using secure random
  String _generateMerchantOid() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(6, (_) => random.nextInt(256));
    final randomHex =
        randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'SP${DateTime.now().millisecondsSinceEpoch}_$randomHex';
  }

  /// Generates a unique request ID using secure random
  String _generateRequestId() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(4, (_) => random.nextInt(256));
    final randomHex =
        randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'REQ${DateTime.now().millisecondsSinceEpoch}_$randomHex';
  }

  String _formatAmount(double amount) => (amount * 100).round().toString();

  String _mapCurrency(Currency currency) {
    switch (currency) {
      case Currency.tryLira:
        return 'TL';
      case Currency.usd:
        return 'USD';
      case Currency.eur:
        return 'EUR';
      case Currency.gbp:
        return 'GBP';
    }
  }

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

  Future<Map<String, dynamic>> _postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    final url = Uri.parse('${PayTREndpoints.baseUrl}$endpoint');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
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
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw PaymentException.timeout(provider: ProviderType.paytr);
      }
      throw PaymentException.networkError(
        providerMessage: e.toString(),
        provider: ProviderType.paytr,
      );
    }
  }
}
