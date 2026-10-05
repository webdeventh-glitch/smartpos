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

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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

  List<BusinessLocation> _locations = [];
  List<TaxRate> _taxRates = [];
  List<InvoiceScheme> _schemes = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

    _loadSubData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bizNameCtrl.dispose();
    _branchCtrl.dispose();
    _currencySymCtrl.dispose();
    _currencyCodeCtrl.dispose();
    _taxCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseService.initialize();
    final locs = await db.getBusinessLocations();
    final taxes = await db.getTaxRates();
    final scs = await db.getInvoiceSchemes();
    if (mounted) {
      setState(() {
        _locations = locs;
        _taxRates = taxes;
        _schemes = scs;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGeneralSettings() async {
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
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
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

  void _showAddLocationDialog() {
    final nameCtrl = TextEditingController();
    final locIdCtrl = TextEditingController(text: 'BL000${_locations.length + 1}');
    final cityCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.store, color: Color(0xFF0038B8)),
            SizedBox(width: 8),
            Text('Add Business Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Location / Branch Name *', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locIdCtrl,
                decoration: const InputDecoration(labelText: 'Location ID (e.g. BL0003)', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'City / Area', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileCtrl,
                decoration: const InputDecoration(labelText: 'Contact Mobile', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final loc = BusinessLocation(
                name: nameCtrl.text.trim(),
                locationId: locIdCtrl.text.trim().isEmpty ? 'BL0001' : locIdCtrl.text.trim(),
                city: cityCtrl.text.trim(),
                mobile: mobileCtrl.text.trim(),
              );
              final db = await DatabaseService.initialize();
              await db.addBusinessLocation(loc);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadSubData();
            },
            child: const Text('Add Location'),
          ),
        ],
      ),
    );
  }

  void _showAddTaxDialog() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.percent, color: Color(0xFF0038B8)),
            SizedBox(width: 8),
            Text('Add Tax Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tax Name (e.g. VAT 10%) *', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rate Percentage (%) *', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
            onPressed: () async {
              final rate = double.tryParse(rateCtrl.text.trim());
              if (nameCtrl.text.trim().isEmpty || rate == null) return;
              final tax = TaxRate(name: nameCtrl.text.trim(), amount: rate);
              final db = await DatabaseService.initialize();
              await db.addTaxRate(tax);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadSubData();
            },
            child: const Text('Save Tax Rate'),
          ),
        ],
      ),
    );
  }

  void _showAddSchemeDialog() {
    final nameCtrl = TextEditingController();
    final prefixCtrl = TextEditingController(text: 'INV-');
    final startNumCtrl = TextEditingController(text: '1001');
    final digitsCtrl = TextEditingController(text: '4');
    String schemeType = 'blank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFF0038B8)),
              SizedBox(width: 8),
              Text('Add Invoice Scheme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Scheme Name *', isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: prefixCtrl,
                        decoration: const InputDecoration(labelText: 'Prefix (e.g. INV-)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: schemeType,
                        decoration: const InputDecoration(labelText: 'Numbering Type', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'blank', child: Text('Sequential (INV-0001)')),
                          DropdownMenuItem(value: 'year', child: Text('Year-based (INV-2026-0001)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => schemeType = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startNumCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Start Number', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: digitsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Digits', isDense: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final sc = InvoiceScheme(
                  name: nameCtrl.text.trim(),
                  prefix: prefixCtrl.text.trim(),
                  schemeType: schemeType,
                  startNumber: int.tryParse(startNumCtrl.text.trim()) ?? 1,
                  totalDigits: int.tryParse(digitsCtrl.text.trim()) ?? 4,
                );
                final db = await DatabaseService.initialize();
                await db.addInvoiceScheme(sc);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadSubData();
              },
              child: const Text('Save Scheme'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Ultimate POS Configuration & Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF0038B8),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0038B8),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: const [
                    Tab(icon: Icon(Icons.storefront, size: 18), text: 'Store Profile'),
                    Tab(icon: Icon(Icons.location_city, size: 18), text: 'Business Locations'),
                    Tab(icon: Icon(Icons.percent, size: 18), text: 'Tax Rates'),
                    Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Invoice Schemes'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Store Profile
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
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
                            decoration: const InputDecoration(labelText: 'Default Branch Name *', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Currency & Standard Tax', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          backgroundColor: const Color(0xFF0038B8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.save, size: 20),
                        label: Text(_isSaving ? 'Saving...' : 'Save Store Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isSaving ? null : _saveGeneralSettings,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab 1: Business Locations (Branches)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Business Branches & Warehouses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0038B8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Add Location'),
                      onPressed: _showAddLocationDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _locations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final loc = _locations[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.store, color: Color(0xFF0038B8)),
                                ),
                                title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('ID: ${loc.locationId} • ${loc.city.isNotEmpty ? loc.city : "City not set"} • Mobile: ${loc.mobile.isNotEmpty ? loc.mobile : "N/A"}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: loc.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    loc.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: loc.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Tab 2: Tax Rates
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tax Rates & Tax Groups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0038B8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Tax Rate'),
                      onPressed: _showAddTaxDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _taxRates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final tax = _taxRates[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(child: Text('%', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 18))),
                                ),
                                title: Text(tax.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('Percentage: ${tax.amount.toStringAsFixed(1)}%'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    if (tax.id != null) {
                                      final db = await DatabaseService.initialize();
                                      await db.deleteTaxRate(tax.id!);
                                      _loadSubData();
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Tab 3: Invoice Schemes
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Invoice Schemes & Sequence Numbering', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0038B8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Scheme'),
                      onPressed: _showAddSchemeDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _schemes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final sc = _schemes[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.format_list_numbered, color: Color(0xFF0038B8)),
                                ),
                                title: Text(sc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('Preview: ${sc.previewExample} • Start: ${sc.startNumber} • Total Invoices: ${sc.invoiceCount}'),
                                trailing: sc.isDefault
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('Default', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 12)),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
