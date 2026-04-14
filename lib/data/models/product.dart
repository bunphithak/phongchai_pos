/// Sellable item in the POS catalog.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.imageAsset,
  });

  final String id;
  final String name;
  final double price;

  /// Optional bundled image (e.g. `assets/images/foo.jpg`). Shown before [imageUrl].
  final String? imageAsset;

  /// Optional remote image URL.
  final String? imageUrl;
}
