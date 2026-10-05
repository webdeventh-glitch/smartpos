import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Function(BusinessSettings) onSettingsUpdated;

  const SettingsScreen({super.key, required this.settings, required this.onSettingsUpdated});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bizNameCtrl;
  late TextEditingController _branchCtrl;
  late TextEditingController _currencySymCtrl;
  late TextEditingController _currencyCodeCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _footerCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _bizNameCtrl = TextEditingController(text: s.businessName);
    _branchCtrl = TextEditingController(text: s.branchName);
    _currencySymCtrl = TextEditingController(text: s.currencySymbol);
    _currencyCodeCtrl = TextEditingController(text: s.currencyCode);
    _taxCtrl = TextEditingController(text: s.defaultTaxRate.toString());
    _phoneCtrl = TextEditingController(text: s.phone);
    _emailCtrl = TextEditingController(text: s.email);
    _addressCtrl = TextEditingController(text: s.address);
    _footerCtrl = TextEditingController(text: s.receiptFooter);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updated = BusinessSettings(
        id: widget.settings.id,
        businessName: _bizNameCtrl.text.trim(),
        branchName: _branchCtrl.text.trim(),
        currencySymbol: _currencySymCtrl.text.trim(),
        currencyCode: _currencyCodeCtrl.text.trim(),
        defaultTaxRate: double.tryParse(_taxCtrl.text.trim()) ?? 5.0,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        receiptFooter: _footerCtrl.text.trim(),
      );

      final db = await DatabaseService.initialize();
      await db.updateBusinessSettings(updated);
      widget.onSettingsUpdated(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business & POS Settings',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customize your store profile, currency, taxes, and receipt printer header/footer.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store Identification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bizNameCtrl,
                            decoration: const InputDecoration(labelText: 'Business Name *', isDense: true),
                            validator: (v) => v == null || v.isEmpty ? 'Business name required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _branchCtrl,
                            decoration: const InputDecoration(labelText: 'Branch Location *', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Currency & Taxation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currencySymCtrl,
                            decoration: const InputDecoration(labelText: 'Currency Symbol * (e.g. \$, Rs, PKR, €)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _currencyCodeCtrl,
                            decoration: const InputDecoration(labelText: 'Currency Code (USD, PKR, EUR)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _taxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Default Tax Rate (%)', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(labelText: 'Email', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Store Physical Address', isDense: true),
                    ),
                    const SizedBox(height: 16),

                    const Text('Thermal Receipt Footer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _footerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Footer Message',
                        hintText: 'e.g. Thank you for shopping with us! Please come again.',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004EEB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.save, size: 20),
                        label: Text(_isSaving ? 'Saving...' : 'Save Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isSaving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
