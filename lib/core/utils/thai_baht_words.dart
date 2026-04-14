/// แปลงจำนวนเงินเป็นคำไทย (บาท / สตางค์) สำหรับใบกำกับภาษี
String thaiBahtWords(double amount) {
  if (amount.isNaN || amount.isInfinite) return '';
  var a = amount;
  if (a < 0) a = -a;
  final baht = a.floor();
  var satang = ((a - baht) * 100).round();
  if (satang >= 100) {
    return thaiBahtWords(baht + satang / 100.0);
  }
  if (baht == 0 && satang == 0) return 'ศูนย์บาทถ้วน';
  if (baht == 0) {
    return '${_readPositiveInt(satang)}สตางค์';
  }
  if (satang == 0) {
    return '${_readPositiveInt(baht)}บาทถ้วน';
  }
  return '${_readPositiveInt(baht)}บาท${_readPositiveInt(satang)}สตางค์';
}

const _unit = [
  '',
  'หนึ่ง',
  'สอง',
  'สาม',
  'สี่',
  'ห้า',
  'หก',
  'เจ็ด',
  'แปด',
  'เก้า',
];

String _readPositiveInt(int n) {
  if (n == 0) return 'ศูนย์';
  if (n < 0) return 'ลบ${_readPositiveInt(-n)}';
  if (n >= 1000000) {
    final m = n ~/ 1000000;
    final r = n % 1000000;
    final left = '${_readPositiveInt(m)}ล้าน';
    if (r == 0) return left;
    return left + _readUnderMillion(r);
  }
  return _readUnderMillion(n);
}

/// 1 .. 999_999
String _readUnderMillion(int n) {
  if (n == 0) return '';
  assert(n < 1000000 && n > 0);
  final la = n ~/ 100000;
  var rem = n % 100000;
  final buf = StringBuffer();
  if (la > 0) {
    buf.write(_unit[la]);
    buf.write('แสน');
  }
  final mu = rem ~/ 10000;
  rem %= 10000;
  if (mu > 0) {
    buf.write(_unit[mu]);
    buf.write('หมื่น');
  }
  final ph = rem ~/ 1000;
  rem %= 1000;
  if (ph > 0) {
    buf.write(_unit[ph]);
    buf.write('พัน');
  }
  buf.write(_readLast0to999(rem, hasHigher: buf.isNotEmpty, hasPhan: ph > 0));
  return buf.toString();
}

/// 0..999 — [hasHigher] มีแสน/หมื่น/พัน อยู่แล้ว, [hasPhan] มีหลักพันในบล็อกนี้
String _readLast0to999(int n, {required bool hasHigher, required bool hasPhan}) {
  if (n == 0) return '';
  if (n < 10) {
    if (n == 1) {
      if (hasHigher && !hasPhan) return 'เอ็ด';
      return 'หนึ่ง';
    }
    return _unit[n];
  }
  if (n < 100) {
    return _read0to99(n);
  }
  final h = n ~/ 100;
  final rr = n % 100;
  final head = '${_unit[h]}ร้อย';
  if (rr == 0) return head;
  if (rr < 10) {
    if (rr == 1) return '$head''เอ็ด';
    return '$head${_unit[rr]}';
  }
  return head + _read0to99(rr);
}

String _read0to99(int n) {
  if (n == 0) return '';
  if (n < 10) {
    return _unit[n];
  }
  if (n == 10) return 'สิบ';
  if (n < 20) {
    if (n == 11) return 'สิบเอ็ด';
    return 'สิบ${_unit[n - 10]}';
  }
  if (n < 100) {
    final t = n ~/ 10;
    final u = n % 10;
    final ten = t == 2 ? 'ยี่สิบ' : '${_unit[t]}สิบ';
    if (u == 0) return ten;
    if (u == 1) return '$ten''เอ็ด';
    return '$ten${_unit[u]}';
  }
  return '';
}
