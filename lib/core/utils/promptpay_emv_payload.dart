/// สร้างสตริง EMVCo QR สำหรับ PromptPay (Any ID) แบบ **dynamic** (มียอด)
/// คำนวณ CRC-16/XMODEM ตาม EMV และ **บังคับ CRC 4 หลัก hex** (ตัวพิมพ์ใหญ่)
///
/// อ้างอิงโครงสร้างเดียวกับไลบรารีอ้างอิง (เช่น kittinan/promptpay) — ไม่เรียก API
String buildPromptPayEmvPayload({
  required String promptPayId,
  required double amount,
}) {
  final sanitized = promptPayId.replaceAll(RegExp(r'\D'), '');
  if (sanitized.isEmpty) {
    throw ArgumentError('promptPayId ว่างหรือไม่มีตัวเลข');
  }
  if (amount <= 0) {
    throw ArgumentError('amount ต้องมากกว่า 0');
  }

  const idPayloadFormat = '00';
  const idPoiMethod = '01';
  const idMerchantBot = '29';
  const idCurrency = '53';
  const idAmount = '54';
  const idCountry = '58';
  const idCrc = '63';

  const payloadFormat = '01';
  const poiDynamic = '12';
  const guidPromptPay = 'A000000677010111';
  const currencyThb = '764';
  const countryTh = 'TH';

  const botPhone = '01';
  const botTaxId = '02';
  const botEwallet = '03';

  String ppType;
  if (sanitized.length >= 15) {
    ppType = botEwallet;
  } else if (sanitized.length >= 13) {
    ppType = botTaxId;
  } else {
    ppType = botPhone;
  }

  final idValue = _formatPromptPayId(sanitized, ppType);
  final amountStr = amount.toStringAsFixed(2);

  String tlv(String id, String value) =>
      id + value.length.toString().padLeft(2, '0') + value;

  final merchantInner = tlv('00', guidPromptPay) + tlv(ppType, idValue);
  final merchant = tlv(idMerchantBot, merchantInner);

  final parts = <String>[
    tlv(idPayloadFormat, payloadFormat),
    tlv(idPoiMethod, poiDynamic),
    merchant,
    tlv(idCountry, countryTh),
    tlv(idCurrency, currencyThb),
    tlv(idAmount, amountStr),
  ];

  final withoutCrc = parts.join();
  final forCrc = '$withoutCrc$idCrc${'04'}';
  final crcHex = _crc16XmodemHex(forCrc);
  return '$forCrc$crcHex';
}

/// เบอร์/เลขนิติ: แปลงเป็นรูปแบบที่ BOT ใช้ใน QR (เบอร์มือถือไทย = 13 หลัก นำหน้า 00 + รหัสประเทศ)
String _formatPromptPayId(String digitsOnly, String ppType) {
  if (ppType != '01') {
    return digitsOnly;
  }
  var n = digitsOnly;
  if (n.length < 13) {
    n = n.replaceFirst(RegExp(r'^0'), '66');
    n = n.padLeft(13, '0');
  }
  return n;
}

/// CRC-16/XMODEM (poly 0x1021, init 0xFFFF) บนข้อมูล ASCII ของ [payload]
/// คืนค่า **4 ตัวอักษร hex พิมพ์ใหญ่** เสมอ
String _crc16XmodemHex(String payload) {
  var crc = 0xFFFF;
  final units = payload.codeUnits;
  for (final unit in units) {
    crc ^= unit << 8;
    for (var i = 0; i < 8; i++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}
