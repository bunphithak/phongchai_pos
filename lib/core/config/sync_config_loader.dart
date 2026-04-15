import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:phongchai_pos/core/config/app_config.dart';

/// โหลดค่าคอนฟิกจาก sync (ตอนนี้ mock จาก asset — ต่อ API จริงให้แทนที่ response)
class SyncConfigLoader {
  SyncConfigLoader._();

  static Future<void> applyBundledMock() async {
    try {
      final s = await rootBundle.loadString('assets/mock/sync_config.json');
      final map = jsonDecode(s) as Map<String, dynamic>;
      final rate = (map['point_exchange_rate'] as num?)?.toDouble();
      if (rate != null && rate > 0) {
        await AppConfig.setPointExchangeRateFromSync(rate);
      }
    } catch (_) {
      // ใช้ค่าจาก initPointExchangeRate / .env
    }
  }
}
