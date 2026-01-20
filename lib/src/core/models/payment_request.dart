import 'package:meta/meta.dart';

import '../enums.dart';
import '../exceptions/validation_exception.dart';
import 'basket_item.dart';
import 'buyer_info.dart';
import 'card_info.dart';

/// Address information for shipping or billing.
///
/// ## Example
///
/// ```dart
/// final address = AddressInfo(
///   contactName: 'John Doe',
///   city: 'Istanbul',
///   country: 'Turkey',
///   address: 'Kadikoy, Istanbul 34000',
/// );
/// ```
@immutable
class AddressInfo {
  /// Creates a new [AddressInfo] instance.
  const AddressInfo({
    required this.contactName,
    required this.city,
    required this.country,
    required this.address,
    this.zipCode,
  });

  /// Creates an [AddressInfo] from a JSON map.
  factory AddressInfo.fromJson(Map<String, dynamic> json) => AddressInfo(
        contactName: json['contactName'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        address: json['address'] as String,
        zipCode: json['zipCode'] as String?,
      );

  /// Contact name for this address.
  final String contactName;

  /// City name.
  final String city;

  /// Country name.
  final String country;

  /// Full street address.
  final String address;

  /// Postal/ZIP code (optional).
  final String? zipCode;

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'contactName': contactName,
        'city': city,
        'country': country,
        'address': address,
        if (zipCode != null) 'zipCode': zipCode,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressInfo &&
          runtimeType == other.runtimeType &&
          contactName == other.contactName &&
          city == other.city &&
          country == other.country &&
          address == other.address &&
          zipCode == other.zipCode;

  @override
  int get hashCode => Object.hash(contactName, city, country, address, zipCode);

  @override
  String toString() => 'AddressInfo(contact: $contactName, city: $city)';
}

/// Payment request containing all data needed to process a payment.
///
/// ## Example
///
/// ```dart
/// final request = PaymentRequest(
///   orderId: 'ORDER_123',
///   amount: 100.0,
///   currency: Currency.tryLira,
///   installment: 1,
///   card: CardInfo(
///     cardHolderName: 'JOHN DOE',
///     cardNumber: '5528790000000008',
///     expireMonth: '12',
///     expireYear: '2030',
///     cvc: '123',
///   ),
///   buyer: BuyerInfo(
///     id: 'BUYER_1',
///     name: 'John',
///     surname: 'Doe',
///     email: 'john@example.com',
///     phone: '+905551234567',
///     ip: '127.0.0.1',
///     city: 'Istanbul',
///     country: 'Turkey',
///     address: 'Test Address',
///   ),
///   basketItems: [
///     BasketItem(
///       id: 'ITEM_1',
///       name: 'Product',
///       category: 'Category',
///       price: 100.0,
///       itemType: ItemType.physical,
///     ),
///   ],
/// );
/// ```
///
/// ## 3D Secure Payments
///
/// For 3DS payments, set [callbackUrl] to receive the verification result:
///
/// ```dart
/// final request = PaymentRequest(
///   // ... other fields ...
///   callbackUrl: 'https://yoursite.com/3ds-callback',
///   use3DS: true,
/// );
/// ```
@immutable
class PaymentRequest {
  /// Creates a new [PaymentRequest] instance.
  const PaymentRequest({
    required this.orderId,
    required this.amount,
    required this.card,
    required this.buyer,
    required this.basketItems,
    this.paidPrice,
    this.currency = Currency.tryLira,
    this.installment = 1,
    this.shippingAddress,
    this.billingAddress,
    this.callbackUrl,
    this.use3DS = false,
    this.metadata,
  });

  /// Creates a [PaymentRequest] from a JSON map.
  ///
  /// Used for deserializing requests from backend or storage.
  factory PaymentRequest.fromJson(Map<String, dynamic> json) => PaymentRequest(
        orderId: json['orderId'] as String,
        amount: (json['amount'] as num).toDouble(),
        paidPrice: json['paidPrice'] != null
            ? (json['paidPrice'] as num).toDouble()
            : null,
        currency: Currency.values.firstWhere(
          (c) => c.name == json['currency'],
          orElse: () => Currency.tryLira,
        ),
        installment: json['installment'] as int? ?? 1,
        card: CardInfo.fromJson(json['card'] as Map<String, dynamic>),
        buyer: BuyerInfo.fromJson(json['buyer'] as Map<String, dynamic>),
        basketItems: (json['basketItems'] as List<dynamic>)
            .map((e) => BasketItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        shippingAddress: json['shippingAddress'] != null
            ? AddressInfo.fromJson(
                json['shippingAddress'] as Map<String, dynamic>,
              )
            : null,
        billingAddress: json['billingAddress'] != null
            ? AddressInfo.fromJson(
                json['billingAddress'] as Map<String, dynamic>,
              )
            : null,
        callbackUrl: json['callbackUrl'] as String?,
        use3DS: json['use3DS'] as bool? ?? false,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  /// Converts this instance to a JSON-compatible map.
  ///
  /// Used for serializing requests to send to backend.
  /// Note: Card data is included for API calls. For logging, use card.toSafeJson().
  // ignore: deprecated_member_use_from_same_package
  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'amount': amount,
        if (paidPrice != null) 'paidPrice': paidPrice,
        'currency': currency.name,
        'installment': installment,
        // ignore: deprecated_member_use_from_same_package
        'card': card.toJson(),
        'buyer': buyer.toJson(),
        'basketItems': basketItems.map((e) => e.toJson()).toList(),
        if (shippingAddress != null)
          'shippingAddress': shippingAddress!.toJson(),
        if (billingAddress != null) 'billingAddress': billingAddress!.toJson(),
        if (callbackUrl != null) 'callbackUrl': callbackUrl,
        'use3DS': use3DS,
        if (metadata != null) 'metadata': metadata,
      };

  /// Unique order identifier in your system.
  ///
  /// Must be unique for each payment attempt.
  final String orderId;

  /// Total payment amount.
  final double amount;

  /// Discounted price (optional).
  ///
  /// If set, this amount will be charged instead of [amount].
  final double? paidPrice;

  /// Currency for the payment.
  ///
  /// Defaults to [Currency.tryLira].
  final Currency currency;

  /// Number of installments.
  ///
  /// 1 = single payment, 2-12 = installments.
  /// Defaults to 1.
  final int installment;

  /// Card information for the payment.
  final CardInfo card;

  /// Buyer information.
  final BuyerInfo buyer;

  /// Items in the shopping basket.
  ///
  /// The total of all items should match [amount].
  final List<BasketItem> basketItems;

  /// Shipping address (optional).
  final AddressInfo? shippingAddress;

  /// Billing address (optional).
  final AddressInfo? billingAddress;

  /// Callback URL for 3D Secure verification.
  ///
  /// Required when [use3DS] is true.
  final String? callbackUrl;

  /// Whether to use 3D Secure verification.
  ///
  /// Defaults to false. Some cards may require 3DS regardless.
  final bool use3DS;

  /// Additional metadata for the payment.
  final Map<String, dynamic>? metadata;

  /// Effective price to charge.
  ///
  /// Returns [paidPrice] if set, otherwise [amount].
  double get effectivePaidAmount => paidPrice ?? amount;

  /// Maximum allowed amount for a single payment
  static const double maxAmount = 999999.99;

  /// Maximum allowed installment count
  static const int maxInstallment = 12;

  /// Maximum order ID length
  static const int maxOrderIdLength = 50;

  /// Validates the payment request and throws [ValidationException] if invalid.
  ///
  /// Validates:
  /// * Amount is positive and within limits
  /// * Order ID is valid
  /// * Installment is between 1 and 12
  /// * 3DS requires callback URL
  /// * Basket items total matches amount
  /// * Card and buyer info are valid
  ///
  /// Also calls [CardInfo.validate] and [BuyerInfo.validate].
  ///
  /// Throws [ValidationException] with all validation errors.
  void validate() {
    final errors = <String>[];

    // Amount validation
    if (amount <= 0) {
      errors.add('amount must be greater than 0');
    } else if (amount > maxAmount) {
      errors.add('amount cannot exceed $maxAmount');
    }

    // Paid price validation
    if (paidPrice != null) {
      if (paidPrice! <= 0) {
        errors.add('paidPrice must be greater than 0 if provided');
      } else if (paidPrice! > amount) {
        errors.add('paidPrice cannot exceed amount');
      }
    }

    // Installment validation
    if (installment < 1) {
      errors.add('installment must be at least 1');
    } else if (installment > maxInstallment) {
      errors.add('installment cannot exceed $maxInstallment');
    }

    // Order ID validation
    if (orderId.isEmpty) {
      errors.add('orderId cannot be empty');
    } else if (orderId.length > maxOrderIdLength) {
      errors.add('orderId cannot exceed $maxOrderIdLength characters');
    }

    // 3DS validation
    if (use3DS && (callbackUrl == null || callbackUrl!.isEmpty)) {
      errors.add('callbackUrl is required when use3DS is true');
    }

    // Basket items validation
    if (basketItems.isEmpty) {
      errors.add('basketItems cannot be empty');
    } else {
      // Calculate basket total
      final basketTotal = basketItems.fold<double>(
        0,
        (sum, item) => sum + (item.price * item.quantity),
      );

      // Allow small rounding differences (0.01)
      if ((basketTotal - amount).abs() > 0.01) {
        errors.add(
          'basket items total ($basketTotal) must equal amount ($amount)',
        );
      }

      // Validate individual basket items
      for (var i = 0; i < basketItems.length; i++) {
        final item = basketItems[i];
        if (item.id.isEmpty) {
          errors.add('basketItems[$i].id cannot be empty');
        }
        if (item.name.isEmpty) {
          errors.add('basketItems[$i].name cannot be empty');
        }
        if (item.price <= 0) {
          errors.add('basketItems[$i].price must be greater than 0');
        }
        if (item.quantity < 1) {
          errors.add('basketItems[$i].quantity must be at least 1');
        }
      }
    }

    // Throw early errors before nested validation
    if (errors.isNotEmpty) {
      throw ValidationException(errors: errors);
    }

    // Card validation (will throw its own ValidationException)
    card.validate();

    // Buyer validation (will throw its own ValidationException)
    buyer.validate();
  }

  /// Creates a copy with the given fields replaced.
  PaymentRequest copyWith({
    String? orderId,
    double? amount,
    double? paidPrice,
    Currency? currency,
    int? installment,
    CardInfo? card,
    BuyerInfo? buyer,
    List<BasketItem>? basketItems,
    AddressInfo? shippingAddress,
    AddressInfo? billingAddress,
    String? callbackUrl,
    bool? use3DS,
    Map<String, dynamic>? metadata,
  }) =>
      PaymentRequest(
        orderId: orderId ?? this.orderId,
        amount: amount ?? this.amount,
        paidPrice: paidPrice ?? this.paidPrice,
        currency: currency ?? this.currency,
        installment: installment ?? this.installment,
        card: card ?? this.card,
        buyer: buyer ?? this.buyer,
        basketItems: basketItems ?? this.basketItems,
        shippingAddress: shippingAddress ?? this.shippingAddress,
        billingAddress: billingAddress ?? this.billingAddress,
        callbackUrl: callbackUrl ?? this.callbackUrl,
        use3DS: use3DS ?? this.use3DS,
        metadata: metadata ?? this.metadata,
      );

  @override
  String toString() =>
      'PaymentRequest(orderId: $orderId, amount: $amount $currency, installment: $installment)';
}
