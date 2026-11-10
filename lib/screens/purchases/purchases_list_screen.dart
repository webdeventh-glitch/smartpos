import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/pay_due_dialog.dart';
import 'add_purchase_dialog.dart';
import 'add_purchase_screen.dart';
import 'purchase_receipt_dialog.dart';

class PurchasesListScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onNavigateToAddPurchase;

  const PurchasesListScreen({
    super.key,
    required this.settings,
    this.onNavigateToAddPurchase,
  });

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  List<Purchase> _purchases = [];
  bool _loading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _paymentFilter = 'all';
  final ScrollController _hScroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getPurchases();
    if (mounted) {
      setState(() {
        _purchases = list;
        _loading = false;
      });
    }
  }

  void _openAddPurchase() {
    if (widget.onNavigateToAddPurchase != null) {
      widget.onNavigateToAddPurchase!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddPurchaseScreen(
            settings: widget.settings,
            onPurchaseSaved: _load,
          ),
        ),
      );
    }
  }

  Future<void> _deletePurchase(Purchase p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Invoice?'),
        content: Text(
          'Are you sure you want to delete purchase invoice "${p.refNo}" from ${p.supplierName}?\n\n'
          'This will automatically reverse the added stock quantity, subtract the payable from the supplier ledger, '
          'and restore any payment recorded in the cash register / bank account.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Invoice'),
          ),
        ],
      ),
    );

    if (confirmed == true && p.id != null) {
      final db = await DatabaseService.initialize();
      final ok = await db.deletePurchase(p.id!);
      if (ok) {
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase invoice ${p.refNo} deleted and stock reversed.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    }
  }

  Future<void> _openUpdateStatusDialog(Purchase p) async {
    String selectedStatus = p.status.toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Update Purchase Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Invoice: ${p.refNo} • ${p.supplierName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select New Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'received',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text('Received (Goods In Store)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_bottom_rounded, size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Text('Pending (Awaiting Delivery)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ordered',
                        child: Row(
                          children: [
                            Icon(Icons.assignment_rounded, size: 16, color: Color(0xFF6366F1)),
                            SizedBox(width: 8),
                            Text('Ordered (Purchase Order)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedStatus == 'received'
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedStatus == 'received'
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: selectedStatus == 'received'
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedStatus == 'received'
                                ? 'Marking as "Received" automatically adds line item quantities to inventory stock and posts payable due to the supplier ledger.'
                                : 'Status "${selectedStatus.toUpperCase()}" records the order without affecting physical inventory stock or supplier payable balance.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: selectedStatus == 'received'
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Apply Status'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          );
        },
      ),
    );

    if (updated == true && selectedStatus != p.status.toLowerCase() && p.id != null) {
      final db = await DatabaseService.initialize();
      final success = await db.updatePurchaseStatus(p.id!, selectedStatus);
      if (success) {
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase ${p.refNo} status updated to ${selectedStatus.toUpperCase()}!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    final filteredPurchases = _purchases.where((p) {
      if (_statusFilter != 'all' && p.status.toLowerCase() != _statusFilter) return false;
      if (_paymentFilter != 'all' && p.paymentStatus.toLowerCase() != _paymentFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchRef = p.refNo.toLowerCase().contains(q);
        final matchSup = p.supplierName.toLowerCase().contains(q);
        final matchLoc = p.locationName.toLowerCase().contains(q);
        final matchNote = p.note.toLowerCase().contains(q);
        if (!matchRef && !matchSup && !matchLoc && !matchNote) return false;
      }
      return true;
    }).toList();

    final totalPurchases = _purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalDue = _purchases.fold(0.0, (sum, p) => sum + p.dueAmount);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchases & Restocking',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage incoming supplier shipments, purchase invoices, and vendor payables.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Add Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _openAddPurchase,
                ),
              ],
            ),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _miniCard('Total Purchases', '$currency${totalPurchases.toStringAsFixed(2)}', const Color(0xFF4F46E5), isDark: isDark);
                final c2 = _miniCard('Total Payables Due', '$currency${totalDue.toStringAsFixed(2)}', const Color(0xFFEF4444), isDark: isDark);
                final c3 = _miniCard('Purchase Orders', '${_purchases.length} orders', const Color(0xFF10B981), isDark: isDark);

                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      c1,
                      const SizedBox(height: 10),
                      c2,
                      const SizedBox(height: 10),
                      c3,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: c1),
                    const SizedBox(width: 14),
                    Expanded(child: c2),
                    const SizedBox(width: 14),
                    Expanded(child: c3),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Status Segmented Quick Filter Tabs
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSegmentTab(
                      label: 'All Purchases',
                      count: _purchases.length,
                      isActive: _statusFilter == 'all',
                      activeColor: const Color(0xFF4F46E5),
                      isDark: isDark,
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      label: 'Received (In Store)',
                      count: _purchases.where((p) => p.status.toLowerCase() == 'received').length,
                      isActive: _statusFilter == 'received',
                      activeColor: const Color(0xFF10B981),
                      isDark: isDark,
                      onTap: () => setState(() => _statusFilter = 'received'),
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      label: 'Pending Delivery',
                      count: _purchases.where((p) => p.status.toLowerCase() == 'pending').length,
                      isActive: _statusFilter == 'pending',
                      activeColor: const Color(0xFFD97706),
                      isDark: isDark,
                      onTap: () => setState(() => _statusFilter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      label: 'Purchase Orders (PO)',
                      count: _purchases.where((p) => p.status.toLowerCase() == 'ordered').length,
                      isActive: _statusFilter == 'ordered',
                      activeColor: const Color(0xFF6366F1),
                      isDark: isDark,
                      onTap: () => setState(() => _statusFilter = 'ordered'),
                    ),
                  ],
                ),
              ),
            ),

            // Search & Filter Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search purchases by Ref No, Supplier, Location...',
                        hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        value: _statusFilter,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Status: All')),
                          DropdownMenuItem(value: 'received', child: Text('Received')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'ordered', child: Text('Ordered')),
                        ],
                        onChanged: (val) => setState(() => _statusFilter = val ?? 'all'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Payment Status Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        value: _paymentFilter,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Payment: All')),
                          DropdownMenuItem(value: 'paid', child: Text('Paid')),
                          DropdownMenuItem(value: 'due', child: Text('Due / Unpaid')),
                          DropdownMenuItem(value: 'partial', child: Text('Partial')),
                        ],
                        onChanged: (val) => setState(() => _paymentFilter = val ?? 'all'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))))
                  : filteredPurchases.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              _purchases.isEmpty ? 'No purchase records yet.' : 'No purchases match your filter.',
                              style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey),
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = math.max(constraints.maxWidth, 1100.0);
                              return Scrollbar(
                                controller: _hScroll,
                                thumbVisibility: true,
                                trackVisibility: true,
                                thickness: 9,
                                radius: const Radius.circular(5),
                                child: SingleChildScrollView(
                                  controller: _hScroll,
                                  scrollDirection: Axis.horizontal,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(1.4), // REF NO
                                          1: FlexColumnWidth(1.6), // DATE
                                          2: FlexColumnWidth(1.8), // LOCATION
                                          3: FlexColumnWidth(2.0), // SUPPLIER
                                          4: FlexColumnWidth(1.2), // STATUS
                                          5: FlexColumnWidth(1.2), // PAYMENT
                                          6: FlexColumnWidth(1.4), // TOTAL AMOUNT
                                          7: FlexColumnWidth(1.4), // PAID AMOUNT
                                          8: FlexColumnWidth(1.3), // BALANCE DUE
                                          9: FlexColumnWidth(1.2), // ACTIONS
                                        },
                                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2)),
                                            ),
                                            children: [
                                              _th('REF NO', isDark),
                                              _th('DATE', isDark),
                                              _th('LOCATION', isDark),
                                              _th('SUPPLIER', isDark),
                                              _th('STATUS', isDark),
                                              _th('PAYMENT', isDark),
                                              _th('TOTAL AMOUNT', isDark),
                                              _th('PAID AMOUNT', isDark),
                                              _th('BALANCE DUE', isDark),
                                              _th('ACTIONS', isDark),
                                            ],
                                          ),
                                          ...filteredPurchases.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final p = entry.value;
                                            final rowBg = idx.isOdd
                                                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                                : (isDark ? const Color(0xFF172033) : const Color(0xFFFBFDFF));

                                            return TableRow(
                                              decoration: BoxDecoration(
                                                color: rowBg,
                                                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0), width: 0.8)),
                                              ),
                                              children: [
                                                _td(Text(
                                                  p.refNo,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                                  ),
                                                )),
                                                _td(Text(
                                                  p.createdAt,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  ),
                                                )),
                                                _td(Text(
                                                  p.locationName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                                  ),
                                                )),
                                                _td(Text(
                                                  p.supplierName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                )),
                                                _td(
                                                  InkWell(
                                                    borderRadius: BorderRadius.circular(20),
                                                    onTap: () => _openUpdateStatusDialog(p),
                                                    child: Tooltip(
                                                      message: 'Click to update status (${p.status.toUpperCase()})',
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          StatusPill(status: p.status),
                                                          const SizedBox(width: 4),
                                                          Icon(
                                                            Icons.arrow_drop_down_rounded,
                                                            size: 16,
                                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                _td(StatusPill(status: p.paymentStatus)),
                                                _td(Text(
                                                  '$currency${p.totalAmount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                )),
                                                _td(Text(
                                                  '$currency${p.paidAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                                )),
                                                _td(Text(
                                                  p.dueAmount > 0 ? '$currency${p.dueAmount.toStringAsFixed(2)}' : '-',
                                                  style: TextStyle(
                                                    color: p.dueAmount > 0 ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF64748B) : Colors.grey),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )),
                                                _td(
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (p.dueAmount > 0)
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.payments_outlined,
                                                            size: 18,
                                                            color: Color(0xFF059669),
                                                          ),
                                                          tooltip: 'Pay Supplier Due',
                                                          onPressed: () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (_) => PayDueDialog(
                                                                settings: widget.settings,
                                                                type: DuePaymentType.purchase,
                                                                entityId: p.id!,
                                                                reference: p.referenceNo,
                                                                contactName: p.supplierName,
                                                                contactId: p.supplierId,
                                                                totalAmount: p.totalAmount,
                                                                paidAmount: p.paidAmount,
                                                                dueAmount: p.dueAmount,
                                                                onPaymentSuccess: _load,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit_note_rounded,
                                                          size: 20,
                                                          color: Color(0xFF4F46E5),
                                                        ),
                                                        tooltip: 'Update Status (Received / Pending / Ordered)',
                                                        onPressed: () => _openUpdateStatusDialog(p),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.print_outlined,
                                                          size: 18,
                                                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF004EEB),
                                                        ),
                                                        tooltip: 'Print Purchase Receipt',
                                                        onPressed: () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (_) => PurchaseReceiptDialog(
                                                              purchase: p,
                                                              settings: widget.settings,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline_rounded,
                                                          size: 18,
                                                          color: Color(0xFFEF4444),
                                                        ),
                                                        tooltip: 'Delete & Reverse Stock',
                                                        onPressed: () => _deletePurchase(p),
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

  Widget _buildSegmentTab({
    required String label,
    required int count,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? activeColor.withValues(alpha: 0.25) : activeColor.withValues(alpha: 0.1))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
