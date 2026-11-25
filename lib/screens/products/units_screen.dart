import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/database_schema.dart';
import '../../widgets/data_table_pagination_bar.dart';

class UnitsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const UnitsScreen({super.key, required this.settings});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  List<Unit> _units = [];
  String _search = '';
  String _selectedCategory = 'all';
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
    var uList = await db.getUnits();
    // Auto-seed full 5-category catalog if only initial legacy units exist
    if (uList.length <= 4) {
      await DatabaseSchema.seedFiveUnitCategories(db.db);
      uList = await db.getUnits();
    }
    if (mounted) {
      setState(() {
        _units = uList;
        _loading = false;
      });
    }
  }

  void _openUnitDialog([Unit? toEdit]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: toEdit?.actualName ?? '');
    final shortCtrl = TextEditingController(text: toEdit?.shortName ?? '');
    final multCtrl = TextEditingController(
        text: toEdit?.baseUnitMultiplier != null &&
                toEdit!.baseUnitMultiplier != 1.0
            ? toEdit.baseUnitMultiplier.toString()
            : '1');
    bool allowDecimal = toEdit?.allowDecimal ?? false;
    int? selectedBaseUnit = toEdit?.baseUnitId;
    String selectedCategory = toEdit?.category ??
        (_selectedCategory != 'all' ? _selectedCategory : 'count');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                        toEdit == null
                            ? 'Add Unit of Measure'
                            : 'Edit Unit of Measure',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 20,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Category / پیمائش کی قسم *', isDark),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: _inputDeco('Select Category', isDark),
                    items: const [
                      DropdownMenuItem(
                        value: 'count',
                        child: Text(
                            '1. Count (گنتی - Pieces, Dozen, Box, Strips)'),
                      ),
                      DropdownMenuItem(
                        value: 'weight',
                        child:
                            Text('2. Weight (وزن - Kg, Gram, Pao, Mann, Bori)'),
                      ),
                      DropdownMenuItem(
                        value: 'volume',
                        child:
                            Text('3. Volume (مائع - Liter, ML, Bottle, Can)'),
                      ),
                      DropdownMenuItem(
                        value: 'length',
                        child: Text(
                            '4. Length / Area (لمبائی و رقبہ - Meter, Ft, Coil, Sq Ft)'),
                      ),
                      DropdownMenuItem(
                        value: 'time',
                        child: Text(
                            '5. Time / Services (وقت و سروسز - Hour, Min, Session)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() {
                          selectedCategory = val;
                          selectedBaseUnit = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Unit Name * (e.g. Pieces, Kilograms, Box, Coil)',
                      isDark),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration:
                        _inputDeco('e.g. Pieces / Coil (90 Mtr)', isDark),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel(
                                'Short Name * (e.g. Pc, Kg, Coil)', isDark),
                            const SizedBox(height: 6),
                            TextField(
                              controller: shortCtrl,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                              decoration: _inputDeco('e.g. Pc', isDark),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Allow Decimal Values?', isDark),
                            const SizedBox(height: 6),
                            Container(
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Switch(
                                    value: allowDecimal,
                                    activeThumbColor: const Color(0xFF4F46E5),
                                    onChanged: (val) =>
                                        setDlgState(() => allowDecimal = val),
                                  ),
                                  Text(
                                    allowDecimal
                                        ? 'Yes (1.5 kg)'
                                        : 'No (Integers)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Secondary Unit / Base Unit Multiplier section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sub-Unit Multiplier (Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'e.g. If unit is "Coil (90 Mtr)" and base unit is "Meters", set multiplier to 90.0',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int?>(
                                initialValue: selectedBaseUnit,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A)),
                                decoration: _inputDeco('Base Unit', isDark),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('None (Primary Base Unit)',
                                        style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A))),
                                  ),
                                  ..._units
                                      .where((u) =>
                                          u.id != toEdit?.id &&
                                          (u.category == selectedCategory ||
                                              u.baseUnitId == null))
                                      .map((u) => DropdownMenuItem<int?>(
                                          value: u.id,
                                          child: Text(
                                              '${u.actualName} (${u.shortName})',
                                              style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(
                                                          0xFF0F172A))))),
                                ],
                                onChanged: (val) =>
                                    setDlgState(() => selectedBaseUnit = val),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: multCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A)),
                                decoration: _inputDeco('Multiplier', isDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final short = shortCtrl.text.trim();
                          final mult =
                              double.tryParse(multCtrl.text.trim()) ?? 1.0;

                          if (name.isEmpty || short.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please fill unit name and short name')),
                            );
                            return;
                          }

                          final db = await DatabaseService.initialize();
                          if (toEdit == null) {
                            await db.addUnit(Unit(
                              actualName: name,
                              shortName: short,
                              allowDecimal: allowDecimal,
                              baseUnitId: selectedBaseUnit,
                              baseUnitMultiplier: mult,
                              category: selectedCategory,
                            ));
                          } else {
                            await db.updateUnit(Unit(
                              id: toEdit.id,
                              actualName: name,
                              shortName: short,
                              allowDecimal: allowDecimal,
                              baseUnitId: selectedBaseUnit,
                              baseUnitMultiplier: mult,
                              category: selectedCategory,
                            ));
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                        child:
                            Text(toEdit == null ? 'Save Unit' : 'Update Unit'),
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

  Future<void> _deleteUnit(Unit unit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit?'),
        content:
            Text('Are you sure you want to delete unit "${unit.actualName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && unit.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteUnit(unit.id!);
      _load();
    }
  }

  Widget _fieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }

  Widget _buildCategoryBadge(String category, bool isDark) {
    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    switch (category.toLowerCase()) {
      case 'weight':
        bg = isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
            : const Color(0xFFECFDF5);
        border = isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0);
        text = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        label = 'Weight (وزن)';
        icon = Icons.scale_rounded;
        break;
      case 'volume':
        bg = isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
            : const Color(0xFFEFF6FF);
        border = isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE);
        text = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
        label = 'Volume (مائع)';
        icon = Icons.water_drop_rounded;
        break;
      case 'length':
        bg = isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.4)
            : const Color(0xFFFFFBEB);
        border = isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
        text = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        label = 'Length / Area';
        icon = Icons.straighten_rounded;
        break;
      case 'time':
        bg = isDark
            ? const Color(0xFF134E4A).withValues(alpha: 0.4)
            : const Color(0xFFF0FDFA);
        border = isDark ? const Color(0xFF0F766E) : const Color(0xFF99F6E4);
        text = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
        label = 'Services (وقت)';
        icon = Icons.schedule_rounded;
        break;
      case 'count':
      default:
        bg = isDark
            ? const Color(0xFF4C1D95).withValues(alpha: 0.4)
            : const Color(0xFFFAF5FF);
        border = isDark ? const Color(0xFF6D28D9) : const Color(0xFFDDD6FE);
        text = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
        label = 'Count (گنتی)';
        icon = Icons.tag_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _units.where((u) {
      if (_selectedCategory != 'all' &&
          u.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_search.isEmpty) return true;
      return u.actualName.toLowerCase().contains(_search) ||
          u.shortName.toLowerCase().contains(_search) ||
          u.category.toLowerCase().contains(_search);
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    final currentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalFiltered);
    final paginatedUnits = (startIndex < totalFiltered)
        ? filtered.sublist(startIndex, endIndex)
        : <Unit>[];

    final categoryTabs = [
      {
        'key': 'all',
        'label': 'All Units',
        'urdu': 'تمام',
        'icon': Icons.tune_rounded
      },
      {
        'key': 'count',
        'label': '1. Count',
        'urdu': 'گنتی',
        'icon': Icons.tag_rounded
      },
      {
        'key': 'weight',
        'label': '2. Weight',
        'urdu': 'وزن',
        'icon': Icons.scale_rounded
      },
      {
        'key': 'volume',
        'label': '3. Volume',
        'urdu': 'مائع',
        'icon': Icons.water_drop_rounded
      },
      {
        'key': 'length',
        'label': '4. Length / Area',
        'urdu': 'لمبائی/رقبہ',
        'icon': Icons.straighten_rounded
      },
      {
        'key': 'time',
        'label': '5. Time / Services',
        'urdu': 'وقت/سروسز',
        'icon': Icons.schedule_rounded
      },
    ];

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
                      Text(
                        'Units of Measure (پیمائشی یونٹس)',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Define measurement units (Count, Weight, Volume, Length/Area, Time/Services) with multipliers & decimal allowances.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
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
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Unit',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _openUnitDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Filter Tabs Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categoryTabs.map((tab) {
                  final key = tab['key'] as String;
                  final isSelected = _selectedCategory == key;
                  final count = key == 'all'
                      ? _units.length
                      : _units
                          .where((u) => u.category.toLowerCase() == key)
                          .length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _selectedCategory = key;
                          _currentPage = 1;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1)),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab['icon'] as IconData,
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${tab['label']} (${tab['urdu']})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A)),
                      onChanged: (val) => setState(() {
                        _search = val.trim().toLowerCase();
                        _currentPage = 1;
                      }),
                      decoration: InputDecoration(
                        hintText:
                            'Search measurement units by name or short code...',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF94A3B8)),
                        isDense: true,
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF0F172A) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0))),
                        focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(
                                color: Color(0xFF4F46E5), width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF312E81).withValues(alpha: 0.4)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF4338CA)
                              : const Color(0xFFC7D2FE)),
                    ),
                    child: Text(
                      '${filtered.length} Units available',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF818CF8)
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Units Data Table
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.straighten_outlined,
                        size: 48,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No Units Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click "Add Unit" to configure measurement units.',
                      style: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                          fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : const Color(0x04000000),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final minWidth = max(constraints.maxWidth, 780.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.3),
                                  1: FlexColumnWidth(1.2),
                                  2: FlexColumnWidth(1.6),
                                  3: FlexColumnWidth(1.4),
                                  4: FlexColumnWidth(1.7),
                                  5: FlexColumnWidth(1.2),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Unit Name', isDark: isDark),
                                      _th('Short Name', isDark: isDark),
                                      _th('Category (قسم)', isDark: isDark),
                                      _th('Allow Decimals', isDark: isDark),
                                      _th('Multiplier / Base', isDark: isDark),
                                      _th('Actions',
                                          alignRight: true, isDark: isDark),
                                    ],
                                  ),
                                  ...paginatedUnits.map((u) {
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        border: Border(
                                            top: BorderSide(
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0))),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF312E81)
                                                          .withValues(
                                                              alpha: 0.4)
                                                      : const Color(0xFFEEF2FF),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    u.shortName,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF818CF8)
                                                          : const Color(
                                                              0xFF4F46E5),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  u.actualName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          child: Text(
                                            u.shortName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: _buildCategoryBadge(
                                                u.category, isDark),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: u.allowDecimal
                                                  ? (isDark
                                                      ? const Color(0xFF064E3B)
                                                          .withValues(
                                                              alpha: 0.4)
                                                      : const Color(0xFFECFDF5))
                                                  : (isDark
                                                      ? const Color(0xFF0F172A)
                                                      : const Color(
                                                          0xFFF1F5F9)),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: u.allowDecimal
                                                    ? (isDark
                                                        ? const Color(
                                                            0xFF047857)
                                                        : const Color(
                                                            0xFFA7F3D0))
                                                    : (isDark
                                                        ? const Color(
                                                            0xFF334155)
                                                        : const Color(
                                                            0xFFE2E8F0)),
                                              ),
                                            ),
                                            child: Text(
                                              u.allowDecimal
                                                  ? 'Yes (Decimal)'
                                                  : 'No (Whole)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: u.allowDecimal
                                                    ? (isDark
                                                        ? const Color(
                                                            0xFF34D399)
                                                        : const Color(
                                                            0xFF059669))
                                                    : (isDark
                                                        ? const Color(
                                                            0xFF94A3B8)
                                                        : const Color(
                                                            0xFF64748B)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          child: Text(
                                            u.baseUnitMultiplier != 1.0
                                                ? 'x${u.baseUnitMultiplier}'
                                                : '1.0 (Base)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit Unit',
                                                icon: Icon(Icons.edit_outlined,
                                                    size: 18,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF818CF8)
                                                        : const Color(
                                                            0xFF4F46E5)),
                                                onPressed: () =>
                                                    _openUnitDialog(u),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete Unit',
                                                icon: Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFF87171)
                                                        : const Color(
                                                            0xFFDC2626)),
                                                onPressed: () => _deleteUnit(u),
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

  Widget _th(String text, {bool alignRight = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }
}
