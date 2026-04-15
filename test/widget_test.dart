import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phongchai_pos/core/sync/pos_sync_service.dart';
import 'package:phongchai_pos/features/auth/domain/employee.dart';
import 'package:phongchai_pos/features/auth/providers/auth_provider.dart';
import 'package:phongchai_pos/features/pos/presentation/pos_screen.dart';
import 'package:phongchai_pos/features/pos/providers/pos_sync_provider.dart';

class _TestAuth extends AuthNotifier {
  @override
  Employee? build() => const Employee(name: 'ทดสอบ', role: 'แคชเชียร์');
}

/// ไม่แตะ SQLite / path_provider ในเทส widget
class _TestPosSyncService extends PosSyncService {
  _TestPosSyncService() : super(apiBaseUrl: null);

  @override
  Future<void> pullProductsOnStartup({bool force = false}) async {}

  @override
  Future<int> purgeSyncedOlderThanDays(int days) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(mergeWith: {
      'POS_PURGE_SYNCED_DAYS': '7',
      'API_BASE_URL': '',
      'POINT_EXCHANGE_RATE': '0.1',
    });
  });

  testWidgets('POS screen shows cart total', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuth.new),
          posSyncServiceProvider.overrideWith((ref) => _TestPosSyncService()),
        ],
        child: const MaterialApp(
          home: POSScreen(),
        ),
      ),
    );

    expect(find.textContaining('ยอดรวมสุทธิ'), findsOneWidget);
    expect(find.textContaining('0.00'), findsWidgets);
  });
}
