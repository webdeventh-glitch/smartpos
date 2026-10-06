import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

class SellingPriceGroupsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const SellingPriceGroupsScreen({super.key, required this.settings});

  @override
  State<SellingPriceGroupsScreen> createState() => _SellingPriceGroupsScreenState();
}

class _SellingPriceGroupsScreenState extends State<SellingPriceGroupsScreen> {
  List<SellingPriceGroup> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.initialize();
      final list = await db.getSellingPriceGroups();
      if (mounted) {
        setState(() {
          _groups = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog([SellingPriceGroup? group]) {
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    final descCtrl = TextEditingController(text: group?.description ?? '');
    bool isActive = group?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          group != null ? 'Edit Selling Price Group' : 'Add Selling Price Group',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Name
                    _buildFieldLabel('Group Name', isRequired: true),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: _inputDecor('e.g. Wholesale, Distributor, VIP Customer'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildFieldLabel('Description'),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: _inputDecor('e.g. Standard wholesale pricing with 15% discount'),
                    ),
                    const SizedBox(height: 16),

                    // Active Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Active Status',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                              Text(
                                'Enable this price group during billing',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          Switch(
                            value: isActive,
                            activeColor: const Color(0xFF4F46E5),
                            onChanged: (val) => setModalState(() => isActive = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final db = await DatabaseService.initialize();
                            if (group != null) {
                              final updated = SellingPriceGroup(
                                id: group.id,
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                isActive: isActive,
                              );
                              await db.updateSellingPriceGroup(updated);
                            } else {
                              final newG = SellingPriceGroup(
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                isActive: isActive,
                              );
                              await db.addSellingPriceGroup(newG);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadGroups();
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(group != null ? 'Update Group' : 'Save Group'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteGroup(SellingPriceGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Price Group'),
        content: Text('Are you sure you want to delete "${group.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && group.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteSellingPriceGroup(group.id!);
      _loadGroups();
    }
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _groups.where((g) {
      if (_searchQuery.isEmpty) return true;
      return g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final activeCount = _groups.where((g) => g.isActive).length;

    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    final currentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalFiltered);
    final paginatedGroups = (startIndex < totalFiltered) ? filtered.sublist(startIndex, endIndex) : <SellingPriceGroup>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Selling Price Groups',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage tiered pricing rules (Retail, Wholesale, VIP, Franchise)',
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
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Price Group', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metric Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Price Groups',
                    value: '${_groups.length}',
                    icon: Icons.price_change_outlined,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Active Groups',
                    value: '$activeCount',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Inactive Groups',
                    value: '${_groups.length - activeCount}',
                    icon: Icons.pause_circle_outline,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar & Filter
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() {
                        _searchQuery = val.trim();
                        _currentPage = 1;
                      }),
                      decoration: const InputDecoration(
                        hintText: 'Search by group name or description...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                          _currentPage = 1;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Data Table Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.price_change_outlined, size: 48, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty ? 'No price groups found' : 'No matching price groups found',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Click "Add Price Group" to configure tiered prices.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final minWidth = max(constraints.maxWidth, 720.0);
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: minWidth),
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                        columnSpacing: 24,
                                        horizontalMargin: 20,
                                        columns: const [
                                          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('GROUP NAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569)))),
                                        ],
                                        rows: List.generate(paginatedGroups.length, (index) {
                                          final g = paginatedGroups[index];
                                          final itemNum = startIndex + index + 1;
                                          return DataRow(
                                            cells: [
                                              DataCell(Text('$itemNum', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEEF2FF),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Icon(Icons.price_change_outlined, size: 16, color: Color(0xFF4F46E5)),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      g.name,
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  g.description.isNotEmpty ? g.description : '-',
                                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: g.isActive ? const Color(0xFFDEF7EC) : const Color(0xFFFEE2E2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    g.isActive ? 'Active' : 'Inactive',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: g.isActive ? const Color(0xFF03543F) : const Color(0xFF991B1B),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF4F46E5)),
                                                      tooltip: 'Edit Group',
                                                      onPressed: () => _showAddEditDialog(g),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                                      tooltip: 'Delete Group',
                                                      onPressed: () => _deleteGroup(g),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
