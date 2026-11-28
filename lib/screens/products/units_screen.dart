import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/database_schema.dart';
import '../../widgets/data_table_pagination_bar.dart';
import '../../services/localization_service.dart';

class UnitsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const UnitsScreen({super.key, required this.settings});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  List<Unit> _units = [];
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
    var uList = await db.getUnits();
    // Auto-seed full 5-category catalog only when no units exist
    if (uList.isEmpty) {
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

  String _formatMult(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toString()
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _openUnitDialog([Unit? toEdit]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: toEdit?.actualName ?? '');
    final shortCtrl = TextEditingController(text: toEdit?.shortName ?? '');
    final multCtrl = TextEditingController(
        text: toEdit?.baseUnitMultiplier != null &&
                toEdit!.baseUnitMultiplier != 1.0
            ? _formatMult(toEdit.baseUnitMultiplier)
            : '1');
    bool allowDecimal = toEdit?.allowDecimal ?? false;
    bool isMultipleOfOther = toEdit?.baseUnitId != null;
    int? selectedBaseUnit = toEdit?.baseUnitId;
    final String selectedCategory = toEdit?.category ?? 'count';
    String? generalError;
    String? nameError;
    String? shortError;
    String? multError;
    String? baseUnitError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final baseCandidates =
              _units.where((u) => u.id != null && u.id != toEdit?.id).toList();
          final safeBaseUnitId =
              baseCandidates.any((u) => u.id == selectedBaseUnit)
                  ? selectedBaseUnit
                  : null;
          final unitLabelPreview = nameCtrl.text.trim().isNotEmpty
              ? nameCtrl.text.trim()
              : (shortCtrl.text.trim().isNotEmpty
                  ? shortCtrl.text.trim()
                  : 'New Unit');

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          toEdit == null ? 'Add Unit' : 'Edit Unit',
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
                    if (generalError != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                generalError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _fieldLabel(
                        'Name:* (e.g. Pieces, Kilograms, Solar Panel Container)',
                        isDark),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setDlgState(() {
                        nameError = null;
                        generalError = null;
                      }),
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration:
                          _inputDeco('e.g. Solar Panel Container', isDark)
                              .copyWith(errorText: nameError, errorMaxLines: 2),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel(
                                  'Short name:* (e.g. Pc, Kg, Con)', isDark),
                              const SizedBox(height: 6),
                              TextField(
                                controller: shortCtrl,
                                onChanged: (_) => setDlgState(() {
                                  shortError = null;
                                  generalError = null;
                                }),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A)),
                                decoration: _inputDeco('e.g. Con', isDark)
                                    .copyWith(
                                        errorText: shortError,
                                        errorMaxLines: 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Allow decimal:*', isDark),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<bool>(
                                initialValue: allowDecimal,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A)),
                                decoration: _inputDeco('Allow decimal', isDark),
                                items: const [
                                  DropdownMenuItem<bool>(
                                    value: false,
                                    child: Text('No (Whole numbers)'),
                                  ),
                                  DropdownMenuItem<bool>(
                                    value: true,
                                    child: Text('Yes (1.5 kg, 0.25 ltr)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDlgState(() => allowDecimal = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Ultimate POS style: Checkbox + "1 [Unit] = [Multiplier] [Base Unit]"
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setDlgState(() {
                        isMultipleOfOther = !isMultipleOfOther;
                        if (!isMultipleOfOther) {
                          selectedBaseUnit = null;
                          multCtrl.text = '1';
                        } else if (safeBaseUnitId == null &&
                            baseCandidates.isNotEmpty) {
                          final primary = baseCandidates.firstWhere(
                            (u) => u.baseUnitId == null,
                            orElse: () => baseCandidates.first,
                          );
                          selectedBaseUnit = primary.id;
                        }
                      }),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isMultipleOfOther,
                            activeColor: const Color(0xFF4F46E5),
                            onChanged: (val) => setDlgState(() {
                              isMultipleOfOther = val ?? false;
                              if (!isMultipleOfOther) {
                                selectedBaseUnit = null;
                                multCtrl.text = '1';
                              } else if (safeBaseUnitId == null &&
                                  baseCandidates.isNotEmpty) {
                                final primary = baseCandidates.firstWhere(
                                  (u) => u.baseUnitId == null,
                                  orElse: () => baseCandidates.first,
                                );
                                selectedBaseUnit = primary.id;
                              }
                            }),
                          ),
                          Text(
                            'Add as multiple of other unit',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message:
                                'Define conversion relative to a primary base unit.\nExample: 1 Box = 12 Pieces, or 1 Gram = 0.001 Kilograms.',
                            child: Icon(
                              Icons.info_rounded,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMultipleOfOther) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: 3,
                                  child: Text(
                                    '1 $unitLabelPreview',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text(
                                    '=',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: multCtrl,
                                    onChanged: (_) => setDlgState(() {
                                      multError = null;
                                      generalError = null;
                                    }),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                    decoration: _inputDeco('e.g. 20', isDark)
                                        .copyWith(
                                            errorText: multError,
                                            errorMaxLines: 2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 4,
                                  child: DropdownButtonFormField<int?>(
                                    initialValue: safeBaseUnitId,
                                    isExpanded: true,
                                    dropdownColor: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                    decoration:
                                        _inputDeco('Select Base Unit', isDark)
                                            .copyWith(
                                                errorText: baseUnitError,
                                                errorMaxLines: 2),
                                    items: baseCandidates
                                        .map((u) => DropdownMenuItem<int?>(
                                            value: u.id,
                                            child: Text(
                                              '${u.actualName} (${u.shortName})',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(
                                                          0xFF0F172A)),
                                            )))
                                        .toList(),
                                    onChanged: (val) => setDlgState(() {
                                      selectedBaseUnit = val;
                                      baseUnitError = null;
                                      generalError = null;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tip: Use >1 for larger packs (1 Box = 12 Pieces) and <1 for smaller sub-units (1 Gram = 0.001 Kilograms).',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Close',
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
                            final parsedMult =
                                double.tryParse(multCtrl.text.trim());
                            final effectiveBase =
                                isMultipleOfOther ? safeBaseUnitId : null;
                            final mult =
                                isMultipleOfOther ? (parsedMult ?? 0.0) : 1.0;

                            final nextNameErr =
                                name.isEmpty ? 'Unit name is required' : null;
                            final nextShortErr =
                                short.isEmpty ? 'Short name is required' : null;
                            final nextMultErr = (isMultipleOfOther && mult <= 0)
                                ? 'Enter a multiplier > 0'
                                : null;
                            final nextBaseErr =
                                (isMultipleOfOther && effectiveBase == null)
                                    ? 'Select a base unit'
                                    : null;
                            final nextGeneralErr = (isMultipleOfOther &&
                                    baseCandidates.isEmpty)
                                ? 'No base unit is available. Create a base unit first.'
                                : null;

                            if (nextNameErr != null ||
                                nextShortErr != null ||
                                nextMultErr != null ||
                                nextBaseErr != null ||
                                nextGeneralErr != null) {
                              setDlgState(() {
                                nameError = nextNameErr;
                                shortError = nextShortErr;
                                multError = nextMultErr;
                                baseUnitError = nextBaseErr;
                                generalError = nextGeneralErr;
                              });
                              return;
                            }

                            try {
                              final db = await DatabaseService.initialize();
                              if (toEdit == null) {
                                final baseCategory = effectiveBase != null
                                    ? baseCandidates
                                        .firstWhere(
                                            (b) => b.id == effectiveBase)
                                        .category
                                    : selectedCategory;
                                await db.addUnit(Unit(
                                  actualName: name,
                                  shortName: short,
                                  allowDecimal: allowDecimal,
                                  baseUnitId: effectiveBase,
                                  baseUnitMultiplier: mult,
                                  category: baseCategory,
                                ));
                              } else {
                                await db.updateUnit(Unit(
                                  id: toEdit.id,
                                  actualName: name,
                                  shortName: short,
                                  allowDecimal: allowDecimal,
                                  baseUnitId: effectiveBase,
                                  baseUnitMultiplier: mult,
                                  category: selectedCategory,
                                ));
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            } catch (e) {
                              if (ctx.mounted) {
                                setDlgState(() {
                                  generalError = 'Failed to save unit: $e';
                                });
                              }
                            }
                          },
                          child: Text(toEdit == null ? 'Save' : 'Update'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _units.where((u) {
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
                        PosLocalization.tr('Units of Measure'),
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
                                  0: FlexColumnWidth(2.8),
                                  1: FlexColumnWidth(1.4),
                                  2: FlexColumnWidth(1.4),
                                  3: FlexColumnWidth(1.2),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Name', isDark: isDark),
                                      _th('Short name', isDark: isDark),
                                      _th('Allow decimal', isDark: isDark),
                                      _th('Action',
                                          alignRight: true, isDark: isDark),
                                    ],
                                  ),
                                  ...paginatedUnits.map((u) {
                                    final baseUnit = u.baseUnitId != null
                                        ? _units
                                            .where((b) => b.id == u.baseUnitId)
                                            .cast<Unit?>()
                                            .firstOrNull
                                        : null;
                                    final subText = baseUnit != null
                                        ? '1 ${u.shortName} = ${_formatMult(u.baseUnitMultiplier)} ${baseUnit.shortName}'
                                        : null;
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
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      u.actualName,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                        color: isDark
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF0F172A),
                                                      ),
                                                    ),
                                                    if (subText != null)
                                                      Text(
                                                        subText,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF93C5FD)
                                                              : const Color(
                                                                  0xFF2563EB),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                  ],
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
                                          child: Text(
                                            u.allowDecimal ? 'Yes' : 'No',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: u.allowDecimal
                                                  ? (isDark
                                                      ? const Color(0xFF34D399)
                                                      : const Color(0xFF059669))
                                                  : (isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(
                                                          0xFF64748B)),
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
