import 'package:phongchai_pos/data/models/product.dart';

/// จำลองฐานข้อมูลสินค้าตามบาร์โค้ด (ขยายได้ภายหลัง)
Product? productForBarcode(String raw) {
  switch (raw.trim()) {
    case '123':
      return const Product(
        id: '123',
        name: 'น้ำดื่ม',
        price: 12,
        imageAsset: 'assets/images/product_water.jpg',
      );
    case '456':
      return const Product(
        id: '456',
        name: 'ข้าวสาร',
        price: 189,
        imageAsset: 'assets/images/product_rice.jpg',
      );
    case '8851473011619':
      return const Product(
        id: '8851473011619',
        name: 'อ๊อพพลีน สเตอไรก์ อาย วอช',
        price: 89,
      );
    case '8851552201030':
      return const Product(
        id: '8851552201030',
        name: 'ปากกาเคมีสีแดง ตราม้า',
        price: 12,
      );
    default:
      return null;
  }
}
