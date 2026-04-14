import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/data/models/member.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';
import 'package:phongchai_pos/features/pos/domain/pos_member_lookup.dart';
import 'package:phongchai_pos/features/pos/domain/tax_invoice_buyer_info.dart';
import 'package:phongchai_pos/features/pos/providers/cart_provider.dart';

/// สมาชิกที่ผูกกับบิลปัจจุบัน (ค้นหา / สมัครใหม่ / พักบิล)
final posMemberProvider =
    NotifierProvider<PosMemberNotifier, PosMemberState>(PosMemberNotifier.new);

String _normalizeThaiPhoneDigits(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length > 10) {
    d = d.substring(d.length - 10);
  }
  return d;
}

class PosMemberState {
  const PosMemberState({
    this.billMember,
    this.searchedNotFound = false,
  });

  final Member? billMember;
  final bool searchedNotFound;

  bool get hasMember => billMember != null;

  /// ใช้กับ UI เดิมที่อ่านชื่ออย่างเดียว
  String? get customerName => billMember?.name;
}

class PosMemberNotifier extends Notifier<PosMemberState> {
  @override
  PosMemberState build() => const PosMemberState();

  void searchByPhone(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) {
      state = const PosMemberState();
      return;
    }
    final hit = memberLookupByPhone(trimmed);
    final digits = _normalizeThaiPhoneDigits(trimmed);
    if (hit != null) {
      state = PosMemberState(
        billMember: Member(
          phone: digits.isEmpty ? trimmed.replaceAll(RegExp(r'\D'), '') : digits,
          name: hit.name,
          type: MemberType.general,
          registeredAt: DateTime.now(),
          loyaltyPoints: hit.loyaltyPoints,
        ),
        searchedNotFound: false,
      );
    } else {
      state = const PosMemberState(searchedNotFound: true);
    }
  }

  void clear() {
    state = const PosMemberState();
  }

  /// หลังสมัครสมาชิกสำเร็จ — ผูกสมาชิกกับบิลปัจจุบัน
  void setBillMember(Member member) {
    state = PosMemberState(billMember: member, searchedNotFound: false);
  }

  /// เรียกบิลพัก (คืนข้อมูลสมาชิกเต็มถ้ามี)
  void restoreBillMember(Member? member) {
    if (member == null) {
      state = const PosMemberState();
    } else {
      state = PosMemberState(billMember: member);
    }
  }
}

/// ข้อมูลบิลที่พักไว้ (ช่องเดียว)
class HeldBillData {
  const HeldBillData({
    required this.cartItems,
    required this.discount,
    this.billMember,
    this.vatEnabled = false,
    this.taxBuyer = const TaxInvoiceBuyerInfo(),
  });

  final List<CartItem> cartItems;
  final CartDiscountState discount;
  final Member? billMember;
  final bool vatEnabled;

  /// ข้อมูลใบกำกับภาษีที่กรอกไว้กับบิลนี้
  final TaxInvoiceBuyerInfo taxBuyer;
}

final heldBillProvider =
    NotifierProvider<HeldBillNotifier, HeldBillData?>(HeldBillNotifier.new);

class HeldBillNotifier extends Notifier<HeldBillData?> {
  @override
  HeldBillData? build() => null;

  void setHeld(HeldBillData data) {
    state = data;
  }

  void clearHeld() {
    state = null;
  }
}
