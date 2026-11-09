import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class QuickAddSupplierDialog extends StatefulWidget {
  final BusinessSettings settings;

  const QuickAddSupplierDialog({super.key, required this.settings});

  @override
  State<QuickAddSupplierDialog> createState() => _QuickAddSupplierDialogState();
}

class _QuickAddSupplierDialogState extends State<QuickAddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0.00');

  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;

      final contact = Contact(
        type: 'supplier',
        name: _nameCtrl.text.trim(),
        businessName: _businessCtrl.text.trim().isNotEmpty ? _businessCtrl.text.trim() : null,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        balance: balance,
      );

      final id = await db.addContact(contact);
      final createdSupplier = Contact(
        id: id,
        type: 'supplier',
        name: contact.name,
        businessName: contact.businessName,
        phone: contact.phone,
        email: contact.email,
        address: contact.address,
        balance: contact.balance,
      );

      if (mounted) {
        Navigator.of(context).pop(createdSupplier);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add supplier: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgHeader = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final inputDeco = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 580,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: bgHeader,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Color(0xFF4F46E5), size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Quick Add Supplier / Vendor',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Form Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Supplier Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _nameCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: inputDeco.copyWith(hintText: 'e.g. Abbott Wholesale Depot'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Business / Company Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _businessCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: inputDeco.copyWith(hintText: 'e.g. Abbott Laboratories'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone / Mobile Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _phoneCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: inputDeco.copyWith(hintText: '0300-1234567'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _emailCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: inputDeco.copyWith(hintText: 'vendor@domain.com'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Office / Depot Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _addressCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: inputDeco.copyWith(hintText: 'e.g. Commercial Market, Karachi'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Opening Payable (${widget.settings.currencySymbol})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _balanceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: inputDeco.copyWith(hintText: '0.00'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: bgHeader,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Save & Select', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isSaving ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
