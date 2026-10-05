import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/money.dart';
import '../../stock_store.dart';
import 'pos_repository.dart';

class PosPage extends StatefulWidget {
  final StockStore store;
  final bool active;
  const PosPage({super.key, required this.store, this.active = true});
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final repo = PosRepository(widget.store);
  final search = TextEditingController(), customer = TextEditingController();
  final discount = TextEditingController(text: '0'),
      tax = TextEditingController(text: '0');
  final searchFocus = FocusNode();
  final cart = <int, Map<String, dynamic>>{};
  List<Map<String, Object?>> products = [], parked = [];
  Timer? debounce;
  String category = 'All products', token = '', query = '';
  String? error;
  bool busy = false, loading = true, taxInclusive = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    token = newToken();
    load();
  }

  @override
  void didUpdateWidget(covariant PosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) load();
  }

  String newToken() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  @override
  void dispose() {
    debounce?.cancel();
    for (final c in [search, customer, discount, tax]) {
      c.dispose();
    }
    searchFocus.dispose();
    super.dispose();
  }

  List<OrderLine> get lines => cart.values
      .map((p) =>
          OrderLine(p['id'] as int, p['count'] as int, p['price'] as int))
      .toList();
  CheckoutTotals get totals => CheckoutTotals.calculate(
      lines, Money.parse(discount.text), Money.parse(tax.text),
      taxInclusive: taxInclusive);
  Future<void> load() async {
    final request = ++generation;
    try {
      final rows = await widget.store.searchProducts(query, limit: 200);
      final held = await repo.parked();
      if (mounted && request == generation) {
        setState(() {
          products = rows;
          parked = held;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  void add(Map<String, Object?> product) {
    if (busy || !widget.active) return;
    final id = product['id'] as int;
    final count = (cart[id]?['count'] as int? ?? 0) + 1;
    if (count > (product['quantity'] as int)) {
      message('No more stock available for ${product['name']}.');
      return;
    }
    setState(() {
      cart[id] = {...product, 'count': count};
    });
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> scan(String value) async {
    if (busy || !widget.active) return;
    try {
      final product = await widget.store.findBarcode(value);
      final matches = product == null
          ? await widget.store.searchProducts(value)
          : [product];
      if (!mounted) return;
      final exact = matches
          .where((p) => '${p['sku']}'.toLowerCase() == value.toLowerCase())
          .toList();
      if (product != null) {
        add(product);
      } else if (exact.length == 1) {
        add(exact.single);
      } else if (matches.length == 1) {
        add(matches.single);
      } else {
        message('Scan a barcode or choose a product below.');
        return;
      }
      search.clear();
      query = '';
      await load();
      searchFocus.requestFocus();
    } catch (e) {
      if (mounted) message('$e');
    }
  }

  void clear() {
    cart.clear();
    customer.clear();
    discount.text = '0';
    tax.text = '0';
    taxInclusive = false;
    token = newToken();
  }

  Future<void> hold() async {
    if (cart.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      totals;
      await repo.park(
          token,
          customer.text.trim().isEmpty
              ? 'Walk-in customer'
              : customer.text.trim(),
          {
            'items': cart.values.toList(),
            'customer': customer.text,
            'discount': discount.text,
            'tax': tax.text,
            'taxInclusive': taxInclusive,
          });
      if (!mounted) return;
      setState(clear);
      await load();
      message('Bill parked on this device.');
    } catch (e) {
      if (mounted) message('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resume() async {
    if (cart.isNotEmpty) {
      message('Park or complete your current bill first.');
      return;
    }
    final row = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (ctx) => SimpleDialog(
              title: const Text('Parked bills'),
              children: [
                if (parked.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No parked bills.')),
                for (final p in parked)
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, p),
                      child: ListTile(
                          title: Text('${p['label']}'),
                          subtitle: Text('${p['created_at']}'),
                          trailing: const Icon(Icons.arrow_forward))),
              ],
            ));
    if (row == null || !mounted) return;
    final payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    setState(() {
      token = row['token'] as String;
      customer.text = payload['customer'] as String;
      discount.text = payload['discount'] as String;
      tax.text = payload['tax'] as String;
      taxInclusive = payload['taxInclusive'] == true;
      for (final item in payload['items'] as List) {
        final p = Map<String, dynamic>.from(item as Map);
        cart[p['id'] as int] = p;
      }
    });
  }

  Future<void> checkout() async {
    if (cart.isEmpty || busy) return;
    CheckoutTotals amount;
    try {
      amount = totals;
    } catch (e) {
      message('$e');
      return;
    }
    final settlement = await showDialog<PaymentSettlement>(
        context: context, builder: (_) => PaymentDialog(total: amount.total));
    if (settlement == null || !mounted) return;
    final allocations = settlement.allocations;
    setState(() => busy = true);
    try {
      final id = await repo.checkout(
          token: token,
          lines: lines,
          payments: allocations,
          customer: customer.text,
          discount: amount.discount,
          taxRate: Money.parse(tax.text),
          taxInclusive: taxInclusive,
          cashReceived: settlement.cashReceived);
      if (!mounted) return;
      final receipt =
          'SALE-${id.toString().padLeft(6, '0')}\n${customer.text.isEmpty ? 'Walk-in customer' : customer.text}\n\n${cart.values.map((p) => '${p['name']}  x${p['count']}  ${Money.format((p['price'] as int) * (p['count'] as int))}').join('\n')}\n\nSubtotal: ${Money.format(amount.subtotal)}\nDiscount: ${Money.format(amount.discount)}\nTax (${taxInclusive ? 'included' : 'exclusive'}): ${Money.format(amount.tax)}\nTOTAL: ${Money.format(amount.total)}\n${allocations.entries.map((e) => '${e.key}: ${Money.format(e.value)}').join('\n')}\nCash received: ${Money.format(settlement.cashReceived)}\nChange: ${Money.format(settlement.change)}';
      setState(clear);
      await load();
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Payment complete'),
                  content:
                      SingleChildScrollView(child: SelectableText(receipt)),
                  actions: [
                    TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: receipt));
                        },
                        child: const Text('Copy receipt')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('New sale')),
                  ]));
    } catch (e) {
      if (mounted) message('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f2): () =>
                searchFocus.requestFocus(),
            const SingleActivator(LogicalKeyboardKey.f4): hold,
            const SingleActivator(LogicalKeyboardKey.f9): checkout,
          },
          child: LayoutBuilder(builder: (context, box) {
            final catalog =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text('Point of sale',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Chip(
                        avatar: Icon(Icons.bolt, size: 16),
                        label: Text('Ready to sell')),
                  ]),
              const SizedBox(height: 6),
              const Text('Search, scan, and serve your next customer.'),
              const SizedBox(height: 22),
              TextField(
                  controller: search,
                  focusNode: searchFocus,
                  autofocus: true,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name, SKU or scan barcode · F2',
                      suffixIcon: Icon(Icons.qr_code_scanner)),
                  onSubmitted: scan,
                  onChanged: (v) {
                    query = v;
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 180), load);
                  }),
              const SizedBox(height: 16),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final label in {
                      'All products',
                      ...products
                          .map((p) => '${p['category']}')
                          .where((c) => c.isNotEmpty)
                    })
                      Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                              label: Text(label),
                              selected: category == label,
                              onSelected: (_) =>
                                  setState(() => category = label))),
                  ])),
              const SizedBox(height: 16),
              Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                          ? Center(
                              child: TextButton(
                                  onPressed: load,
                                  child: Text('Retry: $error')))
                          : products.isEmpty
                              ? const Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      Icon(Icons.inventory_2_outlined,
                                          size: 52, color: Colors.blueGrey),
                                      SizedBox(height: 16),
                                      Text('No products found'),
                                      Text('Add inventory to start selling.')
                                    ]))
                              : LayoutBuilder(builder: (context, grid) {
                                  final visible = products
                                      .where((p) =>
                                          category == 'All products' ||
                                          p['category'] == category)
                                      .toList();
                                  return GridView.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: max(
                                                  1,
                                                  (grid.maxWidth / 180)
                                                      .floor()),
                                              mainAxisExtent: 176,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12),
                                      itemCount: visible.length,
                                      itemBuilder: (_, i) {
                                        final p = visible[i];
                                        final available = p['quantity'] as int;
                                        return Card(
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                                onTap: busy || available == 0
                                                    ? null
                                                    : () => add(p),
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(children: [
                                                            const Icon(
                                                                Icons
                                                                    .inventory_2_outlined,
                                                                color: Color(
                                                                    0xFF4F46E5)),
                                                            const Spacer(),
                                                            Text(
                                                                '$available in stock',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: available ==
                                                                            0
                                                                        ? Colors
                                                                            .red
                                                                        : Colors
                                                                            .blueGrey))
                                                          ]),
                                                          const Spacer(),
                                                          Text('${p['name']}',
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                          Text('${p['sku']}',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .blueGrey,
                                                                  fontSize:
                                                                      11)),
                                                          const SizedBox(
                                                              height: 10),
                                                          Text(
                                                              Money.format(
                                                                  p['price']
                                                                      as int),
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize:
                                                                      18)),
                                                        ]))));
                                      });
                                })),
              const SizedBox(height: 8),
              const Text(
                  'Showing up to 200 matches · Refine your search for more',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ]);
            return Padding(
                padding: const EdgeInsets.all(24),
                child: box.maxWidth >= 850
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Expanded(child: catalog),
                            const SizedBox(width: 24),
                            SizedBox(width: 350, child: bill())
                          ])
                    : DefaultTabController(
                        length: 2,
                        child: Column(children: [
                          TabBar(tabs: [
                            const Tab(text: 'Products'),
                            Tab(text: 'Current bill (${cart.length})')
                          ]),
                          const SizedBox(height: 12),
                          Expanded(
                              child: TabBarView(children: [catalog, bill()]))
                        ])));
          }));
  Widget bill() => SingleChildScrollView(child: billContent());
  Widget billContent() {
    CheckoutTotals? summary;
    try {
      if (cart.isNotEmpty) summary = totals;
    } catch (_) {}
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Current bill',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700))),
                    IconButton(
                        tooltip: 'Parked bills (${parked.length})',
                        onPressed: busy ? null : resume,
                        icon: Badge(
                            label: Text('${parked.length}'),
                            child: const Icon(Icons.restore)))
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                      controller: customer,
                      enabled: !busy,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: 'Walk-in customer')),
                  const SizedBox(height: 12),
                  cart.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                              child: Text(
                                  'Your bill is empty.\nSelect a product to get started.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.blueGrey))))
                      : Column(
                              children: cart.values
                                  .map((p) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('${p['name']}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Row(children: [
                                              IconButton(
                                                  tooltip: 'Decrease quantity',
                                                  onPressed: busy
                                                      ? null
                                                      : () => setState(() {
                                                            if (p['count'] ==
                                                                1) {
                                                              cart.remove(
                                                                  p['id']);
                                                            } else {
                                                              p['count'] = (p[
                                                                          'count']
                                                                      as int) -
                                                                  1;
                                                            }
                                                          }),
                                                  icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                      size: 20)),
                                              Text('${p['count']}'),
                                              IconButton(
                                                  tooltip: 'Increase quantity',
                                                  onPressed: busy
                                                      ? null
                                                      : () => add(p),
                                                  icon: const Icon(
                                                      Icons.add_circle_outline,
                                                      size: 20)),
                                              const Spacer(),
                                              Flexible(
                                                  child: Text(Money.format(
                                                      (p['price'] as int) *
                                                          (p['count']
                                                              as int)))),
                                            ]),
                                            const Divider(height: 1),
                                          ])))
                                  .toList()),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: discount,
                            enabled: !busy,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Discount (Rs)'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: tax,
                            enabled: !busy,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Tax %')))
                  ]),
                  SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prices include tax'),
                      value: taxInclusive,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => taxInclusive = value)),
                  const SizedBox(height: 14),
                  totalRow('Subtotal', summary?.subtotal ?? 0),
                  totalRow(taxInclusive ? 'Tax (included)' : 'Tax',
                      summary?.tax ?? 0),
                  const Divider(height: 24),
                  totalRow('Amount due', summary?.total ?? 0, large: true),
                  if (cart.isNotEmpty && summary == null)
                    const Text('Check discount and tax values.',
                        style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: busy || summary == null ? null : checkout,
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: Text(busy ? 'Saving…' : 'Charge · F9')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: busy || cart.isEmpty ? null : hold,
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Park bill · F4')),
                ])));
  }

  Widget totalRow(String label, int value, {bool large = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label),
        const Spacer(),
        Flexible(
            child: Text(Money.format(value),
                style: TextStyle(
                    fontSize: large ? 23 : 14,
                    fontWeight: large ? FontWeight.w800 : FontWeight.w500)))
      ]));
}

class PaymentDialog extends StatefulWidget {
  final int total;
  const PaymentDialog({super.key, required this.total});
  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final fields = {
    for (final method in ['Cash', 'Card', 'Bank', 'Digital'])
      method: TextEditingController(
          text: method == 'Cash' ? Money.decimal(widget.total) : '0')
  };
  String? error;
  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  String paymentStatus() {
    try {
      final settlement = PaymentSettlement.calculate(widget.total, {
        for (final entry in fields.entries)
          entry.key: Money.parse(entry.value.text),
      });
      return 'Change: ${Money.format(settlement.change)}';
    } catch (e) {
      return e is ArgumentError
          ? '${e.message}'
          : 'Enter valid payment amounts.';
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Collect payment'),
          content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text(Money.format(widget.total),
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text(
                        'Enter cash received and externally collected card, bank or digital amounts. Cash change is calculated automatically.'),
                    const SizedBox(height: 20),
                    for (final field in fields.entries)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                              controller: field.value,
                              onChanged: (_) => setState(() => error = null),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: field.key == 'Cash'
                                      ? 'Cash received (Rs)'
                                      : '${field.key} (Rs)'))),
                    Text(paymentStatus(),
                        key: const ValueKey('payment-status')),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  try {
                    final values = {
                      for (final entry in fields.entries)
                        entry.key: Money.parse(entry.value.text)
                    };
                    final settlement =
                        PaymentSettlement.calculate(widget.total, values);
                    Navigator.pop(context, settlement);
                  } catch (e) {
                    setState(() => error = '$e');
                  }
                },
                child: const Text('Complete sale'))
          ]);
}
