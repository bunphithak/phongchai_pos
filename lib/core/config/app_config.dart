import 'package:flutter_dotenv/flutter_dotenv.dart';

/// อ่านจาก `.env` (โหลดใน [main] ผ่าน `dotenv.load`)
class AppConfig {
  AppConfig._();

  static String? get apiBaseUrl {
    final v = dotenv.env['API_BASE_URL']?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static int get purgeSyncedDaysAfter {
    final raw = dotenv.env['POS_PURGE_SYNCED_DAYS']?.trim();
    return int.tryParse(raw ?? '') ?? 7;
  }
}
