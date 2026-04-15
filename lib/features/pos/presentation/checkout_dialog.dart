import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:phongchai_pos/core/loyalty/points_redeem.dart';
import 'package:phongchai_pos/features/pos/presentation/promptpay_qr_dialog.dart';

enum PosPaymentMethod { cash, transfer, mixed }

class PosCheckoutResult {
  const PosCheckoutResult({
    required this.method,
    this.cashAmount = 0,
    this.transferAmount = 0,
    this.cashReceived,
    required this.change,
    required this.printReceipt,
    this.pointsRedeemed = 0,
    this.pointsDiscountAmount = 0,
  });

  final PosPaymentMethod method;

  /// ยอดที่แบ่งเป็นช่องเงินสด (สำหรับรายงาน / backend)
  final double cashAmount;

  /// ยอดที่แบ่งเป็นช่องโอน (สำหรับ PromptPay / backend)
  final double transferAmount;

  /// ยอดรับเงินสดจริง (ใช้กับใบเสร็จ — โดยทั่วไปเท่ากับ [cashAmount])
  final double? cashReceived;

  final double change;
  final bool printReceipt;

  /// แต้มที่แลกในบิลนี้ (ส่ง backend หักแต้มหลัก)
  final int pointsRedeemed;

  /// ส่วนลดเป็นบาทจากการแลกแต้ม
  final double pointsDiscountAmount;
}

Future<PosCheckoutResult?> showPosCheckoutDialog(
  BuildContext context, {
  required double grandTotal,
  required String promptPayId,
  int? memberLoyaltyPoints,
  double pointExchangeRate = 0.1,
}) {
  return showDialog<PosCheckoutResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CheckoutDialogBody(
      grandTotal: grandTotal,
      promptPayId: promptPayId,
      memberLoyaltyPoints: memberLoyaltyPoints,
      pointExchangeRate: pointExchangeRate,
    ),
  );
}

class _CheckoutDialogBody extends StatefulWidget {
  const _CheckoutDialogBody({
    required this.grandTotal,
    required this.promptPayId,
    required this.memberLoyaltyPoints,
    required this.pointExchangeRate,
  });

  final double grandTotal;
  final String promptPayId;
  final int? memberLoyaltyPoints;
  final double pointExchangeRate;

  @override
  State<_CheckoutDialogBody> createState() => _CheckoutDialogBodyState();
}

class _CheckoutDialogBodyState extends State<_CheckoutDialogBody> {
  final _cashController = TextEditingController();
  final _transferController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');
  final _cashFocus = FocusNode(debugLabel: 'checkoutCash');
  /// ไม่ให้ Tab ข้ามมาที่ช่องโอนโดยอัตโนมัติ — โฟกัสเริ่มที่เงินสดเสมอ พนักงานคลิกช่องโอนเมื่อต้องแก้เอง
  final _transferFocus = FocusNode(debugLabel: 'checkoutTransfer', skipTraversal: true);
  bool _printReceipt = true;
  bool _programmatic = false;

  bool get _hasMemberPoints =>
      widget.memberLoyaltyPoints != null &&
      widget.memberLoyaltyPoints! > 0 &&
      widget.pointExchangeRate > 0;

  int get _clampedPoints {
    if (!_hasMemberPoints) return 0;
    final raw = int.tryParse(_pointsController.text.trim()) ?? 0;
    return PointsRedeem.clampPointsInput(
      raw: raw,
      loyaltyBalance: widget.memberLoyaltyPoints!,
      cartGrandTotal: widget.grandTotal,
      pointExchangeRate: widget.pointExchangeRate,
    );
  }

  double get _pointsDiscount => PointsRedeem.discountBahtCappedToBill(
        points: _clampedPoints,
        pointExchangeRate: widget.pointExchangeRate,
        cartGrandTotal: widget.grandTotal,
      );

  double get _amountDue =>
      (widget.grandTotal - _pointsDiscount).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_onCashChanged);
    _transferController.addListener(_onTransferChanged);
    _pointsController.addListener(_onPointsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncCashTransferToAmountDue();
        if (mounted) _cashFocus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _cashController.removeListener(_onCashChanged);
    _transferController.removeListener(_onTransferChanged);
    _pointsController.removeListener(_onPointsChanged);
    _cashController.dispose();
    _transferController.dispose();
    _pointsController.dispose();
    _cashFocus.dispose();
    _transferFocus.dispose();
    super.dispose();
  }

  static double _parseOrZero(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t.replaceAll(',', '')) ?? 0;
  }

  /// ยอดที่ระบบเติมให้อีกช่อง — แสดงทศนิยมเสมอ (รวม 0.00) เพื่อให้เห็นส่วนต่างทันทีขณะพิมพ์
  static String _fmtSyncedAmount(double v) => v.toStringAsFixed(2);

  double get _cash => _parseOrZero(_cashController.text);
  double get _transfer => _parseOrZero(_transferController.text);
  double get _totalPaid => _cash + _transfer;

  /// เงินทอน: นับเมื่อมีส่วนเงินสด และยอดรวมเกินยอดสุทธิ
  double get _change {
    if (_cash <= 1e-9) return 0;
    if (_totalPaid <= _amountDue + 1e-9) return 0;
    return _totalPaid - _amountDue;
  }

  bool get _canConfirm => _totalPaid + 1e-9 >= _amountDue;

  void _onPointsChanged() {
    if (_programmatic) return;
    if (!_hasMemberPoints) {
      setState(() {});
      return;
    }
    final maxP = PointsRedeem.maxUsablePoints(
      loyaltyBalance: widget.memberLoyaltyPoints ?? 0,
      cartGrandTotal: widget.grandTotal,
      pointExchangeRate: widget.pointExchangeRate,
    );
    final raw = int.tryParse(_pointsController.text.trim()) ?? 0;
    final clamped = raw.clamp(0, maxP);
    if (raw != clamped) {
      _programmatic = true;
      _pointsController.text = clamped.toString();
      _pointsController.selection = TextSelection.collapsed(
        offset: _pointsController.text.length,
      );
      _programmatic = false;
    }
    setState(() {});
    _syncCashTransferToAmountDue();
  }

  void _syncCashTransferToAmountDue() {
    _programmatic = true;
    final due = _amountDue;
    _cashController.text = _fmtSyncedAmount(due);
    _transferController.text = _fmtSyncedAmount(0);
    _programmatic = false;
    setState(() {});
  }

  void _useMaxPoints() {
    if (!_hasMemberPoints) return;
    final maxP = PointsRedeem.maxUsablePoints(
      loyaltyBalance: widget.memberLoyaltyPoints!,
      cartGrandTotal: widget.grandTotal,
      pointExchangeRate: widget.pointExchangeRate,
    );
    _pointsController.text = maxP.toString();
    _pointsController.selection = TextSelection.collapsed(
      offset: _pointsController.text.length,
    );
    setState(() {});
    _syncCashTransferToAmountDue();
  }

  void _onCashChanged() {
    if (_programmatic) return;
    _programmatic = true;
    final c = _parseOrZero(_cashController.text);
    final g = _amountDue;
    final remainder = (g - c).clamp(0.0, double.infinity);
    _transferController.text = _fmtSyncedAmount(remainder);
    _programmatic = false;
    setState(() {});
  }

  void _onTransferChanged() {
    if (_programmatic) return;
    _programmatic = true;
    final t = _parseOrZero(_transferController.text);
    final g = _amountDue;
    final remainder = (g - t).clamp(0.0, double.infinity);
    _cashController.text = _fmtSyncedAmount(remainder);
    _programmatic = false;
    setState(() {});
  }

  void _exactCash() {
    _programmatic = true;
    final t = _parseOrZero(_transferController.text);
    final g = _amountDue;
    _cashController.text = _fmtSyncedAmount((g - t).clamp(0.0, double.infinity));
    _programmatic = false;
    setState(() {});
  }

  void _exactTransfer() {
    _programmatic = true;
    final c = _parseOrZero(_cashController.text);
    final g = _amountDue;
    _transferController.text = _fmtSyncedAmount((g - c).clamp(0.0, double.infinity));
    _programmatic = false;
    setState(() {});
  }

  PosPaymentMethod _deriveMethod(double cash, double transfer) {
    if (cash > 1e-9 && transfer > 1e-9) return PosPaymentMethod.mixed;
    if (transfer > 1e-9) return PosPaymentMethod.transfer;
    return PosPaymentMethod.cash;
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    final cash = _cash;
    final transfer = _transfer;
    final method = _deriveMethod(cash, transfer);
    final change = _change;
    final pts = _clampedPoints;
    final discount = _pointsDiscount;

    if (transfer > 1e-9) {
      final confirmed = await showPromptPayQrDialog(
        context,
        amount: transfer,
        promptPayId: widget.promptPayId,
      );
      if (!mounted) return;
      if (confirmed != true) return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      PosCheckoutResult(
        method: method,
        cashAmount: cash,
        transferAmount: transfer,
        cashReceived: cash > 1e-9 ? cash : null,
        change: change,
        printReceipt: _printReceipt,
        pointsRedeemed: pts,
        pointsDiscountAmount: discount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartTotal = widget.grandTotal;
    final due = _amountDue;
    final maxP = _hasMemberPoints
        ? PointsRedeem.maxUsablePoints(
            loyaltyBalance: widget.memberLoyaltyPoints!,
            cartGrandTotal: cartTotal,
            pointExchangeRate: widget.pointExchangeRate,
          )
        : 0;

    return AlertDialog(
        title: const Text('ชำระเงิน'),
        content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ยอดรวมบิล',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '฿${cartTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_hasMemberPoints) ...[
                const SizedBox(height: 16),
                Text(
                  'แลกแต้ม (Redeem Points)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'แต้มคงเหลือ: ${PointsRedeem.formatPoints(widget.memberLoyaltyPoints!)} แต้ม · 1 แต้ม = ${widget.pointExchangeRate.toStringAsFixed(2)} บาท (สูงสุด ${PointsRedeem.formatPoints(maxP)} แต้มสำหรับบิลนี้)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pointsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'จำนวนแต้มที่ใช้',
                          helperText:
                              'แลก ${PointsRedeem.formatPoints(_clampedPoints)} แต้ม',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: maxP > 0 ? _useMaxPoints : null,
                        child: const Text('ใช้แต้มสูงสุด'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ส่วนลดจากแต้ม',
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          '-฿${_pointsDiscount.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'ยอดที่ต้องชำระ',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '฿${due.toStringAsFixed(2)}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'แบ่งชำระ (เงินสด / โอน)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashController,
                      focusNode: _cashFocus,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'ยอดเงินสด',
                        prefixText: '฿ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: _exactCash,
                      child: const Text('จ่ายพอดี'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _transferController,
                      focusNode: _transferFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'ยอดเงินโอน',
                        prefixText: '฿ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: _exactTransfer,
                      child: const Text('จ่ายพอดี'),
                    ),
                  ),
                ],
              ),
              if (_transfer > 1e-9) ...[
                const SizedBox(height: 8),
                Text(
                  'เมื่อกดยืนยัน จะเปิด QR พร้อมเพย์ตามยอดโอน — ถ้าปิดไปก่อน กด «ยืนยันชำระ» อีกครั้ง',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'รวมกรอก: ฿${_totalPaid.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (!_canConfirm)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'ยอดรวมต้องไม่น้อยกว่ายอดสุทธิ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
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
                        'เงินทอน (เมื่อมีเงินสดและจ่ายเกิน)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '฿${_change.toStringAsFixed(2)}',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
          onPressed: _canConfirm ? () => unawaited(_confirm()) : null,
          child: const Text('ยืนยันชำระ'),
        ),
      ],
    );
  }
}
