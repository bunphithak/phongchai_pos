import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/data/models/member.dart';
import 'package:phongchai_pos/data/remote/member_registration.dart';
import 'package:phongchai_pos/features/pos/providers/pos_session_provider.dart';

Future<void> showMemberRegisterDialog(
  BuildContext context,
  WidgetRef ref, {
  void Function(String normalizedPhone)? onSavedSyncPhoneField,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _MemberRegisterDialogBody(
      onSavedSyncPhoneField: onSavedSyncPhoneField,
    ),
  );
}

class _MemberRegisterDialogBody extends ConsumerStatefulWidget {
  const _MemberRegisterDialogBody({this.onSavedSyncPhoneField});

  final void Function(String normalizedPhone)? onSavedSyncPhoneField;

  @override
  ConsumerState<_MemberRegisterDialogBody> createState() =>
      _MemberRegisterDialogBodyState();
}

class _MemberRegisterDialogBodyState
    extends ConsumerState<_MemberRegisterDialogBody> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  MemberType _type = MemberType.general;
  bool _saving = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validatePhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return 'กรุณากรอกเบอร์โทร 10 หลัก';
    }
    return null;
  }

  String? _validateName() {
    if (_nameController.text.trim().isEmpty) {
      return 'กรุณากรอกชื่อ';
    }
    return null;
  }

  Future<void> _save() async {
    final phoneErr = _validatePhone();
    final nameErr = _validateName();
    if (phoneErr != null || nameErr != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneErr ?? nameErr!)),
      );
      return;
    }

    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final member = Member(
      phone: digits,
      name: _nameController.text.trim(),
      type: _type,
      registeredAt: DateTime.now(),
      loyaltyPoints: 0,
    );

    setState(() => _saving = true);
    try {
      await registerMember(member);
      if (!mounted) return;
      ref.read(posMemberProvider.notifier).setBillMember(member);
      widget.onSavedSyncPhoneField?.call(digits);
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        const SnackBar(content: Text('สมัครสมาชิกและผูกกับบิลนี้แล้ว')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('สมัครสมาชิก'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  hintText: '0812345678',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'ประเภทลูกค้า',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MemberType>(
                    value: _type,
                    isExpanded: true,
                    items: MemberType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.thaiLabel),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v != null) setState(() => _type = v);
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึก'),
        ),
      ],
    );
  }
}
