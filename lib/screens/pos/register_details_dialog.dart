import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class RegisterDetailsDialog extends StatefulWidget {
  final BusinessSettings settings;

  const RegisterDetailsDialog({super.key, required this.settings});

  @override
  State<RegisterDetailsDialog> createState() => _RegisterDetailsDialogState();
}

class _RegisterDetailsDialogState extends State<RegisterDetailsDialog> {
  CashRegister? _register;
  bool _loading = true;
  final TextEditingController _closingCashController = TextEditingController();
  final TextEditingController _closeNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final reg = await db.getActiveRegister();
    if (mounted) {
      setState(() {
        _register = reg;
        _loading = false;
        if (reg != null) {
          _closingCashController.text = reg.totalCashInRegister.toStringAsFixed(2);
        }
      });
    }
  }

  Future<void> _closeRegister() async {
    if (_register == null) return;
    final closingAmount = double.tryParse(_closingCashController.text.trim()) ?? 0.0;
    final db = await DatabaseService.initialize();
    await db.closeRegister(_register!.id!, closingAmount, _closeNoteController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash register closed successfully!'), backgroundColor: Color(0xFF10B981)),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _register == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No Open Cash Register Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('You need to open a register before taking payments.', textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
                        onPressed: () async {
                          final db = await DatabaseService.initialize();
                          await db.openRegister('Admin Cashier', 250.0);
                          _load();
                        },
                        child: const Text('Open Register with \$250.00'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.point_of_sale, color: Color(0xFF10B981), size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Current Register Details',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Info grid
                      _row('Cashier:', _register!.cashierName),
                      _row('Opened At:', _register!.openedAt),
                      _row('Opening Cash in Hand:', '$currency${_register!.openingAmount.toStringAsFixed(2)}'),
                      _row('Cash Sales:', '$currency${_register!.totalSalesCash.toStringAsFixed(2)}'),
                      _row('Card Sales:', '$currency${_register!.totalSalesCard.toStringAsFixed(2)}'),
                      _row('Other / Bank Sales:', '$currency${_register!.totalSalesOther.toStringAsFixed(2)}'),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDEF7EC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF31C48D)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL CASH IN DRAWER:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF03543F), fontSize: 13),
                            ),
                            Text(
                              '$currency${_register!.totalCashInRegister.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF03543F), fontSize: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text('Close Register Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _closingCashController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Actual Closing Cash Counted',
                          prefixText: '$currency ',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _closeNoteController,
                        decoration: const InputDecoration(
                          labelText: 'Closing Note (Optional)',
                          hintText: 'e.g. End of shift, cash balanced',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.lock, size: 18),
                            label: const Text('Close Register & Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _closeRegister,
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
