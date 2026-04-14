/// ผลค้นหาสมาชิกจากเบอร์ (mock / API)
class MemberLookupHit {
  const MemberLookupHit({
    required this.name,
    required this.loyaltyPoints,
  });

  final String name;
  final int loyaltyPoints;
}
