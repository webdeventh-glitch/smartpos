import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
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
    final uList = await db.getUnits();
    if (mounted) {
      setState(() {
        _units = uList;
        _loading = false;
      });
    }
  }

  void _openUnitDialog([Unit? toEdit]) {
    final nameCtrl = TextEditingController(text: toEdit?.actualName ?? '');
    final shortCtrl = TextEditingController(text: toEdit?.shortName ?? '');
    final multCtrl = TextEditingController(text: toEdit?.baseUnitMultiplier != null && toEdit!.baseUnitMultiplier != 1.0 ? toEdit.baseUnitMultiplier.toString() : '1');
    bool allowDecimal = toEdit?.allowDecimal ?? false;
    int? selectedBaseUnit = toEdit?.baseUnitId;

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
                        toEdit == null ? 'Add Unit of Measure' : 'Edit Unit of Measure',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Unit Name * (e.g. Pieces, Kilograms, Box)'),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: _inputDeco('e.g. Pieces')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Short Name * (e.g. Pc, Kg)'),
                            const SizedBox(height: 6),
                            TextField(controller: shortCtrl, decoration: _inputDeco('e.g. Pc')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Allow Decimal Values?'),
                            const SizedBox(height: 6),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Switch(
                                    value: allowDecimal,
                                    activeColor: const Color(0xFF4F46E5),
                                    onChanged: (val) => setDlgState(() => allowDecimal = val),
                                  ),
                                  Text(
                                    allowDecimal ? 'Yes (1.5 kg)' : 'No (Integers)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sub-Unit Multiplier (Optional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'e.g. If this unit is "Box" and base unit is "Pieces", set multiplier to 12.0',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int?>(
                                value: selectedBaseUnit,
                                decoration: _inputDeco('Base Unit'),
                                items: [
                                  const DropdownMenuItem<int?>(value: null, child: Text('None (Primary Base Unit)')),
                                  ..._units.where((u) => u.id != toEdit?.id).map((u) => DropdownMenuItem<int?>(value: u.id, child: Text(u.actualName))),
                                ],
                                onChanged: (val) => setDlgState(() => selectedBaseUnit = val),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: multCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDeco('Multiplier'),
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
                          final short = shortCtrl.text.trim();
                          final mult = double.tryParse(multCtrl.text.trim()) ?? 1.0;

                          if (name.isEmpty || short.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill unit name and short name')),
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
                            ));
                          } else {
                            await db.updateUnit(Unit(
                              id: toEdit.id,
                              actualName: name,
                              shortName: short,
                              allowDecimal: allowDecimal,
                              baseUnitId: selectedBaseUnit,
                              baseUnitMultiplier: mult,
                            ));
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                        child: Text(toEdit == null ? 'Save Unit' : 'Update Unit'),
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
        content: Text('Are you sure you want to delete unit "${unit.actualName}"?'),
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

    if (confirm == true && unit.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteUnit(unit.id!);
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
    final filtered = _units.where((u) {
      if (_search.isEmpty) return true;
      return u.actualName.toLowerCase().contains(_search) || u.shortName.toLowerCase().contains(_search);
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    final currentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalFiltered);
    final paginatedUnits = (startIndex < totalFiltered) ? filtered.sublist(startIndex, endIndex) : <Unit>[];

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
                        'Units of Measure',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Define measurement units (Pieces, Kg, Boxes, Liters) and decimal allowances.',
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
                  label: const Text('Add Unit', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _openUnitDialog(),
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
                        hintText: 'Search measurement units...',
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
                      '${filtered.length} Units available',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Units Data Table
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
                    Icon(Icons.straighten_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No Units Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Click "Add Unit" to configure measurement units.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                                  1: FlexColumnWidth(1.8),
                                  2: FlexColumnWidth(1.8),
                                  3: FlexColumnWidth(2.2),
                                  4: FlexColumnWidth(1.5),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Unit Name'),
                                      _th('Short Name'),
                                      _th('Allow Decimals'),
                                      _th('Multiplier / Base'),
                                      _th('Actions', alignRight: true),
                                    ],
                                  ),
                                  ...paginatedUnits.map((u) {
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
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEEF2FF),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    u.shortName,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                u.actualName,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(u.shortName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: u.allowDecimal ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              u.allowDecimal ? 'Yes (Decimal)' : 'No (Whole)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: u.allowDecimal ? const Color(0xFF059669) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            u.baseUnitMultiplier != 1.0 ? 'x${u.baseUnitMultiplier}' : '1.0 (Base)',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit Unit',
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                                                onPressed: () => _openUnitDialog(u),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete Unit',
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
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
