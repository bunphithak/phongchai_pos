import 'package:flutter/foundation.dart';
import 'package:phongchai_pos/data/models/member.dart';

/// จำลองการส่งสมาชิกไป API — แทนที่ด้วย HTTP client จริงได้ภายหลัง
Future<void> registerMember(Member member) async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (kDebugMode) {
    debugPrint('registerMember POST body: ${member.toJson()}');
  }
}
