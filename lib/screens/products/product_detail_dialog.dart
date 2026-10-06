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
    final p = widget.product;
    final currency = widget.settings.currencySymbol;
    final margin = p.purchasePrice > 0
        ? (((p.sellingPrice - p.purchasePrice) / p.purchasePrice) * 100)
        : 0.0;
    final unitProfit = p.sellingPrice - p.purchasePrice;
    final totalInventoryValue = p.stockQuantity * p.sellingPrice;
    final totalCostValue = p.stockQuantity * p.purchasePrice;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF4F46E5), size: 24),
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.isVariable ? const Color(0xFFF3E8FF) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: p.isVariable ? const Color(0xFFD8B4FE) : const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Text(
                                p.isVariable ? 'Variable Product' : 'Single Product',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: p.isVariable ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${p.sku}  •  Barcode: ${p.barcode} (${p.barcodeType})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
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
                            color: const Color(0xFF0F172A),
                            bgColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statPill(
                            title: 'Selling Price',
                            value: '$currency${p.sellingPrice.toStringAsFixed(2)}',
                            subtitle: 'Retail list price',
                            color: const Color(0xFF4F46E5),
                            bgColor: const Color(0xFFEEF2FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statPill(
                            title: 'Profit Margin',
                            value: '${margin.toStringAsFixed(1)}%',
                            subtitle: '+$currency${unitProfit.toStringAsFixed(2)} profit / unit',
                            color: const Color(0xFF059669),
                            bgColor: const Color(0xFFECFDF5),
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
                                ? const Color(0xFFDC2626)
                                : (p.isLowStock ? const Color(0xFFD97706) : const Color(0xFF059669)),
                            bgColor: p.isOutOfStock
                                ? const Color(0xFFFEF2F2)
                                : (p.isLowStock ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Specification Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'General Specifications',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _specItem('Category', p.categoryName)),
                              Expanded(child: _specItem('Brand', p.brandName)),
                              Expanded(child: _specItem('Standard Unit', p.unit)),
                              Expanded(child: _specItem('Alert Quantity', '${p.alertQuantity} ${p.unit}')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _specItem(
                                  'Warranty Policy',
                                  p.warranty?.isNotEmpty == true ? p.warranty! : 'No Warranty',
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Inventory Valuation (Cost)',
                                  '$currency${totalCostValue.toStringAsFixed(2)}',
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Inventory Valuation (Retail)',
                                  '$currency${totalInventoryValue.toStringAsFixed(2)}',
                                ),
                              ),
                              Expanded(
                                child: _specItem(
                                  'Status',
                                  p.isOutOfStock ? 'Out of Stock' : (p.isLowStock ? 'Low Stock' : 'Active'),
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
                      const Text(
                        'Product Variations & Sub-SKUs',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_variations.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text('No variations recorded yet for this product.'),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                  children: [
                                    _th('Variation / Attribute'),
                                    _th('Sub-SKU'),
                                    _th('Cost Price'),
                                    _th('Selling Price'),
                                    _th('Stock In Hand'),
                                  ],
                                ),
                                ..._variations.map(
                                  (v) => TableRow(
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    children: [
                                      _td(v.name, isBold: true),
                                      _td(v.subSku),
                                      _td('$currency${v.purchasePrice.toStringAsFixed(2)}'),
                                      _td('$currency${v.sellingPrice.toStringAsFixed(2)}', isPrimary: true),
                                      _td('${v.stockQuantity.toStringAsFixed(1)} ${p.unit}'),
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                color: Color(0xFFF8FAFC),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onPrintLabels != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                    child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _specItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '-',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
      ),
    );
  }

  Widget _td(String text, {bool isBold = false, bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: isPrimary ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
        ),
      ),
    );
  }
}
