/// ข้อมูลผู้ซื้อสำหรับใบกำกับภาษี (กรอกจากหน้า POS ต่อบิล)
class TaxInvoiceBuyerInfo {
  const TaxInvoiceBuyerInfo({
    this.taxId = '',
    this.companyOrName = '',
    this.address = '',
    this.isHeadOffice = true,
    this.branchCode = '',
  });

  /// เลขประจำตัวผู้เสียภาษี — ตัวเลขสูงสุด 13 หลัก (เก็บแบบไม่มีขีด)
  final String taxId;

  /// ชื่อบริษัทหรือชื่อลูกค้า
  final String companyOrName;

  /// ที่อยู่ (หลายบรรทัดได้)
  final String address;

  /// `true` = สำนักงานใหญ่, `false` = สาขา (ใช้รหัส [branchCode])
  final bool isHeadOffice;

  /// รหัสสาขา 5 หลัก — ใช้เมื่อ [isHeadOffice] เป็น false
  final String branchCode;

  bool get hasAnyInput =>
      taxId.trim().isNotEmpty ||
      companyOrName.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      !isHeadOffice;

  /// จัดรูปแบบเลข 13 หลักเป็นรูปแบบมาตรฐาน เช่น 0-0000-00000-00-0
  static String formatTaxIdDisplay(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 13) return digits;
    return '${d[0]}-${d.substring(1, 5)}-${d.substring(5, 10)}-${d.substring(10, 12)}-${d[12]}';
  }

  TaxInvoiceBuyerInfo copyWith({
    String? taxId,
    String? companyOrName,
    String? address,
    bool? isHeadOffice,
    String? branchCode,
  }) {
    return TaxInvoiceBuyerInfo(
      taxId: taxId ?? this.taxId,
      companyOrName: companyOrName ?? this.companyOrName,
      address: address ?? this.address,
      isHeadOffice: isHeadOffice ?? this.isHeadOffice,
      branchCode: branchCode ?? this.branchCode,
    );
  }
}
