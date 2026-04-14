import 'package:phongchai_pos/data/models/product.dart';

/// One line on the cart: a product and how many units.
class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;
}
