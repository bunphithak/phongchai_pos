import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phongchai_pos/data/models/product.dart';
import 'package:phongchai_pos/features/pos/domain/cart_item.dart';

/// Manages the current cart lines using Riverpod 2.x [Notifier] / [NotifierProvider].
final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void setItems(List<CartItem> items) {
    state = List.unmodifiable(items);
  }

  void addItem(CartItem item) {
    state = [item, ...state];
  }

  /// ถ้ามีสินค้าเดิมในตะกร้าแล้ว ให้เพิ่มจำนวนและเลื่อนแถวนั้นขึ้นบนสุด (ล่าสุดบนสุด)
  void addOrIncrementProduct(Product product) {
    final idx = state.indexWhere((e) => e.product.id == product.id);
    if (idx >= 0) {
      final line = state[idx];
      final rest = [...state]..removeAt(idx);
      state = [
        CartItem(product: line.product, quantity: line.quantity + 1),
        ...rest,
      ];
    } else {
      state = [CartItem(product: product, quantity: 1), ...state];
    }
  }

  void removeAt(int index) {
    final next = [...state]..removeAt(index);
    state = next;
  }

  void incrementAt(int index) {
    final line = state[index];
    final rest = [...state]..removeAt(index);
    state = [
      CartItem(product: line.product, quantity: line.quantity + 1),
      ...rest,
    ];
  }

  void decrementAt(int index) {
    final line = state[index];
    if (line.quantity <= 1) {
      removeAt(index);
      return;
    }
    final rest = [...state]..removeAt(index);
    state = [
      CartItem(product: line.product, quantity: line.quantity - 1),
      ...rest,
    ];
  }

  /// ตั้งจำนวนแถวตาม index; ถ้า ≤ 0 จะลบแถวนั้น — ถ้ายังอยู่จะเลื่อนแถวนั้นขึ้นบนสุด
  void setQuantityAt(int index, int quantity) {
    if (index < 0 || index >= state.length) return;
    if (quantity <= 0) {
      removeAt(index);
      return;
    }
    final line = state[index];
    if (line.quantity == quantity) return;
    final rest = [...state]..removeAt(index);
    state = [
      CartItem(product: line.product, quantity: quantity),
      ...rest,
    ];
  }

  void clear() {
    state = [];
  }
}

/// ยอดรวมสินค้าก่อนหักส่วนลด
final cartSubtotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold<double>(0, (sum, item) => sum + item.lineTotal);
});

enum DiscountKind { baht, percent }

class CartDiscountState {
  const CartDiscountState({
    this.kind = DiscountKind.baht,
    this.rawValue = 0,
  });

  final DiscountKind kind;

  /// จำนวนบาท หรือ เปอร์เซ็นต์ (0–100) ตาม [kind]
  final double rawValue;
}

final cartDiscountProvider =
    NotifierProvider<CartDiscountNotifier, CartDiscountState>(
  CartDiscountNotifier.new,
);

class CartDiscountNotifier extends Notifier<CartDiscountState> {
  @override
  CartDiscountState build() => const CartDiscountState();

  void setKind(DiscountKind kind) {
    state = CartDiscountState(kind: kind, rawValue: state.rawValue);
  }

  void setRawValue(double value) {
    if (value.isNaN || value.isInfinite) return;
    state = CartDiscountState(
      kind: state.kind,
      rawValue: value < 0 ? 0 : value,
    );
  }

  void reset() {
    state = const CartDiscountState();
  }

  void replaceWith(CartDiscountState other) {
    state = other;
  }
}

/// มูลหักส่วนลดเป็นบาท (คำนวณจากยอดสินค้า)
final cartDiscountAmountProvider = Provider<double>((ref) {
  final sub = ref.watch(cartSubtotalProvider);
  if (sub <= 0) return 0;
  final d = ref.watch(cartDiscountProvider);
  switch (d.kind) {
    case DiscountKind.baht:
      final v = d.rawValue;
      return v > sub ? sub : v;
    case DiscountKind.percent:
      final p = d.rawValue.clamp(0, 100);
      return sub * (p / 100);
  }
});

/// ยอดสินค้าหลังหักส่วนลด (ฐานคำนวณ VAT)
final cartNetSubtotalProvider = Provider<double>((ref) {
  final sub = ref.watch(cartSubtotalProvider);
  final disc = ref.watch(cartDiscountAmountProvider);
  final n = sub - disc;
  return n < 0 ? 0 : n;
});

/// เปิด/ปิดการคำนวณ VAT 7% (สรุปยอดฝั่งขวา)
final cartVatEnabledProvider =
    NotifierProvider<CartVatEnabledNotifier, bool>(CartVatEnabledNotifier.new);

class CartVatEnabledNotifier extends Notifier<bool> {
  /// เริ่มต้นไม่ติ๊ก = ไม่คิด VAT จนกว่าผู้ใช้จะเปิดเอง
  @override
  bool build() => false;

  void setEnabled(bool value) {
    state = value;
  }

  void reset() {
    state = false;
  }
}

/// ภาษี 7% จากยอดหลังหักส่วนลด (เป็น 0 ถ้าปิด VAT)
final cartVatProvider = Provider<double>((ref) {
  if (!ref.watch(cartVatEnabledProvider)) return 0;
  return ref.watch(cartNetSubtotalProvider) * 0.07;
});

/// ยอดรวมสุทธิ = ยอดหลังส่วนลด + VAT (ถ้าเปิด VAT)
final cartGrandTotalProvider = Provider<double>((ref) {
  final net = ref.watch(cartNetSubtotalProvider);
  final vat = ref.watch(cartVatProvider);
  return net + vat;
});
