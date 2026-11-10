import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/record_contact_payment_dialog.dart';
import 'contact_ledger_screen.dart';

class SuppliersScreen extends StatefulWidget {
  final BusinessSettings settings;

  const SuppliersScreen({super.key, required this.settings});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Contact> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getContacts(type: 'supplier');
    if (mounted) {
      setState(() {
        _suppliers = list;
        _loading = false;
      });
    }
  }

  Widget _fieldLabel(String label, {bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        ),
      ),
    );
  }

  void _openAddSupplier() {
    final nameCtrl = TextEditingController();
    final bizCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.factory_rounded, color: Color(0xFF818CF8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Supplier / Vendor',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Register vendor for procurement and purchase orders',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                    splashRadius: 18,
                  ),
                ],
              ),
              Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

              _fieldLabel('Supplier Contact Person *', isDark: isDark),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: inputDecoration.copyWith(
                  hintText: 'e.g. Michael Smith',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.person_outline, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 14),

              _fieldLabel('Company / Business Name *', isDark: isDark),
              TextField(
                controller: bizCtrl,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: inputDecoration.copyWith(
                  hintText: 'e.g. Apex Wholesalers Ltd',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.business_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Phone Number', isDark: isDark),
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: inputDecoration.copyWith(
                            hintText: '+1 (555) 000-0000',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Email Address', isDark: isDark),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: inputDecoration.copyWith(
                            hintText: 'vendor@domain.com',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.email_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _fieldLabel('Physical Address / Warehouse', isDark: isDark),
              TextField(
                controller: addrCtrl,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: inputDecoration.copyWith(
                  hintText: 'Street address, City',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final db = await DatabaseService.initialize();
                      await db.addContact(Contact(
                        type: 'supplier',
                        name: nameCtrl.text.trim(),
                        businessName: bizCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        address: addrCtrl.text.trim(),
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('Save Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPaySupplierDialog(Contact supplier) async {
    await RecordContactPaymentDialog.show(
      context,
      contact: supplier,
      contactType: 'supplier',
      settings: widget.settings,
      onPaymentRecorded: _load,
    );
  }

  Future<void> _openSupplierLedgerDialog(Contact supplier) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactLedgerScreen(
          contact: supplier,
          contactType: 'supplier',
          settings: widget.settings,
          onPaymentRecorded: () => _load(),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final totalPayable = _suppliers.fold(0.0, (sum, s) => sum + s.balance);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (Responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                final addBtn = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.factory_rounded, size: 18),
                  label: const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddSupplier,
                );

                final titleColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suppliers & Vendors',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage manufacturers, product distributors, vendor invoices, and outstanding payables.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleColumn,
                      const SizedBox(height: 12),
                      addBtn,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleColumn),
                    const SizedBox(width: 16),
                    addBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // KPI Cards (Responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _miniCard('Total Suppliers', '${_suppliers.length}', const Color(0xFF4F46E5), isDark: isDark);
                final c2 = _miniCard('Total Payables Due', '$currency${totalPayable.toStringAsFixed(2)}', const Color(0xFFEF4444), isDark: isDark);

                if (constraints.maxWidth < 550) {
                  return Column(
                    children: [
                      c1,
                      const SizedBox(height: 10),
                      c2,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: c1),
                    const SizedBox(width: 14),
                    Expanded(child: c2),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Suppliers Table (Responsive Full Width)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : _suppliers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: Text('No suppliers recorded yet.', style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey))),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = math.max(constraints.maxWidth, 950.0);
                              return Scrollbar(
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(2.0), // SUPPLIER
                                        1: FlexColumnWidth(2.0), // BUSINESS / COMPANY
                                        2: FlexColumnWidth(1.4), // PHONE
                                        3: FlexColumnWidth(1.6), // EMAIL
                                        4: FlexColumnWidth(2.0), // ADDRESS
                                        5: FlexColumnWidth(1.4), // BALANCE PAYABLE
                                        6: FlexColumnWidth(1.6), // ACTIONS
                                      },
                                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2)),
                                          ),
                                          children: [
                                            _th('SUPPLIER', isDark),
                                            _th('BUSINESS / COMPANY', isDark),
                                            _th('PHONE', isDark),
                                            _th('EMAIL', isDark),
                                            _th('ADDRESS', isDark),
                                            _th('BALANCE PAYABLE', isDark),
                                            _th('ACTIONS', isDark),
                                          ],
                                        ),
                                        ..._suppliers.asMap().entries.map((entry) {
                                          final idx = entry.key;
                                          final s = entry.value;
                                          final rowBg = idx.isOdd
                                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                              : (isDark ? const Color(0xFF172033) : const Color(0xFFFBFDFF));

                                          return TableRow(
                                            decoration: BoxDecoration(
                                              color: rowBg,
                                              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0), width: 0.8)),
                                            ),
                                            children: [
                                              _td(
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                                                      child: Text(
                                                        s.name.isNotEmpty ? s.name[0] : 'S',
                                                        style: TextStyle(
                                                          color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        s.name,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _td(Text(
                                                s.businessName ?? '-',
                                                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              )),
                                              _td(Text(
                                                s.phone.isNotEmpty ? s.phone : '-',
                                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                              )),
                                              _td(Text(
                                                s.email.isNotEmpty ? s.email : '-',
                                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              )),
                                              _td(Text(
                                                s.address.isNotEmpty ? s.address : '-',
                                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              )),
                                              _td(Text(
                                                s.balance > 0 ? '$currency${s.balance.toStringAsFixed(2)}' : '$currency 0.00',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: s.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                ),
                                              )),
                                              _td(
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    if (s.balance > 0)
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF2563EB),
                                                          foregroundColor: Colors.white,
                                                          elevation: 0,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        ),
                                                        icon: const Icon(Icons.outbox, size: 14),
                                                        label: const Text('Pay Due', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                        onPressed: () => _openPaySupplierDialog(s),
                                                      ),
                                                    OutlinedButton.icon(
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                                        side: BorderSide(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                      ),
                                                      icon: const Icon(Icons.receipt_long, size: 14),
                                                      label: const Text('Ledger', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      onPressed: () => _openSupplierLedgerDialog(s),
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

  Widget _miniCard(String label, String value, Color color, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _th(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _td(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: child,
    );
  }
}
