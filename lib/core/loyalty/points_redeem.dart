import 'dart:math' as math;

import 'package:intl/intl.dart';

/// คำนวณส่วนลดจากการแลกแต้ม: `points * pointExchangeRate` (บาทต่อ 1 แต้ม)
class PointsRedeem {
  PointsRedeem._();

  /// แสดงจำนวนแต้มแบบมี comma (เช่น 1,280)
  static String formatPoints(int points) {
    return NumberFormat('#,##0', 'en_US').format(points);
  }

  static double discountBaht(int points, double pointExchangeRate) {
    if (points <= 0 || pointExchangeRate <= 0) return 0;
    final raw = points * pointExchangeRate;
    return (raw * 100).round() / 100;
  }

  /// ส่วนลดเป็นบาท — ไม่เกินยอดที่ต้องจ่าย (กันปัดทศนิยมเกินยอดบิล)
  static double discountBahtCappedToBill({
    required int points,
    required double pointExchangeRate,
    required double cartGrandTotal,
  }) {
    if (cartGrandTotal <= 0) return 0;
    final d = discountBaht(points, pointExchangeRate);
    return math.min(d, cartGrandTotal);
  }

  /// แต้มสูงสุดที่ใช้ได้: ไม่เกินยอดคงเหลือ และไม่ให้ส่วนลด (หลังปัด) เกินราคาที่ต้องจ่าย
  static int maxUsablePoints({
    required int loyaltyBalance,
    required double cartGrandTotal,
    required double pointExchangeRate,
  }) {
    if (loyaltyBalance <= 0 ||
        cartGrandTotal <= 0 ||
        pointExchangeRate <= 1e-12) {
      return 0;
    }
    var maxP = math.min(
      loyaltyBalance,
      (cartGrandTotal / pointExchangeRate).floor(),
    );
    while (maxP > 0) {
      final d = discountBaht(maxP, pointExchangeRate);
      if (d <= cartGrandTotal + 1e-6) break;
      maxP--;
    }
    return maxP;
  }

  /// จำกัดจำนวนแต้มที่ผู้ใช้กรอกให้อยู่ในช่วงที่ถูกต้อง
  static int clampPointsInput({
    required int raw,
    required int loyaltyBalance,
    required double cartGrandTotal,
    required double pointExchangeRate,
  }) {
    final maxP = maxUsablePoints(
      loyaltyBalance: loyaltyBalance,
      cartGrandTotal: cartGrandTotal,
      pointExchangeRate: pointExchangeRate,
    );
    if (raw < 0) return 0;
    if (raw > maxP) return maxP;
    return raw;
  }
}
