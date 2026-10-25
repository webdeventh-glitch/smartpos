import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'pos_power_dialogs.dart';

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
    final closeNote = _closeNoteController.text.trim();
    final db = await DatabaseService.initialize();
    await db.closeRegister(_register!.id!, closingAmount, closeNote);
    if (mounted) {
      final reg = _register!;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (_) => RegisterReportDialog(
          isZReport: true,
          register: reg,
          settings: widget.settings,
          actualCash: closingAmount,
          closeNote: closeNote,
        ),
      );
    }
  }

  Widget _fieldLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.lock_clock_rounded, size: 40, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Open Cash Register Session',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need to open an active cash register shift before taking terminal payments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
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
                                  color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cash Register Shift',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Active register session balance & reconciliation',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            onPressed: () => Navigator.of(context).pop(),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _row('Cashier:', _register!.cashierName, isDark),
                            _row('Opened At:', _register!.openedAt, isDark),
                            _row('Opening Cash in Hand:', '$currency${_register!.openingAmount.toStringAsFixed(2)}', isDark),
                            _row('Cash Sales:', '$currency${_register!.totalSalesCash.toStringAsFixed(2)}', isDark),
                            _row('Card Sales:', '$currency${_register!.totalSalesCard.toStringAsFixed(2)}', isDark),
                            _row('Other / Bank Sales:', '$currency${_register!.totalSalesOther.toStringAsFixed(2)}', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL CASH IN DRAWER:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$currency${_register!.totalCashInRegister.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Close Register Form',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),

                      _fieldLabel('Actual Closing Cash Counted *', isDark),
                      TextField(
                        controller: _closingCashController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixText: '$currency ',
                          prefixStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _fieldLabel('Closing Note (Optional)', isDark),
                      TextField(
                        controller: _closeNoteController,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'e.g. End of shift, cash balanced with drawer physical count',
                          hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF004EEB),
                              side: const BorderSide(color: Color(0xFF004EEB)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('View X-Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => RegisterReportDialog(
                                  isZReport: false,
                                  register: _register!,
                                  settings: widget.settings,
                                ),
                              );
                            },
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.lock_rounded, size: 16),
                                label: const Text('Close Shift (Z-Report)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: _closeRegister,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _row(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
