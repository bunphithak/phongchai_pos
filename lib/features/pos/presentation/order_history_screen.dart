import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phongchai_pos/core/utils/pdf_generator.dart';
import 'package:phongchai_pos/core/utils/tax_invoice_print.dart';
import 'package:phongchai_pos/features/pos/domain/sale_record.dart';
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

/// ประวัติการขาย + ออกใบกำกับภาษีย้อนหลัง (ข้อมูลฟอร์มใช้เฉพาะ PDF)
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() =>
      _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = _startOfDay(now.subtract(const Duration(days: 7)));
    _rangeEnd = _endOfDay(now);
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
    final buyer = await showTaxInvoiceFormDialogEphemeral(context);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการขาย'),
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
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ช่วงวันที่: ${DateFormat('dd/MM/yyyy').format(_rangeStart)} — ${DateFormat('dd/MM/yyyy').format(_rangeEnd)}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded, size: 20),
                    label: const Text('เลือกช่วงวันที่'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              data: (all) {
                final filtered = all
                    .where((s) => _saleInRange(s, _rangeStart, _rangeEnd))
                    .toList()
                  ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'ไม่มีรายการในช่วงที่เลือก',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final sale = filtered[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sale.invoiceNo,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateFmt.format(sale.soldAt.toLocal()),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (sale.memberName != null &&
                                          sale.memberName!.trim().isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'สมาชิก: ${sale.memberName}',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                    ],
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
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _issueBackdatedInvoice(sale),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: const Text(
                                  'ออกใบกำกับภาษีเต็มรูปแบบ',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
