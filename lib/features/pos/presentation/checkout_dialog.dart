import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:phongchai_pos/features/pos/presentation/promptpay_qr_dialog.dart';

enum PosPaymentMethod { cash, transfer }

class PosCheckoutResult {
  const PosCheckoutResult({
    required this.method,
    this.cashReceived,
    required this.change,
    required this.printReceipt,
  });

  final PosPaymentMethod method;
  final double? cashReceived;
  final double change;
  final bool printReceipt;
}

Future<PosCheckoutResult?> showPosCheckoutDialog(
  BuildContext context, {
  required double grandTotal,
  required String promptPayId,
}) {
  return showDialog<PosCheckoutResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CheckoutDialogBody(
      grandTotal: grandTotal,
      promptPayId: promptPayId,
    ),
  );
}

class _CheckoutDialogBody extends StatefulWidget {
  const _CheckoutDialogBody({
    required this.grandTotal,
    required this.promptPayId,
  });

  final double grandTotal;
  final String promptPayId;

  @override
  State<_CheckoutDialogBody> createState() => _CheckoutDialogBodyState();
}

class _CheckoutDialogBodyState extends State<_CheckoutDialogBody> {
  PosPaymentMethod _method = PosPaymentMethod.cash;
  final _cashReceivedController = TextEditingController();
  bool _printReceipt = true;

  @override
  void initState() {
    super.initState();
    _cashReceivedController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    super.dispose();
  }

  double? get _parsedCash {
    final t = _cashReceivedController.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  double get _change {
    if (_method != PosPaymentMethod.cash) return 0;
    final r = _parsedCash;
    if (r == null) return 0;
    return r - widget.grandTotal;
  }

  bool get _canConfirm {
    if (_method == PosPaymentMethod.transfer) return true;
    final r = _parsedCash;
    if (r == null) return false;
    return r >= widget.grandTotal;
  }

  /// เปิด QR พร้อมเพย์ — ถ้าโอนแล้วกดยืนยันแล้ว ปิด dialog ชำระเงินพร้อมผลลัพธ์
  Future<void> _openPromptPayAndMaybeComplete() async {
    if (!_canConfirm || _method != PosPaymentMethod.transfer) return;
    final confirmed = await showPromptPayQrDialog(
      context,
      amount: widget.grandTotal,
      promptPayId: widget.promptPayId,
    );
    if (!mounted) return;
    if (confirmed == true) {
      Navigator.of(context).pop(
        PosCheckoutResult(
          method: PosPaymentMethod.transfer,
          change: 0,
          printReceipt: _printReceipt,
        ),
      );
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    if (_method == PosPaymentMethod.transfer) {
      await _openPromptPayAndMaybeComplete();
      return;
    }
    final r = _parsedCash!;
    Navigator.of(context).pop(
      PosCheckoutResult(
        method: PosPaymentMethod.cash,
        cashReceived: r,
        change: r - widget.grandTotal,
        printReceipt: _printReceipt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grand = widget.grandTotal;

    return AlertDialog(
      title: const Text('ชำระเงิน'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
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
              const SizedBox(height: 4),
              Text(
                '฿${grand.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'วิธีชำระ',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PosPaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: PosPaymentMethod.cash,
                    label: Text('เงินสด'),
                    icon: Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: PosPaymentMethod.transfer,
                    label: Text('โอนเงิน'),
                    icon: Icon(Icons.account_balance_outlined),
                  ),
                ],
                selected: {_method},
                onSelectionChanged: (s) {
                  final next = s.first;
                  setState(() => _method = next);
                  if (next == PosPaymentMethod.transfer) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) unawaited(_openPromptPayAndMaybeComplete());
                    });
                  }
                },
              ),
              if (_method == PosPaymentMethod.transfer) ...[
                const SizedBox(height: 8),
                Text(
                  'เปิด QR พร้อมเพย์ทันที — ถ้าปิดไปก่อน กด «ยืนยันชำระ» อีกครั้งเพื่อสแกนใหม่',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              if (_method == PosPaymentMethod.cash) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _cashReceivedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'รับเงิน (บาท)',
                    prefixText: '฿ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เงินทอน',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '฿${_change < 0 ? '—' : _change.toStringAsFixed(2)}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _change < 0
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                        if (_parsedCash != null && _change < 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'รับเงินไม่พอ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SwitchListTile(
                value: _printReceipt,
                onChanged: (v) => setState(() => _printReceipt = v),
                title: const Text('พิมพ์ใบเสร็จ'),
                subtitle: const Text('เปิดเมื่อต้องการส่งไปเครื่องพิมพ์'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _canConfirm ? () => _confirm() : null,
          child: const Text('ยืนยันชำระ'),
        ),
      ],
    );
  }
}
