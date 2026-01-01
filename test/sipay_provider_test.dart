import 'package:test/test.dart';
import 'package:tr_payment_hub/src/providers/sipay/sipay_auth.dart';
import 'package:tr_payment_hub/src/providers/sipay/sipay_error_mapper.dart';
import 'package:tr_payment_hub/src/providers/sipay/sipay_mapper.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('SipayAuth', () {
    late SipayAuth auth;

    setUp(() {
      auth = SipayAuth(
        appKey: 'test_app_key',
        appSecret: 'test_app_secret',
        merchantKey: 'test_merchant_key',
      );
    });

    test('should generate token', () {
      final token = auth.generateToken();

      expect(token, isNotEmpty);
      expect(token, isA<String>());
    });

    test('should generate payment hash', () {
      final hash = auth.generatePaymentHash(
        invoiceId: 'INV123',
        amount: '100.00',
        currency: 'TRY',
      );

      expect(hash, isNotEmpty);
      expect(hash, isA<String>());
    });

    test('should generate refund hash', () {
      final hash = auth.generateRefundHash(
        invoiceId: 'INV123',
        amount: '50.00',
      );

      expect(hash, isNotEmpty);
    });

    test('should generate different hashes for different inputs', () {
      final hash1 = auth.generatePaymentHash(
        invoiceId: 'INV1',
        amount: '100.00',
        currency: 'TRY',
      );
      final hash2 = auth.generatePaymentHash(
        invoiceId: 'INV2',
        amount: '100.00',
        currency: 'TRY',
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('should verify callback hash correctly', () {
      // Geçersiz hash
      final isValid = auth.verifyCallbackHash(
        invoiceId: 'INV123',
        orderId: 'ORD123',
        status: 'success',
        receivedHash: 'invalid_hash',
      );

      expect(isValid, false);
    });
  });

  group('SipayMapper', () {
    test('should create payment request', () {
      final request = _createTestRequest();
      final mapped = SipayMapper.toPaymentRequest(
        request: request,
        merchantKey: 'merchant_key',
        invoiceId: 'INV123',
        hashKey: 'hash_key',
      );

      expect(mapped['cc_holder_name'], 'John Doe');
      expect(mapped['cc_no'], '5528790000000008');
      expect(mapped['merchant_key'], 'merchant_key');
      expect(mapped['invoice_id'], 'INV123');
      expect(mapped['total'], '100.00');
      expect(mapped['currency_code'], 'TRY');
    });

    test('should create 3DS payment request', () {
      final request = _createTestRequest();
      final mapped = SipayMapper.to3DSPaymentRequest(
        request: request,
        merchantKey: 'merchant_key',
        invoiceId: 'INV123',
        hashKey: 'hash_key',
        returnUrl: 'https://example.com/callback',
        cancelUrl: 'https://example.com/cancel',
      );

      expect(mapped['return_url'], 'https://example.com/callback');
      expect(mapped['cancel_url'], 'https://example.com/cancel');
    });

    test('should create refund request', () {
      final mapped = SipayMapper.toRefundRequest(
        invoiceId: 'INV123',
        amount: 50,
        merchantKey: 'merchant_key',
        hashKey: 'hash_key',
      );

      expect(mapped['invoice_id'], 'INV123');
      expect(mapped['amount'], '50.00');
      expect(mapped['merchant_key'], 'merchant_key');
    });

    test('should parse successful payment response', () {
      final response = {
        'status_code': 100,
        'order_id': 'ORD123',
        'transaction_id': 'TX123',
        'amount': 100.0,
        'total': 100.0,
      };

      final result = SipayMapper.fromPaymentResponse(response);

      expect(result.isSuccess, true);
      expect(result.transactionId, 'ORD123');
      expect(result.amount, 100.0);
    });

    test('should parse failed payment response', () {
      final response = {
        'status_code': 0,
        'status_description': 'Payment failed',
      };

      final result = SipayMapper.fromPaymentResponse(response);

      expect(result.isSuccess, false);
      expect(result.errorMessage, 'Payment failed');
    });

    test('should parse 3DS init response', () {
      final response = {
        'status_code': 100,
        'redirect_url': 'https://3ds.example.com',
        'order_id': 'ORD123',
      };

      final result = SipayMapper.from3DSInitResponse(response);

      expect(result.status, ThreeDSStatus.pending);
      expect(result.redirectUrl, 'https://3ds.example.com');
      expect(result.transactionId, 'ORD123');
    });

    test('should parse refund response', () {
      final response = {
        'status_code': 100,
        'refund_id': 'REF123',
        'amount': 50.0,
      };

      final result = SipayMapper.fromRefundResponse(response);

      expect(result.isSuccess, true);
      expect(result.refundId, 'REF123');
      expect(result.refundedAmount, 50.0);
    });

    test('should parse status response', () {
      expect(
        SipayMapper.fromStatusResponse({'order_status': 'success'}),
        PaymentStatus.success,
      );
      expect(
        SipayMapper.fromStatusResponse({'order_status': 'failed'}),
        PaymentStatus.failed,
      );
      expect(
        SipayMapper.fromStatusResponse({'order_status': 'pending'}),
        PaymentStatus.pending,
      );
    });

    test('should parse installment response', () {
      final response = {
        'status_code': 100,
        'installments': [
          {'installment_number': 1, 'total_amount': 100.0},
          {'installment_number': 3, 'total_amount': 103.0},
          {'installment_number': 6, 'total_amount': 106.0},
        ],
      };

      final info = SipayMapper.fromInstallmentResponse(
        response: response,
        binNumber: '552879',
        amount: 100,
      );

      expect(info, isNotNull);
      expect(info!.options.length, 3);
      expect(info.options[0].installmentNumber, 1);
      expect(info.options[1].installmentNumber, 3);
      expect(info.options[2].totalPrice, 106.0);
    });

    test('should parse saved cards response', () {
      final response = {
        'status_code': 100,
        'cards': [
          {
            'card_token': 'token1',
            'last_four': '0008',
            'card_program': 'MASTERCARD',
          },
          {'card_token': 'token2', 'last_four': '1234', 'card_program': 'VISA'},
        ],
      };

      final cards = SipayMapper.fromSavedCardsResponse(response, 'user_key');

      expect(cards.length, 2);
      expect(cards[0].cardToken, 'token1');
      expect(cards[0].lastFourDigits, '0008');
      expect(cards[0].cardAssociation, CardAssociation.masterCard);
      expect(cards[1].cardAssociation, CardAssociation.visa);
    });
  });

  group('SipayErrorMapper', () {
    test('should map insufficient funds error', () {
      final error = SipayErrorMapper.mapError(
        errorCode: 'insufficient_balance',
        errorMessage: 'Yetersiz bakiye',
      );

      expect(error.code, 'insufficient_funds');
      expect(error.provider, ProviderType.sipay);
    });

    test('should map invalid card error', () {
      final error = SipayErrorMapper.mapError(
        errorCode: 'invalid_card_number',
        errorMessage: 'Geçersiz kart numarası',
      );

      expect(error.code, 'invalid_card');
    });

    test('should map expired card error', () {
      final error = SipayErrorMapper.mapError(
        errorCode: 'card_expired',
        errorMessage: 'Kartın süresi dolmuş',
      );

      expect(error.code, 'expired_card');
    });

    test('should map declined error', () {
      final error = SipayErrorMapper.mapError(
        errorCode: 'transaction_declined',
        errorMessage: 'İşlem reddedildi',
      );

      expect(error.code, 'declined');
    });

    test('should map 3DS failed error', () {
      final error = SipayErrorMapper.mapError(
        errorCode: '3ds_failed',
        errorMessage: '3D Secure doğrulama başarısız',
      );

      expect(error.code, 'threeds_failed');
    });

    test('should map unknown error', () {
      final error = SipayErrorMapper.mapError(
        errorCode: 'unknown_code',
        errorMessage: 'Bilinmeyen hata',
      );

      expect(error.code, 'sipay_error');
      expect(error.providerCode, 'unknown_code');
    });

    test('should check success status correctly', () {
      expect(SipayErrorMapper.isSuccess(100), true);
      expect(SipayErrorMapper.isSuccess(1), true);
      expect(SipayErrorMapper.isSuccess(0), false);
      expect(SipayErrorMapper.isSuccess(-1), false);
      expect(SipayErrorMapper.isSuccess(null), false);
    });

    test('should parse card type', () {
      expect(SipayErrorMapper.parseCardType('credit'), CardType.creditCard);
      expect(SipayErrorMapper.parseCardType('debit'), CardType.debitCard);
      expect(SipayErrorMapper.parseCardType('prepaid'), CardType.prepaidCard);
      expect(SipayErrorMapper.parseCardType(null), null);
    });

    test('should parse card association', () {
      expect(
        SipayErrorMapper.parseCardAssociation('VISA'),
        CardAssociation.visa,
      );
      expect(
        SipayErrorMapper.parseCardAssociation('MASTERCARD'),
        CardAssociation.masterCard,
      );
      expect(
        SipayErrorMapper.parseCardAssociation('AMEX'),
        CardAssociation.amex,
      );
      expect(
        SipayErrorMapper.parseCardAssociation('TROY'),
        CardAssociation.troy,
      );
      expect(SipayErrorMapper.parseCardAssociation(null), null);
    });

    test('should parse payment status', () {
      expect(
        SipayErrorMapper.parsePaymentStatus('success'),
        PaymentStatus.success,
      );
      expect(
        SipayErrorMapper.parsePaymentStatus('completed'),
        PaymentStatus.success,
      );
      expect(
        SipayErrorMapper.parsePaymentStatus('failed'),
        PaymentStatus.failed,
      );
      expect(
        SipayErrorMapper.parsePaymentStatus('pending'),
        PaymentStatus.pending,
      );
      expect(
        SipayErrorMapper.parsePaymentStatus('refunded'),
        PaymentStatus.refunded,
      );
    });
  });

  group('SipayProvider', () {
    late SipayProvider provider;
    late SipayConfig config;

    setUp(() {
      provider = SipayProvider();
      config = const SipayConfig(
        merchantId: 'TEST_MERCHANT',
        apiKey: 'test_app_key',
        secretKey: 'test_app_secret',
        merchantKey: 'test_merchant_key',
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('should have correct provider type', () {
      expect(provider.providerType, ProviderType.sipay);
    });

    test('should initialize with valid config', () async {
      await provider.initialize(config);
      // No exception means success
    });

    test('should throw error with invalid config type', () async {
      const invalidConfig = IyzicoConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
      );

      expect(
        () => provider.initialize(invalidConfig),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should throw error with empty config', () async {
      const emptyConfig = SipayConfig(
        merchantId: '',
        apiKey: '',
        secretKey: '',
        merchantKey: '',
      );

      expect(
        () => provider.initialize(emptyConfig),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should throw error when not initialized', () async {
      final request = _createTestRequest();

      expect(
        () => provider.createPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should require callback URL for 3DS payment', () async {
      await provider.initialize(config);
      final request = _createTestRequest();

      expect(
        () => provider.init3DSPayment(request),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should require callback data for complete3DSPayment', () async {
      await provider.initialize(config);

      expect(
        () => provider.complete3DSPayment('INV123'),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should return default installment options', () async {
      await provider.initialize(config);

      final installments = await provider.getInstallments(
        binNumber: '552879',
        amount: 100,
      );

      expect(installments.options.length, greaterThan(0));
      expect(installments.force3DS, true);
    });
  });

  group('SipayConfig', () {
    test('should return sandbox URL when isSandbox is true', () {
      const config = SipayConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        merchantKey: 'test',
      );

      expect(config.baseUrl, 'https://sandbox.sipay.com.tr');
    });

    test('should return production URL when isSandbox is false', () {
      const config = SipayConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        merchantKey: 'test',
        isSandbox: false,
      );

      expect(config.baseUrl, 'https://app.sipay.com.tr');
    });

    test('should validate config correctly', () {
      const validConfig = SipayConfig(
        merchantId: 'test',
        apiKey: 'test',
        secretKey: 'test',
        merchantKey: 'test',
      );

      const invalidConfig = SipayConfig(
        merchantId: '',
        apiKey: 'test',
        secretKey: '',
        merchantKey: '',
      );

      expect(validConfig.validate(), true);
      expect(invalidConfig.validate(), false);
    });
  });

  group('TrPaymentHub Factory', () {
    test('should create SipayProvider from factory', () {
      final provider = TrPaymentHub.create(ProviderType.sipay);

      expect(provider, isA<SipayProvider>());
      expect(provider.providerType, ProviderType.sipay);
    });
  });
}

PaymentRequest _createTestRequest() => const PaymentRequest(
  orderId: 'ORDER_123',
  amount: 100,
  card: CardInfo(
    cardHolderName: 'John Doe',
    cardNumber: '5528790000000008',
    expireMonth: '12',
    expireYear: '2030',
    cvc: '123',
  ),
  buyer: BuyerInfo(
    id: 'BUYER_123',
    name: 'John',
    surname: 'Doe',
    email: 'john@example.com',
    phone: '+905551234567',
    ip: '127.0.0.1',
    city: 'Istanbul',
    country: 'Turkey',
    address: 'Test Address',
  ),
  basketItems: [
    BasketItem(
      id: 'ITEM_1',
      name: 'Test Product',
      category: 'Electronics',
      price: 100,
      itemType: ItemType.physical,
    ),
  ],
);
