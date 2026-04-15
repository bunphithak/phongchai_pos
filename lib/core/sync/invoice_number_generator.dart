import 'package:shared_preferences/shared_preferences.dart';

import 'device_identity.dart';

/// เลขที่บิลแบบไม่ชนกันระหว่างเครื่อง: `[DeviceID]-[YYMMDD]-[RunningNumber]`
class InvoiceNumberGenerator {
  InvoiceNumberGenerator._();

  static Future<String> next() async {
    final device = await DeviceIdentity.getOrCreateDeviceId();
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yymmdd = '$yy$mm$dd';

    final prefs = await SharedPreferences.getInstance();
    final key = 'pos_invoice_run_$yymmdd';
    final nextRun = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, nextRun);

    final run = nextRun.toString().padLeft(4, '0');
    return '$device-$yymmdd-$run';
  }
}
