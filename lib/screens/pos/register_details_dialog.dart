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

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _register == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_clock_rounded, size: 40, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      const Text('No Open Cash Register Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      const Text(
                        'You need to open an active cash register shift before taking terminal payments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final db = await DatabaseService.initialize();
                          await db.openRegister('Admin Cashier', 250.0);
                          _load();
                        },
                        child: const Text('Open Register with \$250.00', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF059669), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cash Register Shift',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Active register session balance & reconciliation',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(context).pop(),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _row('Cashier:', _register!.cashierName),
                            _row('Opened At:', _register!.openedAt),
                            _row('Opening Cash in Hand:', '$currency${_register!.openingAmount.toStringAsFixed(2)}'),
                            _row('Cash Sales:', '$currency${_register!.totalSalesCash.toStringAsFixed(2)}'),
                            _row('Card Sales:', '$currency${_register!.totalSalesCard.toStringAsFixed(2)}'),
                            _row('Other / Bank Sales:', '$currency${_register!.totalSalesOther.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL CASH IN DRAWER:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 13),
                            ),
                            Text(
                              '$currency${_register!.totalCashInRegister.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF065F46), fontSize: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text('Close Register Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 10),

                      _fieldLabel('Actual Closing Cash Counted *'),
                      TextField(
                        controller: _closingCashController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixText: '$currency ',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _fieldLabel('Closing Note (Optional)'),
                      TextField(
                        controller: _closeNoteController,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: 'e.g. End of shift, cash balanced with drawer physical count',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.lock_rounded, size: 16),
                            label: const Text('Close Register & Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
