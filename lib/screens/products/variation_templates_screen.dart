import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

class VariationTemplatesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const VariationTemplatesScreen({super.key, required this.settings});

  @override
  State<VariationTemplatesScreen> createState() => _VariationTemplatesScreenState();
}

class _VariationTemplatesScreenState extends State<VariationTemplatesScreen> {
  List<VariationTemplate> _templates = [];
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
    final list = await db.getVariationTemplates();
    if (mounted) {
      setState(() {
        _templates = list;
        _loading = false;
      });
    }
  }

  void _openTemplateDialog([VariationTemplate? toEdit]) {
    final nameCtrl = TextEditingController(text: toEdit?.name ?? '');
    final valCtrl = TextEditingController();
    List<String> values = List.from(toEdit?.values ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        toEdit == null ? 'Add Variation Template' : 'Edit Variation Template',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Variation Name * (e.g. Size, Color, Capacity)'),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: _inputDeco('e.g. Size')),
                  const SizedBox(height: 16),
                  _fieldLabel('Add Variation Values (e.g. Small, Medium, Large)'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valCtrl,
                          decoration: _inputDeco('Type a value and click Add'),
                          onSubmitted: (text) {
                            final val = text.trim();
                            if (val.isNotEmpty && !values.contains(val)) {
                              setDlgState(() => values.add(val));
                              valCtrl.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF2FF),
                          foregroundColor: const Color(0xFF4F46E5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Value'),
                        onPressed: () {
                          final val = valCtrl.text.trim();
                          if (val.isNotEmpty && !values.contains(val)) {
                            setDlgState(() => values.add(val));
                            valCtrl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Values Tags Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minHeight: 60),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: values.isEmpty
                        ? const Center(
                            child: Text(
                              'No values added yet. Add at least 1 value.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: values
                                .map(
                                  (v) => Chip(
                                    label: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                                    deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                                    onDeleted: () => setDlgState(() => values.remove(v)),
                                  ),
                                )
                                .toList(),
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
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter variation template name')),
                            );
                            return;
                          }
                          if (values.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please add at least one value')),
                            );
                            return;
                          }

                          final db = await DatabaseService.initialize();
                          if (toEdit == null) {
                            await db.addVariationTemplate(VariationTemplate(name: name, values: values));
                          } else {
                            await db.updateVariationTemplate(VariationTemplate(id: toEdit.id, name: name, values: values));
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                        child: Text(toEdit == null ? 'Save Template' : 'Update Template'),
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

  Future<void> _deleteTemplate(VariationTemplate tmpl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete variation template "${tmpl.name}"?'),
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

    if (confirm == true && tmpl.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteVariationTemplate(tmpl.id!);
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
    final filtered = _templates.where((t) {
      if (_search.isEmpty) return true;
      return t.name.toLowerCase().contains(_search) || t.values.any((v) => v.toLowerCase().contains(_search));
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    final currentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalFiltered);
    final paginatedTemplates = (startIndex < totalFiltered) ? filtered.sublist(startIndex, endIndex) : <VariationTemplate>[];

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
                        'Variation Templates',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pre-configure attributes like Size, Color, and Specs for Variable Products.',
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
                  label: const Text('Add Template', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _openTemplateDialog(),
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
                        hintText: 'Search variation templates...',
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
                      '${filtered.length} Templates defined',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Data Table
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
                    Icon(Icons.style_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No Variation Templates Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Click "Add Template" to configure variation templates.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                          final minWidth = max(constraints.maxWidth, 640.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.0),
                                  1: FlexColumnWidth(5.5),
                                  2: FlexColumnWidth(1.5),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Template Name'),
                                      _th('Variation Values'),
                                      _th('Actions', alignRight: true),
                                    ],
                                  ),
                                  ...paginatedTemplates.map((t) {
                                    return TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Text(
                                            t.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: t.values
                                                .map(
                                                  (v) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFEEF2FF),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                                    ),
                                                    child: Text(
                                                      v,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit Template',
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                                                onPressed: () => _openTemplateDialog(t),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete Template',
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                onPressed: () => _deleteTemplate(t),
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
