import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

class WarrantiesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const WarrantiesScreen({super.key, required this.settings});

  @override
  State<WarrantiesScreen> createState() => _WarrantiesScreenState();
}

class _WarrantiesScreenState extends State<WarrantiesScreen> {
  List<Warranty> _warranties = [];
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
    final list = await db.getWarranties();
    if (mounted) {
      setState(() {
        _warranties = list;
        _loading = false;
      });
    }
  }

  void _openWarrantyDialog([Warranty? toEdit]) {
    final nameCtrl = TextEditingController(text: toEdit?.name ?? '');
    final descCtrl = TextEditingController(text: toEdit?.description ?? '');
    final durCtrl = TextEditingController(text: toEdit != null ? toEdit.duration.toString() : '12');
    String durationType = toEdit?.durationType ?? 'months';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
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
                        toEdit == null ? 'Add Warranty Policy' : 'Edit Warranty Policy',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Warranty Name * (e.g. 1 Year Standard Warranty)'),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: _inputDeco('e.g. 1 Year Standard Warranty')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Duration *'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: durCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco('12'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Duration Type'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: durationType,
                              decoration: _inputDeco('Type'),
                              items: ['days', 'months', 'years']
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setDlgState(() => durationType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Terms & Conditions / Description'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: _inputDeco('Optional policy coverage details'),
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
                          final dur = int.tryParse(durCtrl.text.trim()) ?? 0;
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter warranty name')),
                            );
                            return;
                          }

                          final db = await DatabaseService.initialize();
                          if (toEdit == null) {
                            await db.addWarranty(Warranty(
                              name: name,
                              description: descCtrl.text.trim(),
                              duration: dur,
                              durationType: durationType,
                            ));
                          } else {
                            await db.updateWarranty(Warranty(
                              id: toEdit.id,
                              name: name,
                              description: descCtrl.text.trim(),
                              duration: dur,
                              durationType: durationType,
                            ));
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                        child: Text(toEdit == null ? 'Save Warranty' : 'Update Warranty'),
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

  Future<void> _deleteWarranty(Warranty warranty) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Warranty?'),
        content: Text('Are you sure you want to delete warranty "${warranty.name}"?'),
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

    if (confirm == true && warranty.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteWarranty(warranty.id!);
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
    final filtered = _warranties.where((w) {
      if (_search.isEmpty) return true;
      return w.name.toLowerCase().contains(_search) || w.description.toLowerCase().contains(_search);
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    final currentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalFiltered);
    final paginatedWarranties = (startIndex < totalFiltered) ? filtered.sublist(startIndex, endIndex) : <Warranty>[];

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
                        'Warranties & Guarantees',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage customer warranty policies, repair terms, and replacement durations.',
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
                  label: const Text('Add Warranty', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _openWarrantyDialog(),
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
                        hintText: 'Search warranty policies...',
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
                      '${filtered.length} Policies active',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Warranties Table
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
                    Icon(Icons.verified_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No Warranties Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Click "Add Warranty" to define your coverage policies.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                          final minWidth = max(constraints.maxWidth, 680.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.5),
                                  1: FlexColumnWidth(1.8),
                                  2: FlexColumnWidth(3.5),
                                  3: FlexColumnWidth(1.5),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Warranty Name'),
                                      _th('Duration'),
                                      _th('Description / Terms'),
                                      _th('Actions', alignRight: true),
                                    ],
                                  ),
                                  ...paginatedWarranties.map((w) {
                                    return TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            w.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              w.duration > 0 ? '${w.duration} ${w.durationType.toUpperCase()}' : 'No Warranty',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            w.description.isNotEmpty ? w.description : '-',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit Warranty',
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                                                onPressed: () => _openWarrantyDialog(w),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete Warranty',
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                onPressed: () => _deleteWarranty(w),
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
