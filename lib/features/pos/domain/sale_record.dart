import 'package:phongchai_pos/data/models/product.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';
import 'package:phongchai_pos/features/pos/presentation/checkout_dialog.dart';

/// บันทึกการขายหนึ่งครั้ง (เก็บในเครื่อง — ใช้ประวัติ / ออกใบกำกับย้อนหลัง)
class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.soldAt,
    required this.invoiceNo,
    required this.lines,
    required this.subtotal,
    required this.discountAmount,
    required this.netBeforeVat,
    required this.vatAmount,
    required this.vatEnabled,
    required this.grandTotal,
    required this.method,
    this.cashReceived,
    required this.change,
    this.memberName,
    this.memberPhone,
  });

  final String id;
  final DateTime soldAt;
  final String invoiceNo;
  final List<CartItem> lines;

  final double subtotal;
  final double discountAmount;
  final double netBeforeVat;
  final double vatAmount;
  final bool vatEnabled;
  final double grandTotal;

  final PosPaymentMethod method;
  final double? cashReceived;
  final double change;

  /// สแนปช็อตจากบิลเท่านั้น — ไม่ใช่ฐานข้อมูลลูกค้าถาวร
  final String? memberName;
  final String? memberPhone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sold_at': soldAt.toIso8601String(),
        'invoice_no': invoiceNo,
        'lines': lines.map((e) => _lineToJson(e)).toList(),
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'net_before_vat': netBeforeVat,
        'vat_amount': vatAmount,
        'vat_enabled': vatEnabled,
        'grand_total': grandTotal,
        'method': method.name,
        'cash_received': cashReceived,
        'change': change,
        'member_name': memberName,
        'member_phone': memberPhone,
      };

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    return SaleRecord(
      id: json['id'] as String,
      soldAt: DateTime.parse(json['sold_at'] as String),
      invoiceNo: json['invoice_no'] as String,
      lines: (json['lines'] as List<dynamic>)
          .map((e) => _lineFromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num).toDouble(),
      netBeforeVat: (json['net_before_vat'] as num).toDouble(),
      vatAmount: (json['vat_amount'] as num).toDouble(),
      vatEnabled: json['vat_enabled'] as bool,
      grandTotal: (json['grand_total'] as num).toDouble(),
      method: _parsePosPaymentMethod(json['method'] as String?),
      cashReceived: json['cash_received'] != null
          ? (json['cash_received'] as num).toDouble()
          : null,
      change: (json['change'] as num).toDouble(),
      memberName: json['member_name'] as String?,
      memberPhone: json['member_phone'] as String?,
    );
  }

  static Map<String, dynamic> _lineToJson(CartItem line) => {
        'product': line.product.toJson(),
        'quantity': line.quantity,
      };

  static CartItem _lineFromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
    );
  }

  static PosPaymentMethod _parsePosPaymentMethod(String? raw) {
    if (raw == null) return PosPaymentMethod.cash;
    for (final v in PosPaymentMethod.values) {
      if (v.name == raw) return v;
    }
    return PosPaymentMethod.cash;
  }
}
