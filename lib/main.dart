import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/core/theme/app_theme.dart';
import 'package:phongchai_pos/features/auth/presentation/login_screen.dart';
import 'package:phongchai_pos/features/auth/providers/auth_provider.dart';
import 'package:phongchai_pos/features/pos/presentation/pos_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: PhongchaiPosApp(),
    ),
  );
}

class PhongchaiPosApp extends ConsumerWidget {
  const PhongchaiPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(authProvider);

    return MaterialApp(
      title: 'Phongchai POS',
      theme: buildAppTheme(),
      home: employee == null ? const LoginScreen() : const POSScreen(),
    );
  }
}
