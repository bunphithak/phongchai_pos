import 'package:phongchai_pos/core/config/sync_config_loader.dart';
import 'package:phongchai_pos/core/database/app_database.dart';
import 'package:phongchai_pos/core/sync/device_identity.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';
import 'package:phongchai_pos/features/pos/presentation/checkout_dialog.dart';

/// Offline-First: บันทึก SQLite ก่อน แล้วค่อย Push เมื่อมี [apiBaseUrl]
///
/// Pull ตอนนี้ใช้ mock catalog ลง SQLite — เมื่อมี API จริงให้แทนที่ใน [pullProductsOnStartup]
class PosSyncService {
  PosSyncService({this.apiBaseUrl});

  final String? apiBaseUrl;

  final AppDatabase _db = AppDatabase.instance;

  Future<void> pullProductsOnStartup({bool force = false}) async {
    if (!_db.isAvailable) return;
    final lastMs = await _db.getLastPullTimestamp() ?? 0;
    if (!force && lastMs > 0) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    var i = 0;
    for (final e in MockDataStore.instance.productsByBarcode.entries) {
      final p = e.value;
      final stock = MockDataStore.instance.stockByBarcode[e.key] ?? 0;
      final rowUpdated = now + i;
      if (!force && lastMs > 0 && rowUpdated <= lastMs) {
        i++;
        continue;
      }
      await _db.upsertProductRow(
        id: p.id,
        barcode: e.key,
        name: p.name,
        price: p.price,
        stockQty: stock,
        updatedAtMs: rowUpdated,
      );
      i++;
    }
    await _db.setLastPullTimestamp(now);
    await SyncConfigLoader.applyBundledMock();
  }

  /// Push บิลที่ยังไม่ sync — รอ backend สร้าง API แล้วค่อยเชื่อม HTTP + markOrderSynced
  Future<int> tryPushPendingOrders() async {
    if (!_db.isAvailable) return 0;
    final base = apiBaseUrl;
    if (base == null || base.isEmpty) return 0;
    // TODO: POST ไปที่ backend แล้วเรียก markOrderSynced ต่อบิล
    return 0;
  }

  Future<int> purgeSyncedOlderThanDays(int days) async {
    if (!_db.isAvailable) return 0;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    return _db.deleteSyncedOrdersOlderThan(cutoffMs: cutoff);
  }

  Future<int?> persistCheckoutSale({
    required String invoiceNo,
    required double grandTotal,
    required PosPaymentMethod method,
    required List<CartItem> lines,
    int pointsRedeemed = 0,
  }) async {
    if (!_db.isAvailable) return null;

    final deviceId = await DeviceIdentity.getOrCreateDeviceId();
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final paymentMethod = switch (method) {
      PosPaymentMethod.cash => 'cash',
      PosPaymentMethod.transfer => 'transfer',
      PosPaymentMethod.mixed => 'mixed',
    };

    final rows = <({String productId, String barcode, String name, double price, double qty})>[];
    for (final line in lines) {
      final barcode =
          MockDataStore.instance.barcodeForProductId(line.product.id) ?? '';
      final qty = line.quantity.toDouble();
      final price = qty > 0 ? line.lineTotal / qty : line.product.price;
      rows.add((
        productId: line.product.id,
        barcode: barcode,
        name: line.product.name,
        price: price,
        qty: qty,
      ));
    }

    final orderId = await _db.insertOrderWithItems(
      invoiceNo: invoiceNo,
      totalAmount: grandTotal,
      paymentMethod: paymentMethod,
      deviceId: deviceId,
      createdAtMs: createdAt,
      lines: rows,
      pointsRedeemed: pointsRedeemed,
    );

    await tryPushPendingOrders();
    return orderId;
  }
}
