/// สคีมา SQLite ฝั่งเครื่องลูก (Offline-First POS)
class DatabaseSchema {
  DatabaseSchema._();

  static const createTableProducts = '''
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY NOT NULL,
  barcode TEXT NOT NULL,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  stock_qty REAL NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
)''';

  static const indexProductsBarcode =
      'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)';
  static const indexProductsName =
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)';

  static const createTableOrders = '''
CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_no TEXT NOT NULL UNIQUE,
  total_amount REAL NOT NULL,
  payment_method TEXT NOT NULL,
  device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  is_synced INTEGER NOT NULL DEFAULT 0
)''';

  static const createTableOrderItems = '''
CREATE TABLE IF NOT EXISTS order_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  product_id TEXT NOT NULL,
  qty REAL NOT NULL,
  price REAL NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
)''';

  static const indexOrderItemsOrderId =
      'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)';

  static const createTableSyncStatus = '''
CREATE TABLE IF NOT EXISTS sync_status (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  last_pull_timestamp INTEGER NOT NULL DEFAULT 0
)''';

  static const insertDefaultSyncStatus = '''
INSERT OR IGNORE INTO sync_status (id, last_pull_timestamp) VALUES (1, 0)
''';
}
