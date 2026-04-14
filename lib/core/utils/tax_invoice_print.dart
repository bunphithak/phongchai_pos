import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'pdf_generator.dart';

/// เปิดหน้าดูตัวอย่าง PDF ก่อน — แชร์จากแถบล่าง / พิมพ์จากปุ่ม AppBar (มี fallback แชร์ถ้าระบบพิมพ์ไม่พร้อม)
Future<void> openTaxInvoicePdfPreview({
  required BuildContext context,
  required TaxInvoiceData data,
}) async {
  late final Uint8List bytes;
  try {
    bytes = await buildTaxInvoicePdf(data);
  } catch (e, st) {
    debugPrint('buildTaxInvoicePdf: $e\n$st');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้าง PDF ไม่สำเร็จ: $e')),
      );
    }
    return;
  }

  if (bytes.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไฟล์ PDF ว่าง')),
      );
    }
    return;
  }

  if (!context.mounted) return;

  final pdfFileName = 'invoice_${data.invoiceNo}.pdf';

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _TaxInvoicePdfPreviewPage(
        bytes: bytes,
        pdfFileName: pdfFileName,
      ),
    ),
  );
}

class _TaxInvoicePdfPreviewPage extends StatefulWidget {
  const _TaxInvoicePdfPreviewPage({
    required this.bytes,
    required this.pdfFileName,
  });

  final Uint8List bytes;
  final String pdfFileName;

  @override
  State<_TaxInvoicePdfPreviewPage> createState() =>
      _TaxInvoicePdfPreviewPageState();
}

class _TaxInvoicePdfPreviewPageState extends State<_TaxInvoicePdfPreviewPage> {
  @override
  void initState() {
    super.initState();
    pw.Document.debug = false;
  }

  Future<void> _trySystemPrint() async {
    try {
      final printed = await Printing.layoutPdf(
        onLayout: (_) async => widget.bytes,
        name: widget.pdfFileName,
        format: PdfPageFormat.a4,
        dynamicLayout: false,
      );
      if (!printed && mounted) {
        await _sharePdfFallback(
          message: 'ยกเลิกการพิมพ์ หรือเปิดบันทึกไฟล์แทน',
        );
      }
    } catch (e, st) {
      debugPrint('Printing.layoutPdf: $e\n$st');
      if (!mounted) return;
      await _sharePdfFallback(
        message: 'เปิดหน้าต่างพิมพ์ไม่ได้ — เปิดเมนูแชร์/บันทึกแทน',
      );
    }
  }

  Future<void> _sharePdfFallback({required String message}) async {
    await Printing.sharePdf(
      bytes: widget.bytes,
      filename: widget.pdfFileName,
      bounds: Rect.zero,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตัวอย่างใบกำกับภาษี'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'ปิด',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'พิมพ์ (ระบบ)',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => unawaited(_trySystemPrint()),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'macOS: ต้องมีสิทธิ์ com.apple.security.print ใน entitlements แล้วรันแอปใหม่\n'
                      'เลื่อนดูหน้า PDF · แถบล่าง: แชร์/บันทึกไฟล์ · มุมขวาบน: พิมพ์ผ่านระบบ',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) async => widget.bytes,
              initialPageFormat: PdfPageFormat.a4,
              allowPrinting: false,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              /// ปิดสวิตช์ debug ของแพ็กเกจ pdf — ไม่ให้มีเส้นโครงสร้างสีรอบข้อความใน preview
              canDebug: false,
              dynamicLayout: false,
              pdfFileName: widget.pdfFileName,
              maxPageWidth: 720,
              actionBarTheme: PdfActionBarTheme(
                height: 56,
                backgroundColor: theme.colorScheme.primaryContainer,
                iconColor: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// คงชื่อเดิมให้โค้ดเรียกจาก POS
Future<void> printTaxInvoiceWithFallback({
  required BuildContext context,
  required TaxInvoiceData data,
}) async {
  await openTaxInvoicePdfPreview(context: context, data: data);
}
