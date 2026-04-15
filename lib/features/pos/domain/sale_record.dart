import 'package:phongchai_pos/data/models/product.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';
import 'package:phongchai_pos/features/pos/domain/tax_invoice_buyer_info.dart';
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
    this.cashAmount = 0,
    this.transferAmount = 0,
    this.cashReceived,
    required this.change,
    this.memberName,
    this.memberPhone,
    this.taxInvoiceBuyer,
    this.pointsRedeemed = 0,
    this.pointsDiscountAmount = 0,
    this.isVoided = false,
    this.voidReason,
    this.voidedAt,
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

  /// ยอดแบ่งจ่ายเงินสด (ส่ง backend / รายงาน)
  final double cashAmount;

  /// ยอดแบ่งจ่ายโอน
  final double transferAmount;

  final double? cashReceived;
  final double change;

  /// สแนปช็อตจากบิลเท่านั้น — ไม่ใช่ฐานข้อมูลลูกค้าถาวร
  final String? memberName;
  final String? memberPhone;

  /// สแนปช็อตข้อมูลผู้เสียภาษีตอนชำระ (ถ้ากรอกไว้) — ใช้ดูย้อนหลัง / ออกใบกำกับซ้ำ
  final TaxInvoiceBuyerInfo? taxInvoiceBuyer;

  /// แต้มที่แลกในบิลนี้ (ส่ง backend)
  final int pointsRedeemed;

  /// ส่วนลดจากแต้ม (บาท)
  final double pointsDiscountAmount;

  /// บิลถูกยกเลิก (void) หลังชำระแล้ว
  final bool isVoided;

  final String? voidReason;
  final DateTime? voidedAt;

  SaleRecord copyWith({
    bool? isVoided,
    String? voidReason,
    DateTime? voidedAt,
  }) {
    return SaleRecord(
      id: id,
      soldAt: soldAt,
      invoiceNo: invoiceNo,
      lines: lines,
      subtotal: subtotal,
      discountAmount: discountAmount,
      netBeforeVat: netBeforeVat,
      vatAmount: vatAmount,
      vatEnabled: vatEnabled,
      grandTotal: grandTotal,
      method: method,
      cashAmount: cashAmount,
      transferAmount: transferAmount,
      cashReceived: cashReceived,
      change: change,
      memberName: memberName,
      memberPhone: memberPhone,
      taxInvoiceBuyer: taxInvoiceBuyer,
      pointsRedeemed: pointsRedeemed,
      pointsDiscountAmount: pointsDiscountAmount,
      isVoided: isVoided ?? this.isVoided,
      voidReason: voidReason ?? this.voidReason,
      voidedAt: voidedAt ?? this.voidedAt,
    );
  }

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
        'cash_amount': cashAmount,
        'transfer_amount': transferAmount,
        'cash_received': cashReceived,
        'change': change,
        'member_name': memberName,
        'member_phone': memberPhone,
        if (taxInvoiceBuyer != null)
          'tax_invoice_buyer': taxInvoiceBuyer!.toJson(),
        'points_redeemed': pointsRedeemed,
        'points_discount_amount': pointsDiscountAmount,
        'is_voided': isVoided,
        if (voidReason != null) 'void_reason': voidReason,
        if (voidedAt != null) 'voided_at': voidedAt!.toIso8601String(),
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
      cashAmount: _inferCashAmount(json),
      transferAmount: _inferTransferAmount(json),
      cashReceived: json['cash_received'] != null
          ? (json['cash_received'] as num).toDouble()
          : null,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      memberName: json['member_name'] as String?,
      memberPhone: json['member_phone'] as String?,
      taxInvoiceBuyer: json['tax_invoice_buyer'] != null
          ? TaxInvoiceBuyerInfo.fromJson(
              json['tax_invoice_buyer'] as Map<String, dynamic>,
            )
          : null,
      pointsRedeemed: (json['points_redeemed'] as num?)?.toInt() ?? 0,
      pointsDiscountAmount:
          (json['points_discount_amount'] as num?)?.toDouble() ?? 0,
      isVoided: json['is_voided'] as bool? ?? false,
      voidReason: json['void_reason'] as String?,
      voidedAt: json['voided_at'] != null
          ? DateTime.parse(json['voided_at'] as String)
          : null,
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

  static double _inferCashAmount(Map<String, dynamic> json) {
    if (json['cash_amount'] != null) {
      return (json['cash_amount'] as num).toDouble();
    }
    final method = _parsePosPaymentMethod(json['method'] as String?);
    final grand = (json['grand_total'] as num).toDouble();
    if (method == PosPaymentMethod.transfer) return 0;
    if (json['cash_received'] != null) {
      return (json['cash_received'] as num).toDouble();
    }
    return grand;
  }

  static double _inferTransferAmount(Map<String, dynamic> json) {
    if (json['transfer_amount'] != null) {
      return (json['transfer_amount'] as num).toDouble();
    }
    final method = _parsePosPaymentMethod(json['method'] as String?);
    final grand = (json['grand_total'] as num).toDouble();
    if (method == PosPaymentMethod.transfer) return grand;
    return 0;
  }
}
