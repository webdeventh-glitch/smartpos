import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

/// Step 6.1: Sales Orders Management Screen (Ordered -> Partial -> Completed).
class SalesOrdersScreen extends StatefulWidget {
  final BusinessSettings settings;

  const SalesOrdersScreen({super.key, required this.settings});

  @override
  State<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends State<SalesOrdersScreen> {
  bool _loading = true;
  String _orderStatusFilter = 'all'; // 'all', 'ordered', 'partial', 'completed'
  String _search = '';
  int _currentPage = 1;
  int _entriesPerPage = 25;
  int _totalCount = 0;

  List<Sale> _orders = [];
  Map<String, dynamic> _summary = {'count': 0, 'totalAmount': 0.0};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final paged = await db.getSalesPaged(
      status: 'sales_order',
      search: _search,
      page: _currentPage,
      pageSize: _entriesPerPage,
    );
    final summary = await db.getPendingSalesOrdersSummary(limit: 5);

    List<Sale> filtered = paged.items;
    if (_orderStatusFilter != 'all') {
      filtered = filtered
          .where((o) =>
              (o.orderStatus.isEmpty ? 'ordered' : o.orderStatus) ==
              _orderStatusFilter)
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _orders = filtered;
      _totalCount =
          _orderStatusFilter == 'all' ? paged.totalCount : filtered.length;
      _summary = summary;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'partial':
        return const Color(0xFFF59E0B);
      case 'ordered':
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Future<void> _showCreateOrderDialog() async {
    final db = await DatabaseService.initialize();
    final customers = await db.getContacts(type: 'customer');
    final agents = await db.getCommissionAgents(activeOnly: true);
    final productsResp = await db.getProductsPaged(page: 1, pageSize: 100);
    final products = productsResp.items;
    final nextOrderNo = await db.generateNextSalesOrderNo();
    if (!mounted) return;

    Contact? selectedCustomer = customers.isNotEmpty ? customers.first : null;
    CommissionAgent? selectedAgent;
    final orderNoCtrl = TextEditingController(text: nextOrderNo);
    final noteCtrl = TextEditingController();
    final List<Map<String, dynamic>> draftLines = [];
    Product? pickerProduct = products.isNotEmpty ? products.first : null;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(
      text: pickerProduct != null ? pickerProduct.sellingPrice.toStringAsFixed(2) : '0.00',
    );
    bool saving = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final total = draftLines.fold<double>(
            0.0,
            (s, l) => s + ((l['qty'] as double) * (l['price'] as double)),
          );
          final cur = widget.settings.currencySymbol;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.assignment_add, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text('Create New Sales Order',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: orderNoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Order Number',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<Contact>(
                            initialValue: selectedCustomer,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Customer',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: customers
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) => setDlg(() => selectedCustomer = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<CommissionAgent?>(
                      initialValue: selectedAgent,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Commission Agent (Optional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<CommissionAgent?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...agents.map((a) => DropdownMenuItem<CommissionAgent?>(
                              value: a,
                              child: Text('${a.name} (${a.commissionPercent.toStringAsFixed(1)}%)'),
                            )),
                      ],
                      onChanged: (v) => setDlg(() => selectedAgent = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<Product>(
                            initialValue: pickerProduct,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Product',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: products
                                .map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text('${p.name} (${p.sku})',
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setDlg(() {
                                pickerProduct = v;
                                if (v != null) {
                                  priceCtrl.text = v.sellingPrice.toStringAsFixed(2);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 75,
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 95,
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: pickerProduct == null
                              ? null
                              : () {
                                  final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                                  final p = double.tryParse(priceCtrl.text.trim()) ?? 0;
                                  if (q <= 0) return;
                                  setDlg(() {
                                    draftLines.add({
                                      'product': pickerProduct!,
                                      'qty': q,
                                      'price': p,
                                    });
                                    errorMsg = null;
                                  });
                                },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (draftLines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text('Add at least one item to create a sales order.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 170),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: draftLines.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final line = draftLines[idx];
                            final prod = line['product'] as Product;
                            final q = line['qty'] as double;
                            final p = line['price'] as double;
                            return ListTile(
                              dense: true,
                              title: Text(prod.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: Text('${q.toStringAsFixed(2)} x $cur${p.toStringAsFixed(2)} = $cur${(q * p).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => setDlg(() => draftLines.removeAt(idx)),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Order Note / Delivery Instructions',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Order Total: $cur${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        ),
                      ],
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: Text(saving ? 'Saving...' : 'Save Sales Order'),
                onPressed: saving
                    ? null
                    : () async {
                        if (draftLines.isEmpty) {
                          setDlg(() => errorMsg = 'Please add at least one item.');
                          return;
                        }
                        setDlg(() => saving = true);
                        final cartItems = draftLines.map((l) {
                          final prod = l['product'] as Product;
                          final q = l['qty'] as double;
                          final p = l['price'] as double;
                          return CartItem(
                            product: prod,
                            unitPrice: p,
                            quantity: q,
                          );
                        }).toList();
                        final commAmt = selectedAgent != null
                            ? double.parse(((total * selectedAgent!.commissionPercent) / 100.0).toStringAsFixed(2))
                            : 0.0;
                        final sale = Sale(
                          invoiceNo: orderNoCtrl.text.trim().isEmpty
                              ? nextOrderNo
                              : orderNoCtrl.text.trim(),
                          customerId: selectedCustomer?.id,
                          customerName: selectedCustomer?.name ?? 'Walk-in Customer',
                          subtotal: total,
                          totalAmount: total,
                          paidAmount: 0.0,
                          paymentMethod: 'cash',
                          paymentStatus: 'due',
                          saleStatus: 'sales_order',
                          orderStatus: 'ordered',
                          note: noteCtrl.text.trim(),
                          createdAt: DateTime.now().toIso8601String(),
                          userName: AuthService.currentUser?.name ?? 'Cashier',
                          commissionAgentId: selectedAgent?.id,
                          commissionAgentName: selectedAgent?.name ?? '',
                          commissionPercent: selectedAgent?.commissionPercent ?? 0.0,
                          commissionAmount: commAmt,
                        );
                        await db.createSale(sale: sale, items: cartItems);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showConvertOrderDialog(Sale order) async {
    if (order.id == null) return;
    final db = await DatabaseService.initialize();
    final items = await db.getSaleItems(order.id!);
    if (!mounted) return;

    final pendingItems = items.where((i) => i.remainingQuantity > 0).toList();
    if (pendingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items in this sales order are already invoiced.')),
      );
      return;
    }

    final qtyCtrls = <int, TextEditingController>{
      for (final item in pendingItems)
        item.id!: TextEditingController(text: item.remainingQuantity.toStringAsFixed(2)),
    };
    String paymentMethod = 'cash';
    final paidCtrl = TextEditingController();
    final chequeNoCtrl = TextEditingController();
    final bankNameCtrl = TextEditingController();
    final chequeDueCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7))),
    );
    final noteCtrl = TextEditingController(
      text: 'Converted from Sales Order #${order.invoiceNo}',
    );
    bool converting = false;

    double computePlannedTotal() {
      double sum = 0.0;
      for (final item in pendingItems) {
        final q = double.tryParse(qtyCtrls[item.id!]!.text.trim()) ?? 0.0;
        final clamped = q.clamp(0.0, item.remainingQuantity);
        sum += clamped * item.unitPrice;
      }
      return sum;
    }

    paidCtrl.text = computePlannedTotal().toStringAsFixed(2);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final planned = computePlannedTotal();
          final cur = widget.settings.currencySymbol;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Convert ${order.invoiceNo} to Invoice',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${order.customerName} • Status: ${(order.orderStatus.isEmpty ? 'ordered' : order.orderStatus).toUpperCase()}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pendingItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final item = pendingItems[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text(
                                        'Ordered: ${item.quantity.toStringAsFixed(1)} | Fulfilled: ${item.fulfilledQuantity.toStringAsFixed(1)} | Rem: ${item.remainingQuantity.toStringAsFixed(1)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: qtyCtrls[item.id!],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Invoice Qty',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setDlg(() {
                                      paidCtrl.text = computePlannedTotal().toStringAsFixed(2);
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Payment Method',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('Cash')),
                              DropdownMenuItem(value: 'card', child: Text('Card')),
                              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                              DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                            ],
                            onChanged: (v) => setDlg(() => paymentMethod = v ?? 'cash'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Paid ($cur${planned.toStringAsFixed(2)})',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (paymentMethod == 'cheque') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: chequeNoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cheque No.',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: bankNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Bank Name',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: chequeDueCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Due Date (YYYY-MM-DD)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Note',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: converting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(converting ? 'Converting...' : 'Create Invoice ($cur${planned.toStringAsFixed(2)})'),
                onPressed: converting
                    ? null
                    : () async {
                        setDlg(() => converting = true);
                        final map = <int, double>{};
                        for (final item in pendingItems) {
                          map[item.id!] = double.tryParse(qtyCtrls[item.id!]!.text.trim()) ?? 0.0;
                        }
                        try {
                          final inv = await db.convertSalesOrderToInvoice(
                            orderId: order.id!,
                            fulfillQuantitiesByItemId: map,
                            paymentMethod: paymentMethod,
                            paidAmount: double.tryParse(paidCtrl.text.trim()) ?? planned,
                            note: noteCtrl.text.trim(),
                            chequeNumber: chequeNoCtrl.text.trim(),
                            bankName: bankNameCtrl.text.trim(),
                            chequeDueDate: chequeDueCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Generated Invoice ${inv.invoiceNo} from Sales Order ${order.invoiceNo}'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                          await _load();
                        } catch (e) {
                          setDlg(() => converting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF4F46E5), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales Orders',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text(
                        'Manage advance customer orders (Ordered -> Partial -> Completed) & convert to final invoices',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: _showCreateOrderDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Sales Order'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _kpiCard('Pending Orders', '${_summary['count'] ?? 0}', const Color(0xFF4F46E5), cardBg, borderColor),
                const SizedBox(width: 12),
                _kpiCard(
                  'Pending Order Value',
                  '$cur${((_summary['totalAmount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                  const Color(0xFFF59E0B),
                  cardBg,
                  borderColor,
                ),
                const Spacer(),
                for (final st in const [
                  ('all', 'All'),
                  ('ordered', 'Ordered'),
                  ('partial', 'Partial'),
                  ('completed', 'Completed'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(st.$2),
                      selected: _orderStatusFilter == st.$1,
                      onSelected: (_) {
                        setState(() {
                          _orderStatusFilter = st.$1;
                          _currentPage = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search order # or customer...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _search = v;
                      _currentPage = 1;
                      _load();
                    },
                  ),
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
                child: Column(
                  children: [
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _orders.isEmpty
                              ? const Center(child: Text('No sales orders found.', style: TextStyle(color: Colors.grey)))
                              : ListView.separated(
                                  itemCount: _orders.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                                  itemBuilder: (_, idx) {
                                    final order = _orders[idx];
                                    final st = order.orderStatus.isEmpty ? 'ordered' : order.orderStatus;
                                    final stColor = _statusColor(st);
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: stColor.withValues(alpha: 0.14),
                                        child: Icon(Icons.shopping_bag_outlined, color: stColor, size: 18),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(order.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: stColor.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(st.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stColor)),
                                          ),
                                          if (order.commissionAgentName.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text('Agent: ${order.commissionAgentName}',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        'Customer: ${order.customerName} • Date: ${order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : order.createdAt}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$cur${order.totalAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                          ),
                                          const SizedBox(width: 12),
                                          if (st != 'completed')
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              onPressed: () => _showConvertOrderDialog(order),
                                              icon: const Icon(Icons.receipt_long, size: 15),
                                              label: Text(st == 'partial' ? 'Convert Remaining' : 'Convert to Invoice'),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                    DataTablePaginationBar(
                      totalItems: _totalCount,
                      currentPage: _currentPage,
                      pageSize: _entriesPerPage,
                      onPageChanged: (p) {
                        setState(() => _currentPage = p);
                        _load();
                      },
                      onPageSizeChanged: (r) {
                        setState(() {
                          _entriesPerPage = r;
                          _currentPage = 1;
                        });
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String val, Color color, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
