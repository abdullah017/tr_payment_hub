import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() async {
  // Mock provider ile test
  final provider = MockPaymentProvider(shouldSucceed: true);

  // Config oluştur
  final config = IyzicoConfig(
    merchantId: 'test_merchant',
    apiKey: 'test_api_key',
    secretKey: 'test_secret_key',
    isSandbox: true,
  );

  // Provider'ı başlat
  await provider.initialize(config);

  // Test ödeme isteği
  final request = PaymentRequest(
    orderId: 'ORDER_123',
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
      address: 'Test Address',
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

  // Ödeme yap
  try {
    final result = await provider.createPayment(request);
    print('Payment successful!');
    print('Transaction ID: ${result.transactionId}');
    print('Amount: ${result.amount}');
  } on PaymentException catch (e) {
    print('Payment failed: ${e.message}');
  }

  // Taksit sorgula
  final installments = await provider.getInstallments(
    binNumber: '552879',
    amount: 100.0,
  );
  print('\nInstallment options:');
  for (final option in installments.options) {
    print(
      '  ${option.installmentNumber}x ${option.installmentPrice.toStringAsFixed(2)} TL = ${option.totalPrice.toStringAsFixed(2)} TL',
    );
  }

  // Temizle
  provider.dispose();
}
