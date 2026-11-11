import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import 'pos_power_dialogs.dart';
import 'open_register_dialog.dart';

class RegisterDetailsDialog extends StatefulWidget {
  final BusinessSettings settings;

  const RegisterDetailsDialog({super.key, required this.settings});

  @override
  State<RegisterDetailsDialog> createState() => _RegisterDetailsDialogState();
}

class _RegisterDetailsDialogState extends State<RegisterDetailsDialog> {
  CashRegister? _register;
  double _cashExpenses = 0.0;
  double _cashRefunds = 0.0;
  bool _loading = true;
  final TextEditingController _closingCashController = TextEditingController();
  final TextEditingController _closeNoteController = TextEditingController();

  bool _showDenominations = false;
  final Map<int, TextEditingController> _denomControllers = {
    5000: TextEditingController(),
    1000: TextEditingController(),
    500: TextEditingController(),
    100: TextEditingController(),
    50: TextEditingController(),
    20: TextEditingController(),
    10: TextEditingController(),
  };
  final TextEditingController _coinsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closingCashController.dispose();
    _closeNoteController.dispose();
    for (final c in _denomControllers.values) {
      c.dispose();
    }
    _coinsController.dispose();
    super.dispose();
  }

  void _recalculateFromDenominations() {
    double total = 0.0;
    _denomControllers.forEach((val, ctrl) {
      final count = int.tryParse(ctrl.text.trim()) ?? 0;
      total += val * count;
    });
    final coins = double.tryParse(_coinsController.text.trim()) ?? 0.0;
    total += coins;
    setState(() {
      _closingCashController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final reg = await db.getActiveRegister();
    double exp = 0.0;
    double ret = 0.0;
    if (reg != null) {
      try {
        final expRes = await db.db.rawQuery(
          "SELECT SUM(amount) as total FROM expenses WHERE LOWER(payment_method) = 'cash' AND datetime(date) >= datetime(?)",
          [reg.openedAt],
        );
        exp = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e, st) {
        AppLogger.warning(
            'RegisterDetails', 'Failed querying cash expenses', e, st);
      }

      try {
        final retRes = await db.db.rawQuery(
          "SELECT SUM(refund_amount) as total FROM sale_returns WHERE LOWER(refund_method) = 'cash' AND datetime(date) >= datetime(?)",
          [reg.openedAt],
        );
        ret = (retRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e, st) {
        AppLogger.warning(
            'RegisterDetails', 'Failed querying cash sale returns', e, st);
      }
    }
    if (mounted) {
      setState(() {
        _register = reg;
        _cashExpenses = exp;
        _cashRefunds = ret;
        _loading = false;
        if (reg != null) {
          _closingCashController.text =
              reg.totalCashInRegister.toStringAsFixed(2);
        }
      });
    }
  }

  Future<void> _closeRegister() async {
    if (_register == null) return;
    final closingAmount =
        double.tryParse(_closingCashController.text.trim()) ?? 0.0;
    final closeNote = _closeNoteController.text.trim();
    final db = await DatabaseService.initialize();
    await db.closeRegister(_register!.id!, closingAmount, closeNote);
    if (mounted) {
      final reg = _register!;
      Navigator.of(context).pop(true);
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
        width: 520,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded,
                            size: 40, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Active Cash Register Session',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need to open an active cash register shift with opening cash float before taking sales.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: const Text('Open Register Shift Now',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final opened = await showDialog<bool>(
                            context: context,
                            builder: (_) => OpenRegisterDialog(
                                settings: widget.settings, isDismissible: true),
                          );
                          if (opened == true) {
                            _load();
                          }
                        },
                      ),
                    ],
                  )
                : Builder(
                    builder: (context) {
                      final expectedCash = _register!.openingAmount +
                          _register!.totalSalesCash -
                          _cashRefunds -
                          _cashExpenses;
                      return SingleChildScrollView(
                        child: Column(
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
                                        color: isDark
                                            ? const Color(0xFF064E3B)
                                                .withValues(alpha: 0.5)
                                            : const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                          Icons.point_of_sale_rounded,
                                          color: Color(0xFF10B981),
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cash Register Shift',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Active register session balance & reconciliation',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 20,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B)),
                                  onPressed: () => Navigator.of(context).pop(),
                                  splashRadius: 18,
                                ),
                              ],
                            ),
                            Divider(
                                height: 24,
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),

                            // Info card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _row('Cashier:', _register!.cashierName,
                                      isDark),
                                  _row('Opened At:', _register!.openedAt,
                                      isDark),
                                  _row(
                                      'Opening Cash Float:',
                                      '$currency${_register!.openingAmount.toStringAsFixed(2)}',
                                      isDark),
                                  _row(
                                      'Cash Sales:',
                                      '+$currency${_register!.totalSalesCash.toStringAsFixed(2)}',
                                      isDark),
                                  _row(
                                      'Card Sales:',
                                      '$currency${_register!.totalSalesCard.toStringAsFixed(2)}',
                                      isDark),
                                  _row(
                                      'Other / Bank Sales:',
                                      '$currency${_register!.totalSalesOther.toStringAsFixed(2)}',
                                      isDark),
                                  if (_cashRefunds > 0)
                                    _row(
                                        'Cash Returns / Refunds:',
                                        '-$currency${_cashRefunds.toStringAsFixed(2)}',
                                        isDark,
                                        isDeduct: true),
                                  if (_cashExpenses > 0)
                                    _row(
                                        'Cash Expenses Out of Drawer:',
                                        '-$currency${_cashExpenses.toStringAsFixed(2)}',
                                        isDark,
                                        isDeduct: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF064E3B)
                                        .withValues(alpha: 0.4)
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOTAL EXPECTED CASH IN DRAWER:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF065F46),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$currency${expectedCash.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF065F46),
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
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Denomination Counter Toggle Button
                            InkWell(
                              onTap: () => setState(() =>
                                  _showDenominations = !_showDenominations),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF4F46E5)
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.calculate_outlined,
                                            size: 18, color: Color(0xFF4F46E5)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Physical Note Counter (کرنسی نوٹ کاؤنٹر)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF93C5FD)
                                                : const Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      _showDenominations
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: const Color(0xFF4F46E5),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_showDenominations) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        _denomInput(5000, isDark),
                                        const SizedBox(width: 8),
                                        _denomInput(1000, isDark),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _denomInput(500, isDark),
                                        const SizedBox(width: 8),
                                        _denomInput(100, isDark),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _denomInput(50, isDark),
                                        const SizedBox(width: 8),
                                        _denomInput(20, isDark),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _denomInput(10, isDark),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 55,
                                                child: Text('Coins:',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isDark
                                                            ? const Color(
                                                                0xFFCBD5E1)
                                                            : const Color(
                                                                0xFF475569))),
                                              ),
                                              Expanded(
                                                child: SizedBox(
                                                  height: 32,
                                                  child: TextField(
                                                    controller:
                                                        _coinsController,
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                            decimal: true),
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF0F172A)),
                                                    onChanged: (_) =>
                                                        _recalculateFromDenominations(),
                                                    decoration: InputDecoration(
                                                      hintText: '0.00',
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 8,
                                                              vertical: 7),
                                                      filled: true,
                                                      fillColor: isDark
                                                          ? const Color(
                                                              0xFF1E293B)
                                                          : Colors.white,
                                                      border:
                                                          OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            _fieldLabel(
                                'Actual Closing Cash Counted *', isDark),
                            TextField(
                              controller: _closingCashController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                prefixText: '$currency ',
                                prefixStyle: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold),
                                isDense: true,
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1)),
                                ),
                              ),
                            ),

                            // Discrepancy Live Status Banner
                            Builder(builder: (context) {
                              final entered = double.tryParse(
                                      _closingCashController.text.trim()) ??
                                  0.0;
                              final expected = expectedCash;
                              final diff = entered - expected;
                              final isMatch = diff.abs() < 0.01;
                              final isShort = diff < -0.01;

                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isMatch
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.12)
                                      : isShort
                                          ? const Color(0xFFEF4444)
                                              .withValues(alpha: 0.12)
                                          : const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isMatch
                                        ? const Color(0xFF10B981)
                                        : isShort
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFF59E0B),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isMatch
                                          ? Icons.check_circle_rounded
                                          : (isShort
                                              ? Icons.error_outline_rounded
                                              : Icons.info_outline_rounded),
                                      size: 15,
                                      color: isMatch
                                          ? const Color(0xFF059669)
                                          : isShort
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        isMatch
                                            ? 'Balanced: Count matches expected cash exactly ($currency 0.00)'
                                            : isShort
                                                ? 'CASH SHORT: Drawer is short by $currency${diff.abs().toStringAsFixed(2)}'
                                                : 'CASH OVER: Drawer has surplus of $currency${diff.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isMatch
                                              ? const Color(0xFF059669)
                                              : isShort
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),

                            _fieldLabel('Closing Note (Optional)', isDark),
                            TextField(
                              controller: _closeNoteController,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. End of shift, cash balanced with drawer physical count',
                                hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8)),
                                isDense: true,
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1)),
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
                                    side: const BorderSide(
                                        color: Color(0xFF004EEB)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.receipt_long_rounded,
                                      size: 16),
                                  label: const Text('View X-Report',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
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
                                        foregroundColor: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                        side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFCBD5E1)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Cancel',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.lock_rounded,
                                          size: 16),
                                      label: const Text(
                                          'Close Shift (Z-Report)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                      onPressed: _closeRegister,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _denomInput(int value, bool isDark) {
    return Expanded(
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$value x',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color:
                    isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _denomControllers[value],
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                onChanged: (_) => _recalculateFromDenominations(),
                decoration: InputDecoration(
                  hintText: '0',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, bool isDark,
      {bool isDeduct = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDeduct
                  ? const Color(0xFFEF4444)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
