import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/features/pos/domain/pos_member_lookup.dart';
import 'package:phongchai_pos/features/pos/domain/tax_invoice_buyer_info.dart';
import 'package:phongchai_pos/features/pos/providers/pos_session_provider.dart';
import 'package:phongchai_pos/features/pos/providers/tax_invoice_buyer_provider.dart';

/// โหมดฟอร์ม — [ephemeralOnly] ไม่บันทึกลง provider (ใช้เฉพาะสร้าง PDF / PDPA)
enum TaxInvoiceFormMode {
  /// บันทึกลง [taxInvoiceBuyerProvider] สำหรับบิลปัจจุบัน
  currentBill,

  /// ใช้เฉพาะค่าที่ส่งกลับ — ไม่บันทึกถาวร
  ephemeralOnly,
}

/// เปิด Dialog แบบฟอร์ม — บันทึกลง [taxInvoiceBuyerProvider]
Future<void> showTaxInvoiceFormDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TaxInvoiceFormDialog(
      mode: TaxInvoiceFormMode.currentBill,
      ref: ref,
    ),
  );
  if (context.mounted) {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

/// ฟอร์มสำหรับออกใบกำกับย้อนหลัง — **ไม่** เขียนลง provider; คืนค่าเมื่อกดตกลง
Future<TaxInvoiceBuyerInfo?> showTaxInvoiceFormDialogEphemeral(
  BuildContext context,
) {
  return showDialog<TaxInvoiceBuyerInfo>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const TaxInvoiceFormDialog(
      mode: TaxInvoiceFormMode.ephemeralOnly,
    ),
  );
}

class TaxInvoiceFormDialog extends ConsumerStatefulWidget {
  const TaxInvoiceFormDialog({
    super.key,
    required this.mode,
    this.ref,
    this.initialOverride,
  });

  final TaxInvoiceFormMode mode;
  final WidgetRef? ref;
  final TaxInvoiceBuyerInfo? initialOverride;

  @override
  ConsumerState<TaxInvoiceFormDialog> createState() =>
      _TaxInvoiceFormDialogState();
}

class _TaxInvoiceFormDialogState extends ConsumerState<TaxInvoiceFormDialog> {
  late final TextEditingController _taxIdController;
  late final TextEditingController _phoneController;
  late final TextEditingController _companyController;
  late final TextEditingController _addressController;
  late final TextEditingController _branchCodeController;
  late bool _isHeadOffice;

  bool get _ephemeral => widget.mode == TaxInvoiceFormMode.ephemeralOnly;

  @override
  void initState() {
    super.initState();
    final TaxInvoiceBuyerInfo initial;
    if (_ephemeral) {
      initial = widget.initialOverride ?? const TaxInvoiceBuyerInfo();
    } else {
      initial = widget.ref!.read(taxInvoiceBuyerProvider);
    }
    _taxIdController = TextEditingController(text: initial.taxId);
    _phoneController = TextEditingController(text: initial.phone);
    _companyController = TextEditingController(text: initial.companyOrName);
    _addressController = TextEditingController(text: initial.address);
    _branchCodeController = TextEditingController(text: initial.branchCode);
    _isHeadOffice = initial.isHeadOffice;
  }

  @override
  void dispose() {
    _taxIdController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String raw) {
    final hit = memberLookupByPhone(raw);
    if (hit == null) return;
    if (_companyController.text.trim().isEmpty) {
      _companyController.text = hit.name;
    }
  }

  void _onClear() {
    setState(() {
      _taxIdController.clear();
      _companyController.clear();
      _addressController.clear();
      _branchCodeController.clear();
      _isHeadOffice = true;
    });
    if (!_ephemeral) {
      widget.ref!.read(taxInvoiceBuyerProvider.notifier).clear();
    }
  }

  String? _validate() {
    final tax = _taxIdController.text.trim();
    if (tax.isNotEmpty && tax.length != 13) {
      return 'เลขประจำตัวผู้เสียภาษีต้องครบ 13 หลัก หรือเว้นว่าง';
    }
    if (!_isHeadOffice) {
      final b = _branchCodeController.text.trim();
      if (b.length != 5) {
        return 'รหัสสาขาต้องเป็นตัวเลข 5 หลัก';
      }
    }
    return null;
  }

  void _onConfirm() {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    final info = TaxInvoiceBuyerInfo(
      taxId: _taxIdController.text.trim(),
      phone: _phoneController.text.trim(),
      companyOrName: _companyController.text.trim(),
      address: _addressController.text.trim(),
      isHeadOffice: _isHeadOffice,
      branchCode: _isHeadOffice ? '' : _branchCodeController.text.trim(),
    );
    if (_ephemeral) {
      Navigator.of(context).pop(info);
      return;
    }
    widget.ref!.read(taxInvoiceBuyerProvider.notifier).setFromForm(info);
    final phone = info.phone.trim();
    if (phone.isNotEmpty) {
      widget.ref!.read(posMemberProvider.notifier).searchByPhone(phone);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('แบบฟอร์มข้อมูลใบกำกับภาษี'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_ephemeral) ...[
                Text(
                  'ข้อมูลที่กรอกใช้เพื่อสร้าง PDF เท่านั้น ไม่บันทึกลงฐานข้อมูลลูกค้าถาวร (PDPA)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _taxIdController,
                keyboardType: TextInputType.number,
                maxLength: 13,
                decoration: const InputDecoration(
                  labelText: 'เลขประจำตัวผู้เสียภาษี (13 หลัก)',
                  hintText: 'เว้นว่างได้ — กรอกเฉพาะตัวเลข',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  hintText: 'กรอกเบอร์เพื่อค้นหาสมาชิกอัตโนมัติ',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: _onPhoneChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'ชื่อบริษัท / ชื่อลูกค้า',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'สาขา',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('สำนักงานใหญ่'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('สาขา'),
                  ),
                ],
                selected: {_isHeadOffice},
                onSelectionChanged: (s) {
                  setState(() => _isHeadOffice = s.first);
                },
              ),
              if (!_isHeadOffice) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _branchCodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  decoration: const InputDecoration(
                    labelText: 'รหัสสาขา (5 หลัก)',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _onClear,
          child: const Text('ล้างข้อมูล'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _onConfirm,
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}
