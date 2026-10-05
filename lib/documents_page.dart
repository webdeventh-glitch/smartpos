import 'core/money.dart';
import 'features/returns/returns_repository.dart';
import 'features/returns/return_dialog.dart';
import 'package:flutter/material.dart';
import 'stock_store.dart';

String _money(int value) => Money.format(value);
String _reference(Map<String, Object?> d) =>
    '${d['kind'] == 'sale' ? 'SAL' : 'PUR'}-${d['id'].toString().padLeft(5, '0')}';

class DocumentsPage extends StatefulWidget {
  final StockStore store;
  final String kind;
  final bool allowCreate;
  final Future<void> Function() onChanged;
  const DocumentsPage(
      {super.key,
      required this.store,
      required this.kind,
      this.allowCreate = true,
      required this.onChanged});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<Map<String, Object?>>? _rows;
  String? _error;
  bool get _sale => widget.kind == 'sale';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.store.documents(widget.kind);
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load records. Please retry.');
      }
    }
  }

  Future<void> _create() async {
    try {
      final products = await widget.store.products();
      if (!mounted) return;
      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add a product in Products first.')));
        return;
      }
      final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => OrderDialog(
              store: widget.store, kind: widget.kind, products: products));
      if (saved == true) {
        await _load();
        await widget.onChanged();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open entry. Please retry.')));
      }
    }
  }

  Future<void> _details(Map<String, Object?> document) async {
    try {
      final lines = await widget.store.documentLines(document['id'] as int);
      final payments = await widget.store.db.query('payments',
          where: 'document_id = ?', whereArgs: [document['id']]);
      final returns = _sale
          ? await ReturnsRepository(widget.store).history(document['id'] as int)
          : <Map<String, Object?>>[];
      if (!mounted) return;
      final startReturn = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(_reference(document)),
                content: SizedBox(
                    width: 540,
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Text(
                              '${_sale ? 'Customer' : 'Supplier'}: ${(document['party'] as String).isEmpty ? 'Not specified' : document['party']}'),
                          Text(DateTime.parse(document['created_at'] as String)
                              .toLocal()
                              .toString()
                              .substring(0, 19)),
                          if ((document['note'] as String).isNotEmpty)
                            Text(document['note'] as String),
                          const Divider(),
                          for (final line in lines)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${line['name']} (${line['sku']})',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          '${line['quantity']} x ${_money(line['price'] as int)} = ${_money((line['quantity'] as int) * (line['price'] as int))}'),
                                    ])),
                          const Divider(),
                          if (document['subtotal'] != null) ...[
                            Text(
                                'Subtotal: ${_money(document['subtotal'] as int)}'),
                            Text(
                                'Discount: ${_money(document['discount'] as int)}'),
                            Text(
                                'Tax${document['tax_inclusive'] == 1 ? ' (included)' : ''}: ${_money(document['tax'] as int)}'),
                          ],
                          Text('Total: ${_money(document['total'] as int)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          for (final payment in payments)
                            Text(
                                '${payment['method']}: ${_money(payment['amount'] as int)}'),
                          if (document['cash_received'] != null) ...[
                            Text(
                                'Cash received: ${_money(document['cash_received'] as int)}'),
                            Text(
                                'Change: ${_money(document['cash_change'] as int)}'),
                          ],
                          if (returns.isNotEmpty) ...[
                            const Divider(),
                            const Text('Return history'),
                            for (final row in returns)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                      'Return #${row['id']} - ${_money(row['total'] as int)} via ${row['method']}\n${row['items']}\n${row['reason']}\n${row['created_at']}')),
                            Text(
                                'Net sale after refunds: ${_money((document['total'] as int) - returns.fold<int>(0, (sum, row) => sum + (row['total'] as int)))}'),
                          ],
                          if (document['operation_id'] == null)
                            const Text(
                                'Payment status not recorded for this entry.'),
                        ]))),
                actions: [
                  if (_sale && document['operation_id'] != null)
                    FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.assignment_return),
                        label: const Text('Return items')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'))
                ],
              ));
      if (startReturn == true && mounted) await _returnItems(document);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load details.')));
      }
    }
  }

  Future<void> _returnItems(Map<String, Object?> document) async {
    try {
      final repository = ReturnsRepository(widget.store);
      final items = await repository.items(document['id'] as int);
      if (!mounted) return;
      if (items.every((item) => item.remaining == 0)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('All items have already been returned.')));
        return;
      }
      final id = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ReturnDialog(
              repository: repository,
              saleId: document['id'] as int,
              items: items));
      if (id != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Return #$id recorded. Stock restored.')));
        await _load();
        await widget.onChanged();
        if (mounted) await _details(document);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('Retry'))
      ]));
    }
    if (_rows == null) return const Center(child: CircularProgressIndicator());
    final total =
        _rows!.fold<int>(0, (sum, row) => sum + (row['total'] as int));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(_sale ? 'Sales' : 'Purchases',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(_sale
          ? 'Record sales and reduce inventory automatically.'
          : 'Record supplier purchases and receive inventory.'),
      const SizedBox(height: 16),
      Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.allowCreate)
              FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: Text(_sale ? 'New sale' : 'New purchase')),
            Text(
                '${_rows!.length} records | ${_sale ? 'Gross sales before refunds' : 'Total'}: ${_money(total)}'),
          ]),
      const SizedBox(height: 20),
      if (_rows!.isEmpty)
        const Card(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No records yet. Create your first entry.'))),
      for (final row in _rows!)
        Card(
            child: ListTile(
          isThreeLine: true,
          title: Text('${_reference(row)}  |  ${_money(row['total'] as int)}'),
          subtitle: Text(
              '${(row['party'] as String).isEmpty ? 'Not specified' : row['party']}\n${DateTime.parse(row['created_at'] as String).toLocal().toString().substring(0, 16)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _details(row),
        )),
    ]);
  }
}

class _DraftLine {
  final Map<String, Object?> product;
  final int quantity, price;
  _DraftLine(this.product, this.quantity, this.price);
}

class OrderDialog extends StatefulWidget {
  final StockStore store;
  final String kind;
  final List<Map<String, Object?>> products;
  const OrderDialog(
      {super.key,
      required this.store,
      required this.kind,
      required this.products});
  @override
  State<OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<OrderDialog> {
  final _form = GlobalKey<FormState>();
  final _party = TextEditingController(), _note = TextEditingController();
  final _quantity = TextEditingController(text: '1'),
      _price = TextEditingController();
  final List<_DraftLine> _lines = [];
  int? _selected;
  bool _saving = false;
  String? _error;
  bool get _sale => widget.kind == 'sale';
  int get _total =>
      _lines.fold(0, (sum, line) => sum + line.quantity * line.price);
  @override
  void dispose() {
    for (final c in [_party, _note, _quantity, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (!_form.currentState!.validate()) return;
    final product = widget.products.firstWhere((p) => p['id'] == _selected);
    final quantity = int.parse(_quantity.text);
    try {
      Money.add(_total, Money.lineTotal(Money.parse(_price.text), quantity));
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
      return;
    }
    if (_sale && quantity > (product['quantity'] as int)) {
      setState(() => _error = 'Not enough stock available.');
      return;
    }
    setState(() {
      _lines.add(_DraftLine(product, quantity, Money.parse(_price.text)));
      _selected = null;
      _price.clear();
      _quantity.text = '1';
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one item.');
      return;
    }
    if (_selected != null) {
      setState(() => _error = 'Add the selected item before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.postDocument(
          widget.kind,
          _party.text,
          _note.text,
          _lines
              .map((line) => OrderLine(
                  line.product['id'] as int, line.quantity, line.price))
              .toList());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is StateError
              ? e.message
              : 'Could not save. Please check your entry and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        title: Text(_sale ? 'New sale' : 'New purchase'),
        content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  TextField(
                      controller: _party,
                      enabled: !_saving,
                      maxLength: 100,
                      decoration: InputDecoration(
                          labelText: _sale
                              ? 'Customer (optional)'
                              : 'Supplier (optional)')),
                  Form(
                      key: _form,
                      child: Column(children: [
                        DropdownButtonFormField<int>(
                            key: ValueKey(_lines.length),
                            initialValue: _selected,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Product'),
                            items: widget.products
                                .where((p) => !_lines.any(
                                    (line) => line.product['id'] == p['id']))
                                .map((p) => DropdownMenuItem(
                                    value: p['id'] as int,
                                    child: Text(
                                        '${p['name']} | Stock: ${p['quantity']}',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (id) => setState(() {
                                      _selected = id;
                                      final product = widget.products
                                          .firstWhere((p) => p['id'] == id);
                                      _price.text = _sale
                                          ? Money.decimal(
                                              product['price'] as int)
                                          : '';
                                    }),
                            validator: (v) =>
                                v == null ? 'Select a product' : null),
                        TextFormField(
                            controller: _quantity,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Quantity'),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 1 || n > 100000000
                                  ? 'Enter a quantity from 1 to 100,000,000'
                                  : null;
                            }),
                        TextFormField(
                            controller: _price,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: _sale
                                    ? 'Selling price per unit (Rs)'
                                    : 'Purchase cost per unit (Rs)'),
                            validator: (v) => RegExp(r'^\d{1,8}(\.\d{1,2})?$')
                                    .hasMatch(v ?? '')
                                ? null
                                : 'Enter a price with up to 2 decimal places'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: _saving ? null : _add,
                            icon: const Icon(Icons.add),
                            label: const Text('Add item')),
                      ])),
                  const Divider(),
                  for (final line in _lines)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.product['name'] as String),
                        subtitle: Text(
                            '${line.quantity} x ${_money(line.price)} = ${_money(line.quantity * line.price)}'),
                        trailing: IconButton(
                            tooltip: 'Remove item',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _lines.remove(line);
                                      _selected = null;
                                      _price.clear();
                                    }),
                            icon: const Icon(Icons.close))),
                  Text('Total: ${_money(_total)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                      controller: _note,
                      enabled: !_saving,
                      maxLength: 200,
                      decoration:
                          const InputDecoration(labelText: 'Note (optional)')),
                  const Text(
                      'Saving posts this entry immediately and updates stock. Saved entries cannot be edited here.'),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                ]))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving
                  ? 'Saving...'
                  : _sale
                      ? 'Save sale'
                      : 'Save purchase'))
        ],
      ));
}
