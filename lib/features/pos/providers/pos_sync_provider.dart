import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/core/config/app_config.dart';
import 'package:phongchai_pos/core/sync/pos_sync_service.dart';

/// `API_BASE_URL` ใน `.env` — ว่าง = ยังไม่ Push ไปเซิร์ฟเวอร์
final posSyncServiceProvider = Provider<PosSyncService>((ref) {
  return PosSyncService(apiBaseUrl: AppConfig.apiBaseUrl);
});
