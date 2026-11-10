import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class OpenRegisterDialog extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onOpened;
  final bool isDismissible;

  const OpenRegisterDialog({
    super.key,
    required this.settings,
    this.onOpened,
    this.isDismissible = false,
  });

  @override
  State<OpenRegisterDialog> createState() => _OpenRegisterDialogState();
}

class _OpenRegisterDialogState extends State<OpenRegisterDialog> {
  final TextEditingController _cashierController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '0.00');
  final TextEditingController _noteController = TextEditingController();
  bool _loading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _cashierController.text = (user?.name.isNotEmpty == true) ? user!.name : 'Admin Cashier';
  }

  @override
  void dispose() {
    _cashierController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 0) {
      setState(() => _errorText = 'Please enter a valid cash amount (>= 0)');
      return;
    }

    final cashier = _cashierController.text.trim();
    if (cashier.isEmpty) {
      setState(() => _errorText = 'Please enter cashier name');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final db = await DatabaseService.initialize();
      await db.openRegister(cashier, amount);
      if (mounted) {
        final currency = widget.settings.currencySymbol.isNotEmpty ? widget.settings.currencySymbol : 'Rs';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Cash Register opened with $currency ${amount.toStringAsFixed(2)}'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        widget.onOpened?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'Failed to open register: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol.isNotEmpty ? widget.settings.currencySymbol : 'Rs';
    final locationName = widget.settings.businessName.isNotEmpty ? widget.settings.businessName : 'Main Branch HQ';

    return PopScope(
      canPop: widget.isDismissible,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Open Cash Register Shift',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enter opening cash float in drawer to begin sales',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDismissible)
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Location badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storefront_rounded, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location: $locationName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Cashier Name
              _label('Cashier Name *', isDark),
              TextField(
                controller: _cashierController,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Opening Amount in Drawer
              _label('Cash in Drawer / Opening Float *', isDark),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                  fontWeight: FontWeight.w900,
                ),
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  prefixStyle: TextStyle(
                    fontSize: 18,
                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                    fontWeight: FontWeight.w900,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.15) : const Color(0xFFECFDF5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Quick Amount Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [0, 1000, 2000, 5000, 10000].map((v) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _amountController.text = v.toDouble().toStringAsFixed(2);
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '$currency $v',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Shift Note
              _label('Shift Note (Optional)', isDark),
              TextField(
                controller: _noteController,
                maxLines: 2,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g. Morning counter shift opening balance',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],

              const SizedBox(height: 22),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel / Exit', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Open Register Shift', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        ),
      ),
    );
  }
}

