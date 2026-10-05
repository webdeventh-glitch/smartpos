import 'core/money.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'stock_store.dart';
import 'documents_page.dart';

typedef RowData = Map<String, Object?>;
String money(int cents) => Money.format(cents);

class StockPage extends StatefulWidget {
  final StockStore store;
  final bool embedded;
  final int initialSection;
  const StockPage(
      {super.key,
      required this.store,
      this.embedded = false,
      this.initialSection = 0});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<RowData> _products = [], _history = [];
  String _search = '';
  bool _lowOnly = false, _historyView = false, _loading = true;
  String? _error;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _historyView = _section == 2;
    _lowOnly = _section == 1;
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await widget.store.products();
      final history = await widget.store.history();
      if (mounted) {
        setState(() {
          _products = products;
          _history = history;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load stock: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit([RowData? row]) async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProductDialog(store: widget.store, product: row));
    await _load();
  }

  Future<void> _adjust(RowData row, bool incoming) async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MovementDialog(
            store: widget.store, product: row, incoming: incoming));
    await _load();
  }

  Future<void> _delete(RowData row) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Delete product?'),
                content: Text(
                    'Remove ${row['name']} and its ${row['quantity']} remaining units? Stock history will be kept.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'))
                ]));
    if (confirm != true) return;
    try {
      await widget.store.delete(row['id'] as int);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  void _navigate(int index) {
    setState(() {
      _section = index;
      _historyView = index == 2;
      _lowOnly = index == 1;
    });
  }

  Widget _navigation({bool drawer = false}) {
    final selected = _section;
    return Material(
      color: const Color(0xFF173D38),
      child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Row(children: [
              Icon(Icons.inventory_2_outlined, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                  child: Text('Simple Stock',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold))),
            ])),
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('WORKSPACE',
                style: TextStyle(
                    color: Colors.white60, fontSize: 11, letterSpacing: 2))),
        for (final entry in [
          (Icons.inventory_2_outlined, 'Products'),
          (Icons.warning_amber_rounded, 'Low stock'),
          (Icons.history, 'Stock history'),
          (Icons.point_of_sale, 'Sales'),
          (Icons.shopping_cart_outlined, 'Purchases'),
        ].indexed)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                selected: selected == entry.$1,
                selectedTileColor: const Color(0xFF2F6F68),
                textColor: Colors.white70,
                iconColor: Colors.white70,
                selectedColor: Colors.white,
                leading: Icon(entry.$2.$1),
                title: Text(entry.$2.$2),
                onTap: () {
                  _navigate(entry.$1);
                  if (drawer) Navigator.pop(context);
                },
              )),
        const Divider(color: Colors.white24, height: 40),
        const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.offline_bolt_outlined, color: Colors.white60),
            title:
                Text('Local workspace', style: TextStyle(color: Colors.white)),
            subtitle: Text('Saved on this computer',
                style: TextStyle(color: Colors.white60, fontSize: 12))),
      ])),
    );
  }

  void _profile() => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text('Local User'),
            content: const Text(
                'You are using a local workspace on this computer. Login and user accounts have not been configured.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'))
            ],
          ));

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return Center(
            child: TextButton(onPressed: _load, child: Text(_error!)));
      }
      return _content();
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _navigation(drawer: true)),
      appBar: AppBar(
        title: Text(wide ? 'Inventory workspace' : 'Simple Stock',
            style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            tooltip: 'User menu',
            onSelected: (_) => _profile(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profile', child: Text('View profile'))
            ],
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  const CircleAvatar(
                      radius: 17, child: Icon(Icons.person_outline, size: 20)),
                  if (MediaQuery.sizeOf(context).width >= 600) ...[
                    const SizedBox(width: 10),
                    const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Local User',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('Local workspace',
                              style: TextStyle(fontSize: 11)),
                        ]),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ])),
          ),
        ],
      ),
      body: Row(children: [
        if (wide) SizedBox(width: 240, child: _navigation()),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                            Text(_error!),
                            TextButton(
                                onPressed: _load, child: const Text('Retry')),
                          ])))
                    : _section >= 3
                        ? DocumentsPage(
                            key: ValueKey(_section),
                            store: widget.store,
                            kind: _section == 3 ? 'sale' : 'purchase',
                            onChanged: _load)
                        : _content()),
      ]),
    );
  }

  Widget _content() => LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final padding = compact ? 16.0 : 24.0;
        final available = constraints.maxWidth - padding * 2;
        final columns = available >= 900
            ? 4
            : available >= 440
                ? 2
                : 1;
        final cardWidth = (available - (columns - 1) * 12) / columns;
        final low = _products
            .where((p) => (p['quantity'] as int) <= (p['minimum'] as int))
            .length;
        final units =
            _products.fold<int>(0, (sum, p) => sum + (p['quantity'] as int));
        final value = _products.fold<int>(
            0, (sum, p) => sum + (p['quantity'] as int) * (p['price'] as int));
        final filtered = _products
            .where((p) =>
                '${p['name']} ${p['sku']} ${p['barcode'] ?? ''} ${p['category']}'
                    .toLowerCase()
                    .contains(_search.toLowerCase()) &&
                (!_lowOnly || (p['quantity'] as int) <= (p['minimum'] as int)))
            .toList();
        return ListView(padding: EdgeInsets.all(padding), children: [
          Text(
              _historyView
                  ? 'Stock history'
                  : _lowOnly
                      ? 'Low stock'
                      : 'Inventory overview',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Manage products and track every stock movement.'),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: cardWidth,
                child: _stat('Products', '${_products.length}',
                    Icons.inventory_2_outlined)),
            SizedBox(
                width: cardWidth,
                child:
                    _stat('Units in stock', '$units', Icons.layers_outlined)),
            SizedBox(
                width: cardWidth,
                child: _stat('Stock selling value', money(value),
                    Icons.payments_outlined)),
            SizedBox(
                width: cardWidth,
                child: _stat('Low stock', '$low', Icons.warning_amber_rounded)),
          ]),
          const SizedBox(height: 20),
          Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add product')),
                if (!_historyView)
                  SizedBox(
                      width: available < 300 ? available : 300,
                      child: TextFormField(
                          initialValue: _search,
                          onChanged: (v) => setState(() => _search = v),
                          decoration: const InputDecoration(
                              hintText: 'Search name, SKU, barcode, category',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true))),
              ]),
          const SizedBox(height: 16),
          if (_historyView) ...[
            const Text('Latest 200 movements - newest first'),
            const SizedBox(height: 12),
            if (compact) ...[
              if (_history.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No stock movements yet')),
              for (final m in _history)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['product_name'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  'Change: ${m['delta']}   Balance: ${m['balance']}'),
                              Text(m['note'] as String),
                              Text(DateTime.parse(m['created_at'] as String)
                                  .toLocal()
                                  .toString()
                                  .substring(0, 19)),
                            ]))),
            ] else
              SizedBox(height: 420, child: Card(child: _historyTable())),
          ] else if (filtered.isEmpty)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Icon(Icons.inventory_2_outlined, size: 40),
                      const SizedBox(height: 12),
                      Text(_products.isEmpty
                          ? 'Your inventory is empty'
                          : 'No matching products'),
                      if (_products.isEmpty)
                        TextButton(
                            onPressed: () => _edit(),
                            child: const Text('Add your first product')),
                    ])))
          else if (compact) ...[
            for (final p in filtered)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'] as String,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('SKU: ${p['sku']}'),
                            const SizedBox(height: 8),
                            Text('${money(p['price'] as int)} / unit'),
                            Text(
                                'Quantity: ${p['quantity']}  |  Minimum: ${p['minimum']}'),
                            if ((p['quantity'] as int) <= (p['minimum'] as int))
                              Text('Low stock',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            Wrap(children: [
                              IconButton(
                                  tooltip: 'Stock in',
                                  onPressed: () => _adjust(p, true),
                                  icon: const Icon(Icons.add_circle_outline)),
                              IconButton(
                                  tooltip: 'Stock out',
                                  onPressed: (p['quantity'] as int) == 0
                                      ? null
                                      : () => _adjust(p, false),
                                  icon:
                                      const Icon(Icons.remove_circle_outline)),
                              IconButton(
                                  tooltip: 'Edit product',
                                  onPressed: () => _edit(p),
                                  icon: const Icon(Icons.edit_outlined)),
                              IconButton(
                                  tooltip: 'Delete product',
                                  onPressed: () => _delete(p),
                                  icon: const Icon(Icons.delete_outline)),
                            ]),
                          ]))),
          ] else
            SizedBox(height: 420, child: Card(child: _productTable(filtered))),
        ]);
      });

  Widget _stat(String label, String value, IconData icon) => SizedBox(
      width: 220,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label))
                    ]),
                    const SizedBox(height: 12),
                    Text(value,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]))));

  Widget _scrollTable(DataTable table) => SingleChildScrollView(
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, child: table));
  Widget _productTable(List<RowData> rows) => _scrollTable(DataTable(
      columnSpacing: 28,
      columns: const [
        DataColumn(label: Text('Product')),
        DataColumn(label: Text('SKU')),
        DataColumn(label: Text('Unit price')),
        DataColumn(label: Text('Quantity')),
        DataColumn(label: Text('Min. stock')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Actions'))
      ],
      rows: rows
          .map((p) => DataRow(cells: [
                DataCell(SizedBox(
                    width: 180,
                    child: Text(p['name'] as String,
                        overflow: TextOverflow.ellipsis))),
                DataCell(Text(p['sku'] as String)),
                DataCell(Text(money(p['price'] as int))),
                DataCell(Text('${p['quantity']}')),
                DataCell(Text('${p['minimum']}')),
                DataCell(Text(
                    (p['quantity'] as int) == 0
                        ? 'Out of stock'
                        : (p['quantity'] as int) <= (p['minimum'] as int)
                            ? 'Low stock'
                            : 'In stock',
                    style: TextStyle(
                        color: (p['quantity'] as int) <= (p['minimum'] as int)
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary))),
                DataCell(Row(children: [
                  IconButton(
                      tooltip: 'Stock in',
                      onPressed: () => _adjust(p, true),
                      icon: const Icon(Icons.add_circle_outline)),
                  IconButton(
                      tooltip: 'Stock out',
                      onPressed: (p['quantity'] as int) == 0
                          ? null
                          : () => _adjust(p, false),
                      icon: const Icon(Icons.remove_circle_outline)),
                  IconButton(
                      tooltip: 'Edit product',
                      onPressed: () => _edit(p),
                      icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                      tooltip: 'Delete product',
                      onPressed: () => _delete(p),
                      icon: const Icon(Icons.delete_outline)),
                ])),
              ]))
          .toList()));

  Widget _historyTable() => _history.isEmpty
      ? const Center(child: Text('No stock movements yet'))
      : _scrollTable(DataTable(
          columns: const [
              DataColumn(label: Text('Date / time')),
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('Change')),
              DataColumn(label: Text('Balance')),
              DataColumn(label: Text('Note'))
            ],
          rows: _history
              .map((m) => DataRow(cells: [
                    DataCell(Text(DateTime.parse(m['created_at'] as String)
                        .toLocal()
                        .toString()
                        .substring(0, 19))),
                    DataCell(Text(m['product_name'] as String)),
                    DataCell(Text(
                        '${(m['delta'] as int) > 0 ? '+' : ''}${m['delta']}')),
                    DataCell(Text('${m['balance']}')),
                    DataCell(
                        SizedBox(width: 260, child: Text(m['note'] as String))),
                  ]))
              .toList()));
}

String? nonNegative(String? value) {
  final n = int.tryParse(value ?? '');
  return n == null || n < 0 || n > 100000000
      ? 'Enter a whole number from 0 to 100,000,000'
      : null;
}

class ProductDialog extends StatefulWidget {
  final StockStore store;
  final RowData? product;
  const ProductDialog({super.key, required this.store, this.product});
  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _sku, _price, _quantity, _minimum;
  late final TextEditingController _barcode, _category, _cost;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?['name'] as String? ?? '');
    _sku = TextEditingController(text: p?['sku'] as String? ?? '');
    _price =
        TextEditingController(text: Money.decimal(p?['price'] as int? ?? 0));
    _quantity = TextEditingController(text: '${p?['quantity'] ?? 0}');
    _minimum = TextEditingController(text: '${p?['minimum'] ?? 5}');
    _barcode = TextEditingController(text: p?['barcode'] as String? ?? '');
    _category = TextEditingController(text: p?['category'] as String? ?? '');
    _cost = TextEditingController(
        text: p?['cost'] == null ? '' : Money.decimal(p!['cost'] as int));
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _price,
      _quantity,
      _minimum,
      _barcode,
      _category,
      _cost
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.save(
          id: widget.product?['id'] as int?,
          name: _name.text,
          sku: _sku.text,
          price: Money.parse(_price.text),
          barcode: _barcode.text,
          category: _category.text,
          cost: _cost.text.isEmpty ? null : Money.parse(_cost.text),
          clearCost: _cost.text.isEmpty,
          minimum: int.parse(_minimum.text),
          quantity: int.parse(_quantity.text));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is DatabaseException && e.isUniqueConstraintError()
              ? 'This SKU or barcode already exists. Use a unique value.'
              : 'Could not save product. Please try again.';
        });
      }
    }
  }

  Widget _field(TextEditingController c, String label,
          String? Function(String?) validator, {bool numeric = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: c,
              enabled: !_saving,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              validator: validator,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder())));
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _field(
                          _name,
                          'Product name',
                          (v) => v == null || v.trim().isEmpty
                              ? 'Enter a product name'
                              : v.length > 100
                                  ? 'Maximum 100 characters'
                                  : null),
                      _field(
                          _sku,
                          'SKU / product code',
                          (v) => v == null || v.trim().isEmpty
                              ? 'Enter a unique SKU'
                              : v.length > 40
                                  ? 'Maximum 40 characters'
                                  : null),
                      _field(
                          _price,
                          'Unit price (Rs)',
                          (v) => !RegExp(r'^\d{1,8}(\.\d{1,2})?$')
                                  .hasMatch(v ?? '')
                              ? 'Enter a positive price with up to 2 decimal places'
                              : null,
                          numeric: true),
                      if (widget.product == null)
                        _field(_quantity, 'Opening quantity', nonNegative,
                            numeric: true),
                      _field(_minimum, 'Low-stock threshold', nonNegative,
                          numeric: true),
                      _field(
                          _barcode,
                          'Barcode (optional)',
                          (v) => (v?.trim().length ?? 0) > 80
                              ? 'Maximum 80 characters'
                              : null),
                      _field(
                          _category,
                          'Category (optional)',
                          (v) => (v?.trim().length ?? 0) > 80
                              ? 'Maximum 80 characters'
                              : null),
                      _field(_cost, 'Purchase cost (Rs, optional)', (v) {
                        if (v == null || v.isEmpty) return null;
                        try {
                          Money.parse(v);
                          return null;
                        } on FormatException {
                          return 'Enter a price with up to 2 decimal places';
                        }
                      }, numeric: true),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save product'))
        ],
      ));
}

class MovementDialog extends StatefulWidget {
  final StockStore store;
  final RowData product;
  final bool incoming;
  const MovementDialog(
      {super.key,
      required this.store,
      required this.product,
      required this.incoming});
  @override
  State<MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<MovementDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(), _note = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.adjust(widget.product['id'] as int,
          int.parse(_quantity.text) * (widget.incoming ? 1 : -1), _note.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is StateError
              ? e.message
              : 'Could not update stock. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.incoming ? 'Stock in' : 'Stock out'),
        content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${widget.product['name']} • Available: ${widget.product['quantity']}'),
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: _quantity,
                              autofocus: true,
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder()),
                              validator: (v) {
                                final error = nonNegative(v);
                                if (error != null) return error;
                                final n = int.parse(v!);
                                if (n == 0) {
                                  return 'Enter a quantity greater than zero';
                                }
                                if (!widget.incoming &&
                                    n > (widget.product['quantity'] as int)) {
                                  return 'Not enough stock available';
                                }
                                return null;
                              }),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: _note,
                              enabled: !_saving,
                              maxLength: 200,
                              decoration: const InputDecoration(
                                  labelText: 'Note (optional)',
                                  border: OutlineInputBorder())),
                          if (_error != null)
                            Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                        ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Confirm'))
        ],
      ));
}
