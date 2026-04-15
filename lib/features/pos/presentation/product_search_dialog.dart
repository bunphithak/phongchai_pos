import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phongchai_pos/data/mock/mock_data_store.dart';
import 'package:phongchai_pos/data/models/product.dart';

final _money = NumberFormat('#,##0.00', 'en_US');

/// สีเน้นราคา / สต็อก (อ่านง่าย แยกชั้นชัด)
const _kPriceAccent = Color(0xFF1565C0);
const _kStockAccent = Color(0xFF2E7D32);

/// บรรทัดอธิบายประเภทการขาย (ชิ้น / แพ็ค / ลัง ฯลฯ)
List<String> describeProductSaleTiers(Product p) {
  final tiers = p.pricingPolicy?.tiers;
  if (tiers == null || tiers.isEmpty) {
    return [
      'ขายตามหน่วย: ${p.unitLabel} — ${_money.format(p.price)} บาท/หน่วย',
    ];
  }
  final lines = <String>[];
  for (final t in tiers) {
    final label = (t.label ?? t.unit ?? 'ช่วงราคา').trim();
    final unit = (t.unit ?? '').trim();
    final range = t.maxQty != null
        ? '${t.minQty}–${t.maxQty} หน่วยฐาน'
        : 'ตั้งแต่ ${t.minQty} หน่วยฐานขึ้นไป';
    if (t.packSize != null &&
        t.packSize! > 1 &&
        t.totalPrice != null &&
        unit.isNotEmpty) {
      lines.add(
        '$label — $unit (ครบ ${t.packSize} ชิ้น) รวม ${_money.format(t.totalPrice!)} บาท · $range',
      );
    } else {
      final up = t.effectiveUnitPrice ?? t.totalPrice;
      final priceStr = up != null ? '${_money.format(up)} บาท/หน่วย' : '';
      lines.add('$label ${unit.isNotEmpty ? '($unit)' : ''} $priceStr · $range'.trim());
    }
  }
  return lines;
}

Future<void> showProductSearchDialog(
  BuildContext context, {
  required void Function(Product product, int quantity) onAddToCart,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ProductSearchDialogBody(onAddToCart: onAddToCart),
  );
}

class _ProductSearchDialogBody extends StatefulWidget {
  const _ProductSearchDialogBody({required this.onAddToCart});

  final void Function(Product product, int quantity) onAddToCart;

  @override
  State<_ProductSearchDialogBody> createState() =>
      _ProductSearchDialogBodyState();
}

class _ProductSearchDialogBodyState extends State<_ProductSearchDialogBody> {
  final _queryController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _queryFocus = FocusNode();

  List<CatalogSearchHit> _hits = [];
  CatalogSearchHit? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _qtyController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _runSearch(String raw) {
    setState(() {
      _hits = MockDataStore.instance.searchCatalog(raw);
      if (_hits.isEmpty) {
        _selected = null;
      } else {
        final still = _selected != null &&
            _hits.any(
              (h) =>
                  h.barcode == _selected!.barcode &&
                  h.product.id == _selected!.product.id,
            );
        _selected = still
            ? _hits.firstWhere(
                (h) =>
                    h.barcode == _selected!.barcode &&
                    h.product.id == _selected!.product.id,
              )
            : _hits.first;
      }
    });
  }

  int _readQty() {
    final q = int.tryParse(_qtyController.text.trim()) ?? 1;
    if (q <= 0) return 1;
    if (q > 9999) return 9999;
    return q;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.sizeOf(context);
    final dialogW =
        mq.width > 760 ? 720.0 : (mq.width - 40).clamp(280.0, mq.width);
    final dialogH =
        mq.height > 560 ? 420.0 : (mq.height * 0.55).clamp(280.0, mq.height * 0.85);

    return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
        children: [
          Icon(Icons.manage_search_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('ค้นหาสินค้า'),
          ),
          Text(
            'F2',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchField(
                    controller: _queryController,
                    focusNode: _queryFocus,
                    onChanged: _runSearch,
                    onSubmitted: _runSearch,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _hits.isEmpty
                            ? Center(
                                child: Text(
                                  _queryController.text.trim().isEmpty
                                      ? 'พิมพ์เพื่อค้นหา'
                                      : 'ไม่พบสินค้า',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                                itemCount: _hits.length,
                                itemBuilder: (ctx, i) {
                                  final h = _hits[i];
                                  final sel =
                                      _selected?.barcode == h.barcode &&
                                          _selected?.product.id == h.product.id;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _SearchResultTile(
                                      hit: h,
                                      selected: sel,
                                      onTap: () =>
                                          setState(() => _selected = h),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 24),
            Expanded(
              flex: 5,
              child: _selected == null
                  ? Center(
                      child: Text(
                        'เลือกสินค้าเพื่อดูรายละเอียด',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _DetailPane(
                      hit: _selected!,
                      qtyController: _qtyController,
                      onAdd: () {
                        final q = _readQty();
                        widget.onAddToCart(_selected!.product, q);
                        Navigator.of(context).pop();
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: 'ชื่อสินค้า / บาร์โค้ด',
          hintText: 'พิมพ์แล้วกด Enter หรือรอผล',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.primary,
          ),
          filled: true,
          fillColor: fill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.35),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.hit,
    required this.selected,
    required this.onTap,
  });

  final CatalogSearchHit hit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: selected
            ? primary.withValues(alpha: 0.14)
            : theme.colorScheme.surface.withValues(alpha: 0.65),
        border: Border.all(
          color: selected ? primary.withValues(alpha: 0.85) : Colors.transparent,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'บาร์โค้ด ${hit.barcode} · ${_money.format(hit.product.price)} บาท',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.hit,
    required this.qtyController,
    required this.onAdd,
  });

  final CatalogSearchHit hit;
  final TextEditingController qtyController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = hit.product;
    final tiers = describeProductSaleTiers(p);
    final stockText = hit.stockOnHand != null
        ? '${hit.stockOnHand} ${p.unitLabel}'
        : 'ไม่ระบุ (mock)';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'บาร์โค้ด ${hit.barcode}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _DetailInfoRow(
            icon: Icons.sell_rounded,
            iconColor: _kPriceAccent,
            label: 'ราคา',
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _money.format(p.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _kPriceAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' บาท / ${p.unitLabel}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _kPriceAccent.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DetailInfoRow(
            icon: Icons.inventory_2_rounded,
            iconColor: _kStockAccent,
            label: 'สต็อกคงเหลือ',
            child: Text(
              stockText,
              style: theme.textTheme.titleMedium?.copyWith(
                color: _kStockAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'ประเภทการขาย / แถวราคา',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...tiers.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 104,
                child: TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'จำนวน',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PremiumAddToCartButton(onPressed: onAdd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumAddToCartButton extends StatelessWidget {
  const _PremiumAddToCartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E),
                Color(0xFF0D47A1),
                Color(0xFF01579B),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 22,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  'เพิ่มลงตะกร้า',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
