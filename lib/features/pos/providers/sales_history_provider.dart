import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phongchai_pos/features/pos/data/sales_history_repository.dart';
import 'package:phongchai_pos/features/pos/domain/sale_record.dart';

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
}
