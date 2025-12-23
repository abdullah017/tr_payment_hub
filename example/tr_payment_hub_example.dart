import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() async {
  print('=== TR Payment Hub Example ===\n');

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
  // 7. Kart Doğrulama Örneği
  // ----------------------------------------
  print('7. Card Validation Example');
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

  // Cleanup
  mockProvider.dispose();
  failingProvider.dispose();

  print('=== Example Complete ===');
}

PaymentRequest _createTestRequest() {
  return PaymentRequest(
    orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
    amount: 100.0,
    currency: Currency.TRY,
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
