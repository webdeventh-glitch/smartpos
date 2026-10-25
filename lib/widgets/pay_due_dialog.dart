import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

enum DuePaymentType {
  sale,
  purchase,
  contactCustomer,
  contactSupplier,
}

class PayDueDialog extends StatefulWidget {
  final BusinessSettings settings;
  final DuePaymentType type;
  final int entityId;
  final String reference;
  final String contactName;
  final int? contactId;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final VoidCallback? onPaymentSuccess;

  const PayDueDialog({
    super.key,
    required this.settings,
    required this.type,
    required this.entityId,
    required this.reference,
    required this.contactName,
    this.contactId,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
    this.onPaymentSuccess,
  });

  @override
  State<PayDueDialog> createState() => _PayDueDialogState();
}

class _PayDueDialogState extends State<PayDueDialog> {
  late TextEditingController _amountController;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _paymentMethod = 'cash'; // 'cash', 'card', 'bank_transfer', 'cheque'
  String _accountName = 'Cash Register';
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.dueAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _enteredAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;
  double get _remainingAfterPayment {
    final rem = widget.dueAmount - _enteredAmount;
    return rem > 0 ? rem : 0.0;
  }

  Future<void> _submitPayment() async {
    setState(() => _errorMessage = null);

    final amt = _enteredAmount;
    if (amt <= 0) {
      setState(() => _errorMessage = 'Please enter a valid payment amount greater than zero.');
      return;
    }
    if (amt > widget.dueAmount) {
      setState(() => _errorMessage = 'Entered amount exceeds the outstanding balance (${widget.settings.currencySymbol}${widget.dueAmount.toStringAsFixed(2)}).');
      return;
    }

    setState(() => _submitting = true);

    try {
      final db = await DatabaseService.initialize();

      switch (widget.type) {
        case DuePaymentType.sale:
          await db.settleSalePayment(
            saleId: widget.entityId,
            amountPaid: amt,
            paymentMethod: _paymentMethod,
            accountName: _accountName,
            refNo: _refController.text.trim(),
            note: _noteController.text.trim(),
          );
          break;
        case DuePaymentType.purchase:
          await db.settlePurchasePayment(
            purchaseId: widget.entityId,
            amountPaid: amt,
            paymentMethod: _paymentMethod,
            accountName: _accountName,
            refNo: _refController.text.trim(),
            note: _noteController.text.trim(),
          );
          break;
        case DuePaymentType.contactCustomer:
        case DuePaymentType.contactSupplier:
          if (widget.contactId != null) {
            await db.recordContactPayment(
              contactId: widget.contactId!,
              amount: amt,
              paymentMethod: _paymentMethod,
              transactionType: widget.type == DuePaymentType.contactCustomer ? 'customer_payment' : 'supplier_payment',
              accountName: _accountName,
              refNo: _refController.text.trim(),
              note: _noteController.text.trim(),
            );
          }
          break;
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        widget.onPaymentSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Successfully collected ${widget.settings.currencySymbol}${amt.toStringAsFixed(2)} for ${widget.contactName}!'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Error processing payment: $e';
        });
      }
    }
  }

  Widget _quickPctChip(String label, double ratio, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        onPressed: () {
          setState(() {
            _amountController.text = (widget.dueAmount * ratio).toStringAsFixed(2);
            _errorMessage = null;
          });
        },
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settle Due / Pay Installment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${widget.contactName} • ${widget.reference}',
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
                    icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

              // Outstanding Balance Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.25) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL OUTSTANDING DUE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total: $currency${widget.totalAmount.toStringAsFixed(2)} | Paid: $currency${widget.paidAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$currency${widget.dueAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Amount to Collect Input
              Text(
                'AMOUNT TO COLLECT / SETTLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _errorMessage = null),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  prefixStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Quick Percent Chips
              Row(
                children: [
                  _quickPctChip('Full (100%)', 1.0, isDark),
                  _quickPctChip('75%', 0.75, isDark),
                  _quickPctChip('50%', 0.5, isDark),
                  _quickPctChip('25%', 0.25, isDark),
                ],
              ),
              const SizedBox(height: 16),

              // Payment Method & Account
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAYMENT METHOD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'card', child: Text('Card / POS')),
                            DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                          ],
                          onChanged: (val) => setState(() => _paymentMethod = val ?? 'cash'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECEIVING ACCOUNT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _accountName,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Cash Register', child: Text('Cash Register')),
                            DropdownMenuItem(value: 'Main Bank Account', child: Text('Main Bank Account')),
                            DropdownMenuItem(value: 'Petty Cash', child: Text('Petty Cash')),
                          ],
                          onChanged: (val) => setState(() => _accountName = val ?? 'Cash Register'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Reference No & Note
              Text(
                'TRANSACTION REFERENCE / NOTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _refController,
                decoration: InputDecoration(
                  hintText: 'e.g. Bank Ref #, Receipt #, or Cheque #',
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // Remaining Due Preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining Balance After Payment:',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    Text(
                      '$currency${_remainingAfterPayment.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _remainingAfterPayment == 0 ? Colors.green : Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit & Cancel Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _submitting ? 'RECORDING...' : 'RECORD PAYMENT',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _submitting ? null : _submitPayment,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
