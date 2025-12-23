import 'package:meta/meta.dart';

import '../enums.dart';

/// Represents a single item in the shopping basket.
///
/// Each payment request must include at least one basket item.
/// The total of all basket items should match the payment amount.
///
/// ## Example
///
/// ```dart
/// final item = BasketItem(
///   id: 'PRODUCT_001',
///   name: 'Wireless Headphones',
///   category: 'Electronics > Audio',
///   price: 299.99,
///   itemType: ItemType.physical,
///   quantity: 2,
/// );
///
/// print(item.totalPrice); // 599.98
/// ```
///
/// ## Item Types
///
/// * [ItemType.physical] - Tangible goods that require shipping
/// * [ItemType.virtual] - Digital goods, services, or subscriptions
@immutable
class BasketItem {
  /// Creates a new [BasketItem] instance.
  ///
  /// The [quantity] defaults to 1 if not specified.
  const BasketItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.itemType,
    this.quantity = 1,
  });

  /// Creates a [BasketItem] instance from a JSON map.
  ///
  /// Throws [TypeError] if required fields are missing or have wrong types.
  factory BasketItem.fromJson(Map<String, dynamic> json) => BasketItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    price: (json['price'] as num).toDouble(),
    itemType: ItemType.values.firstWhere(
      (e) => e.name == json['itemType'],
      orElse: () => ItemType.physical,
    ),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );

  /// Unique identifier for this item in your inventory.
  ///
  /// Should be consistent across transactions for the same product.
  final String id;

  /// Display name of the item.
  ///
  /// Will appear on payment receipts and provider dashboards.
  final String name;

  /// Category hierarchy for the item.
  ///
  /// Use ' > ' to separate category levels (e.g., 'Electronics > Phones').
  /// Categories help with fraud detection and reporting.
  final String category;

  /// Unit price of the item in the transaction currency.
  ///
  /// Must be greater than zero. For items with quantity > 1,
  /// this is the price per unit, not the total.
  final double price;

  /// Type of item being purchased.
  ///
  /// Affects how payment providers handle the transaction,
  /// particularly for fraud prevention and shipping requirements.
  final ItemType itemType;

  /// Number of units being purchased.
  ///
  /// Defaults to 1. Must be at least 1.
  final int quantity;

  /// Calculates the total price for this line item.
  ///
  /// Returns [price] multiplied by [quantity].
  double get totalPrice => price * quantity;

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'price': price,
    'itemType': itemType.name,
    'quantity': quantity,
  };

  /// Creates a copy of this instance with the given fields replaced.
  BasketItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    ItemType? itemType,
    int? quantity,
  }) => BasketItem(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    price: price ?? this.price,
    itemType: itemType ?? this.itemType,
    quantity: quantity ?? this.quantity,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BasketItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          price == other.price &&
          itemType == other.itemType &&
          quantity == other.quantity;

  @override
  int get hashCode =>
      Object.hash(id, name, category, price, itemType, quantity);

  @override
  String toString() =>
      'BasketItem(id: $id, name: $name, price: $price, qty: $quantity)';
}
