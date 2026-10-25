import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/models.dart';

class ProductSearchDialog extends StatefulWidget {
  final List<Product> products;
  final Product? selectedProduct;
  final ValueChanged<Product> onProductSelected;
  final String currencySymbol;

  const ProductSearchDialog({
    super.key,
    required this.products,
    required this.selectedProduct,
    required this.onProductSelected,
    this.currencySymbol = 'Rs',
  });

  @override
  State<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<Product> _filtered;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _filtered = widget.products;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.products.where((p) {
        final matchesCat = _selectedCategory == null || p.categoryName == _selectedCategory;
        if (!matchesCat) return false;
        if (q.isEmpty) return true;

        final nameMatch = p.name.toLowerCase().contains(q);
        final skuMatch = p.sku.toLowerCase().contains(q);
        final barcodeMatch = p.barcode.toLowerCase().contains(q);
        final brandMatch = p.brandName.toLowerCase().contains(q);
        final catMatch = p.categoryName.toLowerCase().contains(q);
        final batchMatch = p.batchNumber != null && p.batchNumber!.toLowerCase().contains(q);

        return nameMatch || skuMatch || barcodeMatch || brandMatch || catMatch || batchMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final categories = widget.products.map((p) => p.categoryName).toSet().toList();

    return Dialog(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 650),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.search_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search & Select Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Type product name, SKU, or barcode to instantly filter (${widget.products.length} available)',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar & Category Filter
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: TextStyle(fontSize: 13, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name, SKU, barcode, formula...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF4F46E5)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _filter();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                    onChanged: (_) => _filter(),
                  ),
                  if (categories.length > 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('All Categories', style: TextStyle(fontSize: 11)),
                            selected: _selectedCategory == null,
                            onSelected: (val) {
                              setState(() {
                                _selectedCategory = null;
                                _filter();
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          ...categories.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(cat, style: const TextStyle(fontSize: 11)),
                                selected: _selectedCategory == cat,
                                onSelected: (val) {
                                  setState(() {
                                    _selectedCategory = val ? cat : null;
                                    _filter();
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Products Results List
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('No matching products found', style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary)),
                          const SizedBox(height: 4),
                          Text('Try searching with a different keyword or barcode', style: TextStyle(fontSize: 12, color: textSecondary.withValues(alpha: 0.7))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final p = _filtered[index];
                        final isSelected = widget.selectedProduct?.id == p.id;
                        final isLow = p.isLowStock;
                        final isOut = p.isOutOfStock;

                        Color stockColor = const Color(0xFF10B981);
                        if (isOut) {
                          stockColor = const Color(0xFFEF4444);
                        } else if (isLow) {
                          stockColor = const Color(0xFFF59E0B);
                        }

                        return InkWell(
                          onTap: () {
                            widget.onProductSelected(p);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.08)
                                  : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4F46E5) : borderColor,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Builder(
                                  builder: (context) {
                                    final img = p.imageColor;
                                    final hasImg = img != null &&
                                        img.isNotEmpty &&
                                        (img.contains(Platform.pathSeparator) || img.contains('/')) &&
                                        File(img).existsSync();
                                    if (hasImg) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(img),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.medication_liquid_rounded, color: Color(0xFF4F46E5), size: 22),
                                          ),
                                        ),
                                      );
                                    }
                                    return Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.medication_liquid_rounded, color: Color(0xFF4F46E5), size: 22),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.check_circle, size: 16, color: Color(0xFF4F46E5)),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 2,
                                        children: [
                                          Text('SKU: ${p.sku}', style: TextStyle(fontSize: 11, color: textSecondary)),
                                          Text('•', style: TextStyle(fontSize: 11, color: textSecondary)),
                                          Text(p.categoryName, style: TextStyle(fontSize: 11, color: textSecondary)),
                                          if (p.batchNumber != null && p.batchNumber!.isNotEmpty) ...[
                                            Text('•', style: TextStyle(fontSize: 11, color: textSecondary)),
                                            Text('Batch: ${p.batchNumber}', style: TextStyle(fontSize: 11, color: textSecondary)),
                                          ],
                                          if (p.expiryDate != null && p.expiryDate!.isNotEmpty) ...[
                                            Text('•', style: TextStyle(fontSize: 11, color: textSecondary)),
                                            Text('Exp: ${p.expiryDate}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${widget.currencySymbol}${p.purchasePrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: stockColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: stockColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'Stock: ${p.stockQuantity.toInt()} ${p.unit}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: stockColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
