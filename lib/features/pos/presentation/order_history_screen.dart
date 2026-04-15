import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phongchai_pos/core/utils/pdf_generator.dart';
import 'package:phongchai_pos/core/utils/tax_invoice_print.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';
import 'package:phongchai_pos/features/pos/domain/sale_record.dart';
import 'package:phongchai_pos/features/pos/domain/tax_invoice_buyer_info.dart';
import 'package:phongchai_pos/features/pos/presentation/checkout_dialog.dart';
import 'package:phongchai_pos/features/pos/presentation/tax_invoice_form_dialog.dart';
import 'package:phongchai_pos/features/pos/providers/sales_history_provider.dart';

DateTime _startOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day);

DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

bool _saleInRange(SaleRecord s, DateTime from, DateTime to) {
  final t = s.soldAt;
  return !t.isBefore(_startOfDay(from)) && !t.isAfter(_endOfDay(to));
}

bool _saleMatchesSearch(SaleRecord s, String rawQuery) {
  final q = rawQuery.trim();
  if (q.isEmpty) return true;
  final lower = q.toLowerCase();
  if (s.invoiceNo.toLowerCase().contains(lower)) return true;

  final queryDigits = q.replaceAll(RegExp(r'\D'), '');
  if (queryDigits.isEmpty) {
    return s.memberName?.toLowerCase().contains(lower) == true ||
        s.taxInvoiceBuyer?.companyOrName.toLowerCase().contains(lower) ==
            true;
  }

  bool phoneContains(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final d = phone.replaceAll(RegExp(r'\D'), '');
    return d.contains(queryDigits) || phone.contains(q);
  }

  if (phoneContains(s.memberPhone)) return true;
  if (phoneContains(s.taxInvoiceBuyer?.phone)) return true;

  return s.memberName?.toLowerCase().contains(lower) == true ||
      s.taxInvoiceBuyer?.companyOrName.toLowerCase().contains(lower) == true;
}

/// ประวัติการขาย + ออกใบกำกับภาษีย้อนหลัง
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() =>
      _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  final _searchController = TextEditingController();

  SaleRecord? _selectedSale;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = _startOfDay(now.subtract(const Duration(days: 7)));
    _rangeEnd = _endOfDay(now);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSaleDrawer(SaleRecord sale) {
    setState(() => _selectedSale = sale);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );
    if (picked == null) return;
    setState(() {
      _rangeStart = _startOfDay(picked.start);
      _rangeEnd = _endOfDay(picked.end);
    });
  }

  Future<void> _issueBackdatedInvoice(SaleRecord sale) async {
    final buyer = await showTaxInvoiceFormDialogEphemeral(
      context,
      initial: sale.taxInvoiceBuyer?.hasAnyInput == true
          ? sale.taxInvoiceBuyer
          : null,
    );
    if (!mounted) return;
    if (buyer == null) return;

    final invoiceData = TaxInvoiceData(
      issuedAt: sale.soldAt,
      invoiceNo: sale.invoiceNo,
      lines: sale.lines,
      customerName: sale.memberName,
      customerPhone: sale.memberPhone,
      buyerInvoice: buyer.hasAnyInput ? buyer : null,
      subtotal: sale.subtotal,
      discountAmount: sale.discountAmount,
      netBeforeVat: sale.netBeforeVat,
      vatAmount: sale.vatAmount,
      vatEnabled: sale.vatEnabled,
      grandTotal: sale.grandTotal,
      method: sale.method,
      cashAmount: sale.cashAmount,
      transferAmount: sale.transferAmount,
      cashReceived: sale.cashReceived,
      change: sale.change,
      isBackdated: true,
    );

    await printTaxInvoiceWithFallback(context: context, data: invoiceData);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(salesHistoryProvider);
    final moneyFmt = NumberFormat('#,##0.00', 'en_US');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final dateShort = DateFormat('dd/MM/yyyy');

    return Scaffold(
      key: _scaffoldKey,
      onEndDrawerChanged: (isOpened) {
        if (!isOpened) {
          setState(() => _selectedSale = null);
        }
      },
      endDrawer: _selectedSale == null
          ? null
          : _SaleDetailDrawer(
              sale: _selectedSale!,
              moneyFmt: moneyFmt,
              dateFmt: dateFmt,
              onIssueInvoice: () {
                final s = _selectedSale!;
                Navigator.of(context).pop();
                _issueBackdatedInvoice(s);
              },
            ),
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('ประวัติการขาย'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'โหลดใหม่',
            onPressed: () =>
                ref.read(salesHistoryProvider.notifier).reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ค้นหา',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'เลขที่บิล (INV) หรือเบอร์โทรลูกค้า',
                            prefixIcon: const Icon(Icons.search_rounded, size: 22),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    tooltip: 'ล้าง',
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(64),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_rounded, size: 20),
                        label: const Text('ช่วงวันที่'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ช่วง: ${dateShort.format(_rangeStart)} — ${dateShort.format(_rangeEnd)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              data: (all) {
                final inRange = all
                    .where((s) => _saleInRange(s, _rangeStart, _rangeEnd))
                    .where((s) => _saleMatchesSearch(s, _searchController.text))
                    .toList()
                  ..sort((a, b) => b.soldAt.compareTo(a.soldAt));

                if (inRange.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.trim().isEmpty
                                ? 'ไม่มีรายการในช่วงที่เลือก'
                                : 'ไม่พบรายการที่ตรงกับการค้นหา',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final totalInRange = inRange.fold<double>(
                  0,
                  (sum, s) => sum + s.grandTotal,
                );

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: inRange.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final sale = inRange[i];
                          return _SaleHistoryCard(
                            sale: sale,
                            moneyFmt: moneyFmt,
                            dateFmt: dateFmt,
                            onTap: () => _openSaleDrawer(sale),
                          );
                        },
                      ),
                    ),
                    _BottomSalesSummary(total: totalInRange, moneyFmt: moneyFmt),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('โหลดไม่สำเร็จ: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSalesSummary extends StatelessWidget {
  const _BottomSalesSummary({
    required this.total,
    required this.moneyFmt,
  });

  final double total;
  final NumberFormat moneyFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.summarize_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'รวมยอดขายในช่วงวันที่เลือก (ตามตัวกรอง)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '฿${moneyFmt.format(total)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleHistoryCard extends StatelessWidget {
  const _SaleHistoryCard({
    required this.sale,
    required this.moneyFmt,
    required this.dateFmt,
    required this.onTap,
  });

  final SaleRecord sale;
  final NumberFormat moneyFmt;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTax = sale.taxInvoiceBuyer?.hasAnyInput == true;
    final itemCount = sale.lines.length;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasTax
              ? const Color(0xFF81C784).withValues(alpha: 0.65)
              : const Color(0xFFE8E8E8),
          width: hasTax ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasTax)
                Container(
                  width: 5,
                  color: const Color(0xFF66BB6A),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              sale.invoiceNo,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFmt.format(sale.soldAt.toLocal()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PaymentMethodBadge(method: sale.method),
                          _ItemCountBadge(count: itemCount),
                          if (hasTax)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              label: const Text('มีข้อมูล VAT'),
                              avatar: Icon(
                                Icons.verified_outlined,
                                size: 16,
                                color: theme.colorScheme.tertiary,
                              ),
                              backgroundColor: theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.5),
                              side: BorderSide.none,
                              labelStyle: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (sale.memberName != null &&
                          sale.memberName!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'สมาชิก: ${sale.memberName}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '฿${moneyFmt.format(sale.grandTotal)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'แตะเพื่อดูรายการสินค้า',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCountBadge extends StatelessWidget {
  const _ItemCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '$count รายการ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drawer รายละเอียดบิล + รายการสินค้า + ปุ่มออกใบกำกับ
class _SaleDetailDrawer extends StatelessWidget {
  const _SaleDetailDrawer({
    required this.sale,
    required this.moneyFmt,
    required this.dateFmt,
    required this.onIssueInvoice,
  });

  final SaleRecord sale;
  final NumberFormat moneyFmt;
  final DateFormat dateFmt;
  final VoidCallback onIssueInvoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final drawerWidth = w < 500 ? w * 0.92 : 400.0;
    final hasTax = sale.taxInvoiceBuyer?.hasAnyInput == true;

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'ปิด',
                  ),
                  Expanded(
                    child: Text(
                      'รายละเอียดบิล',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.invoiceNo,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFmt.format(sale.soldAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PaymentMethodBadge(method: sale.method),
                      _ItemCountBadge(count: sale.lines.length),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (hasTax)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TaxBuyerHistorySummary(
                        buyer: sale.taxInvoiceBuyer!,
                      ),
                    ),
                  Text(
                    'รายการสินค้า',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...sale.lines.map(
                    (CartItem line) => _LineItemRow(
                      line: line,
                      moneyFmt: moneyFmt,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ยอดรวม',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '฿${moneyFmt.format(sale.grandTotal)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton.icon(
                onPressed: onIssueInvoice,
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text(
                  'ออกใบกำกับภาษีเต็มรูปแบบ',
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodBadge extends StatelessWidget {
  const _PaymentMethodBadge({required this.method});

  final PosPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (method) {
      PosPaymentMethod.cash => (
          const Color(0xFFE8F5E9),
          const Color(0xFF1B5E20),
          'เงินสด',
          Icons.payments_outlined,
        ),
      PosPaymentMethod.transfer => (
          const Color(0xFFE3F2FD),
          const Color(0xFF0D47A1),
          'โอนเงิน',
          Icons.account_balance_outlined,
        ),
      PosPaymentMethod.mixed => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          'สด+โอน',
          Icons.call_split,
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    required this.line,
    required this.moneyFmt,
  });

  final CartItem line;
  final NumberFormat moneyFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = line.product;
    final unit = p.displayUnitForQuantity(line.quantity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              p.name,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${line.quantity} $unit',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '฿${moneyFmt.format(line.lineTotal)}',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ข้อมูลผู้เสียภาษี — แถบสีอ่อนให้สังเกตว่าบิลนี้มีข้อมูล VAT
class _TaxBuyerHistorySummary extends StatelessWidget {
  const _TaxBuyerHistorySummary({required this.buyer});

  final TaxInvoiceBuyerInfo buyer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tax = buyer.taxId.trim();
    final taxDisplay = tax.length == 13
        ? TaxInvoiceBuyerInfo.formatTaxIdDisplay(tax)
        : tax;

    return Material(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFA5D6A7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ข้อมูลผู้เสียภาษี (ออกใบกำกับ / VAT)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'บิลนี้มีข้อมูลสำหรับใบกำกับภาษีตอนขายแล้ว',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF33691E),
                ),
              ),
              if (buyer.companyOrName.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  buyer.companyOrName.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (tax.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'เลขประจำตัวผู้เสียภาษี: $taxDisplay',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (buyer.phone.trim().isNotEmpty)
                Text('โทร: ${buyer.phone}', style: theme.textTheme.bodySmall),
              if (buyer.address.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  buyer.address.trim(),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (!buyer.isHeadOffice && buyer.branchCode.trim().isNotEmpty)
                Text(
                  'สาขา: ${buyer.branchCode}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
