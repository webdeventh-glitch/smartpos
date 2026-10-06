import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class ImportProductsScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onImportSuccess;

  const ImportProductsScreen({super.key, required this.settings, this.onImportSuccess});

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends State<ImportProductsScreen> {
  final TextEditingController _csvInputCtrl = TextEditingController();
  List<Map<String, String>> _parsedRows = [];
  bool _isImporting = false;
  String? _statusMessage;
  bool _isSuccess = false;

  final String _sampleCsv = '''Product Name,Category,Brand,Unit,SKU,Purchase Price,Margin %,Selling Price,Opening Stock,Alert Qty
Samsung Galaxy Buds 2,Electronics,Samsung,Pc,ELEC-501,85.00,20,102.00,25,5
Organic Green Tea 250g,Groceries,Lipton,Box,GROC-201,4.50,30,5.85,50,10
Logitech MX Master 3S,Electronics,Logitech,Pc,ELEC-502,75.00,25,93.75,15,3
Whole Wheat Bread 400g,Groceries,Bakery,Pc,GROC-202,1.80,25,2.25,40,8
Sony WH-1000XM5,Electronics,Sony,Pc,ELEC-503,260.00,20,312.00,10,2''';

  @override
  void initState() {
    super.initState();
    _csvInputCtrl.text = _sampleCsv;
    _parseCsv(_sampleCsv);
  }

  @override
  void dispose() {
    _csvInputCtrl.dispose();
    super.dispose();
  }

  void _parseCsv(String content) {
    final lines = content.trim().split('\n');
    if (lines.length <= 1) {
      setState(() => _parsedRows = []);
      return;
    }

    final headers = lines.first.split(',').map((h) => h.trim()).toList();
    final List<Map<String, String>> rows = [];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final values = line.split(',').map((v) => v.trim()).toList();
      final map = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        map[headers[j]] = j < values.length ? values[j] : '';
      }
      rows.add(map);
    }

    setState(() {
      _parsedRows = rows;
      _statusMessage = null;
    });
  }

  Future<void> _executeImport() async {
    if (_parsedRows.isEmpty) return;
    setState(() {
      _isImporting = true;
      _statusMessage = null;
    });

    try {
      final db = await DatabaseService.initialize();
      final cats = await db.getCategories();
      final brs = await db.getBrands();

      int importedCount = 0;
      for (var row in _parsedRows) {
        final name = row['Product Name'] ?? 'Unnamed Product';
        if (name.trim().isEmpty) continue;

        final catName = row['Category'] ?? 'General';
        final brandName = row['Brand'] ?? 'Standard';
        final unit = row['Unit'] ?? 'Pc';
        final sku = (row['SKU']?.isNotEmpty == true) ? row['SKU']! : 'IMP-${Random().nextInt(99999)}';
        final purchase = double.tryParse(row['Purchase Price'] ?? '0') ?? 0.0;
        final sell = double.tryParse(row['Selling Price'] ?? '0') ?? (purchase * 1.25);
        final stock = double.tryParse(row['Opening Stock'] ?? '0') ?? 10.0;
        final alert = double.tryParse(row['Alert Qty'] ?? '5') ?? 5.0;

        final cat = cats.where((c) => c.name.toLowerCase() == catName.toLowerCase()).firstOrNull;
        final brand = brs.where((b) => b.name.toLowerCase() == brandName.toLowerCase()).firstOrNull;

        final product = Product(
          name: name,
          sku: sku,
          barcode: sku,
          type: 'single',
          barcodeType: 'Code 128',
          categoryId: cat?.id,
          categoryName: catName,
          brandId: brand?.id,
          brandName: brandName,
          unit: unit,
          purchasePrice: purchase,
          sellingPrice: sell,
          stockQuantity: stock,
          alertQuantity: alert,
          imageColor: '#4F46E5',
        );

        await db.insertProduct(product);
        importedCount++;
      }

      setState(() {
        _isImporting = false;
        _isSuccess = true;
        _statusMessage = 'Successfully imported $importedCount products into inventory!';
      });

      if (widget.onImportSuccess != null) {
        Future.delayed(const Duration(seconds: 1), widget.onImportSuccess!);
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _isSuccess = false;
        _statusMessage = 'Error importing products: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Import Products',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Bulk upload products from CSV or spreadsheet template',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _isImporting || _parsedRows.isEmpty ? null : _executeImport,
                  icon: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_upload_outlined, size: 16),
                  label: Text(_isImporting ? 'Importing...' : 'Import ${_parsedRows.length} Products'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Notification Banner if any
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isSuccess ? const Color(0xFFDEF7EC) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isSuccess ? const Color(0xFF31C48D) : const Color(0xFFF87171)),
                ),
                child: Row(
                  children: [
                    Icon(_isSuccess ? Icons.check_circle : Icons.error, color: _isSuccess ? const Color(0xFF03543F) : const Color(0xFF991B1B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isSuccess ? const Color(0xFF03543F) : const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Step 1: Instructions & CSV Formatting Guide
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, size: 20, color: Color(0xFF4F46E5)),
                      SizedBox(width: 10),
                      Text('Instructions & Column Mapping', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. The first line of the CSV must contain column headers.\n'
                    '2. Required columns: "Product Name", "Purchase Price", "Selling Price".\n'
                    '3. Optional columns: "Category", "Brand", "Unit", "SKU", "Opening Stock", "Alert Qty".\n'
                    '4. If SKU is left blank, a unique SKU will automatically be generated.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFFC7D2FE)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          _csvInputCtrl.text = _sampleCsv;
                          _parseCsv(_sampleCsv);
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset Sample Data'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 2: CSV Text / Data Editor
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paste CSV Text', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  const Text('You can paste data copied directly from Excel, Google Sheets, or a .csv file:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _csvInputCtrl,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    onChanged: (val) => _parseCsv(val),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 3: Parsed Data Live Preview
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Data Preview (${_parsedRows.length} Items Found)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                          child: Text('${_parsedRows.length} ready to import', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _parsedRows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No valid rows parsed. Please paste CSV data above.', style: TextStyle(color: Color(0xFF94A3B8)))),
                        )
                      : ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              columnSpacing: 20,
                              horizontalMargin: 20,
                              columns: const [
                                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                DataColumn(label: Text('PRODUCT NAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                DataColumn(label: Text('BRAND', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                DataColumn(label: Text('PURCHASE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                DataColumn(label: Text('SELLING', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                DataColumn(label: Text('STOCK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                              ],
                              rows: List.generate(_parsedRows.length, (index) {
                                final row = _parsedRows[index];
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                    DataCell(Text(row['Product Name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                                    DataCell(Text(row['SKU'] ?? 'Auto', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                    DataCell(Text(row['Category'] ?? 'General', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                    DataCell(Text(row['Brand'] ?? 'Standard', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                    DataCell(Text('$currency${row['Purchase Price'] ?? '0.00'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                    DataCell(Text('$currency${row['Selling Price'] ?? '0.00'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981)))),
                                    DataCell(Text(row['Opening Stock'] ?? '0', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)))),
                                  ],
                                );
                              }),
                            ),
                          ),
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
