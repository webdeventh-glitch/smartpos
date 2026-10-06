import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class PrintLabelsScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Product? initialProduct;

  const PrintLabelsScreen({super.key, required this.settings, this.initialProduct});

  @override
  State<PrintLabelsScreen> createState() => _PrintLabelsScreenState();
}

class _PrintLabelsScreenState extends State<PrintLabelsScreen> {
  List<Product> _allProducts = [];
  final Map<int, int> _selectedProductQuantities = {};
  String _productSearch = '';
  bool _loading = true;

  // Print Settings
  String _paperSize = '24 Labels per Sheet (A4)';
  bool _showBusinessName = true;
  bool _showProductName = true;
  bool _showPrice = true;
  bool _showBarcodeNumber = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getProducts();
    if (mounted) {
      setState(() {
        _allProducts = list;
        _loading = false;
        if (widget.initialProduct != null && widget.initialProduct!.id != null) {
          _selectedProductQuantities[widget.initialProduct!.id!] = 4;
        } else if (list.isNotEmpty) {
          _selectedProductQuantities[list.first.id!] = 4;
        }
      });
    }
  }

  void _addProductToPrint(Product p) {
    if (p.id == null) return;
    setState(() {
      _selectedProductQuantities[p.id!] = (_selectedProductQuantities[p.id!] ?? 0) + 1;
    });
  }

  void _removeProductFromPrint(int id) {
    setState(() {
      _selectedProductQuantities.remove(id);
    });
  }

  Widget _buildBarcodeVisual(String code) {
    // Generates barcode visual pattern based on code string
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(code.length * 3, (index) {
          final isThick = index % 3 == 0;
          final isSpace = index % 5 == 0;
          if (isSpace) return const SizedBox(width: 2);
          return Container(
            width: isThick ? 2.5 : 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 0.8),
            color: Colors.black,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final selectedProducts = _allProducts.where((p) => _selectedProductQuantities.containsKey(p.id)).toList();
    final totalLabelsToPrint = _selectedProductQuantities.values.fold(0, (sum, q) => sum + q);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Print Barcode Labels',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate and print custom barcode sticker labels for shelf placement and stock tagging.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text('Print $totalLabelsToPrint Labels', style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: totalLabelsToPrint == 0
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sent $totalLabelsToPrint barcode labels to printer queue.'),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Two Columns: Select Products & Label Settings
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Selected Products Queue
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Products in Print Queue',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        // Product Search & Add Dropdown
                        Autocomplete<Product>(
                          displayStringForOption: (p) => '${p.name} (${p.sku})',
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                            return _allProducts.where((p) =>
                                p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                p.sku.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                p.barcode.contains(textEditingValue.text));
                          },
                          onSelected: (p) => _addProductToPrint(p),
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Search product to add to print queue...',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        if (selectedProducts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: const Text('No products selected. Search above to add items.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          )
                        else
                          Column(
                            children: selectedProducts.map((p) {
                              final qty = _selectedProductQuantities[p.id] ?? 1;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                          Text('SKU: ${p.sku}  •  $currency${p.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF64748B)),
                                          onPressed: qty > 1
                                              ? () => setState(() => _selectedProductQuantities[p.id!] = qty - 1)
                                              : () => _removeProductFromPrint(p.id!),
                                        ),
                                        Container(
                                          width: 36,
                                          alignment: Alignment.center,
                                          child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF4F46E5)),
                                          onPressed: () => setState(() => _selectedProductQuantities[p.id!] = qty + 1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                          onPressed: () => _removeProductFromPrint(p.id!),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),

                // Right Column: Label Format & Fields Settings
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Label Information & Format',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        const Text('Sheet / Roll Layout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _paperSize,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          items: [
                            '24 Labels per Sheet (A4)',
                            '40 Labels per Sheet (A4)',
                            'Continuous Roll (50mm x 25mm)',
                            'Jewelry Tag (38mm x 15mm)',
                          ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paperSize = val);
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text('Fields to Print on Label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Business Name', style: TextStyle(fontSize: 13)),
                                value: _showBusinessName,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _showBusinessName = v ?? true),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Product Name & Unit', style: TextStyle(fontSize: 13)),
                                value: _showProductName,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _showProductName = v ?? true),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Retail Price (Inc. Tax)', style: TextStyle(fontSize: 13)),
                                value: _showPrice,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _showPrice = v ?? true),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Numeric Barcode / SKU', style: TextStyle(fontSize: 13)),
                                value: _showBarcodeNumber,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _showBarcodeNumber = v ?? true),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottom Section: Live Printable Preview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.preview_rounded, size: 20, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 8),
                          Text(
                            'Live Print Preview ($_paperSize)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$totalLabelsToPrint Sticker Labels to print',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (totalLabelsToPrint == 0)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Text('Add items above to preview printable barcode labels.', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: selectedProducts.expand((p) {
                        final qty = _selectedProductQuantities[p.id] ?? 0;
                        return List.generate(qty, (index) {
                          return Container(
                            width: 210,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black.withOpacity(0.18)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_showBusinessName)
                                  Text(
                                    widget.settings.businessName,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (_showProductName)
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                _buildBarcodeVisual(p.barcode),
                                const SizedBox(height: 2),
                                if (_showBarcodeNumber)
                                  Text(
                                    p.barcode,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                  ),
                                if (_showPrice) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Price: $currency${p.sellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        });
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
