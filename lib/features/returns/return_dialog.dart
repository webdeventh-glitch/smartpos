import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/money.dart';
import 'returns_repository.dart';

class ReturnDialog extends StatefulWidget {
  final ReturnsRepository repository;
  final int saleId;
  final List<ReturnItem> items;
  const ReturnDialog(
      {super.key,
      required this.repository,
      required this.saleId,
      required this.items});
  @override
  State<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<ReturnDialog> {
  final reason = TextEditingController();
  late final fields = {
    for (final item in widget.items)
      item.lineId: TextEditingController(text: '0')
  };
  final token =
      'return-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  String method = 'Cash';
  String? error;
  bool saving = false;
  Map<int, int> get quantities {
    final result = <int, int>{};
    for (final item in widget.items) {
      final text = fields[item.lineId]!.text.trim();
      final quantity = int.tryParse(text);
      if (quantity == null || quantity < 0 || quantity > item.remaining) {
        throw ArgumentError('Enter 0 to ${item.remaining} for ${item.name}.');
      }
      if (quantity > 0) result[item.lineId] = quantity;
    }
    return result;
  }

  int amount(Map<int, int> selected) => widget.items
      .fold(0, (sum, item) => sum + item.refund(selected[item.lineId] ?? 0));
  @override
  void dispose() {
    reason.dispose();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final selected = quantities;
      final id = await widget.repository.post(
          saleId: widget.saleId,
          token: token,
          quantities: selected,
          reason: reason.text,
          method: method,
          expectedRefund: amount(selected));
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String preview;
    try {
      preview = 'Refund: ${Money.format(amount(quantities))}';
    } catch (e) {
      preview = e is ArgumentError ? '${e.message}' : '$e';
    }
    return PopScope(
        canPop: !saving,
        child: AlertDialog(
          title: Text('Return items - Sale #${widget.saleId}'),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text(
                        'Returned items will be restocked. Refund includes the original discount and tax.'),
                    TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() {
                                  for (final item in widget.items) {
                                    fields[item.lineId]!.text =
                                        '${item.remaining}';
                                  }
                                }),
                        child: const Text('Return all remaining')),
                    for (final item in widget.items)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                              key: ValueKey('return-quantity-${item.lineId}'),
                              controller: fields[item.lineId],
                              enabled: !saving && item.remaining > 0,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  labelText: item.name,
                                  helperText:
                                      '${item.remaining} returnable / ${item.sold} sold',
                                  border: const OutlineInputBorder()))),
                    TextField(
                        controller: reason,
                        enabled: !saving,
                        maxLength: 500,
                        decoration:
                            const InputDecoration(labelText: 'Return reason')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration:
                            const InputDecoration(labelText: 'Refund method'),
                        items: [
                          for (final value in [
                            'Cash',
                            'Card',
                            'Bank',
                            'Digital'
                          ])
                            DropdownMenuItem(value: value, child: Text(value))
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setState(() => method = value!)),
                    const SizedBox(height: 16),
                    Text(preview,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Record only once the refund is arranged externally. This app does not transfer money.'),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ]))),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving...' : 'Record return')),
          ],
        ));
  }
}
