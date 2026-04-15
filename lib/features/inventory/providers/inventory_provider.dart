import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/features/inventory/domain/inventory_item.dart';

final inventoryProvider =
    NotifierProvider<InventoryNotifier, List<InventoryItem>>(
  InventoryNotifier.new,
);

class InventoryNotifier extends Notifier<List<InventoryItem>> {
  @override
  List<InventoryItem> build() {
    return _loadFromStore();
  }

  /// โหลดใหม่หลังขาย / void / ซิงค์ (สต็อกใน mock เปลี่ยน)
  void reload() {
    state = _loadFromStore();
  }

  List<InventoryItem> _loadFromStore() {
    final mock = MockDataStore.instance;
    final list = <InventoryItem>[];
    for (final e in mock.productsByBarcode.entries) {
      final barcode = e.key;
      final p = e.value;
      list.add(
        InventoryItem(
          productId: p.id,
          barcode: barcode,
          name: p.name,
          quantityOnHand: mock.stockByBarcode[barcode],
        ),
      );
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
