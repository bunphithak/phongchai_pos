import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phongchai_pos/features/auth/domain/employee.dart';
import 'package:phongchai_pos/features/auth/providers/auth_provider.dart';
import 'package:phongchai_pos/features/pos/presentation/pos_screen.dart';

class _TestAuth extends AuthNotifier {
  @override
  Employee? build() => const Employee(name: 'ทดสอบ', role: 'แคชเชียร์');
}

void main() {
  testWidgets('POS screen shows cart total', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuth.new),
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
