/// Web / แพลตฟอร์มที่ไม่มี sqflite — ปิดการทำงานแบบ no-op
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  bool get isAvailable => false;

  Future<void> init() async {}

  Future<void> close() async {}

  Future<void> upsertProductRow({
    required String id,
    required String barcode,
    required String name,
    required double price,
    required int stockQty,
    required int updatedAtMs,
  }) async {}

  Future<int> insertOrderWithItems({
    required String invoiceNo,
    required double totalAmount,
    required String paymentMethod,
    required String deviceId,
    required int createdAtMs,
    required List<({String productId, String barcode, String name, double price, double qty})> lines,
  }) async {
    return 0;
  }

  Future<int?> getLastPullTimestamp() async => null;

  Future<void> setLastPullTimestamp(int ms) async {}

  Future<List<Map<String, Object?>>> getUnsyncedOrders() async => [];

  Future<void> markOrderSynced(int orderId) async {}

  Future<int> deleteSyncedOrdersOlderThan({required int cutoffMs}) async => 0;

  Future<List<Map<String, Object?>>> getOrderItems(int orderId) async => [];
}
