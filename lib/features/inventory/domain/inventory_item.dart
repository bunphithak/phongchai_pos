/// แถวสต็อกสำหรับหน้าคงคลัง (อ่านจากแหล่งเดียวกับ POS — ตอนนี้ใช้ MockDataStore)
class InventoryItem {
  const InventoryItem({
    required this.productId,
    required this.barcode,
    required this.name,
    this.quantityOnHand,
  });

  final String productId;
  final String barcode;
  final String name;

  /// null = ไม่ได้กำหนดสต็อกใน mock (ไม่จำกัดใน UI ขาย)
  final int? quantityOnHand;
}
