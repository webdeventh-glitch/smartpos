import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class CategoriesBrandsScreen extends StatefulWidget {
  const CategoriesBrandsScreen({super.key});

  @override
  State<CategoriesBrandsScreen> createState() => _CategoriesBrandsScreenState();
}

class _CategoriesBrandsScreenState extends State<CategoriesBrandsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Category> _categories = [];
  List<Brand> _brands = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final cats = await db.getCategories();
    final brs = await db.getBrands();
    if (mounted) {
      setState(() {
        _categories = cats;
        _brands = brs;
        _loading = false;
      });
    }
  }

  void _showAddCategory() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name *', isDense: true)),
            const SizedBox(height: 12),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Short Code * (e.g. BEV)', isDense: true)),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = await DatabaseService.initialize();
              await db.addCategory(Category(name: nameCtrl.text.trim(), code: codeCtrl.text.trim().toUpperCase(), description: descCtrl.text.trim()));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save Category'),
          ),
        ],
      ),
    );
  }

  void _showAddBrand() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Brand'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Brand Name *', isDense: true)),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = await DatabaseService.initialize();
              await db.addBrand(Brand(name: nameCtrl.text.trim(), description: descCtrl.text.trim()));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save Brand'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories & Brands',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organize your store catalog into item classifications and brand manufacturers.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF004EEB),
                        side: const BorderSide(color: Color(0xFF004EEB)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Brand'),
                      onPressed: _showAddBrand,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004EEB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Category'),
                      onPressed: _showAddCategory,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF004EEB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF004EEB),
              tabs: [
                Tab(text: 'Categories (${_categories.length})'),
                Tab(text: 'Brands (${_brands.length})'),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Categories Tab
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = _categories[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(c.code, style: const TextStyle(color: Color(0xFF004EEB), fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(c.description ?? 'No description', style: const TextStyle(fontSize: 12)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              );
                            },
                          ),
                  ),

                  // Brands Tab
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: _brands.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final b = _brands[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFF0FDF4),
                                  child: Text(b.name.isNotEmpty ? b.name[0] : 'B', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                ),
                                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(b.description ?? 'No description', style: const TextStyle(fontSize: 12)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              );
                            },
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
