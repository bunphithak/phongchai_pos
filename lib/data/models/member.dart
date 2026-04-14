/// ประเภทสมาชิก / ลูกค้า
enum MemberType {
  /// ลูกค้าทั่วไป
  general,

  /// ช่าง
  technician,

  /// ผู้รับเหมา
  contractor,
}

extension MemberTypeLabels on MemberType {
  String get thaiLabel => switch (this) {
        MemberType.general => 'ทั่วไป',
        MemberType.technician => 'ช่าง',
        MemberType.contractor => 'ผู้รับเหมา',
      };

  /// ค่าสำหรับส่ง API
  String get apiValue => switch (this) {
        MemberType.general => 'general',
        MemberType.technician => 'technician',
        MemberType.contractor => 'contractor',
      };

  static MemberType fromApiValue(String value) {
    switch (value) {
      case 'technician':
        return MemberType.technician;
      case 'contractor':
        return MemberType.contractor;
      case 'general':
      default:
        return MemberType.general;
    }
  }
}

class Member {
  const Member({
    required this.phone,
    required this.name,
    required this.type,
    required this.registeredAt,
    this.loyaltyPoints = 0,
  });

  /// เบอร์โทร (เก็บเป็นตัวเลข 10 หลัก เช่น 0812345678)
  final String phone;

  final String name;
  final MemberType type;

  /// วันที่สมัคร / บันทึกในระบบ
  final DateTime registeredAt;

  /// แต้มสะสม (จำลอง / จาก API)
  final int loyaltyPoints;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'member_type': type.apiValue,
        'registered_at': registeredAt.toIso8601String(),
        'loyalty_points': loyaltyPoints,
      };
}
