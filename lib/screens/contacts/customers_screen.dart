import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../pos/quick_customer_dialog.dart';
import 'contact_ledger_screen.dart';
import 'payment_reminder_dialog.dart';
import '../../services/print_service.dart';
import '../../widgets/data_table_pagination_bar.dart';
import '../../widgets/record_contact_payment_dialog.dart';
import '../../widgets/universal_print_preview_dialog.dart';

class CustomersScreen extends StatefulWidget {
  final BusinessSettings settings;

  const CustomersScreen({super.key, required this.settings});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Contact> _customers = [];
  bool _loading = true;
  String _filter = 'all'; // 'all', 'defaulters', 'over_limit', 'clear'
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize = 25;
  int _totalFilteredCount = 0;
  int _totalCustomersCount = 0;
  int _defaultersCount = 0;
  int _overLimitCount = 0;
  int _clearCount = 0;
  double _totalReceivable = 0.0;
  Timer? _searchDebounce;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refreshStats = true}) async {
    final db = await DatabaseService.initialize();
    var paged = await db.getContactsPaged(
      type: 'customer',
      search: _searchQuery,
      balanceFilter: _filter,
      page: _currentPage,
      pageSize: _pageSize,
    );
    if (paged.items.isEmpty &&
        paged.totalCount > 0 &&
        _currentPage > paged.totalPages) {
      _currentPage = paged.totalPages;
      paged = await db.getContactsPaged(
        type: 'customer',
        search: _searchQuery,
        balanceFilter: _filter,
        page: _currentPage,
        pageSize: _pageSize,
      );
    }

    Map<String, num>? stats;
    if (refreshStats) {
      stats = await db.getContactSummaryStats(type: 'customer');
    }

    if (mounted) {
      setState(() {
        _customers = paged.items;
        _totalFilteredCount = paged.totalCount;
        if (stats != null) {
          _totalCustomersCount = stats['totalCount']?.toInt() ?? 0;
          _defaultersCount = stats['activeDuesCount']?.toInt() ?? 0;
          _overLimitCount = stats['overLimitCount']?.toInt() ?? 0;
          _clearCount = stats['clearCount']?.toInt() ?? 0;
          _totalReceivable = stats['totalReceivable']?.toDouble() ?? 0.0;
        }
        _loading = false;
      });
    }
  }

  bool get _canManageCustomers =>
      AuthService.currentUser?.hasPermission('customer.manage') ?? true;

  bool get _canRecordKhataPayment =>
      AuthService.currentUser?.hasPermission('contact.khata_payment') ?? true;

  void _denyPermission(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _openAddCustomer([Contact? customerToEdit]) async {
    if (!_canManageCustomers) {
      _denyPermission(
          'Access Denied: You do not have permission to manage customers.');
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => QuickCustomerDialog(
        customerToEdit: customerToEdit,
        onCustomerAdded: (_) => _load(),
      ),
    );
  }

  Future<void> _showCustomerGroupsManager() async {
    if (!_canManageCustomers) {
      _denyPermission(
          'Access Denied: You do not have permission to manage customer groups.');
      return;
    }
    final db = await DatabaseService.initialize();
    List<CustomerGroup> groups = await db.getCustomerGroups();
    final priceGroups = await db.getSellingPriceGroups();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> openGroupForm([CustomerGroup? existing]) async {
            final nameCtrl = TextEditingController(text: existing?.name ?? '');
            final amountCtrl = TextEditingController(
              text: existing != null ? existing.amount.toString() : '-10.0',
            );
            String calcType =
                existing?.priceCalculationType == 'selling_price_group' &&
                        priceGroups.isNotEmpty
                    ? 'selling_price_group'
                    : 'percentage';
            int? selectedPriceGroupId = existing?.sellingPriceGroupId ??
                (priceGroups.isNotEmpty ? priceGroups.first.id : null);

            await showDialog(
              context: ctx,
              builder: (formCtx) => StatefulBuilder(
                builder: (formCtx, setFormState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: Text(existing == null
                      ? 'New Customer Group'
                      : 'Edit Customer Group'),
                  content: SizedBox(
                    width: 380,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Group Name (e.g. Wholesale, VIP) *',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: calcType,
                          decoration: const InputDecoration(
                            labelText: 'Price Calculation Type',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'percentage',
                              child: Text('Percentage (% Discount / Markup)'),
                            ),
                            if (priceGroups.isNotEmpty)
                              const DropdownMenuItem(
                                value: 'selling_price_group',
                                child: Text('Selling Price Group'),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setFormState(() => calcType = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        if (calcType == 'percentage')
                          TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            decoration: const InputDecoration(
                              labelText:
                                  'Price Adjustment % (-10 = 10% off, +5 = 5% markup)',
                              isDense: true,
                            ),
                          )
                        else
                          DropdownButtonFormField<int?>(
                            initialValue: selectedPriceGroupId,
                            decoration: const InputDecoration(
                              labelText: 'Linked Selling Price Group',
                              isDense: true,
                            ),
                            items: priceGroups
                                .map((pg) => DropdownMenuItem<int?>(
                                      value: pg.id,
                                      child: Text(pg.name),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setFormState(() => selectedPriceGroupId = v),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(formCtx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final pct = calcType == 'percentage'
                            ? (double.tryParse(amountCtrl.text.trim()) ?? 0.0)
                            : 0.0;
                        final next = CustomerGroup(
                          id: existing?.id,
                          name: nameCtrl.text.trim(),
                          amount: pct,
                          priceCalculationType: calcType,
                          sellingPriceGroupId: calcType == 'selling_price_group'
                              ? selectedPriceGroupId
                              : null,
                        );
                        if (existing?.id != null) {
                          await db.updateCustomerGroup(next);
                        } else {
                          await db.addCustomerGroup(next);
                        }
                        final refreshed = await db.getCustomerGroups();
                        if (ctx.mounted) setDlgState(() => groups = refreshed);
                        if (formCtx.mounted) Navigator.pop(formCtx);
                        _load();
                      },
                      child: const Text('Save Group'),
                    ),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Customer Groups & Tiered Pricing',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Group'),
                  onPressed: () => openGroupForm(),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              height: 300,
              child: groups.isEmpty
                  ? const Center(child: Text('No customer groups created yet.'))
                  : ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final g = groups[i];
                        final String tag;
                        if (g.priceCalculationType == 'selling_price_group') {
                          final spg =
                              priceGroups.cast<SellingPriceGroup?>().firstWhere(
                                    (p) => p?.id == g.sellingPriceGroupId,
                                    orElse: () => null,
                                  );
                          tag = spg != null
                              ? 'Selling Price Group: ${spg.name}'
                              : 'Selling Price Group';
                        } else {
                          tag = g.amount == 0
                              ? 'Base Price (0%)'
                              : g.amount < 0
                                  ? '${g.amount.abs().toStringAsFixed(1)}% Discount'
                                  : '+${g.amount.toStringAsFixed(1)}% Markup';
                        }
                        return ListTile(
                          leading: const Icon(Icons.groups_rounded,
                              color: Color(0xFF4F46E5)),
                          title: Text(g.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Tier Rule: $tag'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Color(0xFF4F46E5), size: 19),
                                onPressed: () => openGroupForm(g),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 19),
                                onPressed: () async {
                                  if (g.id == null) return;
                                  await db.deleteCustomerGroup(g.id!);
                                  final refreshed =
                                      await db.getCustomerGroups();
                                  if (ctx.mounted)
                                    setDlgState(() => groups = refreshed);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPayDueDialog(Contact customer) async {
    if (!_canRecordKhataPayment) {
      _denyPermission(
          'Access Denied: You do not have permission to record khata payments.');
      return;
    }
    await RecordContactPaymentDialog.show(
      context,
      contact: customer,
      contactType: 'customer',
      settings: widget.settings,
      onPaymentRecorded: _load,
    );
  }

  Future<void> _openLedgerDialog(Contact customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactLedgerScreen(
          contact: customer,
          contactType: 'customer',
          settings: widget.settings,
          onPaymentRecorded: () => _load(),
        ),
      ),
    );
    _load();
  }

  void _openReminderDialog(Contact customer) {
    showDialog(
      context: context,
      builder: (_) => PaymentReminderDialog(
        contact: customer,
        settings: widget.settings,
      ),
    );
  }

  Future<void> _printDefaultersSheet(List<Contact> defaulters) async {
    List<Contact> listToPrint = defaulters;
    if (listToPrint.isEmpty) {
      final db = await DatabaseService.initialize();
      listToPrint = (await db.getContactsPaged(
        type: 'customer',
        balanceFilter: 'defaulters',
        pageSize: 1000,
        includeTotalCount: false,
      ))
          .items;
    }
    if (!mounted) return;
    final html = PrintService.generateDefaultersListHtml(
      settings: widget.settings,
      defaulters: listToPrint,
      paperSize: widget.settings.receiptPaperSize,
    );
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Outstanding Dues & Defaulters Recovery Sheet',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final totalReceivable = _totalReceivable;
    final displayedCustomers = _customers;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar (Responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (_canManageCustomers)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.groups_rounded, size: 18),
                        label: const Text('Customer Groups',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _showCustomerGroupsManager,
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Defaulters Sheet',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _printDefaultersSheet(const <Contact>[]),
                    ),
                    if (_canManageCustomers)
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
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Customer',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _openAddCustomer(),
                      ),
                  ],
                );

                final titleColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customers & Defaulters Khata Management',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track customer accounts, overdue defaulters, send WhatsApp & SMS reminders, and collect dues.',
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleColumn,
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleColumn),
                    const SizedBox(width: 16),
                    actions,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // 4 KPI Summary Cards (Responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _miniCard('Total Customers', '$_totalCustomersCount',
                    const Color(0xFF4F46E5),
                    isDark: isDark);
                final c2 = _miniCard('Defaulters (Pending Due)',
                    '$_defaultersCount customers', const Color(0xFFEF4444),
                    isDark: isDark);
                final c3 = _miniCard(
                    'Total Overdue Receivables',
                    '$currency${totalReceivable.toStringAsFixed(2)}',
                    const Color(0xFFDC2626),
                    isDark: isDark);
                final c4 = _miniCard('Credit Limit Exceeded',
                    '$_overLimitCount accounts', const Color(0xFFF59E0B),
                    isDark: isDark);

                if (constraints.maxWidth >= 1050) {
                  return Row(
                    children: [
                      Expanded(child: c1),
                      const SizedBox(width: 12),
                      Expanded(child: c2),
                      const SizedBox(width: 12),
                      Expanded(child: c3),
                      const SizedBox(width: 12),
                      Expanded(child: c4),
                    ],
                  );
                } else if (constraints.maxWidth >= 600) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: c1),
                          const SizedBox(width: 12),
                          Expanded(child: c2),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: c3),
                          const SizedBox(width: 12),
                          Expanded(child: c4),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    c1,
                    const SizedBox(height: 10),
                    c2,
                    const SizedBox(height: 10),
                    c3,
                    const SizedBox(height: 10),
                    c4,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Search and Defaulter Filter Bar (Responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final chips = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _filterChip('all', 'All ($_totalCustomersCount)', isDark),
                    _filterChip('defaulters',
                        'Defaulters / Dues ($_defaultersCount)', isDark,
                        isHighlight: true, icon: Icons.warning_amber_rounded),
                    _filterChip('over_limit',
                        'Limit Exceeded ($_overLimitCount)', isDark,
                        icon: Icons.block_rounded),
                    _filterChip('clear', 'Zero Balance ($_clearCount)', isDark,
                        icon: Icons.check_circle_outline_rounded),
                  ],
                );

                final searchBox = SizedBox(
                  width: constraints.maxWidth < 750 ? double.infinity : 280,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                                _load(refreshStats: false);
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                        _currentPage = 1;
                      });
                      _searchDebounce?.cancel();
                      if (Platform.environment.containsKey('FLUTTER_TEST')) {
                        _load(refreshStats: false);
                      } else {
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 220),
                          () => _load(refreshStats: false),
                        );
                      }
                    },
                  ),
                );

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: constraints.maxWidth < 950
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            chips,
                            const SizedBox(height: 12),
                            searchBox,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: chips),
                            const SizedBox(width: 16),
                            searchBox,
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 18),

            // Customers Table (Responsive Full Width)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()))
                  : displayedCustomers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 40,
                                    color: isDark
                                        ? const Color(0xFF475569)
                                        : const Color(0xFFCBD5E1)),
                                const SizedBox(height: 10),
                                Text(
                                  _filter == 'defaulters'
                                      ? 'Great news! No defaulters found.'
                                      : 'No customers match the selected criteria.',
                                  style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth =
                                  math.max(constraints.maxWidth, 950.0);
                              return Scrollbar(
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(
                                            2.2), // CUSTOMER NAME
                                        1: FlexColumnWidth(1.8), // BUSINESS
                                        2: FlexColumnWidth(1.4), // PHONE
                                        3: FlexColumnWidth(1.4), // CREDIT LIMIT
                                        4: FlexColumnWidth(1.4), // CURRENT DUE
                                        5: FlexColumnWidth(
                                            2.2), // ACTIONS & REMINDERS
                                      },
                                      defaultVerticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFFF8FAFC),
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF334155)
                                                        : const Color(
                                                            0xFFE2E8F0),
                                                    width: 1.2)),
                                          ),
                                          children: [
                                            _th('CUSTOMER NAME', isDark),
                                            _th('BUSINESS', isDark),
                                            _th('PHONE', isDark),
                                            _th('CREDIT LIMIT', isDark),
                                            _th('CURRENT DUE', isDark),
                                            _th('ACTIONS & REMINDERS', isDark),
                                          ],
                                        ),
                                        ...displayedCustomers
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final idx = entry.key;
                                          final c = entry.value;
                                          final isOverLimit =
                                              c.creditLimit > 0 &&
                                                  c.balance > c.creditLimit;
                                          final rowBg = idx.isOdd
                                              ? (isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white)
                                              : (isDark
                                                  ? const Color(0xFF172033)
                                                  : const Color(0xFFFBFDFF));

                                          return TableRow(
                                            decoration: BoxDecoration(
                                              color: rowBg,
                                              border: Border(
                                                  bottom: BorderSide(
                                                      color: isDark
                                                          ? const Color(
                                                                  0xFF334155)
                                                              .withValues(
                                                                  alpha: 0.6)
                                                          : const Color(
                                                              0xFFE2E8F0),
                                                      width: 0.8)),
                                            ),
                                            children: [
                                              _td(
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: c
                                                                  .balance >
                                                              0
                                                          ? const Color(
                                                              0xFFFEE2E2)
                                                          : (isDark
                                                              ? const Color(
                                                                  0xFF312E81)
                                                              : const Color(
                                                                  0xFFEEF2FF)),
                                                      child: Text(
                                                        c.name.isNotEmpty
                                                            ? c.name[0]
                                                            : 'C',
                                                        style: TextStyle(
                                                          color: c.balance > 0
                                                              ? const Color(
                                                                  0xFFDC2626)
                                                              : const Color(
                                                                  0xFF4F46E5),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            c.name,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : const Color(
                                                                      0xFF0F172A),
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          if (c.customerGroupName !=
                                                                  null &&
                                                              c.customerGroupName!
                                                                  .isNotEmpty)
                                                            Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      top: 2),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          1),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                    0xFFEEF2FF),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                              child: Text(
                                                                c.customerGroupName!,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Color(
                                                                        0xFF4F46E5),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700),
                                                              ),
                                                            ),
                                                          if (isOverLimit)
                                                            const Text(
                                                              'Exceeded Limit!',
                                                              style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .orange,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _td(Text(
                                                c.businessName?.isNotEmpty ==
                                                        true
                                                    ? c.businessName!
                                                    : '-',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFCBD5E1)
                                                        : Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              )),
                                              _td(Text(
                                                c.phone.isNotEmpty
                                                    ? c.phone
                                                    : '-',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFCBD5E1)
                                                        : Colors.black87),
                                              )),
                                              _td(Text(
                                                '$currency${c.creditLimit.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFCBD5E1)
                                                        : Colors.black87),
                                              )),
                                              _td(Text(
                                                c.balance > 0
                                                    ? '$currency${c.balance.toStringAsFixed(2)}'
                                                    : '$currency 0.00',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: c.balance > 0
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFF10B981),
                                                ),
                                              )),
                                              _td(
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    // Pay Due
                                                    if (c.balance > 0) ...[
                                                      if (_canRecordKhataPayment)
                                                        ElevatedButton.icon(
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                    0xFF059669),
                                                            foregroundColor:
                                                                Colors.white,
                                                            elevation: 0,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical:
                                                                        6),
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6)),
                                                          ),
                                                          icon: const Icon(
                                                              Icons
                                                                  .attach_money,
                                                              size: 14),
                                                          label: const Text(
                                                              'Pay Due',
                                                              style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                          onPressed: () =>
                                                              _openPayDueDialog(
                                                                  c),
                                                        ),

                                                      // WhatsApp / SMS Reminder
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                  0xFF10B981),
                                                          foregroundColor:
                                                              Colors.white,
                                                          elevation: 0,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 6),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6)),
                                                        ),
                                                        icon: const FaIcon(
                                                            FontAwesomeIcons
                                                                .whatsapp,
                                                            size: 13),
                                                        label: const Text(
                                                            'Reminder',
                                                            style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                        onPressed: () =>
                                                            _openReminderDialog(
                                                                c),
                                                      ),
                                                    ],

                                                    // Khata Ledger
                                                    OutlinedButton.icon(
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        foregroundColor: isDark
                                                            ? const Color(
                                                                0xFFA5B4FC)
                                                            : const Color(
                                                                0xFF4F46E5),
                                                        side: BorderSide(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF4338CA)
                                                                : const Color(
                                                                    0xFFC7D2FE)),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 6),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6)),
                                                      ),
                                                      icon: const Icon(
                                                          Icons.receipt_long,
                                                          size: 14),
                                                      label: const Text(
                                                          'Ledger',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      onPressed: () =>
                                                          _openLedgerDialog(c),
                                                    ),
                                                    if (_canManageCustomers)
                                                      OutlinedButton.icon(
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor: isDark
                                                              ? const Color(
                                                                  0xFF94A3B8)
                                                              : const Color(
                                                                  0xFF475569),
                                                          side: BorderSide(
                                                              color: isDark
                                                                  ? const Color(
                                                                      0xFF334155)
                                                                  : const Color(
                                                                      0xFFCBD5E1)),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 6),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6)),
                                                        ),
                                                        icon: const Icon(
                                                            Icons.edit_outlined,
                                                            size: 14),
                                                        label: const Text(
                                                            'Edit',
                                                            style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                        onPressed: () =>
                                                            _openAddCustomer(c),
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
            if (!_loading && _customers.isNotEmpty) ...[
              const SizedBox(height: 12),
              DataTablePaginationBar(
                currentPage: _currentPage,
                pageSize: _pageSize,
                totalItems: _totalFilteredCount,
                onPageChanged: (newPage) {
                  setState(() => _currentPage = newPage);
                  _load(refreshStats: false);
                },
                onPageSizeChanged: (newSize) {
                  setState(() {
                    _pageSize = newSize;
                    _currentPage = 1;
                  });
                  _load(refreshStats: false);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String id, String label, bool isDark,
      {bool isHighlight = false, IconData? icon}) {
    final isSelected = _filter == id;
    final color =
        isHighlight ? const Color(0xFFEF4444) : const Color(0xFF4F46E5);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _filter = id;
          _currentPage = 1;
        });
        _load(refreshStats: false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isHighlight
                  ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isHighlight
                    ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                    : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? Colors.white
                    : (isHighlight
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isHighlight
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(String label, String value, Color color,
      {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: color),
              overflow: TextOverflow.ellipsis),
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
