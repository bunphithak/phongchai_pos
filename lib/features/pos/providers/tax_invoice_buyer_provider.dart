import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/features/pos/domain/tax_invoice_buyer_info.dart';

/// State ข้อมูลใบกำกับภาษีของบิลปัจจุบัน (ก่อนส่งออก PDF)
final taxInvoiceBuyerProvider =
    NotifierProvider<TaxInvoiceBuyerNotifier, TaxInvoiceBuyerInfo>(
  TaxInvoiceBuyerNotifier.new,
);

class TaxInvoiceBuyerNotifier extends Notifier<TaxInvoiceBuyerInfo> {
  @override
  TaxInvoiceBuyerInfo build() => const TaxInvoiceBuyerInfo();

  void setFromForm(TaxInvoiceBuyerInfo value) {
    state = value;
  }

  void clear() {
    state = const TaxInvoiceBuyerInfo();
  }
}
