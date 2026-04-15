import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:phongchai_pos/features/pos/domain/sale_record.dart';

const _kSalesHistoryKey = 'phongchai_sales_history_v1';

/// เก็บรายการขายในเครื่อง (SharedPreferences) — ไม่รวมข้อมูลฟอร์มใบกำกับที่กรอกย้อนหลัง
class SalesHistoryRepository {
  SalesHistoryRepository._();
  static final SalesHistoryRepository instance = SalesHistoryRepository._();

  Future<List<SaleRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSalesHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SaleRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> append(SaleRecord sale) async {
    final all = await loadAll();
    all.add(sale);
    await _saveAll(all);
  }

  /// ทำเครื่องหมายว่าบิลถูก void (ตามเลขที่ใบกำกับ)
  Future<bool> voidSaleByInvoiceNo({
    required String invoiceNo,
    required String reason,
    required DateTime voidedAt,
  }) async {
    final all = await loadAll();
    final idx = all.indexWhere(
      (s) => s.invoiceNo == invoiceNo && !s.isVoided,
    );
    if (idx < 0) return false;
    all[idx] = all[idx].copyWith(
      isVoided: true,
      voidReason: reason,
      voidedAt: voidedAt,
    );
    await _saveAll(all);
    return true;
  }

  Future<void> _saveAll(List<SaleRecord> sales) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(sales.map((e) => e.toJson()).toList());
    await prefs.setString(_kSalesHistoryKey, encoded);
  }
}
