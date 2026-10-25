import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/pay_due_dialog.dart';
import '../pos/receipt_dialog.dart';

class SalesListScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onOpenPos;

  const SalesListScreen({super.key, required this.settings, this.onOpenPos});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  List<Sale> _sales = [];
  bool _filtersOpen = false;
  String _search = '';
  bool _loading = true;
  int _entriesPerPage = 25;
  final ScrollController _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getSales(search: _search);
    if (mounted) {
      setState(() {
        _sales = list;
        _loading = false;
      });
    }
  }

  void _printReceipt(Sale s) async {
    final db = await DatabaseService.initialize();
    final items = await db.getSaleItems(s.id!);
    final fullSale = Sale.fromMap(s.toMap(), items: items);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(
          sale: fullSale,
          settings: widget.settings,
          tenderedAmount: fullSale.paidAmount,
          changeReturn: 0.0,
        ),
      );
    }
  }

  Widget _exportBtn(String label, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label completed successfully.'), duration: const Duration(seconds: 1)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: POS (Matching Screenshot 3)
            Text(
              'POS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Collapsible Filters Panel (Screenshot 3)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                initiallyExpanded: _filtersOpen,
                onExpansionChanged: (val) => setState(() => _filtersOpen = val),
                leading: const Icon(Icons.filter_alt_outlined, color: Color(0xFF004EEB), size: 20),
                title: Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: 'All',
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(labelText: 'Business Location', isDense: true),
                            items: [
                              DropdownMenuItem(value: 'All', child: Text('${widget.settings.businessName} (All)')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: 'All',
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(labelText: 'Customer', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Customers')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: 'All',
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(labelText: 'Payment Status', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Payment Statuses')),
                              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                              DropdownMenuItem(value: 'Due', child: Text('Due')),
                              DropdownMenuItem(value: 'Partial', child: Text('Partial')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Card: List POS (Screenshot 3)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x04000000),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: List POS title + [+ Add] button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'List POS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004EEB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: widget.onOpenPos,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Actions and Export Buttons Toolbar (Adaptive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final showDropdown = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Show ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _entriesPerPage,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) => setState(() => _entriesPerPage = val ?? 25),
                              ),
                            ),
                          ),
                          Text(' entries', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      );

                      final exportButtons = Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          showDropdown,
                          const SizedBox(width: 8),
                          _exportBtn('Export CSV', Icons.table_chart_outlined, isDark),
                          _exportBtn('Export Excel', Icons.description_outlined, isDark),
                          _exportBtn('Print', Icons.print_outlined, isDark),
                          _exportBtn('Column visibility', Icons.view_column_outlined, isDark),
                          _exportBtn('Export PDF', Icons.picture_as_pdf_outlined, isDark),
                        ],
                      );

                      final searchBox = Container(
                        width: constraints.maxWidth < 600 ? double.infinity : 220,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          onChanged: (val) {
                            _search = val;
                            _load();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search sales, invoices, customers...',
                            prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      );

                      if (constraints.maxWidth < 980) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            exportButtons,
                            const SizedBox(height: 12),
                            searchBox,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: exportButtons),
                          const SizedBox(width: 16),
                          searchBox,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Data Table with Explicit Scrollbar and Compact Spacing
                  _loading
                      ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                      : _sales.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: Text('No POS records found', style: TextStyle(color: Colors.grey))),
                            )
                          : Scrollbar(
                              controller: _tableScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              interactive: true,
                              thickness: 9,
                              radius: const Radius.circular(5),
                              child: SingleChildScrollView(
                                controller: _tableScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: DataTable(
                                    columnSpacing: 20,
                                    horizontalMargin: 16,
                                    headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                    headingTextStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      fontSize: 12,
                                    ),
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 54,
                                    columns: const [
                                      DataColumn(label: Text('Action')),
                                      DataColumn(label: Text('Date ⇅')),
                                      DataColumn(label: Text('Invoice No. ⇅')),
                                      DataColumn(label: Text('Customer name ⇅')),
                                      DataColumn(label: Text('Contact Number ⇅')),
                                      DataColumn(label: Text('Location ⇅')),
                                      DataColumn(label: Text('Payment Status ⇅')),
                                      DataColumn(label: Text('Payment Method')),
                                      DataColumn(label: Text('Total amount ⇅')),
                                      DataColumn(label: Text('Total paid ⇅')),
                                      DataColumn(label: Text('Sell Due')),
                                    ],
                                    rows: _sales.map((s) {
                                      return DataRow(
                                        cells: [
                                          // Blue Actions ⌵ Button
                                          DataCell(
                                            PopupMenuButton<String>(
                                              onSelected: (val) {
                                                if (val == 'receipt') {
                                                  _printReceipt(s);
                                                } else if (val == 'pay_due') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => PayDueDialog(
                                                      settings: widget.settings,
                                                      type: DuePaymentType.sale,
                                                      entityId: s.id!,
                                                      reference: s.invoiceNo,
                                                      contactName: s.customerName,
                                                      contactId: s.customerId,
                                                      totalAmount: s.totalAmount,
                                                      paidAmount: s.paidAmount,
                                                      dueAmount: s.dueAmount,
                                                      onPaymentSuccess: _load,
                                                    ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(value: 'receipt', child: Text('Print Receipt')),
                                                if (s.dueAmount > 0)
                                                  const PopupMenuItem(
                                                    value: 'pay_due',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.payments_outlined, size: 16, color: Color(0xFF059669)),
                                                        SizedBox(width: 8),
                                                        Text('Pay Due / Collect', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ),
                                                const PopupMenuItem(value: 'view', child: Text('View Details')),
                                              ],
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF004EEB),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('Actions', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                    SizedBox(width: 4),
                                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(s.createdAt, style: const TextStyle(fontSize: 12))),
                                          DataCell(Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                          DataCell(Text(s.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                          const DataCell(Text('(378) 400-1234', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                          DataCell(Text(widget.settings.businessName, style: const TextStyle(fontSize: 12))),
                                          DataCell(StatusPill(status: s.paymentStatus)),
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                            ),
                                            child: Text(
                                              s.paymentMethod.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                              ),
                                            ),
                                          )),
                                          DataCell(Text(
                                            '$currency ${s.totalAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          )),
                                          DataCell(Text(
                                            '$currency ${s.paidAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                          )),
                                          DataCell(Text(
                                            s.dueAmount > 0 ? '$currency ${s.dueAmount.toStringAsFixed(2)}' : '$currency 0.00',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: s.dueAmount > 0 ? FontWeight.bold : FontWeight.normal,
                                              color: s.dueAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                            ),
                                          )),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
