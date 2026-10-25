import 'package:flutter/material.dart';

class PaymentModal extends StatefulWidget {
  final double grandTotal;
  final String currencySymbol;
  final String customerName;
  final bool isWalkIn;
  final double customerCreditLimit;
  final double customerCurrentBalance;

  const PaymentModal({
    super.key,
    required this.grandTotal,
    required this.currencySymbol,
    required this.customerName,
    this.isWalkIn = true,
    this.customerCreditLimit = 0.0,
    this.customerCurrentBalance = 0.0,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  late TextEditingController _tenderedController;
  final TextEditingController _noteController = TextEditingController();

  // Split tender controllers
  final TextEditingController _splitCashController = TextEditingController();
  final TextEditingController _splitCardController = TextEditingController();
  final TextEditingController _splitBankController = TextEditingController();

  bool _isSplitMode = false;
  String _selectedMethod = 'cash'; // 'cash', 'card', 'bank_transfer', 'cheque', 'credit'
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _tenderedController = TextEditingController(
      text: widget.grandTotal.toStringAsFixed(2),
    );
    _splitCashController.text = (widget.grandTotal / 2).toStringAsFixed(2);
    _splitCardController.text = (widget.grandTotal / 2).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    _noteController.dispose();
    _splitCashController.dispose();
    _splitCardController.dispose();
    _splitBankController.dispose();
    super.dispose();
  }

  double get _tendered => double.tryParse(_tenderedController.text.trim()) ?? 0.0;
  double get _changeReturn => _tendered > widget.grandTotal ? _tendered - widget.grandTotal : 0.0;
  double get _balanceDue => _tendered < widget.grandTotal ? widget.grandTotal - _tendered : 0.0;

  // Split calculation getters
  double get _splitCash => double.tryParse(_splitCashController.text.trim()) ?? 0.0;
  double get _splitCard => double.tryParse(_splitCardController.text.trim()) ?? 0.0;
  double get _splitBank => double.tryParse(_splitBankController.text.trim()) ?? 0.0;
  double get _splitTotalPaid => _splitCash + _splitCard + _splitBank;
  double get _splitBalanceDue => _splitTotalPaid < widget.grandTotal ? widget.grandTotal - _splitTotalPaid : 0.0;
  double get _splitChangeReturn => _splitTotalPaid > widget.grandTotal ? _splitTotalPaid - widget.grandTotal : 0.0;

  void _setTendered(double amount) {
    setState(() {
      _tenderedController.text = amount.toStringAsFixed(2);
      _validationError = null;
    });
  }

  void _addTendered(double increment) {
    final current = _tendered;
    setState(() {
      _tenderedController.text = (current + increment).toStringAsFixed(2);
      _validationError = null;
    });
  }

  void _confirmPayment() {
    setState(() => _validationError = null);

    if (_isSplitMode) {
      // Split payment mode validation
      if (widget.isWalkIn && _splitTotalPaid < widget.grandTotal) {
        setState(() {
          _validationError = 'Strict Walk-in Rule: Walk-in customers must pay 100% upfront (${widget.currencySymbol}${widget.grandTotal.toStringAsFixed(2)}). Partial split payments are disabled.';
        });
        return;
      }

      if (_splitTotalPaid <= 0 && widget.isWalkIn) {
        setState(() {
          _validationError = 'Please allocate payment amounts across Cash, Card, or Bank.';
        });
        return;
      }

      final effectivePaid = _splitTotalPaid > widget.grandTotal ? widget.grandTotal : _splitTotalPaid;
      String paymentStatus = 'paid';
      if (_splitTotalPaid == 0.0) {
        paymentStatus = 'due';
      } else if (_splitTotalPaid < widget.grandTotal) {
        paymentStatus = 'partial';
      }

      final splitTenders = <Map<String, dynamic>>[];
      if (_splitCash > 0) splitTenders.add({'method': 'cash', 'amount': _splitCash});
      if (_splitCard > 0) splitTenders.add({'method': 'card', 'amount': _splitCard});
      if (_splitBank > 0) splitTenders.add({'method': 'bank_transfer', 'amount': _splitBank});

      Navigator.of(context).pop({
        'isSplit': true,
        'method': 'split',
        'tendered': _splitTotalPaid,
        'change': _splitChangeReturn,
        'paidAmount': effectivePaid,
        'paymentStatus': paymentStatus,
        'splitTenders': splitTenders,
        'note': _noteController.text.trim(),
      });
      return;
    }

    // Standard mode validation
    if (widget.isWalkIn) {
      if (_selectedMethod == 'credit') {
        setState(() {
          _validationError = 'Strict Walk-in Rule: Walk-in customers cannot buy on credit. Please select a registered customer account.';
        });
        return;
      }

      if (_tendered < widget.grandTotal) {
        setState(() {
          _validationError = 'Strict Walk-in Rule: Walk-in customers must pay 100% upfront (${widget.currencySymbol}${widget.grandTotal.toStringAsFixed(2)}). Partial balance due is strictly restricted.';
        });
        return;
      }
    }

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

    // Credit limit warning for registered customers
    final due = widget.grandTotal - paid;
    if (!widget.isWalkIn && due > 0 && widget.customerCreditLimit > 0) {
      final projectedBalance = widget.customerCurrentBalance + due;
      if (projectedBalance > widget.customerCreditLimit) {
        // Enforce or warn
      }
    }

    Navigator.of(context).pop({
      'isSplit': false,
      'method': _selectedMethod,
      'tendered': _tendered,
      'change': _changeReturn,
      'paidAmount': paid,
      'paymentStatus': paymentStatus,
      'splitTenders': [
        if (paid > 0) {'method': _selectedMethod, 'amount': paid},
      ],
      'note': _noteController.text.trim(),
    });
  }

  Widget _methodTile(String id, String label, IconData icon, bool isDark) {
    final isSelected = _selectedMethod == id;
    final isCreditDisabled = id == 'credit' && widget.isWalkIn;

    return Expanded(
      child: Tooltip(
        message: isCreditDisabled ? 'Credit disabled for Walk-in customers' : '',
        child: InkWell(
          onTap: isCreditDisabled
              ? () {
                  setState(() {
                    _validationError = 'Credit/Due sales are strictly reserved for registered account holders.';
                  });
                }
              : () => setState(() {
                    _selectedMethod = id;
                    _validationError = null;
                  }),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isCreditDisabled
                  ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9))
                  : (isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))),
              border: Border.all(
                color: isCreditDisabled
                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                    : (isSelected
                        ? const Color(0xFF4F46E5)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Icon(
                      icon,
                      color: isCreditDisabled
                          ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                          : (isSelected
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
                      size: 22,
                    ),
                    if (isCreditDisabled)
                      const Icon(Icons.lock, size: 12, color: Colors.amber),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCreditDisabled
                        ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                        : (isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickCashBtn(String text, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Customer Badge & Split Tender Mode Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Payment & Checkout',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.isWalkIn
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: widget.isWalkIn
                                      ? Colors.amber.withValues(alpha: 0.5)
                                      : Colors.blue.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.isWalkIn ? Icons.person_outline : Icons.verified_user_outlined,
                                    size: 13,
                                    color: widget.isWalkIn ? Colors.amber[700] : Colors.blue[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.isWalkIn ? 'Walk-in (100% Upfront)' : 'Registered Account',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: widget.isWalkIn ? Colors.amber[700] : Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Customer: ${widget.customerName}' +
                              (!widget.isWalkIn && widget.customerCreditLimit > 0
                                  ? ' • Credit Limit: $currency${widget.customerCreditLimit.toStringAsFixed(0)} • Current Due: $currency${widget.customerCurrentBalance.toStringAsFixed(0)}'
                                  : ''),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

              // Amount Payable Display Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A8A).withValues(alpha: 0.4), const Color(0xFF1E293B)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL PAYABLE AMOUNT',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (widget.isWalkIn)
                          Text(
                            'Must be paid in full (No credit)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '$currency${widget.grandTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mode Tabs: Single Tender vs Split Payment
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isSplitMode = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isSplitMode
                                ? (isDark ? const Color(0xFF4F46E5) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isSplitMode && !isDark
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Single Tender',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: !_isSplitMode
                                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isSplitMode = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isSplitMode
                                ? (isDark ? const Color(0xFF4F46E5) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isSplitMode && !isDark
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.call_split_rounded, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Split Tender (Cash + Card/Bank)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _isSplitMode
                                        ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_validationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ================= Single Tender Mode UI =================
              if (!_isSplitMode) ...[
                Text(
                  'SELECT PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _methodTile('cash', 'Cash', Icons.payments_outlined, isDark),
                    const SizedBox(width: 8),
                    _methodTile('card', 'Card', Icons.credit_card_outlined, isDark),
                    const SizedBox(width: 8),
                    _methodTile('bank_transfer', 'Bank', Icons.account_balance_outlined, isDark),
                    const SizedBox(width: 8),
                    _methodTile('cheque', 'Cheque', Icons.article_outlined, isDark),
                    const SizedBox(width: 8),
                    _methodTile('credit', 'Due/Credit', Icons.pending_actions_outlined, isDark),
                  ],
                ),
                const SizedBox(height: 16),

                if (_selectedMethod != 'credit') ...[
                  Text(
                    'AMOUNT TENDERED / RECEIVED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tenderedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _validationError = null),
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

                  Wrap(
                    children: [
                      _quickCashBtn('Exact', () => _setTendered(widget.grandTotal), isDark),
                      _quickCashBtn('$currency 100', () => _setTendered(100), isDark),
                      _quickCashBtn('$currency 500', () => _setTendered(500), isDark),
                      _quickCashBtn('$currency 1,000', () => _setTendered(1000), isDark),
                      _quickCashBtn('$currency 5,000', () => _setTendered(5000), isDark),
                      _quickCashBtn('+ $currency 500', () => _addTendered(500), isDark),
                      _quickCashBtn('+ $currency 1,000', () => _addTendered(1000), isDark),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDEF7EC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF065F46) : const Color(0xFFBCF0DA),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHANGE RETURN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF03543F),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$currency${_changeReturn.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF03543F),
                                ),
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
                            color: _balanceDue > 0
                                ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.5) : const Color(0xFFFDE8E8))
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _balanceDue > 0
                                  ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFF87171).withValues(alpha: 0.3))
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BALANCE DUE / CREDIT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _balanceDue > 0
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF9B1C1C))
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$currency${_balanceDue.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _balanceDue > 0
                                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFF9B1C1C))
                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                // ================= Split Tender Mode UI =================
                Text(
                  'MULTI-TENDER SPLIT ALLOCATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // Cash Input
                Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text('Cash:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _splitCashController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _validationError = null),
                        decoration: InputDecoration(
                          prefixText: '$currency ',
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Card Input
                Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card_outlined, size: 18, color: Colors.indigo),
                          const SizedBox(width: 8),
                          const Text('Card / POS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _splitCardController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _validationError = null),
                        decoration: InputDecoration(
                          prefixText: '$currency ',
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bank Transfer Input
                Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_outlined, size: 18, color: Colors.teal),
                          const SizedBox(width: 8),
                          const Text('Bank / Online:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _splitBankController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _validationError = null),
                        decoration: InputDecoration(
                          prefixText: '$currency ',
                          hintText: '0.00',
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Split Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Allocated: $currency${_splitTotalPaid.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (_splitBalanceDue > 0)
                            Text('Remaining Due: $currency${_splitBalanceDue.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          if (_splitChangeReturn > 0)
                            Text('Change Return: $currency${_splitChangeReturn.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () {
                          setState(() {
                            _splitCashController.text = (widget.grandTotal / 2).toStringAsFixed(2);
                            _splitCardController.text = (widget.grandTotal / 2).toStringAsFixed(2);
                            _splitBankController.clear();
                          });
                        },
                        child: const Text('Split 50/50', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                'PAYMENT REFERENCE / NOTE (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g. Card Auth #98124, Bank Ref PK9921, or Cheque #00452',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
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
                    label: Text(
                      _isSplitMode ? 'FINALIZE SPLIT PAYMENT' : 'FINALIZE PAYMENT',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: _confirmPayment,
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
