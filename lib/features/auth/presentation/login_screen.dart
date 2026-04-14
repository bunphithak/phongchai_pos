import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/features/auth/providers/auth_provider.dart';

const _kNavy = Color(0xFF1E293B);
const _kBg = Color(0xFFF1F5F9);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _pinLength = 6;
  final StringBuffer _pin = StringBuffer();

  void _appendDigit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin.write(d));
    if (_pin.length == _pinLength) {
      _trySubmit();
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      final s = _pin.toString();
      _pin.clear();
      if (s.length > 1) {
        _pin.write(s.substring(0, s.length - 1));
      }
    });
  }

  void _clearAll() {
    if (_pin.isEmpty) return;
    setState(() => _pin.clear());
  }

  void _trySubmit() {
    final code = _pin.toString();
    final ok = ref.read(authProvider.notifier).tryLoginWithPin(code);
    if (!ok && mounted) {
      setState(() => _pin.clear());
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัส PIN ไม่ถูกต้อง'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Phongchai POS',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _kNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรอกรหัส PIN 6 หลัก',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _pin.length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? _kNavy : Colors.transparent,
                            border: Border.all(
                              color: filled ? _kNavy : _kSummaryBorderLogin,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 40),
                  _Numpad(
                    onDigit: _appendDigit,
                    onBackspace: _backspace,
                    onClear: _clearAll,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ทดลอง: 123456 หรือ 654321',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _kSummaryBorderLogin = Color(0xFFCBD5E1);

class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget keyCell({required Widget child, required VoidCallback onTap}) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 64,
            child: Center(child: child),
          ),
        ),
      );
    }

    Widget numKey(String n) {
      return keyCell(
        onTap: () {
          HapticFeedback.lightImpact();
          onDigit(n);
        },
        child: Text(
          n,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: _kNavy,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (final d in row) ...[
                  Expanded(child: numKey(d)),
                  if (d != row.last) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: keyCell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onClear();
                },
                child: Text(
                  'ล้าง',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: numKey('0')),
            const SizedBox(width: 12),
            Expanded(
              child: keyCell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onBackspace();
                },
                child: Icon(
                  Icons.backspace_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
