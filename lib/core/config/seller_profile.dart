/// ข้อมูลผู้ขายบนใบกำกับภาษี — โหลดจาก assets/mock หรือค่าเริ่มต้น
class SellerProfile {
  const SellerProfile({
    required this.companyNameTh,
    required this.companyNameEn,
    required this.taxId,
    required this.addressTh,
    required this.tel,
    required this.email,
  });

  final String companyNameTh;
  final String companyNameEn;
  final String taxId;
  final String addressTh;
  final String tel;
  final String email;

  static const SellerProfile defaults = SellerProfile(
    companyNameTh: 'ห้างหุ้นส่วนจำกัด พงษ์ชัย พอส',
    companyNameEn: 'Phongchai POS Partnership Limited',
    taxId: '0-0000-00000-00-0',
    addressTh:
        'เลขที่ — ถนน — ตำบล/แขวง — อำเภอ/เขต — จังหวัด — รหัสไปรษณีย์',
    tel: 'โทร. 0-0000-0000',
    email: 'tax@example.com',
  );

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      companyNameTh: json['company_name_th'] as String,
      companyNameEn: json['company_name_en'] as String,
      taxId: json['tax_id'] as String,
      addressTh: json['address_th'] as String,
      tel: json['tel'] as String,
      email: json['email'] as String,
    );
  }
}
