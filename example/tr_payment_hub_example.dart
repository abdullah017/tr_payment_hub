// Full SDK import (includes all features)
// For client-only usage, use: import 'package:tr_payment_hub/tr_payment_hub_client.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() async {
  print('=== TR Payment Hub v3.0 Example ===\n');

  // ========================================
  // USAGE MODES / KULLANIM MODLARI
  // ========================================
  //
  // 1. DIRECT MODE (Dart Backend için):
  //    import 'package:tr_payment_hub/tr_payment_hub.dart';
  //    final provider = TrPaymentHub.create(ProviderType.iyzico);
  //    await provider.initialize(IyzicoConfig(...));
  //
  // 2. PROXY MODE (Flutter + Custom Backend için):
  //    import 'package:tr_payment_hub/tr_payment_hub_client.dart';
  //    final provider = TrPaymentHub.createProxy(baseUrl: '...');
  //    await provider.initializeWithProvider(ProviderType.iyzico);
  //
  // ========================================

  // ----------------------------------------
  // 1. Mock Provider ile Test
  // ----------------------------------------
  print('1. Mock Provider Test');
  print('-' * 40);

  final mockProvider = TrPaymentHub.createMock(shouldSucceed: true);
  final mockConfig = IyzicoConfig(
    merchantId: 'mock_merchant',
    apiKey: 'mock_api_key',
    secretKey: 'mock_secret_key',
  );

  await mockProvider.initialize(mockConfig);

  final mockResult = await mockProvider.createPayment(_createTestRequest());
  print('Mock Payment Result: ${mockResult.isSuccess ? "SUCCESS" : "FAILED"}');
  print('Transaction ID: ${mockResult.transactionId}');
  print('');

  // ----------------------------------------
  // 2. iyzico Provider Örneği
  // ----------------------------------------
  print('2. iyzico Provider Example');
  print('-' * 40);

  final iyzicoProvider = TrPaymentHub.create(ProviderType.iyzico);
  final iyzicoConfig = IyzicoConfig(
    merchantId: 'your_merchant_id', // Gerçek değerlerinizi girin
    apiKey: 'your_api_key',
    secretKey: 'your_secret_key',
    isSandbox: true,
  );

  print('Provider Type: ${iyzicoProvider.providerType}');
  print('Base URL: ${iyzicoConfig.baseUrl}');
  print('');

  // NOT: Gerçek API çağrısı için initialize ve createPayment kullanın
  // await iyzicoProvider.initialize(iyzicoConfig);
  // final result = await iyzicoProvider.createPayment(request);

  // ----------------------------------------
  // 3. PayTR Provider Örneği
  // ----------------------------------------
  print('3. PayTR Provider Example');
  print('-' * 40);

  final paytrProvider = TrPaymentHub.create(ProviderType.paytr);
  final paytrConfig = PayTRConfig(
    merchantId: 'your_merchant_id', // Gerçek değerlerinizi girin
    apiKey: 'your_merchant_key',
    secretKey: 'your_merchant_salt',
    successUrl: 'https://yoursite.com/success',
    failUrl: 'https://yoursite.com/fail',
    callbackUrl: 'https://yoursite.com/callback',
    isSandbox: true,
  );

  print('Provider Type: ${paytrProvider.providerType}');
  print('Base URL: ${paytrConfig.baseUrl}');
  print('');

  // ----------------------------------------
  // 4. Taksit Sorgulama Örneği
  // ----------------------------------------
  print('4. Installment Query Example');
  print('-' * 40);

  final installments = await mockProvider.getInstallments(
    binNumber: '552879',
    amount: 1000.0,
  );

  print('Card Family: ${installments.cardFamily}');
  print('Bank: ${installments.bankName}');
  print('Force 3DS: ${installments.force3DS}');
  print('Installment Options:');
  for (final option in installments.options) {
    final rate = option.calculateInterestRate(1000.0);
    print(
      '  ${option.installmentNumber}x ${option.installmentPrice.toStringAsFixed(2)} TL '
      '= ${option.totalPrice.toStringAsFixed(2)} TL '
      '(${rate.toStringAsFixed(1)}% faiz)',
    );
  }
  print('');

  // ----------------------------------------
  // 5. Hata Yönetimi Örneği
  // ----------------------------------------
  print('5. Error Handling Example');
  print('-' * 40);

  final failingProvider = TrPaymentHub.createMock(
    shouldSucceed: false,
    customError: PaymentException.insufficientFunds(),
  );
  await failingProvider.initialize(mockConfig);

  try {
    await failingProvider.createPayment(_createTestRequest());
  } on PaymentException catch (e) {
    print('Payment Error: ${e.code}');
    print('Message: ${e.message}');
    print('User Friendly: ${e.userFriendlyMessage}');
  }
  print('');

  // ----------------------------------------
  // 6. Log Sanitization Örneği
  // ----------------------------------------
  print('6. Log Sanitization Example');
  print('-' * 40);

  const sensitiveLog = 'Card: 5528790000000008, CVV: 123';
  final sanitizedLog = LogSanitizer.sanitize(sensitiveLog);
  print('Original: $sensitiveLog');
  print('Sanitized: $sanitizedLog');
  print('');

  // ----------------------------------------
  // 7. Kart Doğrulama Örneği (CardInfo)
  // ----------------------------------------
  print('7. Card Validation Example (CardInfo)');
  print('-' * 40);

  final card = CardInfo(
    cardHolderName: 'John Doe',
    cardNumber: '5528790000000008',
    expireMonth: '12',
    expireYear: '2030',
    cvc: '123',
  );

  print('Card Number: ${card.maskedNumber}');
  print('BIN: ${card.binNumber}');
  print('Last 4: ${card.lastFourDigits}');
  print('Valid (Luhn): ${card.isValidNumber}');
  print('');

  // ----------------------------------------
  // 8. Client-Side CardValidator (v3.0+)
  // ----------------------------------------
  print('8. Client-Side CardValidator (v3.0+)');
  print('-' * 40);

  // Kart doğrulama - backend'e göndermeden önce
  final cardValidation = CardValidator.validate(
    cardNumber: '5528790000000008',
    expireMonth: '12',
    expireYear: '2030',
    cvv: '123',
    holderName: 'Ahmet Yilmaz',
  );

  print('Valid: ${cardValidation.isValid}');
  print('Card Brand: ${cardValidation.cardBrand.displayName}');
  if (!cardValidation.isValid) {
    print('Errors: ${cardValidation.errors}');
  }

  // Kart numarası formatlama ve maskeleme
  print('Formatted: ${CardValidator.formatCardNumber("5528790000000008")}');
  print('Masked: ${CardValidator.maskCardNumber("5528790000000008")}');
  print('BIN: ${CardValidator.extractBin("5528790000000008")}');

  // Kart markası tespiti
  print(
      'Visa: ${CardValidator.detectCardBrand("4111111111111111").displayName}');
  print(
      'Amex: ${CardValidator.detectCardBrand("374245455400126").displayName}');
  print(
      'Troy: ${CardValidator.detectCardBrand("9792000000000001").displayName}');
  print('');

  // ----------------------------------------
  // 9. Client-Side RequestValidator (v3.0+)
  // ----------------------------------------
  print('9. Client-Side RequestValidator (v3.0+)');
  print('-' * 40);

  final request = _createTestRequest();
  final requestValidation = RequestValidator.validate(request);

  print('Request Valid: ${requestValidation.isValid}');
  print('Error Count: ${requestValidation.errorCount}');
  if (!requestValidation.isValid) {
    for (final error in requestValidation.allErrors) {
      print('  - $error');
    }
  }
  print('');

  // ----------------------------------------
  // 10. Proxy Mode Örneği (v3.0+)
  // ----------------------------------------
  print('10. Proxy Mode Example (v3.0+)');
  print('-' * 40);

  // NOT: Bu örnek çalışması için backend gerektirir
  // Backend örnekleri: backend-examples/nodejs-express/ veya backend-examples/python-fastapi/

  print('Proxy Mode için:');
  print('  1. Backend\'inizi kurun (Node.js/Python/Go/PHP)');
  print('  2. API anahtarlarını backend\'de saklayın');
  print('  3. Flutter\'da createProxy kullanın:');
  print('');
  print('  final provider = TrPaymentHub.createProxy(');
  print('    baseUrl: "https://api.yourbackend.com/payment",');
  print('    provider: ProviderType.iyzico,');
  print('    authToken: "user_jwt_token",');
  print('  );');
  print('');

  // Proxy config örneği
  const proxyConfig = ProxyConfig(
    baseUrl: 'https://api.example.com/payment',
    authToken: 'example_token',
    timeout: Duration(seconds: 30),
    maxRetries: 3,
  );

  print('Proxy Config:');
  print('  Base URL: ${proxyConfig.baseUrl}');
  print('  Timeout: ${proxyConfig.timeout.inSeconds}s');
  print('  Max Retries: ${proxyConfig.maxRetries}');
  print('  Valid: ${proxyConfig.validate()}');
  print('');

  // ----------------------------------------
  // 11. JSON Serialization (v3.0+)
  // ----------------------------------------
  print('11. JSON Serialization (v3.0+)');
  print('-' * 40);

  // PaymentRequest toJson/fromJson
  final requestJson = request.toJson();
  print('PaymentRequest toJson: orderId=${requestJson['orderId']}');

  final restoredRequest = PaymentRequest.fromJson(requestJson);
  print('PaymentRequest fromJson: orderId=${restoredRequest.orderId}');
  print('');

  // Cleanup
  mockProvider.dispose();
  failingProvider.dispose();

  print('=== Example Complete ===');
}

PaymentRequest _createTestRequest() {
  return PaymentRequest(
    orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
    amount: 100.0,
    currency: Currency.tryLira,
    installment: 1,
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
      address: 'Test Address, No: 1',
    ),
    basketItems: [
      BasketItem(
        id: 'ITEM_1',
        name: 'Test Product',
        category: 'Electronics',
        price: 100.0,
        itemType: ItemType.physical,
      ),
    ],
  );
}
