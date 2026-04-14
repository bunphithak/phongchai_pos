import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/features/inventory/domain/inventory_item.dart';

final inventoryProvider =
    NotifierProvider<InventoryNotifier, List<InventoryItem>>(
  InventoryNotifier.new,
);

class InventoryNotifier extends Notifier<List<InventoryItem>> {
  @override
  List<InventoryItem> build() => [];
}
