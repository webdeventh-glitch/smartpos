import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

class CategoriesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const CategoriesScreen({super.key, required this.settings});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];
  Map<int, int> _categoryProductCounts = {};
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
    final cats = await db.getCategories();
    final prods = await db.getProducts();

    final counts = <int, int>{};
    for (var p in prods) {
      if (p.categoryId != null) {
        counts[p.categoryId!] = (counts[p.categoryId!] ?? 0) + 1;
      }
    }

    if (mounted) {
      setState(() {
        _categories = cats;
        _categoryProductCounts = counts;
        _loading = false;
      });
    }
  }

  void _openCategoryDialog([Category? toEdit]) {
    final nameCtrl = TextEditingController(text: toEdit?.name ?? '');
    final codeCtrl = TextEditingController(text: toEdit?.code ?? '');
    final descCtrl = TextEditingController(text: toEdit?.description ?? '');
    int? selectedParent = toEdit?.parentId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
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
                        toEdit == null ? 'Add Category' : 'Edit Category',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Category Name *'),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: _inputDeco('e.g. Beverages, Groceries, Bakery')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Category Code *'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: codeCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _inputDeco('e.g. BEV, BAK'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Parent Category (Optional)'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int?>(
                              value: selectedParent,
                              decoration: _inputDeco('None (Top Level)'),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('None (Main Level)')),
                                ..._categories.where((c) => c.id != toEdit?.id).map(
                                      (c) => DropdownMenuItem<int?>(
                                        value: c.id,
                                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                              ],
                              onChanged: (val) => setDlgState(() => selectedParent = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Description'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: _inputDeco('Optional category summary or details'),
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
                          final code = codeCtrl.text.trim().toUpperCase();

                          if (name.isEmpty || code.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter category name and code')),
                            );
                            return;
                          }

                          final db = await DatabaseService.initialize();
                          if (toEdit == null) {
                            await db.addCategory(Category(
                              name: name,
                              code: code,
                              description: descCtrl.text.trim(),
                              parentId: selectedParent,
                            ));
                          } else {
                            await db.updateCategory(Category(
                              id: toEdit.id,
                              name: name,
                              code: code,
                              description: descCtrl.text.trim(),
                              parentId: selectedParent,
                            ));
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                        child: Text(toEdit == null ? 'Save Category' : 'Update Category'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCategory(Category cat) async {
    final prodsCount = _categoryProductCounts[cat.id] ?? 0;
    if (prodsCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Category'),
          content: Text(
            'Category "${cat.name}" has $prodsCount active products associated with it. Please reassign or delete these products first.',
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
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete category "${cat.name}"?'),
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

    if (confirm == true && cat.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteCategory(cat.id!);
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
    final filtered = _categories.where((c) {
      if (_search.isEmpty) return true;
      return c.name.toLowerCase().contains(_search) || c.code.toLowerCase().contains(_search) || (c.description ?? '').toLowerCase().contains(_search);
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    final currentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalFiltered);
    final paginatedCategories = (startIndex < totalFiltered) ? filtered.sublist(startIndex, endIndex) : <Category>[];

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
                        'Categories & Sub-Categories',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organize products into hierarchical departments, categories, and sub-groups.',
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
                  label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _openCategoryDialog(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
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
                      onChanged: (val) => setState(() {
                        _search = val.trim().toLowerCase();
                        _currentPage = 1;
                      }),
                      decoration: InputDecoration(
                        hintText: 'Search categories by name, code, or description...',
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
                      '${filtered.length} Categories',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Categories Table
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
                    Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No Categories Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Click "Add Category" above to organize your catalog.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                          final minWidth = max(constraints.maxWidth, 840.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.5),
                                  1: FlexColumnWidth(1.4),
                                  2: FlexColumnWidth(1.8),
                                  3: FlexColumnWidth(2.5),
                                  4: FlexColumnWidth(1.2),
                                  5: FlexColumnWidth(1.4),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Category Name'),
                                      _th('Short Code'),
                                      _th('Hierarchy Level'),
                                      _th('Description'),
                                      _th('Products'),
                                      _th('Actions', alignRight: true),
                                    ],
                                  ),
                                  ...paginatedCategories.map((c) {
                                    final count = _categoryProductCounts[c.id] ?? 0;
                                    final isSub = c.parentId != null;
                                    String parentName = '';
                                    if (isSub) {
                                      final parent = _categories.firstWhere((p) => p.id == c.parentId, orElse: () => Category(name: 'Main', code: ''));
                                      parentName = parent.name;
                                    }

                                    return TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: isSub ? const Color(0xFFF1F5F9) : const Color(0xFFEEF2FF),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  isSub ? Icons.subdirectory_arrow_right_rounded : Icons.folder_rounded,
                                                  size: 16,
                                                  color: isSub ? const Color(0xFF64748B) : const Color(0xFF4F46E5),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  c.name,
                                                  style: TextStyle(
                                                    fontWeight: isSub ? FontWeight.w600 : FontWeight.w700,
                                                    fontSize: 13,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(c.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155))),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            isSub ? 'Sub ($parentName)' : 'Main Category',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isSub ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            c.description?.isNotEmpty == true ? c.description! : '-',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            '$count Items',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: count > 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit Category',
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                                                onPressed: () => _openCategoryDialog(c),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete Category',
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                onPressed: () => _deleteCategory(c),
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
