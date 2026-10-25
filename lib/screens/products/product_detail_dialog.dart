import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class ProductDetailDialog extends StatefulWidget {
  final Product product;
  final BusinessSettings settings;
  final VoidCallback? onEdit;
  final VoidCallback? onPrintLabels;

  const ProductDetailDialog({
    super.key,
    required this.product,
    required this.settings,
    this.onEdit,
    this.onPrintLabels,
  });

  @override
  State<ProductDetailDialog> createState() => _ProductDetailDialogState();
}

class _ProductDetailDialogState extends State<ProductDetailDialog> {
  List<ProductVariation> _variations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.product.id != null) {
      final db = await DatabaseService.initialize();
      final vars = await db.getProductVariations(widget.product.id!);
      if (mounted) {
        setState(() {
          _variations = vars;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.product;
    final currency = widget.settings.currencySymbol;
    final margin = p.purchasePrice > 0
        ? (((p.sellingPrice - p.purchasePrice) / p.purchasePrice) * 100)
        : 0.0;
    final unitProfit = p.sellingPrice - p.purchasePrice;
    final totalInventoryValue = p.stockQuantity * p.sellingPrice;
    final totalCostValue = p.stockQuantity * p.purchasePrice;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 14),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.isVariable
                                    ? (isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF))
                                    : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: p.isVariable
                                      ? (isDark ? const Color(0xFF7E22CE) : const Color(0xFFD8B4FE))
                                      : (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0)),
                                ),
                              ),
                              child: Text(
                                p.isVariable ? 'Variable Product' : 'Single Product',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: p.isVariable
                                      ? (isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED))
                                      : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${p.sku}  •  Barcode: ${p.barcode} (${p.barcodeType})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Overview Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _statPill(
                            title: 'Purchase Cost',
                            value: '$currency${p.purchasePrice.toStringAsFixed(2)}',
                            subtitle: 'Default supplier cost',
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            bgColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statPill(
                            title: 'Selling Price',
                            value: '$currency${p.sellingPrice.toStringAsFixed(2)}',
                            subtitle: 'Retail list price',
                            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                            bgColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statPill(
                            title: 'Profit Margin',
                            value: '${margin.toStringAsFixed(1)}%',
                            subtitle: '+$currency${unitProfit.toStringAsFixed(2)} profit / unit',
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statPill(
                            title: 'Stock in Hand',
                            value: '${p.stockQuantity.toStringAsFixed(1)} ${p.unit}',
                            subtitle: p.isOutOfStock
                                ? 'Out of Stock'
                                : (p.isLowStock ? 'Low Stock Warning' : 'Optimal Inventory'),
                            color: p.isOutOfStock
                                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                : (p.isLowStock ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)) : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))),
                            bgColor: p.isOutOfStock
                                ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.4) : const Color(0xFFFEF2F2))
                                : (p.isLowStock ? (isDark ? const Color(0xFF451A03).withValues(alpha: 0.4) : const Color(0xFFFFFBEB)) : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4))),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Specification Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'General Specifications',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _specItem('Category', p.categoryName, isDark)),
                              Expanded(child: _specItem('Brand', p.brandName, isDark)),
                              Expanded(child: _specItem('Standard Unit', p.unit, isDark)),
                              Expanded(child: _specItem('Alert Quantity', '${p.alertQuantity} ${p.unit}', isDark)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _specItem(
                                  'Warranty Policy',
                                  p.warranty?.isNotEmpty == true ? p.warranty! : 'No Warranty',
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Batch / Lot Number',
                                  p.batchNumber?.isNotEmpty == true ? p.batchNumber! : 'N/A',
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Expiry Date',
                                  p.expiryDate?.isNotEmpty == true ? p.expiryDate! : 'N/A',
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Bonus Scheme',
                                  (p.bonusQty > 0) ? '+${p.bonusQty} Free Units' : 'None',
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _specItem(
                                  'Inventory Valuation (Cost)',
                                  '$currency${totalCostValue.toStringAsFixed(2)}',
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Inventory Valuation (Retail)',
                                  '$currency${totalInventoryValue.toStringAsFixed(2)}',
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Pack Multiplier',
                                  '${p.packSize} units/pack',
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Status',
                                  p.isOutOfStock ? 'Out of Stock' : (p.isLowStock ? 'Low Stock' : 'Active'),
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // If Variable Product, Show Variations Matrix Table
                    if (p.isVariable) ...[
                      Text(
                        'Product Variations & Sub-SKUs',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_variations.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'No variations recorded yet for this product.',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.0),
                                1: FlexColumnWidth(1.8),
                                2: FlexColumnWidth(1.2),
                                3: FlexColumnWidth(1.2),
                                4: FlexColumnWidth(1.2),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  ),
                                  children: [
                                    _th('Variation / Attribute', isDark),
                                    _th('Sub-SKU', isDark),
                                    _th('Cost Price', isDark),
                                    _th('Selling Price', isDark),
                                    _th('Stock In Hand', isDark),
                                  ],
                                ),
                                ..._variations.map(
                                  (v) => TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                    ),
                                    children: [
                                      _td(v.name, isBold: true, isDark: isDark),
                                      _td(v.subSku, isDark: isDark),
                                      _td('$currency${v.purchasePrice.toStringAsFixed(2)}', isDark: isDark),
                                      _td('$currency${v.sellingPrice.toStringAsFixed(2)}', isPrimary: true, isDark: isDark),
                                      _td('${v.stockQuantity.toStringAsFixed(1)} ${p.unit}', isDark: isDark),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onPrintLabels != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Print Labels'),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onPrintLabels!();
                      },
                    ),
                  const SizedBox(width: 10),
                  if (widget.onEdit != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit!();
                      },
                    ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _specItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '-',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _th(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
    );
  }

  Widget _td(String text, {bool isBold = false, bool isPrimary = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: isPrimary ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)) : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
        ),
      ),
    );
  }
}
