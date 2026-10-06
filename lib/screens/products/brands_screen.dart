import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

class BrandsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const BrandsScreen({super.key, required this.settings});

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  List<Brand> _brands = [];
  Map<int, int> _brandProductCounts = {};
  String _search = '';
  bool _loading = true;
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final brs = await db.getBrands();
    final prods = await db.getProducts();

    final counts = <int, int>{};
    for (var p in prods) {
      if (p.brandId != null) {
        counts[p.brandId!] = (counts[p.brandId!] ?? 0) + 1;
      }
    }

    if (mounted) {
      setState(() {
        _brands = brs;
        _brandProductCounts = counts;
        _loading = false;
      });
    }
  }

  void _openBrandDialog([Brand? brandToEdit]) {
    final nameCtrl = TextEditingController(text: brandToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: brandToEdit?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      brandToEdit == null ? 'Add Brand' : 'Edit Brand',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _fieldLabel('Brand Name *'),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: _inputDeco('e.g. Coca-Cola, Samsung, Nestle'),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Short Description'),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: _inputDeco('Optional notes or brand details'),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter brand name')),
                          );
                          return;
                        }

                        final db = await DatabaseService.initialize();
                        if (brandToEdit == null) {
                          await db.addBrand(Brand(name: name, description: descCtrl.text.trim()));
                        } else {
                          await db.updateBrand(Brand(
                            id: brandToEdit.id,
                            name: name,
                            description: descCtrl.text.trim(),
                          ));
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      child: Text(brandToEdit == null ? 'Save Brand' : 'Update Brand'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBrand(Brand brand) async {
    final prodsCount = _brandProductCounts[brand.id] ?? 0;
    if (prodsCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Brand'),
          content: Text(
            'Brand "${brand.name}" has $prodsCount active products associated with it. Please reassign or delete these products before deleting the brand.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Brand?'),
        content: Text('Are you sure you want to permanently delete "${brand.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && brand.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteBrand(brand.id!);
      _load();
    }
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _brands.where((b) {
      if (_search.isEmpty) return true;
      return b.name.toLowerCase().contains(_search) || (b.description ?? '').toLowerCase().contains(_search);
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = max(1, (totalFiltered / _pageSize).ceil());
    final currentPage = _currentPage > totalPages ? totalPages : _currentPage;
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = min(totalFiltered, startIndex + _pageSize);
    final paginatedBrands = totalFiltered > 0 ? filtered.sublist(startIndex, endIndex) : <Brand>[];

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
                        'Brands Management',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage manufacturers, labels, and brands for product categorization.',
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
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Brand', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _openBrandDialog(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search brand name or notes...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filtered.length} Brands found',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Brands Data Table
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.branding_watermark_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No Brands Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Click "Add Brand" above to register your first brand.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final minWidth = max(constraints.maxWidth, 720.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.5),
                                  1: FlexColumnWidth(3.5),
                                  2: FlexColumnWidth(1.5),
                                  3: FlexColumnWidth(1.5),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Brand Name'),
                                      _th('Description'),
                                      _th('Products Linked'),
                                      _th('Actions', alignRight: true),
                                    ],
                                  ),
                                  ...paginatedBrands.map((b) {
                                    final count = _brandProductCounts[b.id] ?? 0;
                                    return TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: const Color(0xFFEEF2FF),
                                                child: Text(
                                                  b.name.isNotEmpty ? b.name[0].toUpperCase() : 'B',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                b.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            b.description?.isNotEmpty == true ? b.description! : '-',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: count > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '$count Items',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: count > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit Brand',
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                                                onPressed: () => _openBrandDialog(b),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete Brand',
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                onPressed: () => _deleteBrand(b),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    DataTablePaginationBar(
                      currentPage: currentPage,
                      pageSize: _pageSize,
                      totalItems: totalFiltered,
                      onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                      onPageSizeChanged: (newSize) => setState(() {
                        _pageSize = newSize;
                        _currentPage = 1;
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _th(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
      ),
    );
  }
}
