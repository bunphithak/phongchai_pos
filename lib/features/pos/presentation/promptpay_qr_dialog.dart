import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phongchai_pos/core/utils/promptpay_emv_payload.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// แสดง QR พร้อมเพย์แบบ **Dynamic QR** (มียอดเงินในสตริง EMVCo)
///
/// Payload สร้างในเครื่องด้วย [buildPromptPayEmvPayload] (CRC ครบ 4 หลักตามมาตรฐาน EMV)
/// การแสดง QR ใช้ `qr_flutter` ตามที่กำหนด
class PromptPayQrDialog extends StatelessWidget {
  const PromptPayQrDialog({
    super.key,
    required this.amount,
    required this.promptPayId,
  });

  final double amount;
  final String promptPayId;

  static final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');

  ({String? error, String? payload}) _compute() {
    if (amount <= 0) {
      return (error: 'ยอดเงินไม่ถูกต้อง (ต้องมากกว่า 0)', payload: null);
    }
    final digits = promptPayId.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return (error: 'ยังไม่ได้ตั้งเลขพร้อมเพย์ของร้าน', payload: null);
    }
    try {
      final p = buildPromptPayEmvPayload(
        promptPayId: promptPayId.trim(),
        amount: amount,
      );
      return (error: null, payload: p);
    } catch (_) {
      return (
        error: 'สร้าง QR ไม่สำเร็จ ลองตรวจเลขพร้อมเพย์ (เบอร์/เลขนิติ) อีกครั้ง',
        payload: null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (error: err, payload: payload) = _compute();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      title: _PromptPayHeader(theme: theme),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ยอดที่ต้องชำระ',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '฿${_money.format(amount)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              if (err != null)
                Material(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            err,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (payload != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 220,
                      gapless: true,
                      // โลโก้ตรงกลางต้องใช้ error correction สูง (H) ให้สแกนได้แม้มีรูปบัง
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      backgroundColor: Colors.white,
                      embeddedImage: const AssetImage(
                        'assets/images/promptpay_logo.png',
                      ),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(56, 56),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: 12),
              Text(
                'สแกน QR เพื่อโอนผ่านพร้อมเพย์ (ยอดถูกล็อกตามบิลนี้)',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: err != null || payload == null
              ? null
              : () => Navigator.of(context).pop(true),
          child: const Text('ยืนยันการชำระเงิน'),
        ),
      ],
    );
  }
}

class _PromptPayHeader extends StatelessWidget {
  const _PromptPayHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF00427D);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: brandBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PromptPay',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: brandBlue,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'พร้อมเพย์',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// คืนค่า `true` เมื่อผู้ใช้กดยืนยันว่าโอนแล้ว, `false` เมื่อยกเลิก
Future<bool?> showPromptPayQrDialog(
  BuildContext context, {
  required double amount,
  required String promptPayId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PromptPayQrDialog(
      amount: amount,
      promptPayId: promptPayId,
    ),
  );
}
