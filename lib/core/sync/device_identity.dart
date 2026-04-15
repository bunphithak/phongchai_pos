import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _kDeviceIdKey = 'pos_offline_device_id';

/// รหัสเครื่องคงที่ (เก็บใน SharedPreferences) สำหรับเลขที่บิลและคอลัมน์ device_id
class DeviceIdentity {
  DeviceIdentity._();

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id != null && id.trim().isNotEmpty) {
      return _sanitize(id.trim());
    }
    final rnd = Random.secure();
    final buf = StringBuffer();
    const chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    for (var i = 0; i < 8; i++) {
      buf.write(chars[rnd.nextInt(chars.length)]);
    }
    id = buf.toString();
    await prefs.setString(_kDeviceIdKey, id);
    return id;
  }

  static String _sanitize(String raw) {
    final s = raw.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '').toUpperCase();
    if (s.isEmpty) return 'POS';
    if (s.length > 12) return s.substring(0, 12);
    return s;
  }
}
