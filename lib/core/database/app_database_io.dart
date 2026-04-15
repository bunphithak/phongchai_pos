import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// SQLite บนเครื่องลูก (iOS / Android / desktop)
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  bool get isAvailable => true;

  Future<Database> get database async {
    if (_db != null) return _db!;
    throw StateError('Call AppDatabase.init() first');
  }

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'phongchai_pos.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(DatabaseSchema.createTableProducts);
        await db.execute(DatabaseSchema.indexProductsBarcode);
        await db.execute(DatabaseSchema.indexProductsName);
        await db.execute(DatabaseSchema.createTableOrders);
        await db.execute(DatabaseSchema.createTableOrderItems);
        await db.execute(DatabaseSchema.indexOrderItemsOrderId);
        await db.execute(DatabaseSchema.createTableSyncStatus);
        await db.execute(DatabaseSchema.insertDefaultSyncStatus);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _ensureOrdersPointsRedeemedColumn(db);
        }
      },
    );
    await _ensureOrdersPointsRedeemedColumn(_db!);
    await _db!.execute('PRAGMA foreign_keys = ON');
  }

  /// กรณี DB เคยขึ้น user_version = 2 แต่ยังไม่มีคอลัมน์ (onUpgrade ไม่รันอีก) — เติมคอลัมน์เมื่อขาด
  static Future<void> _ensureOrdersPointsRedeemedColumn(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info(orders)');
    final has = rows.any((r) => (r['name'] as String?) == 'points_redeemed');
    if (!has) {
      await db.execute(
        'ALTER TABLE orders ADD COLUMN points_redeemed INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> upsertProductRow({
    required String id,
    required String barcode,
    required String name,
    required double price,
    required int stockQty,
    required int updatedAtMs,
  }) async {
    final db = await database;
    await db.insert(
      'products',
      {
        'id': id,
        'barcode': barcode,
        'name': name,
        'price': price,
        'stock_qty': stockQty,
        'updated_at': updatedAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertOrderWithItems({
    required String invoiceNo,
    required double totalAmount,
    required String paymentMethod,
    required String deviceId,
    required int createdAtMs,
    required List<({String productId, String barcode, String name, double price, double qty})> lines,
    int pointsRedeemed = 0,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final orderId = await txn.insert('orders', {
        'invoice_no': invoiceNo,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'device_id': deviceId,
        'created_at': createdAtMs,
        'is_synced': 0,
        'points_redeemed': pointsRedeemed,
      });

      for (final line in lines) {
        await txn.insert(
          'products',
          {
            'id': line.productId,
            'barcode': line.barcode,
            'name': line.name,
            'price': line.price,
            'stock_qty': 0,
            'updated_at': createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.insert('order_items', {
          'order_id': orderId,
          'product_id': line.productId,
          'qty': line.qty,
          'price': line.price,
        });
      }
      return orderId;
    });
  }

  Future<int?> getLastPullTimestamp() async {
    final db = await database;
    final rows = await db.query(
      'sync_status',
      columns: ['last_pull_timestamp'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['last_pull_timestamp'] as int?;
  }

  Future<void> setLastPullTimestamp(int ms) async {
    final db = await database;
    await db.update(
      'sync_status',
      {'last_pull_timestamp': ms},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<List<Map<String, Object?>>> getUnsyncedOrders() async {
    final db = await database;
    return db.query(
      'orders',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markOrderSynced(int orderId) async {
    final db = await database;
    await db.update(
      'orders',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// ลบ orders (+ order_items ผ่าน ON DELETE CASCADE) ที่ sync แล้วและเก่ากว่า cutoff
  Future<int> deleteSyncedOrdersOlderThan({required int cutoffMs}) async {
    final db = await database;
    return db.rawDelete(
      'DELETE FROM orders WHERE is_synced = 1 AND created_at < ?',
      [cutoffMs],
    );
  }

  Future<List<Map<String, Object?>>> getOrderItems(int orderId) async {
    final db = await database;
    return db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }
}
