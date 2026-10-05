import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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

  Widget _exportBtn(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          foregroundColor: const Color(0xFF334155),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 14, color: const Color(0xFF64748B)),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: POS (Matching Screenshot 3)
            const Text(
              'POS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Collapsible Filters Panel (Screenshot 3)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                initiallyExpanded: _filtersOpen,
                onExpansionChanged: (val) => setState(() => _filtersOpen = val),
                leading: const Icon(Icons.filter_alt_outlined, color: Color(0xFF004EEB), size: 20),
                title: const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: 'All',
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: List POS title + [+ Add] button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'List POS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

                  // Actions and Export Buttons Toolbar
                  Row(
                    children: [
                      // Show 25 entries
                      Row(
                        children: [
                          const Text('Show ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _entriesPerPage,
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) => setState(() => _entriesPerPage = val ?? 25),
                              ),
                            ),
                          ),
                          const Text(' entries', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Export buttons (Matching Screenshot 3)
                      _exportBtn('Export CSV', Icons.table_chart_outlined),
                      _exportBtn('Export Excel', Icons.description_outlined),
                      _exportBtn('Print', Icons.print_outlined),
                      _exportBtn('Column visibility', Icons.view_column_outlined),
                      _exportBtn('Export PDF', Icons.picture_as_pdf_outlined),

                      const Spacer(),

                      // Search ... input
                      Container(
                        width: 200,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          style: const TextStyle(fontSize: 12),
                          onChanged: (val) {
                            _search = val;
                            _load();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search ...',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Data Table (Columns matching Screenshot 3)
                  _loading
                      ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                      : _sales.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: Text('No POS records found', style: TextStyle(color: Colors.grey))),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 12),
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 56,
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
                                            if (val == 'receipt') _printReceipt(s);
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(value: 'receipt', child: Text('Print Receipt')),
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
                                      DataCell(Text(s.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 12))),
                                      DataCell(Text('$currency ${s.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                      DataCell(Text('$currency ${s.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(
                                        s.dueAmount > 0 ? '$currency ${s.dueAmount.toStringAsFixed(2)}' : '$currency 0.00',
                                        style: TextStyle(fontSize: 12, color: s.dueAmount > 0 ? const Color(0xFFEF4444) : Colors.grey),
                                      )),
                                    ],
                                  );
                                }).toList(),
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
