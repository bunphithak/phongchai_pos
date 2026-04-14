/// จัดรูปแบบวันที่แบบไทย พ.ศ. เช่น `วันศุกร์ที่ 11 เมษายน 2569`
String formatThaiBuddhistDate(DateTime dateTime) {
  const weekdays = [
    '',
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];
  const months = [
    '',
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  final wd = weekdays[dateTime.weekday];
  final m = months[dateTime.month];
  final be = dateTime.year + 543;
  return 'วัน$wdที่ ${dateTime.day} $m $be';
}

String twoDigitTimePart(int n) => n.toString().padLeft(2, '0');
