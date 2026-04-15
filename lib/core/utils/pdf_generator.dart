import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:phongchai_pos/core/config/seller_profile.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';
import 'package:phongchai_pos/features/pos/domain/tax_invoice_buyer_info.dart';
import 'package:phongchai_pos/features/pos/presentation/checkout_dialog.dart';
import 'package:printing/printing.dart';

import 'thai_baht_words.dart';

/// บรรทัดสรุปการชำระ (ใบกำกับ + ใบเสร็จความร้อน)
String taxInvoicePaymentLine(TaxInvoiceData data, NumberFormat moneyFmt) {
  final methodLabel = switch (data.method) {
    PosPaymentMethod.cash => 'เงินสด',
    PosPaymentMethod.transfer => 'โอนเงิน',
    PosPaymentMethod.mixed => 'เงินสด + โอนเงิน',
  };
  final parts = <String>['การชำระเงิน: $methodLabel'];
  if (data.method == PosPaymentMethod.mixed) {
    if (data.cashAmount > 1e-9) {
      parts.add('เงินสด ${moneyFmt.format(data.cashAmount)}');
    }
    if (data.transferAmount > 1e-9) {
      parts.add('โอน ${moneyFmt.format(data.transferAmount)}');
    }
  } else if (data.method == PosPaymentMethod.cash) {
    if (data.cashAmount > 1e-9) {
      parts.add('รับเงิน ${moneyFmt.format(data.cashAmount)}');
    }
  } else {
    if (data.transferAmount > 1e-9) {
      parts.add('ยอดโอน ${moneyFmt.format(data.transferAmount)}');
    }
  }
  if (data.change > 1e-9) {
    parts.add('เงินทอน ${moneyFmt.format(data.change)}');
  }
  return parts.join(' | ');
}

/// ข้อมูลสำหรับออกใบกำกับภาษี (เก็บก่อนล้างตะกร้า)
class TaxInvoiceData {
  const TaxInvoiceData({
    required this.issuedAt,
    required this.invoiceNo,
    required this.lines,
    this.customerName,
    this.customerPhone,
    this.buyerInvoice,
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
    this.isBackdated = false,
  });

  final DateTime issuedAt;
  final String invoiceNo;
  final List<CartItem> lines;
  final String? customerName;
  final String? customerPhone;

  /// ข้อมูลผู้ซื้อจากฟอร์มใบกำกับภาษี (ถ้ากรอกไว้)
  final TaxInvoiceBuyerInfo? buyerInvoice;

  final double subtotal;
  final double discountAmount;
  final double netBeforeVat;
  final double vatAmount;
  final bool vatEnabled;
  final double grandTotal;

  final PosPaymentMethod method;

  /// ยอดแบ่งจ่ายเงินสด (รายงาน / แยกประเภท)
  final double cashAmount;

  /// ยอดแบ่งจ่ายโอน
  final double transferAmount;

  final double? cashReceived;
  final double change;

  /// ใบกำกับที่ออกย้อนหลังจากประวัติการขาย
  final bool isBackdated;
}

SellerProfile _seller() => MockDataStore.instance.sellerProfile;

Future<Uint8List> buildTaxInvoicePdf(TaxInvoiceData data) async {
  // ปิดโหมดวาดเส้น debug ของแพ็กเกจ pdf (ถ้าเคยเปิดจาก preview จะไม่ติดไปในไฟล์)
  pw.Document.debug = false;

  final font = await PdfGoogleFonts.sarabunRegular();
  final fontBold = await PdfGoogleFonts.sarabunBold();

  pw.TextStyle t({double size = 10.5, bool bold = false, PdfColor? color}) {
    return pw.TextStyle(
      font: bold ? fontBold : font,
      fontSize: size,
      color: color ?? PdfColors.black,
    );
  }

  final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(data.issuedAt);
  final moneyFmt = NumberFormat('#,##0.00', 'en_US');

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                _seller().companyNameTh,
                style: t(size: 16, bold: true),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _seller().companyNameEn,
                style: t(size: 10),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'เลขประจำตัวผู้เสียภาษี ${_seller().taxId}',
                style: t(bold: true),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _seller().addressTh,
                style: t(size: 9.5),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${_seller().tel}  |  ${_seller().email}',
                style: t(size: 9.5),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'ใบกำกับภาษี / ใบเสร็จรับเงิน',
                style: t(size: 14, bold: true),
              ),
              pw.Text(
                'TAX INVOICE / RECEIPT',
                style: t(size: 11, bold: true),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('เลขที่: ${data.invoiceNo}', style: t(bold: true)),
                  pw.Text('วันที่: $dateStr', style: t()),
                  if (data.isBackdated)
                    pw.Text(
                      '(ออกใบกำกับภาษีย้อนหลัง — วันที่ตามรายการขายเดิม)',
                      style: t(size: 8.5, color: PdfColors.grey700),
                    ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: _taxInvoiceBuyerBlock(data, t),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.1),
            1: const pw.FlexColumnWidth(4.2),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.6),
            4: const pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              children: [
                _cell('ลำดับ', t(bold: true), center: true),
                _cell('รายการ', t(bold: true)),
                _cell('จำนวน', t(bold: true), center: true),
                _cell('ราคา/หน่วย', t(bold: true), right: true),
                _cell('จำนวนเงิน', t(bold: true), right: true),
              ],
            ),
            ...List.generate(data.lines.length, (i) {
              final line = data.lines[i];
              final p = line.product;
              return pw.TableRow(
                children: [
                  _cell('${i + 1}', t(), center: true),
                  _cell(p.name, t()),
                  _cell('${line.quantity}', t(), center: true),
                  _cell(
                    moneyFmt.format(p.unitPriceForQuantity(line.quantity)),
                    t(),
                    right: true,
                  ),
                  _cell(moneyFmt.format(line.lineTotal), t(), right: true),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 260,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _sumRow('รวมมูลค่าสินค้า', moneyFmt.format(data.subtotal), t),
                if (data.discountAmount > 0)
                  _sumRow('หักส่วนลด', '-${moneyFmt.format(data.discountAmount)}', t),
                _sumRow(
                  data.vatEnabled
                      ? 'มูลค่าสินค้า (หลังหักส่วนลด) — ฐานภาษี'
                      : 'มูลค่าสินค้า (หลังหักส่วนลด)',
                  moneyFmt.format(data.netBeforeVat),
                  t,
                ),
                if (data.vatEnabled)
                  _sumRow(
                    'ภาษีมูลค่าเพิ่ม 7%',
                    moneyFmt.format(data.vatAmount),
                    t,
                  ),
                pw.Divider(thickness: 1, color: PdfColors.black),
                _sumRow(
                  'จำนวนเงินรวมทั้งสิ้น',
                  moneyFmt.format(data.grandTotal),
                  t,
                  boldValue: true,
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '(จำนวนเงินเป็นตัวอักษร)',
                style: t(size: 9.5, bold: true),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                thaiBahtWords(data.grandTotal),
                style: t(size: 11, bold: true),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          taxInvoicePaymentLine(data, moneyFmt),
          style: t(),
        ),
        pw.SizedBox(height: 28),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ได้รับสินค้า / บริการครบถ้วนแล้ว', style: t(size: 9)),
                pw.SizedBox(height: 36),
                pw.Container(width: 160, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text('ผู้รับสินค้า / ลูกค้า', style: t(size: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ในนาม ${_seller().companyNameTh}', style: t(size: 9)),
                pw.SizedBox(height: 36),
                pw.Container(width: 160, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text('ผู้ออกใบกำกับภาษี / Authorized signature', style: t(size: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'เอกสารนี้ออกด้วยระบบอิเล็กทรอนิกส์ — ใช้เป็นหลักฐานทางภาษีได้ตามประกาศกรมสรรพากร',
            style: t(size: 8, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _taxInvoiceBuyerBlock(
  TaxInvoiceData data,
  pw.TextStyle Function({double size, bool bold, PdfColor? color}) t,
) {
  final b = data.buyerInvoice;
  if (b != null && b.hasAnyInput) {
    final name = b.companyOrName.trim().isNotEmpty
        ? b.companyOrName.trim()
        : (data.customerName?.trim().isNotEmpty == true
            ? data.customerName!.trim()
            : 'ลูกค้าทั่วไป / Walk-in');
    final children = <pw.Widget>[
      pw.Text('ลูกค้า / Customer', style: t(bold: true)),
      pw.SizedBox(height: 4),
      pw.Text(name, style: t()),
    ];
    if (b.taxId.length == 13) {
      children.add(pw.SizedBox(height: 2));
      children.add(
        pw.Text(
          'เลขประจำตัวผู้เสียภาษี ${TaxInvoiceBuyerInfo.formatTaxIdDisplay(b.taxId)}',
          style: t(size: 9.5),
        ),
      );
    }
    for (final line in b.address.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      children.add(pw.SizedBox(height: 2));
      children.add(pw.Text(trimmed, style: t(size: 9.5)));
    }
    children.add(pw.SizedBox(height: 2));
    children.add(
      pw.Text(
        b.isHeadOffice ? 'สำนักงานใหญ่' : 'สาขาเลขที่ ${b.branchCode}',
        style: t(size: 9.5),
      ),
    );
    final phone = b.phone.trim().isNotEmpty
        ? b.phone.trim()
        : (data.customerPhone?.trim() ?? '');
    if (phone.isNotEmpty) {
      children.add(pw.SizedBox(height: 2));
      children.add(pw.Text('โทร: $phone', style: t(size: 9.5)));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('ลูกค้า / Customer', style: t(bold: true)),
      pw.SizedBox(height: 4),
      pw.Text(
        data.customerName?.trim().isNotEmpty == true
            ? data.customerName!.trim()
            : 'ลูกค้าทั่วไป / Walk-in',
        style: t(),
      ),
      if (data.customerPhone != null && data.customerPhone!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text('โทร: ${data.customerPhone}', style: t(size: 9.5)),
      ],
    ],
  );
}

pw.Widget _cell(
  String text,
  pw.TextStyle style, {
  bool center = false,
  bool right = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(
      text,
      style: style,
      textAlign: center
          ? pw.TextAlign.center
          : right
              ? pw.TextAlign.right
              : pw.TextAlign.left,
    ),
  );
}

pw.Widget _sumRow(
  String label,
  String value,
  pw.TextStyle Function({double size, bool bold, PdfColor? color}) t, {
  bool boldValue = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(label, style: t())),
        pw.Text(value, style: t(bold: boldValue)),
      ],
    ),
  );
}
