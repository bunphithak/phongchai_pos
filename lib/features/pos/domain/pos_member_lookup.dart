/// ผลค้นหาสมาชิกจากเบอร์ (จำลอง — ต่อ API ได้ภายหลัง)
class MemberLookupHit {
  const MemberLookupHit({
    required this.name,
    required this.loyaltyPoints,
  });

  final String name;
  final int loyaltyPoints;
}

/// ค้นหาสมาชิกจากเบอร์โทร
MemberLookupHit? memberLookupByPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits == '0812345678' || digits.endsWith('812345678')) {
    return const MemberLookupHit(name: 'คุณสมชาย ใจดี', loyaltyPoints: 1280);
  }
  if (digits == '0899999999') {
    return const MemberLookupHit(name: 'คุณสมหญิง รักสบาย', loyaltyPoints: 560);
  }
  return null;
}

/// คืนเฉพาะชื่อ (ใช้ที่อื่นที่ต้องการแค่ชื่อ)
String? memberNameForPhone(String raw) => memberLookupByPhone(raw)?.name;
