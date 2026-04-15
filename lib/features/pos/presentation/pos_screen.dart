import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/core/utils/pdf_generator.dart';
import 'package:phongchai_pos/core/utils/tax_invoice_print.dart';
import 'package:phongchai_pos/core/utils/thermal_receipt_pdf.dart';
import 'package:phongchai_pos/core/utils/thai_date_time.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:phongchai_pos/data/models/product.dart';
import 'package:phongchai_pos/features/pos/domain/barcode_catalog.dart';
import 'package:phongchai_pos/features/pos/domain/tax_invoice_buyer_info.dart';
import 'package:phongchai_pos/features/auth/presentation/login_screen.dart';
import 'package:phongchai_pos/features/auth/providers/auth_provider.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';
import 'package:phongchai_pos/features/pos/presentation/checkout_dialog.dart';
import 'package:phongchai_pos/features/pos/domain/sale_record.dart';
import 'package:phongchai_pos/features/pos/presentation/order_history_screen.dart';
import 'package:phongchai_pos/features/pos/presentation/tax_invoice_form_dialog.dart';
import 'package:phongchai_pos/features/pos/providers/cart_provider.dart';
import 'package:phongchai_pos/features/pos/providers/pos_session_provider.dart';
import 'package:phongchai_pos/features/pos/providers/sales_history_provider.dart';
import 'package:phongchai_pos/features/pos/providers/tax_invoice_buyer_provider.dart';

/// สีธีม POS — โทน slate / navy อ่านสบายตา
const _kHeaderNavy = Color(0xFF1E293B);

/// แถบบนแบบมืดสนิท (navbar ไอคอน)
const _kAppBarDark = Color(0xFF121212);
const _kScaffoldBg = Color(0xFFF1F5F9);
const _kSummaryBorder = Color(0xFFE2E8F0);
final NumberFormat _kMoneyFmt = NumberFormat('#,##0.00', 'en_US');

/// ยอดรวมสุทธิ — สีน้ำเงินเข้มให้เด่น
const _kNetTotalColor = Color(0xFF0D47A1);

String _formatLoyaltyPoints(int points) {
  final s = points.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(s[i]);
  }
  return buf.toString();
}

String _formatDiscountField(double v) {
  if (v == 0) return '';
  if (v == v.roundToDouble()) return '${v.round()}';
  return v.toString();
}

/// ไอคอนแถบบนแบบเส้น (outline) บนพื้นมืด
Widget _posNavIconButton({
  required IconData icon,
  required String tooltip,
  VoidCallback? onPressed,
  bool selected = false,
}) {
  final box = Container(
    width: 54,
    height: 74,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: selected
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.06),
      border: Border.all(
        color: selected
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.22),
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 24),
        SizedBox(height: 10),
        Text(
          tooltip,
          style: TextStyle(color: Colors.white, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  if (onPressed == null) {
    return Tooltip(message: tooltip, child: box);
  }

  return Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: box,
      ),
    ),
  );
}

/// หัวแถบ POS: วันที่ + ไอคอนร้าน / ประวัติ (ไม่มีช่องค้นหาในแถบ)
class _PosAppBarHeader extends StatefulWidget {
  const _PosAppBarHeader({
    required this.onOpenMemberPicker,
    required this.onOpenHistory,
    required this.onOpenTaxInvoiceForm,
  });

  final VoidCallback onOpenMemberPicker;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenTaxInvoiceForm;

  @override
  State<_PosAppBarHeader> createState() => _PosAppBarHeaderState();
}

class _PosAppBarHeaderState extends State<_PosAppBarHeader> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ขายหน้าร้าน',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatThaiBuddhistDate(_now),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.2,
                ),
              ),
              Text(
                '${twoDigitTimePart(_now.hour)}:${twoDigitTimePart(_now.minute)}:${twoDigitTimePart(_now.second)} น.',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _posNavIconButton(
                    icon: Icons.people_alt_outlined,
                    tooltip: 'สมาชิก(F1)',
                    onPressed: widget.onOpenMemberPicker,
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 10),
                  _posNavIconButton(
                    icon: Icons.receipt_long_outlined,
                    tooltip: 'ประวัติการขาย',
                    onPressed: widget.onOpenHistory,
                  ),
                  const SizedBox(width: 8),
                  _posNavIconButton(
                    icon: Icons.edit_document,
                    tooltip: 'ใบกำกับภาษี',
                    onPressed: widget.onOpenTaxInvoiceForm,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  final _barcodeController = TextEditingController();
  final _scanQtyController = TextEditingController(text: '1');
  final _barcodeFocus = FocusNode();
  final _discountController = TextEditingController();
  final _memberPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _scanQtyController.dispose();
    _barcodeFocus.dispose();
    _discountController.dispose();
    _memberPhoneController.dispose();
    super.dispose();
  }

  void _refocusBarcode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _barcodeFocus.requestFocus();
      }
    });
  }

  int _readScanQuantity() {
    final parsed = int.tryParse(_scanQtyController.text.trim()) ?? 1;
    if (parsed <= 0) return 1;
    if (parsed > 999) return 999;
    return parsed;
  }

  void _onScanQtySubmitted(String value) {
    final raw = value.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 8) {
      // กันกรณีปืนยิงสแกนหลุดมาที่ช่องจำนวน: ย้ายเป็นบาร์โค้ดให้อัตโนมัติ
      _scanQtyController.text = '1';
      _barcodeController.text = digits;
      unawaited(_onBarcodeSubmitted(digits));
      return;
    }
    if (digits.isEmpty || digits == '0') {
      _scanQtyController.text = '1';
    } else if (digits.length > 3) {
      _scanQtyController.text = '999';
    } else if (digits != raw) {
      _scanQtyController.text = digits;
    }
    _refocusBarcode();
  }

  Future<void> _onBarcodeSubmitted(String value) async {
    final qty = _readScanQuantity();
    final code = value.trim();
    if (code.isEmpty) {
      _refocusBarcode();
      return;
    }

    final product = productForBarcode(code);
    if (product == null) {
      _barcodeController.clear();
      if (!mounted) return;
      await _showProductNotFoundDialog(code);
      if (mounted) {
        _refocusBarcode();
      }
      return;
    }

    final cart = ref.read(cartProvider.notifier);
    for (var i = 0; i < qty; i++) {
      cart.addOrIncrementProduct(product);
    }
    _barcodeController.clear();
    _scanQtyController.text = '1';
    _refocusBarcode();
  }

  Future<void> _showProductNotFoundDialog(String code) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: colorScheme.error,
              size: 32,
            ),
          ),
          title: Text(
            'ไม่พบสินค้า',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: _kHeaderNavy,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ไม่มีรหัสนี้ในระบบ กรุณาตรวจสอบบาร์โค้ดหรือลองสแกนใหม่',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.65,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kSummaryBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetDiscountField() {
    _discountController.clear();
    ref.read(cartDiscountProvider.notifier).reset();
  }

  void _resetMemberField() {
    _memberPhoneController.clear();
    ref.read(posMemberProvider.notifier).clear();
  }

  void _performClearCart() {
    ref.read(cartProvider.notifier).clear();
    _resetDiscountField();
    _resetMemberField();
    ref.read(taxInvoiceBuyerProvider.notifier).clear();
    _refocusBarcode();
  }

  Future<void> _onRequestClearCart() async {
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ตะกร้าว่าง')));
      }
      _refocusBarcode();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ล้างตะกร้า?'),
          content: const Text(
            'สินค้า ส่วนลด และข้อมูลสมาชิกบนหน้านี้จะถูกล้างทั้งหมด การกระทำนี้ไม่สามารถย้อนกลับได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              child: const Text('ล้างตะกร้า'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (confirmed == true) {
      _performClearCart();
    } else {
      _refocusBarcode();
    }
  }

  Future<void> _onCheckout() async {
    final total = ref.read(cartGrandTotalProvider);
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ตะกร้าว่าง')));
      }
      _refocusBarcode();
      return;
    }

    final result = await showPosCheckoutDialog(context, grandTotal: total);
    if (!mounted || result == null) {
      _refocusBarcode();
      return;
    }

    final snapshotLines = List<CartItem>.from(lines);
    final member = ref.read(posMemberProvider);
    final subtotal = ref.read(cartSubtotalProvider);
    final discAmount = ref.read(cartDiscountAmountProvider);
    final net = ref.read(cartNetSubtotalProvider);
    final vat = ref.read(cartVatProvider);
    final vatEnabled = ref.read(cartVatEnabledProvider);
    final soldAt = DateTime.now();
    final invoiceNo =
        'INV-${soldAt.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '')}';

    final taxBuyer = ref.read(taxInvoiceBuyerProvider);
    final invoiceData = TaxInvoiceData(
      issuedAt: soldAt,
      invoiceNo: invoiceNo,
      lines: snapshotLines,
      customerName: member.billMember?.name,
      customerPhone: member.billMember?.phone,
      buyerInvoice: taxBuyer.hasAnyInput ? taxBuyer : null,
      subtotal: subtotal,
      discountAmount: discAmount,
      netBeforeVat: net,
      vatAmount: vat,
      vatEnabled: vatEnabled,
      grandTotal: total,
      method: result.method,
      cashReceived: result.cashReceived,
      change: result.change,
    );

    await ref
        .read(salesHistoryProvider.notifier)
        .recordSale(
          SaleRecord(
            id: '${soldAt.microsecondsSinceEpoch}_$invoiceNo',
            soldAt: soldAt,
            invoiceNo: invoiceNo,
            lines: snapshotLines,
            subtotal: subtotal,
            discountAmount: discAmount,
            netBeforeVat: net,
            vatAmount: vat,
            vatEnabled: vatEnabled,
            grandTotal: total,
            method: result.method,
            cashReceived: result.cashReceived,
            change: result.change,
            memberName: member.billMember?.name,
            memberPhone: member.billMember?.phone,
          ),
        );

    if (taxBuyer.hasAnyInput) {
      // มีข้อมูลกำกับภาษี: เปิดหน้า PDF A4 ก่อน
      await _printTaxInvoice(invoiceData);
      if (!mounted) return;
      await _showCheckoutSuccessModal(result: result);
      if (!mounted) return;
      _refocusBarcode();
      return;
    }

    // ไม่มีข้อมูลกำกับภาษี: ชั่วคราวเปิดเป็น PDF ก่อน (รอเครื่องพิมพ์จริง)
    await _openThermalReceiptPdfPreview(invoiceData);
    if (!mounted) return;
    await _showCheckoutSuccessModal(result: result);
    if (!mounted) return;
    _refocusBarcode();
  }

  void _finalizeCheckoutAndClearCurrentSale() {
    ref.read(cartProvider.notifier).clear();
    _resetDiscountField();
    _resetMemberField();
    ref.read(taxInvoiceBuyerProvider.notifier).clear();
  }

  Future<void> _printTaxInvoice(TaxInvoiceData data) async {
    await printTaxInvoiceWithFallback(context: context, data: data);
  }

  Future<void> _showCheckoutSuccessModal({
    required PosCheckoutResult result,
  }) async {
    if (!mounted) return;
    final shouldClear = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final methodLabel = result.method == PosPaymentMethod.cash
            ? 'เงินสด'
            : 'โอนเงิน';
        return AlertDialog(
          title: const Text('ชำระเงินสำเร็จ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('วิธีชำระ: $methodLabel'),
              if (result.method == PosPaymentMethod.cash) ...[
                const SizedBox(height: 6),
                Text('เงินทอน: ฿${_kMoneyFmt.format(result.change)}'),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      _finalizeCheckoutAndClearCurrentSale();
    }
  }

  Future<void> _openThermalReceiptPdfPreview(TaxInvoiceData data) async {
    try {
      final bytes = await buildThermalReceiptPdfBytes(data);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            appBar: AppBar(title: const Text('ตัวอย่างใบเสร็จ (ชั่วคราว)')),
            body: PdfPreview(
              maxPageWidth: 420,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: true,
              build: (_) async => bytes,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เปิดตัวอย่างใบเสร็จไม่สำเร็จ: $e')),
        );
      }
    }
  }

  Future<void> _onHoldBill() async {
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่มีรายการในตะกร้า')));
      }
      _refocusBarcode();
      return;
    }

    final existing = ref.read(heldBillProvider);
    if (existing != null && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('มีบิลพักอยู่แล้ว'),
          content: const Text('ต้องการแทนที่บิลพักเดิมด้วยบิลนี้หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('แทนที่'),
            ),
          ],
        ),
      );
      if (ok != true) {
        _refocusBarcode();
        return;
      }
    }

    final discount = ref.read(cartDiscountProvider);
    final member = ref.read(posMemberProvider);
    final taxBuyer = ref.read(taxInvoiceBuyerProvider);
    ref
        .read(heldBillProvider.notifier)
        .setHeld(
          HeldBillData(
            cartItems: List<CartItem>.from(lines),
            discount: discount,
            billMember: member.billMember,
            vatEnabled: ref.read(cartVatEnabledProvider),
            taxBuyer: taxBuyer,
          ),
        );
    ref.read(cartProvider.notifier).clear();
    _resetDiscountField();
    _resetMemberField();
    ref.read(taxInvoiceBuyerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('พักบิลเรียบร้อย')));
    }
    _refocusBarcode();
  }

  Future<void> _onRecallHeldBill() async {
    final held = ref.read(heldBillProvider);
    if (held == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่มีบิลพัก')));
      }
      _refocusBarcode();
      return;
    }

    final current = ref.read(cartProvider);
    if (current.isNotEmpty && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ตะกร้ามีสินค้าอยู่'),
          content: const Text(
            'เรียกบิลพักจะแทนที่รายการในตะกร้าปัจจุบัน ต้องการดำเนินการต่อหรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('เรียกบิลพัก'),
            ),
          ],
        ),
      );
      if (ok != true) {
        _refocusBarcode();
        return;
      }
    }

    ref
        .read(cartProvider.notifier)
        .setItems(List<CartItem>.from(held.cartItems));
    ref.read(cartDiscountProvider.notifier).replaceWith(held.discount);
    _discountController.text = _formatDiscountField(held.discount.rawValue);
    ref.read(cartVatEnabledProvider.notifier).setEnabled(held.vatEnabled);
    ref.read(posMemberProvider.notifier).restoreBillMember(held.billMember);
    ref.read(taxInvoiceBuyerProvider.notifier).setFromForm(held.taxBuyer);
    ref.read(heldBillProvider.notifier).clearHeld();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เรียกบิลพักแล้ว')));
    }
    _refocusBarcode();
  }

  void _onMemberSearch() {
    ref
        .read(posMemberProvider.notifier)
        .searchByPhone(_memberPhoneController.text);
    _refocusBarcode();
  }

  Future<void> _openMemberPickerModal() async {
    final all = MockDataStore.instance.memberDirectory;
    if (all.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ยังไม่มีข้อมูลสมาชิก')));
      }
      _refocusBarcode();
      return;
    }

    final queryController = TextEditingController();
    final selected = await showDialog<MockMemberCandidate>(
      context: context,
      builder: (ctx) {
        var filtered = all;
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('ค้นหาสมาชิก'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาจากชื่อหรือเบอร์โทร',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        final q = v.trim().toLowerCase();
                        setLocalState(() {
                          if (q.isEmpty) {
                            filtered = all;
                          } else {
                            filtered = all.where((e) {
                              return e.phone.contains(q) ||
                                  e.name.toLowerCase().contains(q);
                            }).toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Center(child: Text('ไม่พบสมาชิก'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final m = filtered[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(m.name),
                                  subtitle: Text(
                                    '${m.phone} • แต้ม ${_formatLoyaltyPoints(m.loyaltyPoints)}',
                                  ),
                                  onTap: () => Navigator.of(ctx).pop(m),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
    queryController.dispose();
    if (!mounted) return;
    if (selected != null) {
      _memberPhoneController.text = selected.phone;
      _onMemberSearch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เลือกสมาชิกแล้ว: ${selected.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    _refocusBarcode();
  }

  Future<void> _showEditQuantityDialog(int index, CartItem item) async {
    final controller = TextEditingController(text: '${item.quantity}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.product.name),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'จำนวน',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      final q = int.tryParse(controller.text.trim());
      if (q != null) {
        if (q <= 0) {
          ref.read(cartProvider.notifier).removeAt(index);
        } else {
          ref.read(cartProvider.notifier).setQuantityAt(index, q);
        }
      }
    }
    controller.dispose();
    _refocusBarcode();
  }

  void _logout() {
    ref.read(authProvider.notifier).logout();
    ref.read(cartProvider.notifier).clear();
    ref.read(cartDiscountProvider.notifier).reset();
    ref.read(cartVatEnabledProvider.notifier).reset();
    ref.read(posMemberProvider.notifier).clear();
    ref.read(taxInvoiceBuyerProvider.notifier).clear();
    ref.read(heldBillProvider.notifier).clearHeld();
  }

  void _openTaxInvoiceForm() {
    showTaxInvoiceFormDialog(context, ref).whenComplete(() {
      if (mounted) _refocusBarcode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(authProvider);
    if (employee == null) {
      return const LoginScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // F5/F12 ถูกเบราว์เซอร์ใช้ (รีเฟรช / DevTools) และบน macOS มักถูกระบบจับ — ใช้ CallbackShortcuts
    // และมี Ctrl+Shift+P / Ctrl+Shift+L เป็นทางสำรอง
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f12): () {
          if (mounted) unawaited(_onCheckout());
        },
        const SingleActivator(LogicalKeyboardKey.f5): () {
          if (mounted) unawaited(_onRequestClearCart());
        },
        const SingleActivator(LogicalKeyboardKey.f1): () {
          if (mounted) unawaited(_openMemberPickerModal());
        },
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
        ): () {
          if (mounted) unawaited(_onCheckout());
        },
        const SingleActivator(
          LogicalKeyboardKey.keyL,
          control: true,
          shift: true,
        ): () {
          if (mounted) unawaited(_onRequestClearCart());
        },
      },
      child: Scaffold(
        backgroundColor: _kScaffoldBg,
        appBar: AppBar(
          toolbarHeight: 104,
          centerTitle: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _PosAppBarHeader(
              onOpenMemberPicker: () => unawaited(_openMemberPickerModal()),
              onOpenTaxInvoiceForm: _openTaxInvoiceForm,
              onOpenHistory: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const OrderHistoryScreen(),
                  ),
                );
              },
            ),
          ),
          elevation: 0,
          backgroundColor: _kAppBarDark,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    employee.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    employee.role,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'ออกจากระบบ',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 67,
                    child: _CartPanel(
                      onHoldBill: _onHoldBill,
                      onRecallHeldBill: _onRecallHeldBill,
                      hasHeldBill: ref.watch(heldBillProvider) != null,
                      onEditLineQuantity: _showEditQuantityDialog,
                      onRequestClearCart: _onRequestClearCart,
                    ),
                  ),
                  Expanded(
                    flex: 33,
                    child: _SummaryPanel(
                      onRefocusBarcode: _refocusBarcode,
                      onScanQtySubmitted: _onScanQtySubmitted,
                    onOpenTaxInvoiceForm: _openTaxInvoiceForm,
                      scanQtyController: _scanQtyController,
                      barcodeController: _barcodeController,
                      barcodeFocus: _barcodeFocus,
                      discountController: _discountController,
                      onBarcodeSubmitted: _onBarcodeSubmitted,
                      onCheckout: _onCheckout,
                      onDiscountRawChanged: (v) {
                        ref.read(cartDiscountProvider.notifier).setRawValue(v);
                      },
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _CartPanel(
                    onHoldBill: _onHoldBill,
                    onRecallHeldBill: _onRecallHeldBill,
                    hasHeldBill: ref.watch(heldBillProvider) != null,
                    onEditLineQuantity: _showEditQuantityDialog,
                    onRequestClearCart: _onRequestClearCart,
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Material(
                    color: colorScheme.surface,
                    elevation: 6,
                    shadowColor: Colors.black26,
                    child: _SummaryPanel(
                      onRefocusBarcode: _refocusBarcode,
                      onScanQtySubmitted: _onScanQtySubmitted,
                      onOpenTaxInvoiceForm: _openTaxInvoiceForm,
                      scanQtyController: _scanQtyController,
                      barcodeController: _barcodeController,
                      barcodeFocus: _barcodeFocus,
                      discountController: _discountController,
                      onBarcodeSubmitted: _onBarcodeSubmitted,
                      onCheckout: _onCheckout,
                      onDiscountRawChanged: (v) {
                        ref.read(cartDiscountProvider.notifier).setRawValue(v);
                      },
                      scrollable: true,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({
    required this.onHoldBill,
    required this.onRecallHeldBill,
    required this.hasHeldBill,
    required this.onEditLineQuantity,
    required this.onRequestClearCart,
  });

  final VoidCallback onHoldBill;
  final VoidCallback onRecallHeldBill;
  final bool hasHeldBill;
  final Future<void> Function(int index, CartItem item) onEditLineQuantity;
  final Future<void> Function() onRequestClearCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cartRows = <_CartDisplayRow>[];
    for (var i = 0; i < cart.length; i++) {
      final item = cart[i];
      final breakdown = item.product.breakdownForQuantity(item.quantity);
      if (breakdown.isEmpty) {
        cartRows.add(
          _CartDisplayRow(
            sourceIndex: i,
            item: item,
            part: null,
            allowEdit: true,
          ),
        );
        continue;
      }

      // ถ้าแตกได้แค่ 1 แถวและยังเป็นหน่วยฐานเดิม ให้แสดงแบบรายการปกติ
      if (breakdown.length == 1 &&
          breakdown.first.unit == item.product.unitLabel) {
        cartRows.add(
          _CartDisplayRow(
            sourceIndex: i,
            item: item,
            part: null,
            allowEdit: true,
          ),
        );
        continue;
      }

      for (var j = 0; j < breakdown.length; j++) {
        cartRows.add(
          _CartDisplayRow(
            sourceIndex: i,
            item: item,
            part: breakdown[j],
            allowEdit: true,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'ตะกร้า',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _kHeaderNavy,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onHoldBill,
                icon: const Icon(Icons.pause_circle_outline, size: 18),
                label: const Text('พักบิล'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: _kHeaderNavy,
                ),
              ),
              if (hasHeldBill) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onRecallHeldBill,
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('เรียกบิล'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${cart.length} รายการ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'สแกนบาร์โค้ดเพื่อเพิ่มสินค้า',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ทดลอง: 123 (น้ำดื่ม), 456 (ข้าวสาร)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      physics: const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                    ),
                    child: CustomScrollView(
                      cacheExtent: 400,
                      slivers: [
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final row = cartRows[index];
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (index > 0)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: _kSummaryBorder.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  _CartLineTile(
                                    key: ValueKey(
                                      '${row.item.product.id}_${row.sourceIndex}_${row.part?.unit ?? 'base'}_${row.part?.unitCount ?? row.item.quantity}',
                                    ),
                                    index: row.sourceIndex,
                                    item: row.item,
                                    displayPart: row.part,
                                    allowEdit: row.allowEdit,
                                    onOpenQuantityDialog: () =>
                                        onEditLineQuantity(
                                          row.sourceIndex,
                                          row.item,
                                        ),
                                  ),
                                ],
                              );
                            },
                            childCount: cartRows.length,
                            addAutomaticKeepAlives: false,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _CartListClearFooter(
                            enabled: cart.isNotEmpty,
                            onRequestClearCart: onRequestClearCart,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CartListClearFooter extends StatelessWidget {
  const _CartListClearFooter({
    required this.enabled,
    required this.onRequestClearCart,
    required this.colorScheme,
    required this.theme,
  });

  final bool enabled;
  final Future<void> Function() onRequestClearCart;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: _kSummaryBorder.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 6),
          Tooltip(
            message: 'ล้างตะกร้า (F5 หรือ Ctrl+Shift+L)',
            child: TextButton.icon(
              onPressed: enabled ? () => onRequestClearCart() : null,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              label: Text(
                'ล้างตะกร้า',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          Text(
            'F5 · Ctrl+Shift+L',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartDisplayRow {
  const _CartDisplayRow({
    required this.sourceIndex,
    required this.item,
    required this.part,
    required this.allowEdit,
  });

  final int sourceIndex;
  final CartItem item;
  final ProductUnitBreakdown? part;
  final bool allowEdit;
}

class _CartLineTile extends ConsumerStatefulWidget {
  const _CartLineTile({
    super.key,
    required this.index,
    required this.item,
    this.displayPart,
    this.allowEdit = true,
    required this.onOpenQuantityDialog,
  });

  final int index;
  final CartItem item;
  final ProductUnitBreakdown? displayPart;
  final bool allowEdit;
  final VoidCallback onOpenQuantityDialog;

  @override
  ConsumerState<_CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends ConsumerState<_CartLineTile> {
  late final TextEditingController _qtyController;
  late final FocusNode _qtyFocus;

  int get _displayedUnitQty =>
      widget.displayPart?.unitCount ?? widget.item.quantity;

  int get _stepQty {
    final part = widget.displayPart;
    if (part == null) return 1;
    if (part.unitCount <= 0) return 1;
    final step = part.baseQty ~/ part.unitCount;
    return step <= 0 ? 1 : step;
  }

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '$_displayedUnitQty');
    _qtyFocus = FocusNode();
    _qtyFocus.addListener(_onQtyFocusChange);
  }

  @override
  void dispose() {
    _qtyFocus.removeListener(_onQtyFocusChange);
    _qtyFocus.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onQtyFocusChange() {
    if (!_qtyFocus.hasFocus) {
      _commitQuantity();
    }
  }

  void _commitQuantity() {
    final raw = _qtyController.text.trim();
    final notifier = ref.read(cartProvider.notifier);
    final idx = widget.index;
    final part = widget.displayPart;
    final currentQty = widget.item.quantity;

    if (raw.isEmpty) {
      _qtyController.text = '$_displayedUnitQty';
      return;
    }

    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _qtyController.text = '$_displayedUnitQty';
      return;
    }

    if (parsed <= 0) {
      if (part == null) {
        notifier.removeAt(idx);
      } else {
        final next = currentQty - part.baseQty;
        if (next <= 0) {
          notifier.removeAt(idx);
        } else {
          notifier.setQuantityAt(idx, next);
        }
      }
      return;
    }

    if (part == null) {
      notifier.setQuantityAt(idx, parsed);
    } else {
      final desiredBaseQty = parsed * _stepQty;
      final delta = desiredBaseQty - part.baseQty;
      final next = currentQty + delta;
      if (next <= 0) {
        notifier.removeAt(idx);
      } else {
        notifier.setQuantityAt(idx, next);
      }
    }
    if (mounted) {
      _qtyController.text = '$parsed';
    }
  }

  @override
  void didUpdateWidget(_CartLineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final qtyChanged = oldWidget.item.quantity != widget.item.quantity;
    final productChanged = oldWidget.item.product.id != widget.item.product.id;
    final partChanged =
        oldWidget.displayPart?.unitCount != widget.displayPart?.unitCount ||
        oldWidget.displayPart?.unit != widget.displayPart?.unit ||
        oldWidget.displayPart?.baseQty != widget.displayPart?.baseQty;
    if ((qtyChanged || productChanged) && !_qtyFocus.hasFocus) {
      _qtyController.text = '$_displayedUnitQty';
    } else if (partChanged && !_qtyFocus.hasFocus) {
      _qtyController.text = '$_displayedUnitQty';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final product = widget.item.product;
    final index = widget.index;
    final breakdown = product.breakdownForQuantity(widget.item.quantity);
    final displayPart = widget.displayPart;
    final rowSubtotal = displayPart?.totalPrice ?? widget.item.lineTotal;
    final piecesPerUnit = displayPart != null && displayPart.unitCount > 0
        ? (displayPart.baseQty / displayPart.unitCount).round()
        : 1;
    final partUnitSuffix = displayPart != null && piecesPerUnit > 1
        ? ' ($piecesPerUnit ชิ้น)'
        : '';
    final rowUnitText = displayPart != null
        ? '฿${_kMoneyFmt.format(displayPart.unitPrice)} / ${displayPart.unit}$partUnitSuffix'
        : '฿${_kMoneyFmt.format(product.displayPriceForShownUnit(widget.item.quantity))} / ${product.displayUnitForQuantity(widget.item.quantity)}';
    const thumbSize = 44.0;

    return Material(
      color: colorScheme.surface,
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        minLeadingWidth: thumbSize,
        horizontalTitleGap: 8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onTap: widget.allowEdit && widget.displayPart == null
            ? widget.onOpenQuantityDialog
            : null,
        leading: _ProductThumbnail(product: product, size: thumbSize),
        title: Text(
          displayPart == null
              ? product.name
              : '${product.name} (${displayPart.unitCount} ${displayPart.unit})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: _kHeaderNavy,
          ),
        ),
        subtitle: displayPart != null || breakdown.length <= 1
            ? Text(
                rowUnitText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final part in breakdown)
                    Text(
                      '${part.unitCount} ${part.unit} = ฿${_kMoneyFmt.format(part.totalPrice)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
        trailing: widget.allowEdit
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'ลดจำนวน',
                      onPressed: () {
                        final notifier = ref.read(cartProvider.notifier);
                        if (widget.displayPart == null) {
                          notifier.decrementAt(index);
                          return;
                        }
                        final next = widget.item.quantity - _stepQty;
                        if (next <= 0) {
                          notifier.removeAt(index);
                        } else {
                          notifier.setQuantityAt(index, next);
                        }
                      },
                    ),
                    SizedBox(
                      width: 36,
                      child: TextField(
                        controller: _qtyController,
                        focusNode: _qtyFocus,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        onSubmitted: (_) => _commitQuantity(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'เพิ่มจำนวน',
                      onPressed: () {
                        final notifier = ref.read(cartProvider.notifier);
                        if (widget.displayPart == null) {
                          notifier.incrementAt(index);
                          return;
                        }
                        notifier.setQuantityAt(
                          index,
                          widget.item.quantity + _stepQty,
                        );
                      },
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        '฿${_kMoneyFmt.format(rowSubtotal)}',
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      tooltip: 'ลบรายการนี้',
                      onPressed: () {
                        ref.read(cartProvider.notifier).removeAt(index);
                      },
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: 140,
                child: Text(
                  '฿${_kMoneyFmt.format(rowSubtotal)} ',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.product, this.size = 72});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget placeholder() {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        child: Icon(
          Icons.image_outlined,
          color: theme.colorScheme.outline,
          size: size * 0.42,
        ),
      );
    }

    Widget imageChild;
    final asset = product.imageAsset;
    final url = product.imageUrl;
    if (asset != null) {
      imageChild = Image.asset(
        asset,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    } else if (url != null) {
      imageChild = Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        headers: const {'User-Agent': 'PhongchaiPOS/1.0'},
        errorBuilder: (context, error, stackTrace) => placeholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      imageChild = placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: size, height: size, child: imageChild),
    );
  }
}

class _SummaryPanel extends ConsumerWidget {
  const _SummaryPanel({
    required this.onRefocusBarcode,
    required this.onScanQtySubmitted,
    required this.onOpenTaxInvoiceForm,
    required this.scanQtyController,
    required this.barcodeController,
    required this.barcodeFocus,
    required this.discountController,
    required this.onBarcodeSubmitted,
    required this.onCheckout,
    required this.onDiscountRawChanged,
    this.scrollable = false,
  });

  final VoidCallback onRefocusBarcode;
  final void Function(String) onScanQtySubmitted;
  final VoidCallback onOpenTaxInvoiceForm;
  final TextEditingController scanQtyController;
  final TextEditingController barcodeController;
  final FocusNode barcodeFocus;
  final TextEditingController discountController;
  final void Function(String) onBarcodeSubmitted;
  final VoidCallback onCheckout;
  final void Function(double) onDiscountRawChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtotal = ref.watch(cartSubtotalProvider);
    final discAmount = ref.watch(cartDiscountAmountProvider);
    final vat = ref.watch(cartVatProvider);
    final grand = ref.watch(cartGrandTotalProvider);
    final vatEnabled = ref.watch(cartVatEnabledProvider);
    final member = ref.watch(posMemberProvider);
    final taxBuyer = ref.watch(taxInvoiceBuyerProvider);
    final discountState = ref.watch(cartDiscountProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final children = <Widget>[
      if (member.hasMember)
        Text(
          'ข้อมูลสมาชิก',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: _kHeaderNavy,
          ),
        ),
      if (member.hasMember) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.billMember!.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _kHeaderNavy,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    size: 18,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'แต้มสะสม ${_formatLoyaltyPoints(member.billMember!.loyaltyPoints)} คะแนน',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      if (taxBuyer.hasAnyInput) ...[
        const SizedBox(height: 12),
        _TaxInvoiceInfoCard(
          buyer: taxBuyer,
          onEdit: onOpenTaxInvoiceForm,
        ),
      ],
      const SizedBox(height: 20),
      Text(
        'สรุปยอด',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: _kHeaderNavy,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: TextField(
              controller: scanQtyController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'จำนวน',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: onScanQtySubmitted,
              onEditingComplete: onRefocusBarcode,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: barcodeController,
              focusNode: barcodeFocus,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                labelText: 'สแกนบาร์โค้ด',
                hintText: 'พิมพ์แล้วกด Enter',
                prefixIcon: Container(
                  margin: const EdgeInsets.only(left: 8, right: 4),
                  child: CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 52,
                  minHeight: 48,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2.5,
                  ),
                ),
              ),
              onSubmitted: onBarcodeSubmitted,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z\-]')),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _SummaryRow(label: 'ยอดรวมสินค้า', value: subtotal, muted: false),
      if (discAmount > 0) ...[
        const SizedBox(height: 10),
        _SummaryRow(
          label: discountState.kind == DiscountKind.percent
              ? 'ส่วนลด (${_formatDiscountField(discountState.rawValue.clamp(0, 100))}%)'
              : 'ส่วนลด',
          value: discAmount,
          muted: true,
          asDeduction: true,
        ),
      ],
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: vatEnabled,
            onChanged: (v) {
              if (v != null) {
                ref.read(cartVatEnabledProvider.notifier).setEnabled(v);
                onRefocusBarcode();
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              'ภาษี VAT 7%',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
                '฿${_kMoneyFmt.format(vat)}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        'ประเภทส่วนลด',
        style: theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 6),
      SegmentedButton<DiscountKind>(
        segments: const [
          ButtonSegment(value: DiscountKind.baht, label: Text('บาท')),
          ButtonSegment(value: DiscountKind.percent, label: Text('%')),
        ],
        selected: {discountState.kind},
        onSelectionChanged: (s) {
          ref.read(cartDiscountProvider.notifier).setKind(s.first);
          onRefocusBarcode();
        },
      ),
      const SizedBox(height: 10),
      TextField(
        controller: discountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        decoration: InputDecoration(
          labelText: discountState.kind == DiscountKind.baht
              ? 'จำนวนส่วนลด (บาท)'
              : 'ส่วนลด (%)',
          prefixText: discountState.kind == DiscountKind.baht ? '฿ ' : null,
          suffixText: discountState.kind == DiscountKind.percent ? '%' : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (s) {
          final v = double.tryParse(s.trim()) ?? 0;
          onDiscountRawChanged(v);
        },
        onEditingComplete: onRefocusBarcode,
      ),
      const SizedBox(height: 20),
      Divider(height: 1, color: _kSummaryBorder),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'ยอดรวมสุทธิ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _kHeaderNavy,
              ),
            ),
          ),
          Text(
            '฿${_kMoneyFmt.format(grand)}',
            style: (theme.textTheme.displaySmall ?? theme.textTheme.headlineMedium)
                ?.copyWith(
                  // ใหญ่ขึ้น 1 เท่า (2x จากขนาดเดิม)
                  fontSize:
                      ((theme.textTheme.displaySmall?.fontSize ?? 36) * 2),
                  fontWeight: FontWeight.w800,
                  color: _kNetTotalColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
          ),
        ],
      ),
      if (!scrollable) const Spacer(),
      if (scrollable) const SizedBox(height: 24),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 60,
        child: FilledButton(
          onPressed: onCheckout,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 60),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('ชำระเงิน'),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'ชำระเงิน (F12 หรือ Ctrl+Shift+P)',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    ];

    final content = Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        children: children,
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(child: content);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFCFE),
        border: Border(left: BorderSide(color: _kSummaryBorder)),
      ),
      child: content,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.muted,
    this.asDeduction = false,
  });

  final String label;
  final double value;
  final bool muted;
  final bool asDeduction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = asDeduction
        ? '-฿${_kMoneyFmt.format(value)}'
        : '฿${_kMoneyFmt.format(value)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: muted
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
        Text(
          valueText,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: asDeduction
                ? theme.colorScheme.error
                : (muted
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

class _TaxInvoiceInfoCard extends StatelessWidget {
  const _TaxInvoiceInfoCard({
    required this.buyer,
    required this.onEdit,
  });

  final TaxInvoiceBuyerInfo buyer;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchText = buyer.isHeadOffice
        ? 'สำนักงานใหญ่'
        : 'สาขา ${buyer.branchCode.trim().isEmpty ? '—' : buyer.branchCode.trim()}';
    final company = buyer.companyOrName.trim();
    final taxId = buyer.taxId.trim();
    final phone = buyer.phone.trim();
    final address = buyer.address.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: Color(0xFF92400E),
              ),
              const SizedBox(width: 6),
              Text(
                'ข้อมูลกำกับภาษี',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF92400E),
                ),
                child: const Text('แก้ไข'),
              ),
            ],
          ),
          if (company.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              company,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (taxId.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Tax ID: ${TaxInvoiceBuyerInfo.formatTaxIdDisplay(taxId)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'โทร: $phone',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 2),
          Text(
            branchText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              address,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
