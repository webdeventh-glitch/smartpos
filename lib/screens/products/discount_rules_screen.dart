import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/searchable_select_dialog.dart';

/// Step 6.5: Discount Schedules & Promotional Rules Engine UI.
class DiscountRulesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const DiscountRulesScreen({super.key, required this.settings});

  @override
  State<DiscountRulesScreen> createState() => _DiscountRulesScreenState();
}

class _DiscountRulesScreenState extends State<DiscountRulesScreen> {
  bool _loading = true;
  List<DiscountRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final rules = await db.getDiscountRules();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _showRuleDialog([DiscountRule? existing]) async {
    final db = await DatabaseService.initialize();
    final categories = await db.getCategories();
    final brands = await db.getBrands();
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String ruleType = existing?.ruleType ?? 'standard';
    String discountType = existing?.discountType ?? 'percentage';
    final amountCtrl = TextEditingController(
      text: (existing?.discountAmount ?? 10.0).toStringAsFixed(2),
    );
    final startsCtrl = TextEditingController(
      text:
          existing?.startsAt ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final endsCtrl = TextEditingController(
      text: existing?.endsAt ??
          DateFormat('yyyy-MM-dd')
              .format(DateTime.now().add(const Duration(days: 30))),
    );
    final startTimeCtrl =
        TextEditingController(text: existing?.startTime ?? '');
    final endTimeCtrl = TextEditingController(text: existing?.endTime ?? '');
    final minQtyCtrl = TextEditingController(
        text: (existing?.minQuantity ?? 5).toStringAsFixed(0));
    final buyQtyCtrl = TextEditingController(
        text: (existing?.buyQuantity ?? 2).toStringAsFixed(0));
    final freeQtyCtrl = TextEditingController(
        text: (existing?.freeQuantity ?? 1).toStringAsFixed(0));
    final priorityCtrl =
        TextEditingController(text: '${existing?.priority ?? 1}');
    int? categoryId = existing?.categoryId;
    int? brandId = existing?.brandId;
    final selectedDays =
        existing != null && existing.daysOfWeek.trim().isNotEmpty
            ? existing.daysOfWeek
                .split(',')
                .map((e) => int.tryParse(e.trim()))
                .whereType<int>()
                .toSet()
            : <int>{};
    bool isActive = existing?.isActive ?? true;
    bool saving = false;

    const weekdayLabels = [
      (1, 'Mon'),
      (2, 'Tue'),
      (3, 'Wed'),
      (4, 'Thu'),
      (5, 'Fri'),
      (6, 'Sat'),
      (7, 'Sun'),
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
              existing == null
                  ? 'Create Discount Schedule'
                  : 'Edit Discount Schedule',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                        labelText: PosLocalization.tr(
                            'Rule Name (e.g., Weekend 15% Off)'),
                        isDense: true,
                        border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: ruleType,
                          decoration: InputDecoration(
                              labelText: PosLocalization.tr('Rule Mode'),
                              isDense: true,
                              border: const OutlineInputBorder()),
                          items: [
                            DropdownMenuItem(
                                value: 'standard',
                                child:
                                    Text(PosLocalization.tr('Standard Promo'))),
                            DropdownMenuItem(
                                value: 'buy_x_get_y',
                                child: Text(
                                    PosLocalization.tr('Buy X Get Y Free'))),
                            DropdownMenuItem(
                                value: 'quantity_break',
                                child:
                                    Text(PosLocalization.tr('Quantity Break'))),
                            DropdownMenuItem(
                                value: 'time_based',
                                child: Text(PosLocalization.tr(
                                    'Time-Based Happy Hour'))),
                          ],
                          onChanged: (v) =>
                              setDlg(() => ruleType = v ?? 'standard'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: priorityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: PosLocalization.tr('Priority'),
                              isDense: true,
                              border: const OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (ruleType == 'buy_x_get_y')
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: buyQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: PosLocalization.tr('Buy X Qty'),
                                isDense: true,
                                border: const OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: freeQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: PosLocalization.tr('Get Y Free Qty'),
                                isDense: true,
                                border: const OutlineInputBorder()),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: discountType,
                            decoration: InputDecoration(
                                labelText: PosLocalization.tr('Discount Type'),
                                isDense: true,
                                border: const OutlineInputBorder()),
                            items: [
                              DropdownMenuItem(
                                  value: 'percentage',
                                  child: Text(
                                      PosLocalization.tr('Percentage (%)'))),
                              DropdownMenuItem(
                                  value: 'fixed',
                                  child:
                                      Text(PosLocalization.tr('Fixed Amount'))),
                            ],
                            onChanged: (v) =>
                                setDlg(() => discountType = v ?? 'percentage'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: PosLocalization.tr('Value'),
                                isDense: true,
                                border: const OutlineInputBorder()),
                          ),
                        ),
                        if (ruleType == 'quantity_break') ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: minQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: PosLocalization.tr('Min Qty'),
                                  isDense: true,
                                  border: const OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startsCtrl,
                          decoration: InputDecoration(
                              labelText:
                                  PosLocalization.tr('Start Date (YYYY-MM-DD)'),
                              isDense: true,
                              border: const OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endsCtrl,
                          decoration: InputDecoration(
                              labelText:
                                  PosLocalization.tr('End Date (YYYY-MM-DD)'),
                              isDense: true,
                              border: const OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startTimeCtrl,
                          decoration: InputDecoration(
                              labelText: PosLocalization.tr(
                                  'Start Time HH:mm (optional)'),
                              isDense: true,
                              border: const OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endTimeCtrl,
                          decoration: InputDecoration(
                              labelText: PosLocalization.tr(
                                  'End Time HH:mm (optional)'),
                              isDense: true,
                              border: const OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                      PosLocalization.tr(
                          'Days of Week (leave empty for all days)'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: weekdayLabels.map((wd) {
                      final active = selectedDays.contains(wd.$1);
                      return FilterChip(
                        label:
                            Text(wd.$2, style: const TextStyle(fontSize: 11)),
                        selected: active,
                        onSelected: (sel) => setDlg(() {
                          if (sel) {
                            selectedDays.add(wd.$1);
                          } else {
                            selectedDays.remove(wd.$1);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SearchableDropdownField<Category>(
                          label: PosLocalization.tr('Category Scope'),
                          selectedItem: categoryId == null
                              ? null
                              : categories
                                  .where((c) => c.id == categoryId)
                                  .firstOrNull,
                          items: categories,
                          labelBuilder: (c) => c.name,
                          placeholder: PosLocalization.tr('All Categories'),
                          searchHint: 'Search category...',
                          prefixIcon: Icons.category_outlined,
                          height: 40,
                          allowClear: true,
                          clearLabel: PosLocalization.tr('All Categories'),
                          onChanged: (v) => setDlg(() => categoryId = v?.id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SearchableDropdownField<Brand>(
                          label: PosLocalization.tr('Brand Scope'),
                          selectedItem: brandId == null
                              ? null
                              : brands
                                  .where((b) => b.id == brandId)
                                  .firstOrNull,
                          items: brands,
                          labelBuilder: (b) => b.name,
                          placeholder: PosLocalization.tr('All Brands'),
                          searchHint: 'Search brand...',
                          prefixIcon: Icons.branding_watermark_outlined,
                          height: 40,
                          allowClear: true,
                          clearLabel: PosLocalization.tr('All Brands'),
                          onChanged: (v) => setDlg(() => brandId = v?.id),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(PosLocalization.tr('Rule Active in POS'),
                        style: const TextStyle(fontSize: 13)),
                    value: isActive,
                    onChanged: (v) => setDlg(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(PosLocalization.tr('Cancel'))),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setDlg(() => saving = true);
                      final rule = DiscountRule(
                        id: existing?.id,
                        name: name,
                        ruleType: ruleType,
                        discountType: discountType,
                        discountAmount:
                            double.tryParse(amountCtrl.text.trim()) ?? 0.0,
                        startsAt: startsCtrl.text.trim(),
                        endsAt: endsCtrl.text.trim(),
                        categoryId: categoryId,
                        brandId: brandId,
                        daysOfWeek: (selectedDays.toList()..sort()).join(','),
                        startTime: startTimeCtrl.text.trim(),
                        endTime: endTimeCtrl.text.trim(),
                        minQuantity: ruleType == 'quantity_break'
                            ? (double.tryParse(minQtyCtrl.text.trim()) ?? 0.0)
                            : 0.0,
                        buyQuantity: ruleType == 'buy_x_get_y'
                            ? (double.tryParse(buyQtyCtrl.text.trim()) ?? 0.0)
                            : 0.0,
                        freeQuantity: ruleType == 'buy_x_get_y'
                            ? (double.tryParse(freeQtyCtrl.text.trim()) ?? 0.0)
                            : 0.0,
                        priority: int.tryParse(priorityCtrl.text.trim()) ?? 1,
                        isActive: isActive,
                        createdAt: existing?.createdAt ??
                            DateTime.now().toIso8601String(),
                      );
                      if (existing == null) {
                        await db.addDiscountRule(rule);
                      } else {
                        await db.updateDiscountRule(rule);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
              child: Text(saving ? 'Saving...' : 'Save Rule'),
            ),
          ],
        ),
      ),
    );
  }

  String _describeRule(DiscountRule r) {
    final cur = widget.settings.currencySymbol;
    if (r.ruleType == 'buy_x_get_y') {
      return 'Buy ${r.buyQuantity.toStringAsFixed(0)} Get ${r.freeQuantity.toStringAsFixed(0)} Free';
    }
    final val = r.discountType == 'percentage'
        ? '${r.discountAmount.toStringAsFixed(1)}%'
        : '$cur${r.discountAmount.toStringAsFixed(2)}';
    if (r.ruleType == 'quantity_break') {
      return '$val off on ${r.minQuantity.toStringAsFixed(0)}+ units';
    }
    if (r.ruleType == 'time_based') {
      return '$val off (${r.startTime.isEmpty ? "Any" : r.startTime}-${r.endTime.isEmpty ? "Any" : r.endTime})';
    }
    return '$val off';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_rounded,
                    color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          PosLocalization.tr(
                              'Discount Schedules & Auto-Promos'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A))),
                      Text(
                          PosLocalization.tr(
                              'Configure Buy X Get Y, Quantity Breaks, and Time-Based rules auto-evaluated at POS'),
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B))),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white),
                  onPressed: () => _showRuleDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(PosLocalization.tr('New Discount Rule')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rules.isEmpty
                        ? Center(
                            child: Text(
                                PosLocalization.tr(
                                    'No scheduled discount rules configured yet.'),
                                style: const TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: _rules.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: borderColor),
                            itemBuilder: (_, idx) {
                              final r = _rules[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (r.isActive
                                          ? const Color(0xFF10B981)
                                          : Colors.grey)
                                      .withValues(alpha: 0.14),
                                  child: Icon(Icons.discount_outlined,
                                      color: r.isActive
                                          ? const Color(0xFF10B981)
                                          : Colors.grey,
                                      size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Text(r.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(_describeRule(r),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981))),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Mode: ${r.ruleType.replaceAll('_', ' ')} • Priority: ${r.priority} • Window: ${r.startsAt ?? ""} to ${r.endsAt ?? ""}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: r.isActive,
                                      onChanged: (v) async {
                                        final db =
                                            await DatabaseService.initialize();
                                        await db.updateDiscountRule(
                                            r.copyWith(isActive: v));
                                        await _load();
                                      },
                                    ),
                                    IconButton(
                                      tooltip: PosLocalization.tr('Edit Rule'),
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () => _showRuleDialog(r),
                                    ),
                                    IconButton(
                                      tooltip:
                                          PosLocalization.tr('Delete Rule'),
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      onPressed: r.id == null
                                          ? null
                                          : () async {
                                              final db = await DatabaseService
                                                  .initialize();
                                              await db
                                                  .deleteDiscountRule(r.id!);
                                              await _load();
                                            },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
