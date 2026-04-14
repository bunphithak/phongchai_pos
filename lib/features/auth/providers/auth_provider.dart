import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/features/auth/domain/employee.dart';

/// สถานะล็อกอิน: `null` = ยังไม่เข้าระบบ
final authProvider =
    NotifierProvider<AuthNotifier, Employee?>(AuthNotifier.new);

class AuthNotifier extends Notifier<Employee?> {
  @override
  Employee? build() => null;

  /// ตรวจ PIN 6 หลัก (จำลอง — ต่อ API/ฐานข้อมูลได้ภายหลัง)
  bool tryLoginWithPin(String pin) {
    if (pin.length != 6) return false;
    final employee = _employeeForPin(pin);
    if (employee == null) return false;
    state = employee;
    return true;
  }

  void logout() {
    state = null;
  }
}

Employee? _employeeForPin(String pin) {
  return MockDataStore.instance.employeeForPin(pin);
}
