import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/data/models/product.dart';

/// สินค้าตามบาร์โค้ด — ข้อมูลจาก `assets/mock/catalog_by_barcode.json`
Product? productForBarcode(String raw) {
  return MockDataStore.instance.productForBarcode(raw);
}
