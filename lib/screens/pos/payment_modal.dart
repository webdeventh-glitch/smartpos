import 'package:flutter/material.dart';

class PaymentModal extends StatefulWidget {
  final double grandTotal;
  final String currencySymbol;
  final String customerName;

  const PaymentModal({
    super.key,
    required this.grandTotal,
    required this.currencySymbol,
    required this.customerName,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  late TextEditingController _tenderedController;
  final TextEditingController _noteController = TextEditingController();
  String _selectedMethod = 'cash'; // 'cash', 'card', 'bank_transfer', 'cheque', 'credit'

  @override
  void initState() {
    super.initState();
    _tenderedController = TextEditingController(
      text: widget.grandTotal.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _tendered => double.tryParse(_tenderedController.text.trim()) ?? 0.0;
  double get _changeReturn => _tendered > widget.grandTotal ? _tendered - widget.grandTotal : 0.0;
  double get _balanceDue => _tendered < widget.grandTotal ? widget.grandTotal - _tendered : 0.0;

  void _setTendered(double amount) {
    setState(() {
      _tenderedController.text = amount.toStringAsFixed(2);
    });
  }

  void _addTendered(double increment) {
    final current = _tendered;
    setState(() {
      _tenderedController.text = (current + increment).toStringAsFixed(2);
    });
  }

  void _confirmPayment() {
    double paid = _tendered;
    if (_selectedMethod == 'credit') {
      paid = 0.0;
    } else if (paid > widget.grandTotal) {
      paid = widget.grandTotal;
    }

    String paymentStatus = 'paid';
    if (paid == 0.0) {
      paymentStatus = 'due';
    } else if (paid < widget.grandTotal) {
      paymentStatus = 'partial';
    }

    Navigator.of(context).pop({
      'method': _selectedMethod,
      'tendered': _tendered,
      'change': _changeReturn,
      'paidAmount': paid,
      'paymentStatus': paymentStatus,
      'note': _noteController.text.trim(),
    });
  }

  Widget _methodTile(String id, String label, IconData icon) {
    final isSelected = _selectedMethod == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : const Color(0xFF475569), size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickCashBtn(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currencySymbol;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment & Checkout',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Customer: ${widget.customerName}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Amount Payable Display Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL PAYABLE:',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF), fontSize: 14),
                  ),
                  Text(
                    '$currency${widget.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Methods Selector
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _methodTile('cash', 'Cash', Icons.payments_outlined),
                const SizedBox(width: 8),
                _methodTile('card', 'Card', Icons.credit_card_outlined),
                const SizedBox(width: 8),
                _methodTile('bank_transfer', 'Bank', Icons.account_balance_outlined),
                const SizedBox(width: 8),
                _methodTile('cheque', 'Cheque', Icons.article_outlined),
                const SizedBox(width: 8),
                _methodTile('credit', 'Due/Credit', Icons.pending_actions_outlined),
              ],
            ),
            const SizedBox(height: 20),

            // Tendered Input & Calculations
            if (_selectedMethod != 'credit') ...[
              const Text(
                'AMOUNT TENDERED / RECEIVED',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tenderedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),

              // Quick Cash Chips
              Wrap(
                runSpacing: 6,
                children: [
                  _quickCashBtn('Exact', () => _setTendered(widget.grandTotal)),
                  _quickCashBtn('$currency 10', () => _setTendered(10)),
                  _quickCashBtn('$currency 20', () => _setTendered(20)),
                  _quickCashBtn('$currency 50', () => _setTendered(50)),
                  _quickCashBtn('$currency 100', () => _setTendered(100)),
                  _quickCashBtn('+ $currency 10', () => _addTendered(10)),
                  _quickCashBtn('+ $currency 50', () => _addTendered(50)),
                ],
              ),
              const SizedBox(height: 16),

              // Change Return / Due Balance Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEF7EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CHANGE RETURN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF03543F))),
                          const SizedBox(height: 2),
                          Text(
                            '$currency${_changeReturn.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF03543F)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _balanceDue > 0 ? const Color(0xFFFDE8E8) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BALANCE DUE',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _balanceDue > 0 ? const Color(0xFF9B1C1C) : const Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            '$currency${_balanceDue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _balanceDue > 0 ? const Color(0xFF9B1C1C) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'PAYMENT NOTE / REFERENCE (OPTIONAL)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                hintText: 'e.g. Card Auth #98124, or Cheque #00452',
                isDense: true,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
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
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('FINALIZE PAYMENT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  onPressed: _confirmPayment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
