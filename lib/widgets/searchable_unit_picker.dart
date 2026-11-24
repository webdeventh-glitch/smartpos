import 'package:flutter/material.dart';
import '../models/models.dart';

/// Modal dialog providing search-to-select functionality for Units of Measure
/// with category grouping, base-unit highlighting, and deduplication.
class UnitSearchDialog extends StatefulWidget {
  final List<Unit> units;
  final String currentUnit;
  final ValueChanged<String> onSelected;
  final VoidCallback? onAddNewUnit;

  const UnitSearchDialog({
    super.key,
    required this.units,
    required this.currentUnit,
    required this.onSelected,
    this.onAddNewUnit,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<Unit> units,
    required String currentUnit,
    VoidCallback? onAddNewUnit,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => UnitSearchDialog(
        units: units,
        currentUnit: currentUnit,
        onSelected: (val) => Navigator.pop(ctx, val),
        onAddNewUnit: onAddNewUnit,
      ),
    );
  }

  @override
  State<UnitSearchDialog> createState() => _UnitSearchDialogState();
}

class _UnitSearchDialogState extends State<UnitSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';
  late List<Unit> _deduplicatedUnits;

  @override
  void initState() {
    super.initState();
    _deduplicatedUnits = _deduplicate(widget.units);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Deduplicates units by normalized short code and canonical actual name
  List<Unit> _deduplicate(List<Unit> rawList) {
    final Map<String, Unit> map = {};

    for (final u in rawList) {
      final actual = u.actualName.trim().toLowerCase();
      final short = u.shortName.trim().toLowerCase();

      // Normalize common synonyms to prevent duplicate base units
      String key = short;
      if (key == 'kg' || actual == 'kilogram' || actual == 'kilograms') {
        key = 'kg';
      } else if (key == 'pc' ||
          key == 'pcs' ||
          actual == 'piece' ||
          actual == 'pieces') {
        key = 'pc';
      } else if (key == 'ltr' ||
          key == 'l' ||
          actual == 'liter' ||
          actual == 'liters') {
        key = 'ltr';
      } else if (key == 'm' || actual == 'meter' || actual == 'meters') {
        key = 'm';
      } else if (key == 'hr' || actual == 'hour' || actual == 'hours') {
        key = 'hr';
      } else if (key == 'gm' ||
          key == 'g' ||
          actual == 'gram' ||
          actual == 'grams') {
        key = 'gm';
      } else if (key.isEmpty) {
        key = actual;
      }

      // Keep base unit (baseUnitMultiplier == 1.0 or baseUnitId == null) if duplicate exists
      if (!map.containsKey(key)) {
        map[key] = u;
      } else {
        final existing = map[key]!;
        if (existing.baseUnitMultiplier != 1.0 && u.baseUnitMultiplier == 1.0) {
          map[key] = u;
        }
      }
    }

    // Sort: base units first, then sub-units alphabetically
    final list = map.values.toList();
    list.sort((a, b) {
      final aIsBase = a.baseUnitId == null || a.baseUnitMultiplier == 1.0;
      final bIsBase = b.baseUnitId == null || b.baseUnitMultiplier == 1.0;
      if (aIsBase && !bIsBase) return -1;
      if (!aIsBase && bIsBase) return 1;
      return a.actualName.compareTo(b.actualName);
    });

    return list;
  }

  String _formatLabel(Unit u) {
    if (u.shortName.isNotEmpty &&
        u.shortName.toLowerCase() != u.actualName.toLowerCase()) {
      return '${u.actualName} (${u.shortName})';
    }
    return u.actualName;
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'count':
        return Icons.pin_outlined;
      case 'weight':
        return Icons.scale_rounded;
      case 'volume':
        return Icons.water_drop_outlined;
      case 'length':
        return Icons.square_foot_rounded;
      case 'time':
        return Icons.access_time_rounded;
      default:
        return Icons.straighten_rounded;
    }
  }

  List<Unit> _getFilteredUnits() {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _deduplicatedUnits.where((u) {
      if (_selectedCategory != 'all' &&
          u.category.toLowerCase() != _selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;

      final actualMatch = u.actualName.toLowerCase().contains(q);
      final shortMatch = u.shortName.toLowerCase().contains(q);
      final catMatch = u.category.toLowerCase().contains(q);

      return actualMatch || shortMatch || catMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _getFilteredUnits();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.straighten_rounded,
                        color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Unit of Measure',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          'پیمائش کی اکائی تلاش کر کے منتخب کریں',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Box with auto-focus
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText:
                      'Search unit (e.g. kg, meter, pcs, liter, dozen)...',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All Units (تمام)'),
                    _filterChip('count', '1. Count (گنتی)'),
                    _filterChip('weight', '2. Weight (وزن)'),
                    _filterChip('volume', '3. Volume (مائع)'),
                    _filterChip('length', '4. Length / Area (لمبائی)'),
                    _filterChip('time', '5. Time (وقت)'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Units List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No matching unit found',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Click below to add a new custom unit.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final u = filtered[idx];
                          final label = _formatLabel(u);
                          final isBase = u.baseUnitId == null ||
                              u.baseUnitMultiplier == 1.0;
                          final isSelected = widget.currentUnit == label ||
                              widget.currentUnit == u.actualName ||
                              widget.currentUnit == u.shortName;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isBase
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.12)
                                    : const Color(0xFF4F46E5)
                                        .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getCategoryIcon(u.category),
                                size: 18,
                                color: isBase
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF4F46E5),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 13,
                                      color: isSelected
                                          ? const Color(0xFF4F46E5)
                                          : (isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                if (isBase)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BASE UNIT',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  )
                                else if (u.baseUnitMultiplier != 1.0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'x${u.baseUnitMultiplier} Base',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              'Category: ${u.category.toUpperCase()} • Code: ${u.shortName}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B)),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF4F46E5), size: 20)
                                : null,
                            onTap: () => widget.onSelected(label),
                          );
                        },
                      ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer with + Add New Unit option
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.onAddNewUnit != null)
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Custom Unit (نیا یونٹ بنائیں)',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAddNewUnit!();
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xFF0F172A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String catKey, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedCategory == catKey;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        selectedColor: const Color(0xFF4F46E5),
        checkmarkColor: Colors.white,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        onSelected: (_) => setState(() => _selectedCategory = catKey),
      ),
    );
  }
}
