/// Sellable item in the POS catalog.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.unit,
    this.pricingPolicy,
    this.imageUrl,
    this.imageAsset,
  });

  final String id;
  final String name;
  final double price;
  final String? unit;
  final ProductPricingPolicy? pricingPolicy;

  /// Optional bundled image (e.g. `assets/images/foo.jpg`). Shown before [imageUrl].
  final String? imageAsset;

  /// Optional remote image URL.
  final String? imageUrl;

  String get unitLabel {
    final u = unit?.trim();
    if (u == null || u.isEmpty) return 'ชิ้น';
    return u;
  }

  ProductPricingTier? tierForQuantity(int quantity) {
    if (quantity <= 0) return null;
    final tiers = pricingPolicy?.tiers;
    if (tiers == null || tiers.isEmpty) return null;
    ProductPricingTier? selected;
    for (final tier in tiers) {
      if (quantity < tier.minQty) continue;
      if (tier.maxQty != null && quantity > tier.maxQty!) continue;
      selected = tier;
    }
    return selected;
  }

  List<ProductUnitBreakdown> breakdownForQuantity(int quantity) {
    if (quantity <= 0) return const [];

    final tiers = pricingPolicy?.tiers ?? const <ProductPricingTier>[];
    final packTiers = tiers
        .where(
          (t) =>
              (t.packSize ?? 0) > 1 &&
              t.totalPrice != null &&
              (t.unit?.trim().isNotEmpty ?? false),
        )
        .toList()
      ..sort((a, b) => (b.packSize ?? 0).compareTo(a.packSize ?? 0));

    var remaining = quantity;
    final result = <ProductUnitBreakdown>[];

    for (final tier in packTiers) {
      final packSize = tier.packSize!;
      if (remaining < packSize) continue;

      // Respect min_qty if provided.
      if (remaining < tier.minQty) continue;

      final packCount = remaining ~/ packSize;
      if (packCount <= 0) continue;

      final total = packCount * tier.totalPrice!;
      result.add(
        ProductUnitBreakdown(
          unit: tier.unit!,
          unitCount: packCount,
          baseQty: packCount * packSize,
          unitPrice: tier.totalPrice!,
          totalPrice: total,
          label: tier.label,
        ),
      );
      remaining -= packCount * packSize;
    }

    if (remaining > 0) {
      result.add(
        ProductUnitBreakdown(
          unit: unitLabel,
          unitCount: remaining,
          baseQty: remaining,
          unitPrice: price,
          totalPrice: remaining * price,
        ),
      );
    }

    return result;
  }

  double totalPriceForQuantity(int quantity) {
    if (quantity <= 0) return 0;
    final breakdown = breakdownForQuantity(quantity);
    if (breakdown.isEmpty) return price * quantity;
    return breakdown.fold<double>(0, (sum, e) => sum + e.totalPrice);
  }

  double unitPriceForQuantity(int quantity) {
    if (quantity <= 0) return price;
    return totalPriceForQuantity(quantity) / quantity;
  }

  String displayUnitForQuantity(int quantity) {
    final breakdown = breakdownForQuantity(quantity);
    if (breakdown.length == 1) return breakdown.first.unit;
    return unitLabel;
  }

  double displayPriceForShownUnit(int quantity) {
    final breakdown = breakdownForQuantity(quantity);
    if (breakdown.length == 1) return breakdown.first.unitPrice;
    return unitPriceForQuantity(quantity);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'unit': unit,
        'pricing_policy': pricingPolicy?.toJson(),
        'image_asset': imageAsset,
        'image_url': imageUrl,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String?,
      pricingPolicy: json['pricing_policy'] is Map<String, dynamic>
          ? ProductPricingPolicy.fromJson(
              json['pricing_policy'] as Map<String, dynamic>,
            )
          : null,
      imageAsset: json['image_asset'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class ProductPricingPolicy {
  const ProductPricingPolicy({
    this.strategy,
    this.baseUnit,
    this.tiers = const [],
  });

  final String? strategy;
  final String? baseUnit;
  final List<ProductPricingTier> tiers;

  Map<String, dynamic> toJson() => {
        'strategy': strategy,
        'base_unit': baseUnit,
        'tiers': tiers.map((e) => e.toJson()).toList(),
      };

  factory ProductPricingPolicy.fromJson(Map<String, dynamic> json) {
    final tiersRaw = json['tiers'] as List<dynamic>? ?? const [];
    return ProductPricingPolicy(
      strategy: json['strategy'] as String?,
      baseUnit: json['base_unit'] as String?,
      tiers: tiersRaw
          .whereType<Map<String, dynamic>>()
          .map(ProductPricingTier.fromJson)
          .toList(),
    );
  }
}

class ProductPricingTier {
  const ProductPricingTier({
    required this.minQty,
    this.maxQty,
    this.label,
    this.unit,
    this.packSize,
    this.totalPrice,
    this.effectiveUnitPrice,
  });

  final int minQty;
  final int? maxQty;
  final String? label;
  final String? unit;
  final int? packSize;
  final double? totalPrice;
  final double? effectiveUnitPrice;

  Map<String, dynamic> toJson() => {
        'min_qty': minQty,
        'max_qty': maxQty,
        'label': label,
        'unit': unit,
        'pack_size': packSize,
        'total_price': totalPrice,
        'effective_unit_price': effectiveUnitPrice,
      };

  factory ProductPricingTier.fromJson(Map<String, dynamic> json) {
    return ProductPricingTier(
      minQty: (json['min_qty'] as num).toInt(),
      maxQty: (json['max_qty'] as num?)?.toInt(),
      label: json['label'] as String?,
      unit: json['unit'] as String?,
      packSize: (json['pack_size'] as num?)?.toInt(),
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      effectiveUnitPrice: (json['effective_unit_price'] as num?)?.toDouble(),
    );
  }
}

class ProductUnitBreakdown {
  const ProductUnitBreakdown({
    required this.unit,
    required this.unitCount,
    required this.baseQty,
    required this.unitPrice,
    required this.totalPrice,
    this.label,
  });

  final String unit;
  final int unitCount;
  final int baseQty;
  final double unitPrice;
  final double totalPrice;
  final String? label;
}
