import '../core/enums.dart';
import '../core/models/basket_item.dart';
import '../core/models/buyer_info.dart';
import '../core/models/card_info.dart';
import '../core/models/payment_request.dart';
import 'test_cards.dart';

/// Generates fake [CardInfo] objects for testing.
///
/// ## Example
///
/// ```dart
/// final validCard = FakeCardInfo.valid();
/// final expiredCard = FakeCardInfo.expired();
/// ```
class FakeCardInfo {
  FakeCardInfo._();

  /// Creates a valid Visa card for testing.
  static CardInfo valid({CardAssociation? association, bool saveCard = false}) {
    final cardNumber = _getCardNumberForAssociation(association);
    return CardInfo(
      cardHolderName: 'Test User',
      cardNumber: cardNumber,
      expireMonth: '12',
      expireYear: '2030',
      cvc: '123',
      saveCard: saveCard,
    );
  }

  /// Creates a valid Visa card.
  static CardInfo visa({bool saveCard = false}) =>
      valid(association: CardAssociation.visa, saveCard: saveCard);

  /// Creates a valid Mastercard.
  static CardInfo mastercard({bool saveCard = false}) =>
      valid(association: CardAssociation.masterCard, saveCard: saveCard);

  /// Creates a valid AMEX card.
  static CardInfo amex({bool saveCard = false}) => CardInfo(
        cardHolderName: 'Test User',
        cardNumber: TestCards.iyzicoAmex,
        expireMonth: '12',
        expireYear: '2030',
        cvc: '1234', // AMEX uses 4-digit CVV
        saveCard: saveCard,
      );

  /// Creates a valid Troy card.
  static CardInfo troy({bool saveCard = false}) =>
      valid(association: CardAssociation.troy, saveCard: saveCard);

  /// Creates an expired card.
  static CardInfo expired() => const CardInfo(
        cardHolderName: 'Expired User',
        cardNumber: '5528790000000008',
        expireMonth: TestCards.expiredMonth,
        expireYear: TestCards.expiredYear,
        cvc: '123',
      );

  /// Creates a card that will trigger insufficient funds error.
  static CardInfo insufficientFunds() => const CardInfo(
        cardHolderName: 'Poor User',
        cardNumber: TestCards.iyzicoInsufficientFunds,
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

  /// Creates a card that requires 3D Secure.
  static CardInfo threeDSRequired() => const CardInfo(
        cardHolderName: '3DS User',
        cardNumber: TestCards.iyzico3DSRequired,
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

  /// Creates a card with invalid Luhn checksum.
  static CardInfo luhnInvalid() => const CardInfo(
        cardHolderName: 'Invalid User',
        cardNumber: TestCards.luhnInvalid,
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

  /// Creates a card number that's too short.
  static CardInfo tooShort() => const CardInfo(
        cardHolderName: 'Short User',
        cardNumber: TestCards.tooShort,
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      );

  static String _getCardNumberForAssociation(CardAssociation? association) {
    switch (association) {
      case CardAssociation.visa:
        return TestCards.iyzicoSuccessVisa;
      case CardAssociation.masterCard:
        return TestCards.iyzicoSuccessMastercard;
      case CardAssociation.amex:
        return TestCards.iyzicoAmex;
      case CardAssociation.troy:
        return TestCards.iyzicoTroy;
      case null:
        return TestCards.iyzicoSuccessMastercard;
    }
  }
}

/// Generates fake [BuyerInfo] objects for testing.
///
/// ## Example
///
/// ```dart
/// final buyer = FakeBuyerInfo.standard();
/// final customBuyer = FakeBuyerInfo.withEmail('custom@test.com');
/// ```
class FakeBuyerInfo {
  FakeBuyerInfo._();

  /// Creates a standard test buyer.
  static BuyerInfo standard() => const BuyerInfo(
        id: 'BUYER_001',
        name: 'John',
        surname: 'Doe',
        email: 'john.doe@test.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Caddesi No:123 Kadikoy',
        zipCode: '34700',
        identityNumber: '11111111111',
      );

  /// Creates a buyer with minimal required fields.
  static BuyerInfo minimal() => const BuyerInfo(
        id: 'BUYER_MIN',
        name: 'Min',
        surname: 'User',
        email: 'min@test.com',
        phone: '+905550000000',
        ip: '127.0.0.1',
        city: 'Ankara',
        country: 'Turkey',
        address: 'Minimal Address',
      );

  /// Creates a buyer with a specific email.
  static BuyerInfo withEmail(String email) => BuyerInfo(
        id: 'BUYER_EMAIL',
        name: 'Email',
        surname: 'User',
        email: email,
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      );

  /// Creates a buyer with a specific phone number.
  static BuyerInfo withPhone(String phone) => BuyerInfo(
        id: 'BUYER_PHONE',
        name: 'Phone',
        surname: 'User',
        email: 'phone@test.com',
        phone: phone,
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      );

  /// Creates a buyer with a specific IP address.
  static BuyerInfo withIp(String ip) => BuyerInfo(
        id: 'BUYER_IP',
        name: 'IP',
        surname: 'User',
        email: 'ip@test.com',
        phone: '+905551234567',
        ip: ip,
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      );
}

/// Generates fake [BasketItem] objects for testing.
///
/// ## Example
///
/// ```dart
/// final item = FakeBasketItem.physical(price: 100);
/// final items = FakeBasketItem.multipleItems(count: 3);
/// ```
class FakeBasketItem {
  FakeBasketItem._();

  /// Creates a physical product item.
  static BasketItem physical({
    double price = 100,
    int quantity = 1,
    String? name,
  }) =>
      BasketItem(
        id: 'ITEM_${DateTime.now().millisecondsSinceEpoch}',
        name: name ?? 'Test Physical Product',
        category: 'Electronics',
        price: price,
        quantity: quantity,
        itemType: ItemType.physical,
      );

  /// Creates a virtual/digital product item.
  static BasketItem virtual({
    double price = 50,
    int quantity = 1,
    String? name,
  }) =>
      BasketItem(
        id: 'ITEM_${DateTime.now().millisecondsSinceEpoch}',
        name: name ?? 'Test Virtual Product',
        category: 'Digital',
        price: price,
        quantity: quantity,
        itemType: ItemType.virtual,
      );

  /// Creates a subscription item.
  static BasketItem subscription({double price = 29.99, String? name}) =>
      BasketItem(
        id: 'SUB_${DateTime.now().millisecondsSinceEpoch}',
        name: name ?? 'Monthly Subscription',
        category: 'Subscription',
        price: price,
        itemType: ItemType.virtual,
      );

  /// Creates multiple items with sequential names.
  static List<BasketItem> multipleItems({
    int count = 3,
    double pricePerItem = 100,
  }) =>
      List.generate(
        count,
        (index) => BasketItem(
          id: 'ITEM_$index',
          name: 'Product ${index + 1}',
          category: 'Mixed',
          price: pricePerItem,
          itemType: index.isEven ? ItemType.physical : ItemType.virtual,
        ),
      );
}

/// Generates fake [PaymentRequest] objects for testing.
///
/// ## Example
///
/// ```dart
/// final request = FakePaymentRequest.simple(amount: 500);
/// final fullRequest = FakePaymentRequest.complete();
/// ```
class FakePaymentRequest {
  FakePaymentRequest._();

  /// Creates a simple payment request with minimal fields.
  static PaymentRequest simple({
    double amount = 100,
    int installment = 1,
    Currency currency = Currency.tryLira,
  }) =>
      PaymentRequest(
        orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        currency: currency,
        installment: installment,
        card: FakeCardInfo.valid(),
        buyer: FakeBuyerInfo.standard(),
        basketItems: [FakeBasketItem.physical(price: amount)],
      );

  /// Creates a complete payment request with all fields populated.
  static PaymentRequest complete({
    double amount = 500,
    int installment = 3,
    Currency currency = Currency.tryLira,
    bool use3DS = true,
  }) =>
      PaymentRequest(
        orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        paidPrice: amount * 1.03, // 3% installment fee
        currency: currency,
        installment: installment,
        use3DS: use3DS,
        card: FakeCardInfo.valid(),
        buyer: FakeBuyerInfo.standard(),
        shippingAddress: const AddressInfo(
          contactName: 'John Doe',
          city: 'Istanbul',
          country: 'Turkey',
          address: 'Shipping Address 123',
          zipCode: '34700',
        ),
        billingAddress: const AddressInfo(
          contactName: 'John Doe',
          city: 'Istanbul',
          country: 'Turkey',
          address: 'Billing Address 456',
          zipCode: '34700',
        ),
        basketItems: FakeBasketItem.multipleItems(pricePerItem: 166.67),
      );

  /// Creates a payment request with a specific amount.
  static PaymentRequest withAmount(double amount) => simple(amount: amount);

  /// Creates a payment request with installments.
  static PaymentRequest withInstallments(int installments) =>
      simple(installment: installments);

  /// Creates a payment request that requires 3D Secure.
  static PaymentRequest threeDSRequired({
    double amount = 100,
    int installment = 1,
  }) =>
      PaymentRequest(
        orderId: 'ORDER_3DS_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        installment: installment,
        use3DS: true,
        card: FakeCardInfo.threeDSRequired(),
        buyer: FakeBuyerInfo.standard(),
        basketItems: [FakeBasketItem.physical(price: amount)],
      );

  /// Creates a payment request with an expired card.
  static PaymentRequest expiredCard({double amount = 100}) => PaymentRequest(
        orderId: 'ORDER_EXP_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        card: FakeCardInfo.expired(),
        buyer: FakeBuyerInfo.standard(),
        basketItems: [FakeBasketItem.physical(price: amount)],
      );

  /// Creates a payment request that will fail due to insufficient funds.
  static PaymentRequest insufficientFunds({double amount = 100000}) =>
      PaymentRequest(
        orderId: 'ORDER_NSF_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        card: FakeCardInfo.insufficientFunds(),
        buyer: FakeBuyerInfo.standard(),
        basketItems: [FakeBasketItem.physical(price: amount)],
      );

  /// Creates a payment request with a Visa card.
  static PaymentRequest visa({double amount = 100}) => PaymentRequest(
        orderId: 'ORDER_VISA_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        card: FakeCardInfo.visa(),
        buyer: FakeBuyerInfo.standard(),
        basketItems: [FakeBasketItem.physical(price: amount)],
      );

  /// Creates a payment request with a Mastercard.
  static PaymentRequest mastercard({double amount = 100}) => PaymentRequest(
        orderId: 'ORDER_MC_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        card: FakeCardInfo.mastercard(),
        buyer: FakeBuyerInfo.standard(),
        basketItems: [FakeBasketItem.physical(price: amount)],
      );

  /// Creates a payment request with an AMEX card.
  static PaymentRequest amex({double amount = 100}) => PaymentRequest(
        orderId: 'ORDER_AMEX_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        card: FakeCardInfo.amex(),
        buyer: FakeBuyerInfo.standard(),
        basketItems: [FakeBasketItem.physical(price: amount)],
      );
}
