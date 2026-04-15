import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phongchai_pos/features/pos/data/sales_history_repository.dart';
import 'package:phongchai_pos/features/pos/domain/sale_record.dart';
import 'package:phongchai_pos/features/pos/providers/pos_sync_provider.dart';

final salesHistoryProvider =
    AsyncNotifierProvider<SalesHistoryNotifier, List<SaleRecord>>(
  SalesHistoryNotifier.new,
);

class SalesHistoryNotifier extends AsyncNotifier<List<SaleRecord>> {
  @override
  Future<List<SaleRecord>> build() async {
    return SalesHistoryRepository.instance.loadAll();
  }

  Future<void> recordSale(SaleRecord sale) async {
    await SalesHistoryRepository.instance.append(sale);
    final next = await SalesHistoryRepository.instance.loadAll();
    state = AsyncData(next);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await SalesHistoryRepository.instance.loadAll());
  }

  /// ยกเลิกบิล (void) — อัปเดต SQLite + mock + ประวัติในเครื่อง
  Future<bool> voidSale({
    required SaleRecord sale,
    required String reason,
    required String voidedByLabel,
  }) async {
    if (sale.isVoided) return false;
    final voidedAt = DateTime.now();
    final sync = ref.read(posSyncServiceProvider);
    await sync.voidRecordedSale(
      sale: sale,
      reason: reason,
      voidedByLabel: voidedByLabel,
    );
    final ok = await SalesHistoryRepository.instance.voidSaleByInvoiceNo(
      invoiceNo: sale.invoiceNo,
      reason: reason,
      voidedAt: voidedAt,
    );
    if (ok) {
      state = AsyncData(await SalesHistoryRepository.instance.loadAll());
    }
    return ok;
  }
}
