import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// อ่านจาก `.env` (โหลดใน [main] ผ่าน `dotenv.load`)
/// อัตราแลกแต้ม: ค่าจากซิงค์ (SharedPreferences) ทับค่า `.env` หลัง [initPointExchangeRate] / [setPointExchangeRateFromSync]
class AppConfig {
  AppConfig._();

  static const _kPointExchangeRatePrefs = 'pos_point_exchange_rate';

  static double _pointExchangeRateCached = 0.1;

  /// เรียกหลัง `dotenv.load` — อ่าน `.env` แล้วตามด้วยค่าที่ซิงค์ไว้ (ถ้ามี)
  static Future<void> initPointExchangeRate() async {
    final env = _pointExchangeRateFromEnv();
    final prefs = await SharedPreferences.getInstance();
    final synced = prefs.getDouble(_kPointExchangeRatePrefs);
    _pointExchangeRateCached = synced ?? env;
  }

  static double _pointExchangeRateFromEnv() {
    final raw = dotenv.env['POINT_EXCHANGE_RATE']?.trim();
    final v = double.tryParse(raw ?? '') ?? 0.1;
    return v > 0 ? v : 0.1;
  }

  /// บาทต่อ 1 แต้ม (เช่น 0.1 = 1 แต้ม = 0.1 บาท)
  static double get pointExchangeRate => _pointExchangeRateCached;

  /// เรียกหลังดึงคอนฟิกจาก backend/sync สำเร็จ
  static Future<void> setPointExchangeRateFromSync(double rate) async {
    if (rate <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPointExchangeRatePrefs, rate);
    _pointExchangeRateCached = rate;
  }

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
