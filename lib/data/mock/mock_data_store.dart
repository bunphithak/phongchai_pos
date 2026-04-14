import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:phongchai_pos/core/config/seller_profile.dart';
import 'package:phongchai_pos/data/models/product.dart';
import 'package:phongchai_pos/features/auth/domain/employee.dart';
import 'package:phongchai_pos/data/models/member_lookup_hit.dart';

/// โหลดข้อมูล mock จาก `assets/mock/*.json` — โครงสร้างเตรียมไว้สำหรับสลับเป็น API
class MockDataStore {
  MockDataStore._();
  static final MockDataStore instance = MockDataStore._();

  Map<String, Product> productsByBarcode = {};
  final Map<String, MemberLookupHit> _membersByPhone = {};
  final Map<String, Employee> _employeesByPin = {};
  SellerProfile sellerProfile = SellerProfile.defaults;

  Product? productForBarcode(String raw) {
    final key = raw.trim();
    return productsByBarcode[key];
  }

  MemberLookupHit? memberLookupByPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.isEmpty) return null;
    final hit = _membersByPhone[digits];
    if (hit != null) return hit;
    for (final e in _membersByPhone.entries) {
      if (digits.endsWith(e.key) || e.key.endsWith(digits)) {
        return e.value;
      }
    }
    return null;
  }

  Employee? employeeForPin(String pin) {
    if (pin.length != 6) return null;
    return _employeesByPin[pin];
  }

  Future<void> loadAll() async {
    try {
      await Future.wait([
        _loadCatalog(),
        _loadMembers(),
        _loadEmployees(),
        _loadSeller(),
      ]);
    } catch (_) {
      _applyHardcodedFallback();
    }
    if (productsByBarcode.isEmpty) {
      _applyHardcodedFallback();
    }
  }

  Future<void> _loadCatalog() async {
    final s = await rootBundle.loadString('assets/mock/catalog_by_barcode.json');
    final map = jsonDecode(s) as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>? ?? [];
    final next = <String, Product>{};
    for (final e in items) {
      final row = e as Map<String, dynamic>;
      final barcode = row['barcode'] as String;
      final product = Product.fromJson(row['product'] as Map<String, dynamic>);
      next[barcode] = product;
    }
    productsByBarcode = next;
  }

  Future<void> _loadMembers() async {
    final s =
        await rootBundle.loadString('assets/mock/members_by_phone.json');
    final map = jsonDecode(s) as Map<String, dynamic>;
    final list = map['members'] as List<dynamic>? ?? [];
    _membersByPhone.clear();
    for (final e in list) {
      final row = e as Map<String, dynamic>;
      final phone = row['phone'] as String;
      var digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length > 10) {
        digits = digits.substring(digits.length - 10);
      }
      if (digits.isEmpty) continue;
      _membersByPhone[digits] = MemberLookupHit(
        name: row['name'] as String,
        loyaltyPoints: (row['loyalty_points'] as num).toInt(),
      );
    }
  }

  Future<void> _loadEmployees() async {
    final s =
        await rootBundle.loadString('assets/mock/employees_by_pin.json');
    final map = jsonDecode(s) as Map<String, dynamic>;
    final list = map['accounts'] as List<dynamic>? ?? [];
    _employeesByPin.clear();
    for (final e in list) {
      final row = e as Map<String, dynamic>;
      final pin = row['pin'] as String;
      final emp = row['employee'] as Map<String, dynamic>;
      _employeesByPin[pin] = Employee(
        name: emp['name'] as String,
        role: emp['role'] as String,
      );
    }
  }

  Future<void> _loadSeller() async {
    final s = await rootBundle.loadString('assets/mock/seller_profile.json');
    final map = jsonDecode(s) as Map<String, dynamic>;
    sellerProfile = SellerProfile.fromJson(map);
  }

  void _applyHardcodedFallback() {
    productsByBarcode = {
      '123': const Product(
        id: '123',
        name: 'น้ำดื่ม',
        price: 12,
        unit: 'ขวด',
        imageAsset: 'assets/images/product_water.jpg',
      ),
      '456': const Product(
        id: '456',
        name: 'ข้าวสาร',
        price: 189,
        unit: 'ถุง',
        imageAsset: 'assets/images/product_rice.jpg',
      ),
      '8851473011619': const Product(
        id: '8851473011619',
        name: 'อ๊อพพลีน สเตอไรก์ อาย วอช',
        price: 89,
        unit: 'ขวด',
      ),
      '8851552201030': const Product(
        id: '8851552201030',
        name: 'ปากกาเคมีสีแดง ตราม้า',
        price: 12,
        unit: 'ด้าม',
      ),
      '8851907130077': const Product(
        id: '8851907130077',
        name: 'ปากกาควอนตั้ม',
        price: 30,
        unit: 'ด้าม',
      ),
      '8859685401792': const Product(
        id: '8859685401792',
        name: 'หน้ากากคาร์บอน PM 2.5',
        price: 60,
        unit: 'ชิ้น',
      ),
    };
    _membersByPhone
      ..clear()
      ..['0812345678'] =
          const MemberLookupHit(name: 'คุณสมชาย ใจดี', loyaltyPoints: 1280)
      ..['0899999999'] =
          const MemberLookupHit(name: 'คุณสมหญิง รักสบาย', loyaltyPoints: 560);
    _employeesByPin
      ..clear()
      ..['123456'] = const Employee(name: 'สมชาย ใจดี', role: 'แคชเชียร์')
      ..['654321'] = const Employee(name: 'นารี รักงาน', role: 'หัวหน้าแผนก');
    sellerProfile = SellerProfile.defaults;
  }
}
