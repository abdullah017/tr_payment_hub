import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() {
  group('ProxyPaymentProvider', () {
    late ProxyPaymentProvider provider;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/create')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'transactionId': 'TXN_123',
              'paymentId': 'PAY_123',
              'amount': 100.0,
              'paidAmount': 100.0,
              'installment': 1,
              'cardType': 'creditCard',
              'cardAssociation': 'masterCard',
              'binNumber': '552879',
              'lastFourDigits': '0008',
            }),
            200,
          );
        }

        if (path.endsWith('/installments')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'binNumber': '552879',
              'bankName': 'Garanti Bankasi',
              'bankCode': 62,
              'cardType': 'creditCard',
              'cardAssociation': 'masterCard',
              'options': [
                {
                  'installmentNumber': 1,
                  'installmentPrice': 100.0,
                  'totalPrice': 100.0,
                },
                {
                  'installmentNumber': 3,
                  'installmentPrice': 34.0,
                  'totalPrice': 102.0,
                },
              ],
            }),
            200,
          );
        }

        if (path.endsWith('/3ds/init')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'pending',
              'transactionId': 'TXN_3DS',
              'redirectUrl': 'https://bank.com/3ds',
            }),
            200,
          );
        }

        if (path.endsWith('/3ds/complete')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'transactionId': 'TXN_3DS',
              'amount': 100.0,
              'paidAmount': 100.0,
            }),
            200,
          );
        }

        if (path.endsWith('/refund')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'refundId': 'REF_123',
              'refundedAmount': 50.0,
            }),
            200,
          );
        }

        if (path.contains('/status/')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'success',
            }),
            200,
          );
        }

        if (path.endsWith('/cards')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'cards': [
                {
                  'cardToken': 'CARD_TOKEN_123',
                  'cardAlias': 'Bonus Kartim',
                  'binNumber': '552879',
                  'lastFourDigits': '0008',
                  'cardType': 'creditCard',
                  'cardAssociation': 'masterCard',
                },
              ],
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      provider = ProxyPaymentProvider(
        config: ProxyConfig(baseUrl: 'https://api.test.com/payment'),
        httpClient: mockHttpClient,
      );
    });

    test('should initialize with provider type', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      expect(provider.isInitialized, true);
      expect(provider.providerType, ProviderType.iyzico);
    });

    test('should throw if not initialized', () async {
      expect(
        () => provider.createPayment(_createTestRequest()),
        throwsA(isA<PaymentException>()),
      );
    });

    test('should create payment via proxy', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      final result = await provider.createPayment(_createTestRequest());

      expect(result.isSuccess, true);
      expect(result.transactionId, 'TXN_123');
      expect(result.amount, 100.0);
      expect(result.binNumber, '552879');
    });

    test('should query installments via proxy', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      final result = await provider.getInstallments(
        binNumber: '552879',
        amount: 100.0,
      );

      expect(result.bankName, 'Garanti Bankasi');
      expect(result.options.length, 2);
      expect(result.options.first.installmentNumber, 1);
    });

    test('should init 3DS payment', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      final result = await provider.init3DSPayment(_createTestRequest());

      expect(result.status, ThreeDSStatus.pending);
      expect(result.transactionId, 'TXN_3DS');
      expect(result.redirectUrl, 'https://bank.com/3ds');
    });

    test('should complete 3DS payment', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      final result = await provider.complete3DSPayment('TXN_3DS');

      expect(result.isSuccess, true);
      expect(result.transactionId, 'TXN_3DS');
    });

    test('should process refund', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      final result = await provider.refund(
        RefundRequest(
          transactionId: 'TXN_123',
          amount: 50.0,
        ),
      );

      expect(result.isSuccess, true);
      expect(result.refundId, 'REF_123');
      expect(result.refundedAmount, 50.0);
    });

    test('should get payment status', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      final status = await provider.getPaymentStatus('TXN_123');

      expect(status, PaymentStatus.success);
    });

    test('should get saved cards', () async {
      await provider.initializeWithProvider(ProviderType.iyzico);

      final cards = await provider.getSavedCards('USER_123');

      expect(cards.length, 1);
      expect(cards.first.cardToken, 'CARD_TOKEN_123');
      expect(cards.first.binNumber, '552879');
    });

    test('should handle backend errors', () async {
      final errorClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'errorCode': 'insufficient_funds',
            'errorMessage': 'Yetersiz bakiye',
          }),
          400,
        );
      });

      final errorProvider = ProxyPaymentProvider(
        config: ProxyConfig(baseUrl: 'https://api.test.com/payment'),
        httpClient: errorClient,
      );

      await errorProvider.initializeWithProvider(ProviderType.iyzico);

      expect(
        () => errorProvider.createPayment(_createTestRequest()),
        throwsA(
          isA<PaymentException>().having(
            (e) => e.code,
            'code',
            'insufficient_funds',
          ),
        ),
      );
    });

    test('should retry on network error', () async {
      var callCount = 0;

      final retryClient = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          throw http.ClientException('Network error');
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'transactionId': 'TXN_RETRY',
            'amount': 100.0,
          }),
          200,
        );
      });

      final retryProvider = ProxyPaymentProvider(
        config: ProxyConfig(
          baseUrl: 'https://api.test.com/payment',
          maxRetries: 3,
          retryDelay: const Duration(milliseconds: 10),
        ),
        httpClient: retryClient,
      );

      await retryProvider.initializeWithProvider(ProviderType.iyzico);
      final result = await retryProvider.createPayment(_createTestRequest());

      expect(result.transactionId, 'TXN_RETRY');
      expect(callCount, 3);
    });

    test('should include auth token in headers', () async {
      String? capturedAuthHeader;

      final authClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'success': true,
            'transactionId': 'TXN_AUTH',
            'amount': 100.0,
          }),
          200,
        );
      });

      final authProvider = ProxyPaymentProvider(
        config: ProxyConfig(
          baseUrl: 'https://api.test.com/payment',
          authToken: 'my_jwt_token',
        ),
        httpClient: authClient,
      );

      await authProvider.initializeWithProvider(ProviderType.iyzico);
      await authProvider.createPayment(_createTestRequest());

      expect(capturedAuthHeader, 'Bearer my_jwt_token');
    });

    test('should validate config on initialization', () async {
      final invalidProvider = ProxyPaymentProvider(
        config: const ProxyConfig(baseUrl: ''),
      );

      expect(
        () => invalidProvider.initializeWithProvider(ProviderType.iyzico),
        throwsA(isA<PaymentException>()),
      );
    });
  });

  group('ProxyConfig', () {
    test('should validate baseUrl', () {
      expect(
        const ProxyConfig(baseUrl: 'https://api.test.com').validate(),
        true,
      );
      expect(
        const ProxyConfig(baseUrl: 'http://localhost:3000').validate(),
        true,
      );
      expect(
        const ProxyConfig(baseUrl: '').validate(),
        false,
      );
      expect(
        const ProxyConfig(baseUrl: 'invalid-url').validate(),
        false,
      );
    });

    test('should merge headers', () {
      const config = ProxyConfig(
        baseUrl: 'https://api.test.com',
        authToken: 'token123',
        headers: {'X-Custom': 'value'},
      );

      expect(config.allHeaders['Authorization'], 'Bearer token123');
      expect(config.allHeaders['X-Custom'], 'value');
      expect(config.allHeaders['Content-Type'], 'application/json');
    });

    test('should support copyWith', () {
      const original = ProxyConfig(
        baseUrl: 'https://api.test.com',
        authToken: 'old_token',
      );

      final modified = original.copyWith(authToken: 'new_token');

      expect(modified.baseUrl, 'https://api.test.com');
      expect(modified.authToken, 'new_token');
    });
  });
}

PaymentRequest _createTestRequest() {
  return PaymentRequest(
    orderId: 'TEST_ORDER',
    amount: 100.0,
    currency: Currency.tryLira,
    installment: 1,
    card: const CardInfo(
      cardHolderName: 'Test User',
      cardNumber: '5528790000000008',
      expireMonth: '12',
      expireYear: '2030',
      cvc: '123',
    ),
    buyer: const BuyerInfo(
      id: 'BUYER_1',
      name: 'Test',
      surname: 'User',
      email: 'test@example.com',
      phone: '+905551234567',
      ip: '127.0.0.1',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Address',
    ),
    basketItems: const [
      BasketItem(
        id: 'ITEM_1',
        name: 'Test Product',
        category: 'Test',
        price: 100.0,
        itemType: ItemType.physical,
      ),
    ],
  );
}
