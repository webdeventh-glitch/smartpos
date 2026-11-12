import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/data_table_pagination_bar.dart';

/// Step 6.2: Purchase Orders Workflow (Ordered -> Partial -> Received + Supplier Email).
class PurchaseOrdersScreen extends StatefulWidget {
  final BusinessSettings settings;

  const PurchaseOrdersScreen({super.key, required this.settings});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  bool _loading = true;
  String _statusFilter = 'all'; // 'all', 'ordered', 'partial', 'received'
  String _search = '';
  int _currentPage = 1;
  int _entriesPerPage = 25;
  int _totalCount = 0;

  List<Purchase> _orders = [];
  Map<int, Contact> _suppliersById = {};
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
    final paged = await db.getPurchasesPaged(
      purchaseOrdersOnly: true,
      status: _statusFilter == 'all' ? null : _statusFilter,
      search: _search,
      page: _currentPage,
      pageSize: _entriesPerPage,
    );
    final summary = await db.getPendingPurchaseOrdersSummary(limit: 5);
    final suppliers = await db.getContacts(type: 'supplier');
    final map = <int, Contact>{
      for (final s in suppliers)
        if (s.id != null) s.id!: s,
    };

    if (!mounted) return;
    setState(() {
      _orders = paged.items;
      _totalCount = paged.totalCount;
      _summary = summary;
      _suppliersById = map;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return const Color(0xFF10B981);
      case 'partial':
        return const Color(0xFFF59E0B);
      case 'ordered':
      default:
        return const Color(0xFF0038B8);
    }
  }

  Future<void> _showCreatePurchaseOrderDialog() async {
    final db = await DatabaseService.initialize();
    final suppliers = await db.getContacts(type: 'supplier');
    final products = (await db.getProductsPaged(page: 1, pageSize: 100)).items;
    final nextRef = await db.generateNextPurchaseOrderRef();
    if (!mounted) return;

    Contact? selectedSupplier = suppliers.isNotEmpty ? suppliers.first : null;
    final refCtrl = TextEditingController(text: nextRef);
    final noteCtrl = TextEditingController();
    final List<Map<String, dynamic>> lines = [];
    Product? pickerProd = products.isNotEmpty ? products.first : null;
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(
      text: pickerProd != null ? pickerProd.purchasePrice.toStringAsFixed(2) : '0.00',
    );
    bool saving = false;
    String? err;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final total = lines.fold<double>(
            0.0,
            (s, l) => s + ((l['quantity'] as double) * (l['purchase_price'] as double)),
          );
          final cur = widget.settings.currencySymbol;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: Color(0xFF0038B8)),
                SizedBox(width: 8),
                Text('Create Purchase Order (PO)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: refCtrl,
                            decoration: const InputDecoration(
                              labelText: 'PO Reference #',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<Contact>(
                            initialValue: selectedSupplier,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Supplier',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: suppliers
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) => setDlg(() => selectedSupplier = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<Product>(
                            initialValue: pickerProd,
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
                            onChanged: (v) => setDlg(() {
                              pickerProd = v;
                              if (v != null) {
                                costCtrl.text = v.purchasePrice.toStringAsFixed(2);
                              }
                            }),
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
                            controller: costCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Unit Cost',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: pickerProd == null
                              ? null
                              : () {
                                  final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                                  final c = double.tryParse(costCtrl.text.trim()) ?? 0;
                                  if (q <= 0) return;
                                  setDlg(() {
                                    lines.add({
                                      'product_id': pickerProd!.id,
                                      'product_name': pickerProd!.name,
                                      'sku': pickerProd!.sku,
                                      'quantity': q,
                                      'received_quantity': 0.0,
                                      'purchase_price': c,
                                      'unit_cost': c,
                                      'selling_price': pickerProd!.sellingPrice,
                                    });
                                    err = null;
                                  });
                                },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Add products to create a purchase order.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 165),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: lines.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final l = lines[i];
                            final q = l['quantity'] as double;
                            final c = l['purchase_price'] as double;
                            return ListTile(
                              dense: true,
                              title: Text('${l['product_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: Text('${q.toStringAsFixed(2)} x $cur${c.toStringAsFixed(2)} = $cur${(q * c).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => setDlg(() => lines.removeAt(i)),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PO Notes / Supplier Delivery Terms',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('PO Total: $cur${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0038B8))),
                      ],
                    ),
                    if (err != null) ...[
                      const SizedBox(height: 6),
                      Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                label: Text(saving ? 'Saving...' : 'Create PO'),
                onPressed: saving
                    ? null
                    : () async {
                        if (lines.isEmpty) {
                          setDlg(() => err = 'Please add at least one line item.');
                          return;
                        }
                        setDlg(() => saving = true);
                        final nowStr = DateTime.now().toIso8601String();
                        final po = Purchase(
                          refNo: refCtrl.text.trim().isEmpty ? nextRef : refCtrl.text.trim(),
                          supplierId: selectedSupplier?.id,
                          supplierName: selectedSupplier?.name ?? 'General Supplier',
                          totalAmount: total,
                          paidAmount: 0.0,
                          status: 'ordered',
                          paymentStatus: 'due',
                          createdAt: nowStr,
                          note: noteCtrl.text.trim(),
                          itemsJson: jsonEncode(lines),
                          purchaseDate: nowStr,
                          isPurchaseOrder: true,
                        );
                        await db.createPurchase(purchase: po, items: lines);
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

  Future<void> _showReceiveGoodsDialog(Purchase po) async {
    if (po.id == null) return;
    final poItems = po.getItems();
    final pendingIndices = <int>[];
    for (int i = 0; i < poItems.length; i++) {
      final qty = (poItems[i]['quantity'] as num?)?.toDouble() ?? 0.0;
      final recv = (poItems[i]['received_quantity'] as num?)?.toDouble() ?? 0.0;
      if (qty - recv > 0.0001) pendingIndices.add(i);
    }
    if (pendingIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items on this Purchase Order have already been received.')),
      );
      return;
    }

    final qtyCtrls = <int, TextEditingController>{
      for (final i in pendingIndices)
        i: TextEditingController(
          text: (((poItems[i]['quantity'] as num?)?.toDouble() ?? 0.0) -
                  ((poItems[i]['received_quantity'] as num?)?.toDouble() ?? 0.0))
              .toStringAsFixed(2),
        ),
    };

    double calcTotal() {
      double s = 0.0;
      for (final i in pendingIndices) {
        final line = poItems[i];
        final rem = ((line['quantity'] as num?)?.toDouble() ?? 0.0) -
            ((line['received_quantity'] as num?)?.toDouble() ?? 0.0);
        final req = (double.tryParse(qtyCtrls[i]!.text.trim()) ?? 0.0).clamp(0.0, rem);
        final cost = (line['purchase_price'] as num?)?.toDouble() ??
            (line['unit_cost'] as num?)?.toDouble() ??
            0.0;
        s += req * cost;
      }
      return s;
    }

    final grnRefCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: calcTotal().toStringAsFixed(2));
    String paymentMethod = 'cash';
    final chequeNoCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final dueCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7))),
    );
    bool receiving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final grnTotal = calcTotal();
          final cur = widget.settings.currencySymbol;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_rounded, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Receive Goods — ${po.refNo}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    Text('Supplier: ${po.supplierName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pendingIndices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final i = pendingIndices[idx];
                          final line = poItems[i];
                          final ordered = (line['quantity'] as num?)?.toDouble() ?? 0.0;
                          final already = (line['received_quantity'] as num?)?.toDouble() ?? 0.0;
                          final rem = ordered - already;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${line['product_name'] ?? 'Product'}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text(
                                        'Ordered: ${ordered.toStringAsFixed(1)} | Received: ${already.toStringAsFixed(1)} | Rem: ${rem.toStringAsFixed(1)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: qtyCtrls[i],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Receive Qty',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setDlg(() {
                                      paidCtrl.text = calcTotal().toStringAsFixed(2);
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
                    TextField(
                      controller: grnRefCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Invoice / GRN Ref (optional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                              DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                              DropdownMenuItem(value: 'card', child: Text('Card')),
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
                              labelText: 'Paid ($cur${grnTotal.toStringAsFixed(2)})',
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
                              controller: bankCtrl,
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
                              controller: dueCtrl,
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: receiving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                icon: const Icon(Icons.check, size: 16),
                label: Text(receiving ? 'Receiving...' : 'Receive Into Stock ($cur${grnTotal.toStringAsFixed(2)})'),
                onPressed: receiving
                    ? null
                    : () async {
                        setDlg(() => receiving = true);
                        final db = await DatabaseService.initialize();
                        final qtyMap = <int, double>{
                          for (final i in pendingIndices)
                            i: double.tryParse(qtyCtrls[i]!.text.trim()) ?? 0.0,
                        };
                        try {
                          await db.receivePurchaseOrderItems(
                            poId: po.id!,
                            receiveQtyByLineIndex: qtyMap,
                            supplierInvoiceRef: grnRefCtrl.text.trim(),
                            paidNow: double.tryParse(paidCtrl.text.trim()) ?? grnTotal,
                            paymentMethod: paymentMethod,
                            chequeNumber: chequeNoCtrl.text.trim(),
                            bankName: bankCtrl.text.trim(),
                            chequeDueDate: dueCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Goods received and stock updated for ${po.refNo}'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                          await _load();
                        } catch (e) {
                          setDlg(() => receiving = false);
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

  Future<void> _emailPoToSupplier(Purchase po) async {
    final supplier = po.supplierId != null ? _suppliersById[po.supplierId!] : null;
    final items = po.getItems();
    final cur = widget.settings.currencySymbol;
    final rows = items.map((line) {
      final qty = (line['quantity'] as num?)?.toDouble() ?? 0.0;
      final cost = (line['purchase_price'] as num?)?.toDouble() ??
          (line['unit_cost'] as num?)?.toDouble() ??
          0.0;
      return [
        '${line['product_name'] ?? ''}',
        '${line['sku'] ?? ''}',
        qty.toStringAsFixed(2),
        '$cur${cost.toStringAsFixed(2)}',
        '$cur${(qty * cost).toStringAsFixed(2)}',
      ];
    }).toList();

    final pdfBytes = await PdfExportService.generateReportPdf(
      title: 'Purchase Order ${po.refNo}',
      subtitle: 'Supplier: ${po.supplierName} | Status: ${po.status.toUpperCase()}',
      settings: widget.settings,
      summaryMetrics: {
        'PO Number': po.refNo,
        'Order Date': po.createdAt.length >= 10 ? po.createdAt.substring(0, 10) : po.createdAt,
        'Line Items': '${items.length}',
        'Estimated Total': '$cur${po.totalAmount.toStringAsFixed(2)}',
      },
      headers: const ['Product', 'SKU', 'Ordered Qty', 'Unit Cost', 'Line Total'],
      rows: rows,
    );

    final body =
        'Dear ${po.supplierName},\n\nPlease find attached/below Purchase Order ${po.refNo} totaling $cur${po.totalAmount.toStringAsFixed(2)}.\nPlease confirm dispatch schedule.\n\nRegards,\n${widget.settings.businessName}';
    await Clipboard.setData(ClipboardData(text: body));
    final savedFile = await PdfExportService.emailPdfInvoice(
      bytes: pdfBytes,
      baseName: 'PurchaseOrder_${po.refNo}',
      recipientEmail: supplier?.email ?? '',
      subject: 'Purchase Order ${po.refNo} - ${widget.settings.businessName}',
      body: body,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PO PDF saved (${savedFile.path.split('\\').last}), email client launched & summary copied!'),
        backgroundColor: const Color(0xFF0038B8),
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
                const Icon(Icons.local_shipping_rounded, color: Color(0xFF0038B8), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Purchase Orders',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text(
                        'Issue supplier POs (Ordered -> Partial -> Received), receive GRNs into stock & email PO PDFs',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0038B8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: _showCreatePurchaseOrderDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Purchase Order'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statChip('Pending POs', '${_summary['count'] ?? 0}', const Color(0xFF0038B8), cardBg, borderColor),
                const SizedBox(width: 12),
                _statChip(
                  'Pending PO Value',
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
                  ('received', 'Received'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(st.$2),
                      selected: _statusFilter == st.$1,
                      onSelected: (_) {
                        setState(() {
                          _statusFilter = st.$1;
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
                      hintText: 'Search PO ref or supplier...',
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
                              ? const Center(child: Text('No purchase orders found.', style: TextStyle(color: Colors.grey)))
                              : ListView.separated(
                                  itemCount: _orders.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                                  itemBuilder: (_, idx) {
                                    final po = _orders[idx];
                                    final stColor = _statusColor(po.status);
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: stColor.withValues(alpha: 0.14),
                                        child: Icon(Icons.inventory_2_outlined, color: stColor, size: 18),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(po.refNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: stColor.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(po.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stColor)),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        'Supplier: ${po.supplierName} • Date: ${po.createdAt.length >= 10 ? po.createdAt.substring(0, 10) : po.createdAt}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$cur${po.totalAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                          ),
                                          const SizedBox(width: 10),
                                          OutlinedButton.icon(
                                            onPressed: () => _emailPoToSupplier(po),
                                            icon: const Icon(Icons.email_outlined, size: 15),
                                            label: const Text('Email PO'),
                                          ),
                                          const SizedBox(width: 8),
                                          if (po.status != 'received')
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () => _showReceiveGoodsDialog(po),
                                              icon: const Icon(Icons.download_done_rounded, size: 15),
                                              label: Text(po.status == 'partial' ? 'Receive Remaining' : 'Receive Goods'),
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

  Widget _statChip(String label, String val, Color color, Color bg, Color border) {
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
