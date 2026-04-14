/// Domain model for stock/inventory rows (expand when you add real inventory logic).
class InventoryItem {
  const InventoryItem({
    required this.productId,
    required this.quantityOnHand,
  });

  final String productId;
  final int quantityOnHand;
}
