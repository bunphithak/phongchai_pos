import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:phongchai_pos/core/loyalty/points_redeem.dart';
import 'package:phongchai_pos/core/utils/pdf_generator.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:printing/printing.dart';

Future<Uint8List> buildThermalReceiptPdfBytes(TaxInvoiceData data) async {
  final font = await PdfGoogleFonts.sarabunRegular();
  final fontBold = await PdfGoogleFonts.sarabunBold();
  final money = NumberFormat('#,##0.00', 'en_US');
  final date = DateFormat('dd/MM/yyyy HH:mm').format(data.issuedAt);
  final shortInvoiceNo = data.invoiceNo.length > 20
      ? data.invoiceNo.substring(0, 20)
      : data.invoiceNo;
  final paymentExtra = (data.cashAmount > 1e-9 ||
          data.transferAmount > 1e-9 ||
          data.change > 1e-9)
      ? 36.0
      : 0.0;
  final estimatedHeight =
      (230 + (data.lines.length * 24) + (data.discountAmount > 0 ? 14 : 0) + paymentExtra)
          .toDouble()
          .clamp(260.0, 900.0);
  final roll80Format = PdfPageFormat(
    80 * PdfPageFormat.mm,
    estimatedHeight,
    marginLeft: 6,
    marginRight: 6,
    marginTop: 6,
    marginBottom: 6,
  );

  final seller = MockDataStore.instance.sellerProfile;
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: roll80Format,
      margin: const pw.EdgeInsets.fromLTRB(6, 6, 6, 6),
      build: (context) {
        return pw.DefaultTextStyle(
          style: pw.TextStyle(font: font, fontSize: 8.5, lineSpacing: 1.2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'ใบเสร็จรับเงิน',
                  style: pw.TextStyle(font: fontBold, fontSize: 10.5),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  seller.companyNameTh,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (seller.taxId.trim().isNotEmpty)
                pw.Center(child: pw.Text('Tax ID: ${seller.taxId}')),
              pw.SizedBox(height: 4),
              pw.Text('เลขที่: $shortInvoiceNo'),
              pw.Text('เวลา: $date'),
              pw.SizedBox(height: 4),
              pw.Text('--------------------------------'),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('รายการ', style: pw.TextStyle(font: fontBold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'จำนวน',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'รวม',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold),
                    ),
                  ),
                ],
              ),
              pw.Text('--------------------------------'),
              for (final line in data.lines) ...[
                pw.Text(line.product.name, maxLines: 2, overflow: pw.TextOverflow.clip),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        '@ ${money.format(line.product.unitPriceForQuantity(line.quantity))}',
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('${line.quantity}', textAlign: pw.TextAlign.right),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        money.format(line.lineTotal),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 1),
              ],
              pw.Text('--------------------------------'),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ยอดก่อนส่วนลด'),
                  pw.Text(money.format(data.subtotal)),
                ],
              ),
              if (data.discountAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ส่วนลด'),
                    pw.Text('-${money.format(data.discountAmount)}'),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VAT 7%'),
                  pw.Text(money.format(data.vatAmount)),
                ],
              ),
              if (data.pointsDiscountAmount > 1e-9)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('แลกแต้ม (${PointsRedeem.formatPoints(data.pointsRedeemed)})'),
                    pw.Text('-${money.format(data.pointsDiscountAmount)}'),
                  ],
                ),
              pw.Text('--------------------------------'),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('รวมสุทธิ', style: pw.TextStyle(font: fontBold, fontSize: 9.5)),
                  pw.Text(
                    money.format(data.grandTotal),
                    style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(taxInvoicePaymentLine(data, money)),
              pw.SizedBox(height: 4),
              pw.Text('--------------------------------'),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'ขอบคุณที่ใช้บริการ',
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                ),
              ),
              pw.Center(child: pw.Text('XP-N160II Thermal Receipt')),
            ],
          ),
        );
      },
    ),
  );
  return doc.save();
}
