import '../enums.dart';

/// Sepet ürünü
class BasketItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final ItemType itemType;
  final int quantity;

  const BasketItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.itemType,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;
}
