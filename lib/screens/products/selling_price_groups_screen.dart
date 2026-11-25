import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

class SellingPriceGroupsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const SellingPriceGroupsScreen({super.key, required this.settings});

  @override
  State<SellingPriceGroupsScreen> createState() =>
      _SellingPriceGroupsScreenState();
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                          group != null
                              ? PosLocalization.tr('Edit Selling Price Group',
                                  settings: widget.settings)
                              : PosLocalization.tr('Add Selling Price Group',
                                  settings: widget.settings),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close,
                              size: 20,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Name
                    _buildFieldLabel(
                        PosLocalization.tr('Group Name',
                            settings: widget.settings),
                        isRequired: true,
                        isDark: isDark),
                    TextFormField(
                      controller: nameCtrl,
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: _inputDecor(
                          PosLocalization.tr(
                              'e.g. Wholesale, Distributor, VIP Customer',
                              settings: widget.settings),
                          isDark: isDark),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? PosLocalization.tr('Please enter a name',
                              settings: widget.settings)
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildFieldLabel(
                        PosLocalization.tr('Description',
                            settings: widget.settings),
                        isDark: isDark),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: _inputDecor(
                          PosLocalization.tr(
                              'e.g. Standard wholesale pricing with 15% discount',
                              settings: widget.settings),
                          isDark: isDark),
                    ),
                    const SizedBox(height: 16),

                    // Active Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                PosLocalization.tr('Active Status',
                                    settings: widget.settings),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                PosLocalization.tr(
                                    'Enable this price group during billing',
                                    settings: widget.settings),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: isActive,
                            activeThumbColor: const Color(0xFF6366F1),
                            onChanged: (val) =>
                                setModalState(() => isActive = val),
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
                            foregroundColor: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(PosLocalization.tr('Cancel',
                              settings: widget.settings)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
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
                          label: Text(group != null
                              ? PosLocalization.tr('Update Group',
                                  settings: widget.settings)
                              : PosLocalization.tr('Save Group',
                                  settings: widget.settings)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
            PosLocalization.tr('Delete Price Group', settings: widget.settings),
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A))),
        content: Text(
            PosLocalization.trParams(
                'Are you sure you want to delete "{name}"?',
                {'name': group.name},
                settings: widget.settings),
            style: TextStyle(
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(PosLocalization.tr('Cancel', settings: widget.settings),
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(PosLocalization.tr('Delete', settings: widget.settings)),
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

  Widget _buildFieldLabel(String label,
      {bool isRequired = false, bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint, {bool isDark = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.5),
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
    final paginatedGroups = (startIndex < totalFiltered)
        ? filtered.sublist(startIndex, endIndex)
        : <SellingPriceGroup>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
                    children: [
                      Text(
                        PosLocalization.tr('Selling Price Groups',
                            settings: widget.settings),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PosLocalization.tr(
                            'Manage tiered pricing rules (Retail, Wholesale, VIP, Franchise)',
                            settings: widget.settings),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                      PosLocalization.tr('Add Price Group',
                          settings: widget.settings),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metric Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: PosLocalization.tr('Total Price Groups',
                        settings: widget.settings),
                    value: '${_groups.length}',
                    icon: Icons.price_change_outlined,
                    color: const Color(0xFF4F46E5),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: PosLocalization.tr('Active Groups',
                        settings: widget.settings),
                    value: '$activeCount',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: PosLocalization.tr('Inactive Groups',
                        settings: widget.settings),
                    value: '${_groups.length - activeCount}',
                    icon: Icons.pause_circle_outline,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar & Filter
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A)),
                      onChanged: (val) => setState(() {
                        _searchQuery = val.trim();
                        _currentPage = 1;
                      }),
                      decoration: InputDecoration(
                        hintText: PosLocalization.tr(
                            'Search by group name or description...',
                            settings: widget.settings),
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF94A3B8)),
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
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
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
                                Icon(Icons.price_change_outlined,
                                    size: 48,
                                    color: isDark
                                        ? const Color(0xFF475569)
                                        : const Color(0xFFCBD5E1)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? PosLocalization.tr(
                                          'No price groups found',
                                          settings: widget.settings)
                                      : PosLocalization.tr(
                                          'No matching price groups found',
                                          settings: widget.settings),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  PosLocalization.tr(
                                      'Click "Add Price Group" to configure tiered prices.',
                                      settings: widget.settings),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10)),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final minWidth =
                                      max(constraints.maxWidth, 720.0);
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints:
                                          BoxConstraints(minWidth: minWidth),
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(isDark
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFFF8FAFC)),
                                        columnSpacing: 24,
                                        horizontalMargin: 20,
                                        columns: [
                                          DataColumn(
                                              label: Text('#',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF475569)))),
                                          DataColumn(
                                              label: Text(
                                                  PosLocalization.tr(
                                                      'GROUP NAME',
                                                      settings:
                                                          widget.settings),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF475569)))),
                                          DataColumn(
                                              label: Text(
                                                  PosLocalization.tr(
                                                      'DESCRIPTION',
                                                      settings:
                                                          widget.settings),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF475569)))),
                                          DataColumn(
                                              label: Text(
                                                  PosLocalization.tr('STATUS',
                                                      settings:
                                                          widget.settings),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF475569)))),
                                          DataColumn(
                                              label: Text(
                                                  PosLocalization.tr('ACTIONS',
                                                      settings:
                                                          widget.settings),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF475569)))),
                                        ],
                                        rows: List.generate(
                                            paginatedGroups.length, (index) {
                                          final g = paginatedGroups[index];
                                          final itemNum =
                                              startIndex + index + 1;
                                          return DataRow(
                                            cells: [
                                              DataCell(Text('$itemNum',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF64748B)))),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? const Color(
                                                                    0xFF312E81)
                                                                .withValues(
                                                                    alpha: 0.4)
                                                            : const Color(
                                                                0xFFEEF2FF),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Icon(
                                                          Icons
                                                              .price_change_outlined,
                                                          size: 16,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF818CF8)
                                                              : const Color(
                                                                  0xFF4F46E5)),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      g.name,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isDark
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF0F172A),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  g.description.isNotEmpty
                                                      ? g.description
                                                      : '-',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF64748B)),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: g.isActive
                                                        ? (isDark
                                                            ? const Color(
                                                                    0xFF064E3B)
                                                                .withValues(
                                                                    alpha: 0.5)
                                                            : const Color(
                                                                0xFFDEF7EC))
                                                        : (isDark
                                                            ? const Color(
                                                                    0xFF450A0A)
                                                                .withValues(
                                                                    alpha: 0.5)
                                                            : const Color(
                                                                0xFFFEE2E2)),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    g.isActive
                                                        ? PosLocalization.tr(
                                                            'Active',
                                                            settings:
                                                                widget.settings)
                                                        : PosLocalization.tr(
                                                            'Inactive',
                                                            settings: widget
                                                                .settings),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: g.isActive
                                                          ? (isDark
                                                              ? const Color(
                                                                  0xFF34D399)
                                                              : const Color(
                                                                  0xFF03543F))
                                                          : (isDark
                                                              ? const Color(
                                                                  0xFFF87171)
                                                              : const Color(
                                                                  0xFF991B1B)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                          Icons.edit_outlined,
                                                          size: 16,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF818CF8)
                                                              : const Color(
                                                                  0xFF4F46E5)),
                                                      tooltip:
                                                          PosLocalization.tr(
                                                              'Edit Group',
                                                              settings: widget
                                                                  .settings),
                                                      onPressed: () =>
                                                          _showAddEditDialog(g),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 16,
                                                          color: Color(
                                                              0xFFEF4444)),
                                                      tooltip:
                                                          PosLocalization.tr(
                                                              'Delete Group',
                                                              settings: widget
                                                                  .settings),
                                                      onPressed: () =>
                                                          _deleteGroup(g),
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
                              onPageChanged: (newPage) =>
                                  setState(() => _currentPage = newPage),
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
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
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
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
