import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class QuickCustomerDialog extends StatefulWidget {
  final Function(Contact) onCustomerAdded;

  const QuickCustomerDialog({super.key, required this.onCustomerAdded});

  @override
  State<QuickCustomerDialog> createState() => _QuickCustomerDialogState();
}

class _QuickCustomerDialogState extends State<QuickCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController(text: '1000.00');
  bool _isSaving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final contact = Contact(
        type: 'customer',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        creditLimit: double.tryParse(_creditLimitController.text.trim()) ?? 1000.0,
      );

      final id = await db.addContact(contact);
      final createdContact = Contact(
        id: id,
        type: contact.type,
        name: contact.name,
        phone: contact.phone,
        email: contact.email,
        address: contact.address,
        creditLimit: contact.creditLimit,
      );

      if (mounted) {
        widget.onCustomerAdded(createdContact);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding customer: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    super.dispose();
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
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
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Color(0xFF4F46E5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Quick Customer',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Create new customer and assign to current cart',
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

              // Name
              _fieldLabel('Customer Name *'),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'e.g. John Doe / Walk-in Buyer',
                  prefixIcon: Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Customer name is required' : null,
              ),
              const SizedBox(height: 14),

              // Phone & Credit Limit
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Mobile Phone'),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: '+1 (555) 000-0000',
                            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Credit Limit'),
                        TextFormField(
                          controller: _creditLimitController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.credit_card_outlined, size: 18, color: Color(0xFF64748B)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Email
              _fieldLabel('Email Address'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'customer@example.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              // Address
              _fieldLabel('Address / Location'),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Street address, City, State',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save & Select', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
