import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/core/database/app_database.dart';
import 'package:phongchai_pos/core/theme/app_theme.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/features/auth/presentation/login_screen.dart';
import 'package:phongchai_pos/features/auth/providers/auth_provider.dart';
import 'package:phongchai_pos/features/pos/presentation/pos_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    debugPrint('dotenv load failed: $e\n$st');
  }
  await MockDataStore.instance.loadAll();
  if (!kIsWeb) {
    await AppDatabase.instance.init();
  }
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
