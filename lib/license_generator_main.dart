import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'services/license_service.dart';
import 'services/vendor_license_registry_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LicenseGeneratorApp());
}

class LicenseGeneratorApp extends StatelessWidget {
  const LicenseGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart POS — SaaS License Generator (Vendor Suite)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const LicenseGeneratorScreen(),
    );
  }
}

class LicenseGeneratorScreen extends StatefulWidget {
  const LicenseGeneratorScreen({super.key});

  @override
  State<LicenseGeneratorScreen> createState() => _LicenseGeneratorScreenState();
}

class _LicenseGeneratorScreenState extends State<LicenseGeneratorScreen> {
  static const List<Map<String, String>> _businessTypeOptions = [
    {'id': 'universal', 'label': 'Universal Business (Wholesale & Retail)'},
    {'id': 'pharmacy', 'label': 'Pharmacy / Medical Store & Agency'},
    {'id': 'supermarket', 'label': 'Supermarket / Departmental Store'},
    {'id': 'general_store', 'label': 'General Store / Kiryana / Mini Mart'},
    {'id': 'clothing', 'label': 'Apparel & Garments / Footwear / Boutique'},
    {'id': 'mobile', 'label': 'Mobile Phones & Electronics Agency'},
    {'id': 'solar', 'label': 'Solar Energy & Hardware Systems Agency'},
    {'id': 'restaurant', 'label': 'Restaurant / Cafe / Fast Food / Bakery'},
    {'id': 'wholesale', 'label': 'Wholesale & Bulk FMCG Distribution'},
    {'id': 'repair', 'label': 'Repairing Shop / Mobile & Auto Service'},
    {'id': 'hotel', 'label': 'Hotel Management & Room Booking'},
    {'id': 'gym', 'label': 'Gym & Fitness Center Club'},
    {'id': 'manufacturing', 'label': 'Manufacturing / Production & Assembly'},
    {
      'id': 'fruit_wholesale',
      'label': 'Fruit & Sabzi Mandi / Commission Agency'
    },
    {'id': 'poultry', 'label': 'Poultry Farm & Broiler Trading Agency'},
    {'id': 'accounting_crm', 'label': 'Accounting, Tax & Corporate CRM'},
    {'id': 'woocommerce', 'label': 'Online Store / E-Commerce & WooCommerce'},
    {'id': 'dairy_milk', 'label': 'Dairy, Milk & Eggs'},
    {'id': 'tyres_battery', 'label': 'Tyre Shop, Rims & Battery'},
    {'id': 'hardware_tools', 'label': 'Hardware, Tools & Paint'},
    {'id': 'auto_parts', 'label': 'Auto Spare Parts & Automotive'},
    {'id': 'meat_butchery', 'label': 'Meat, Butchery & Poultry'},
    {'id': 'fabrics_textile', 'label': 'Fabrics & Cloth (Meter / Gazz)'},
    {'id': 'lubricants_oil', 'label': 'Mobile Oil & Lubricants'},
    {'id': 'sanitary_tiles', 'label': 'Sanitary, Tiles & Bath Fittings'},
    {'id': 'custom_other', 'label': 'Other / Custom Business'},
  ];

  final VendorLicenseRegistryService _registry =
      const VendorLicenseRegistryService();

  final TextEditingController _clientNameCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _macCtrl = TextEditingController();
  final TextEditingController _customDaysCtrl =
      TextEditingController(text: '30');
  final TextEditingController _searchRegistryCtrl = TextEditingController();

  String _selectedBusinessType = 'universal';
  String _selectedAccessMode = 'offline'; // 'offline', 'hybrid', 'online'
  String _selectedTier = 'YRL'; // TRL, QTR, HLF, YRL, CST, LFT
  bool _allowUpdates = true;
  DateTime? _customExpiryDate;

  String _generatedKey = '';
  DateTime? _calcExpiry;
  String _hostHwId = 'Loading...';
  String _hostMac = 'Loading...';

  List<VendorLicenseRecord> _registryRecords = [];
  String _registrySearch = '';
  String _websiteSyncUrl = '';
  String _websiteApiToken = '';
  String _publicUpdateBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _loadHostIdentifiers();
    _loadRegistryAndConfig();
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _contactCtrl.dispose();
    _macCtrl.dispose();
    _customDaysCtrl.dispose();
    _searchRegistryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHostIdentifiers() async {
    final hwId = await LicenseService.getHardwareId();
    final mac = await LicenseService.getDeviceMacAddress();
    if (mounted) {
      setState(() {
        _hostHwId = hwId;
        _hostMac = mac;
      });
    }
  }

  Future<void> _loadRegistryAndConfig() async {
    final records = await _registry.loadRecords();
    final cfg = await _registry.loadSyncConfig();
    if (mounted) {
      setState(() {
        _registryRecords = records;
        _websiteSyncUrl = cfg['website_sync_url'] ?? '';
        _websiteApiToken = cfg['api_token'] ?? '';
        _publicUpdateBaseUrl = cfg['public_update_base_url'] ?? '';
      });
    }
  }

  String _businessTypeLabel(String id) {
    for (final opt in _businessTypeOptions) {
      if (opt['id'] == id) return opt['label']!;
    }
    return id;
  }

  Future<void> _generateKey() async {
    final client = _clientNameCtrl.text.trim();
    final mac = _macCtrl.text.trim();

    if (client.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter client business or customer name'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (mac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please enter client Hardware ID (HWID), MAC, or ANY'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    int days = 365;
    if (_selectedTier == 'TRL') days = 30;
    if (_selectedTier == 'QTR') days = 90;
    if (_selectedTier == 'HLF') days = 180;
    if (_selectedTier == 'YRL') days = 365;
    if (_selectedTier == 'CST') {
      final parsedDays = int.tryParse(_customDaysCtrl.text.trim());
      if (_customExpiryDate == null && (parsedDays == null || parsedDays < 1)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Custom duration must be at least 1 day or pick a future date.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      days = parsedDays ?? 30;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? expiry;
    if (_selectedTier == 'LFT') {
      expiry = null;
    } else if (_customExpiryDate != null && _selectedTier == 'CST') {
      final pickedDay = DateTime(_customExpiryDate!.year,
          _customExpiryDate!.month, _customExpiryDate!.day);
      if (pickedDay.isBefore(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom expiry date cannot be in the past.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      expiry = pickedDay;
    } else {
      expiry = today.add(Duration(days: days));
    }

    final key = LicenseService.generatePurchaseKey(
      macAddress: mac,
      clientName: client,
      tierCode: _selectedTier,
      businessType: _selectedBusinessType,
      accessMode: _selectedAccessMode,
      allowUpdates: _allowUpdates,
      customDays: days,
      customExpiryDate: expiry,
    );

    final normalizedTarget = LicenseService.normalizeMac(mac);
    final generatedDateStr = now.toIso8601String().split('T').first;
    final renewalDateStr =
        expiry != null ? expiry.toIso8601String().split('T').first : 'Lifetime';

    final record = VendorLicenseRecord(
      id: '${now.millisecondsSinceEpoch}_${normalizedTarget.isNotEmpty ? normalizedTarget : 'ANY'}',
      clientName: client,
      businessType: _selectedBusinessType,
      accessMode: _selectedAccessMode,
      contactInfo: _contactCtrl.text.trim(),
      machineId: mac.toUpperCase(),
      tierCode: _selectedTier,
      tierLabel: LicenseService.getTierLabel(_selectedTier),
      generatedAt: generatedDateStr,
      nextRenewalDate: renewalDateStr,
      allowUpdates: _allowUpdates,
      licenseKey: key,
    );

    final updatedList = await _registry.upsertRecord(record);

    if (!mounted) return;
    setState(() {
      _generatedKey = key;
      _calcExpiry = expiry;
      _registryRecords = updatedList;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('License Key Generated & Saved to Portable Vendor Registry!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _openVerifyKeyDialog() async {
    final ctrl = TextEditingController(text: _generatedKey);
    QulopStatus? result;
    if (ctrl.text.trim().isNotEmpty) {
      result = await LicenseService.verifyQulopKey(ctrl.text,
          ignoreHardwareCheck: true);
    }
    if (!mounted) {
      ctrl.dispose();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Text('Inspect / Verify License Key',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Courier', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Paste QULOP / SPOS Key',
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                if (result != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: result!.isValid
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: result!.isValid
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result!.isValid
                              ? 'SIGNATURE VALID — ${result!.tierLabel}'
                              : 'INVALID — ${result!.tierLabel}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text('Message: ${result!.message}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        if (result!.clientName != null)
                          Text('Client: ${result!.clientName}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        if (result!.businessType != null &&
                            result!.businessType!.isNotEmpty)
                          Text(
                              'Business Type: ${_businessTypeLabel(result!.businessType!)}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        Text('Operation Mode: ${result!.accessModeLabel}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        if (result!.targetMac != null)
                          Text('Bound ID: ${result!.targetMac}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        Text(
                            'Auto-Updates Allowed: ${result!.allowUpdates ? "Yes" : "No (Blocked)"}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        if (result!.issueDate != null)
                          Text(
                              'Issued: ${result!.issueDate!.toIso8601String().split('T').first}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        if (result!.expiryDate != null && !result!.isLifetime)
                          Text(
                              'Expires: ${result!.expiryDate!.toIso8601String().split('T').first} (${result!.remainingDays} days)',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final inspected = await LicenseService.verifyQulopKey(
                  ctrl.text,
                  ignoreHardwareCheck: true,
                );
                setDialogState(() => result = inspected);
              },
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Verify Key'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  void _copyKeyOnly() {
    if (_generatedKey.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _generatedKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('License Key copied to clipboard!')),
    );
  }

  void _copyWhatsAppTemplate() {
    if (_generatedKey.isEmpty) return;
    final client = _clientNameCtrl.text.trim();
    final mac = _macCtrl.text.trim();
    final tier = LicenseService.getTierLabel(_selectedTier);
    final expiryStr = _calcExpiry != null
        ? '${_calcExpiry!.day.toString().padLeft(2, '0')}/${_calcExpiry!.month.toString().padLeft(2, '0')}/${_calcExpiry!.year}'
        : 'Lifetime (Never Expires)';

    final msg = LicenseService.generateWhatsAppTemplate(
      clientName: client,
      macAddress: mac,
      tierLabel: tier,
      key: _generatedKey,
      expiryDateStr: expiryStr,
    );

    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'WhatsApp Message Template copied! You can now paste and send to customer.'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  Future<void> _openWebsiteSyncDialog() async {
    final syncUrlCtrl = TextEditingController(text: _websiteSyncUrl);
    final tokenCtrl = TextEditingController(text: _websiteApiToken);
    final updateUrlCtrl = TextEditingController(text: _publicUpdateBaseUrl);
    bool isPushing = false;
    String? syncFeedback;
    bool? syncOk;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Text('Website Sync & Export Registry',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portable Registry File: ${_registry.registryPath}',
                    style:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: syncUrlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Website License Sync API URL (HTTP POST)',
                      hintText:
                          'https://yourdomain.com/api/smartpos/sync-licenses',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tokenCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Website API Secret / Bearer Token',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: updateUrlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Default Public Updates Base URL',
                      hintText: 'https://yourdomain.com/updates/smartpos/',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text('Copy JSON'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  _registry.buildExportJson(_registryRecords)));
                          setDialogState(() {
                            syncOk = true;
                            syncFeedback =
                                'All ${_registryRecords.length} license record(s) copied as JSON.';
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_rounded, size: 16),
                        label: const Text('Save CSV & JSON'),
                        onPressed: () async {
                          final vendorDir = VendorLicenseRegistryService
                              .resolvePortableVendorDir();
                          final csvFile = File(p.join(
                              vendorDir.path, 'vendor_licenses_export.csv'));
                          final jsonFile = File(p.join(
                              vendorDir.path, 'vendor_licenses_export.json'));
                          await csvFile.writeAsString(
                              _registry.buildExportCsv(_registryRecords),
                              flush: true);
                          await jsonFile.writeAsString(
                              _registry.buildExportJson(_registryRecords),
                              flush: true);
                          setDialogState(() {
                            syncOk = true;
                            syncFeedback =
                                'Saved CSV & JSON to ${vendorDir.path}';
                          });
                        },
                      ),
                    ],
                  ),
                  if (syncFeedback != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: syncOk == true
                            ? const Color(0xFF064E3B)
                            : const Color(0xFF450A0A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(syncFeedback!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await _registry.saveSyncConfig(
                  websiteSyncUrl: syncUrlCtrl.text,
                  apiToken: tokenCtrl.text,
                  publicUpdateBaseUrl: updateUrlCtrl.text,
                );
                if (mounted) {
                  setState(() {
                    _websiteSyncUrl = syncUrlCtrl.text.trim();
                    _websiteApiToken = tokenCtrl.text.trim();
                    _publicUpdateBaseUrl = updateUrlCtrl.text.trim();
                  });
                }
                setDialogState(() {
                  syncOk = true;
                  syncFeedback = 'Website sync settings saved locally.';
                });
              },
              child: const Text('Save Config'),
            ),
            ElevatedButton.icon(
              onPressed: isPushing
                  ? null
                  : () async {
                      setDialogState(() => isPushing = true);
                      await _registry.saveSyncConfig(
                        websiteSyncUrl: syncUrlCtrl.text,
                        apiToken: tokenCtrl.text,
                        publicUpdateBaseUrl: updateUrlCtrl.text,
                      );
                      final res = await _registry.pushRegistryToWebsite(
                        syncUrl: syncUrlCtrl.text,
                        apiToken: tokenCtrl.text,
                        records: _registryRecords,
                      );
                      setDialogState(() {
                        isPushing = false;
                        syncOk = res['success'] == true;
                        syncFeedback = res['message']?.toString();
                      });
                    },
              icon: const Icon(Icons.cloud_sync_rounded, size: 16),
              label: Text(isPushing ? 'Syncing...' : 'Push to Website'),
            ),
          ],
        ),
      ),
    );
    syncUrlCtrl.dispose();
    tokenCtrl.dispose();
    updateUrlCtrl.dispose();
  }

  Future<void> _openManifestBuilderDialog() async {
    final exeCtrl = TextEditingController(
      text: p.join(
        Directory.current.path,
        'installer_output',
        'SmartPOS_Enterprise_Setup_v1.1.1.exe',
      ),
    );
    final versionCtrl = TextEditingController(text: '1.1.2');
    final buildCtrl = TextEditingController(text: '4');
    final base = _publicUpdateBaseUrl.isNotEmpty
        ? _publicUpdateBaseUrl
        : 'https://yourdomain.com/updates/smartpos/';
    final downloadUrlCtrl = TextEditingController(
      text:
          '${base.endsWith('/') ? base : '$base/'}SmartPOS_Enterprise_Setup_v1.1.2.exe',
    );
    final licenseCheckCtrl = TextEditingController();
    final notesCtrl = TextEditingController(
      text:
          '• Safe bug fixes and performance improvements\n• Automatic encrypted database backup & schema migration',
    );
    String? generatedJson;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.system_update_alt_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Text('Website Update Manifest (version.json)',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: exeCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Local Installer (.exe) File Path',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: versionCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'New Version (e.g. 1.1.2)',
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: buildCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Build #',
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: downloadUrlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Public Installer Download URL on Website',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: licenseCheckCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText:
                          'Optional Remote License Verify API URL (POST)',
                      hintText:
                          'https://yourdomain.com/api/smartpos/check-license',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Release Notes',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ],
                  if (generatedJson != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: SelectableText(
                        generatedJson!,
                        style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontFamily: 'Courier',
                            fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (generatedJson != null)
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: generatedJson!));
                },
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy version.json'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final map = await VendorLicenseRegistryService
                      .buildUpdateManifestForFile(
                    installerFilePath: exeCtrl.text,
                    version: versionCtrl.text,
                    buildNumber: int.tryParse(buildCtrl.text.trim()) ?? 1,
                    downloadUrl: downloadUrlCtrl.text,
                    releaseNotes: notesCtrl.text,
                    licenseVerifyUrl: licenseCheckCtrl.text,
                  );
                  const encoder = JsonEncoder.withIndent('  ');
                  final jsonOut = encoder.convert(map);
                  final vendorDir =
                      VendorLicenseRegistryService.resolvePortableVendorDir();
                  final outFile = File(p.join(vendorDir.path, 'version.json'));
                  await outFile.writeAsString(jsonOut, flush: true);
                  setDialogState(() {
                    err = null;
                    generatedJson = jsonOut;
                  });
                } catch (e) {
                  setDialogState(() => err = e.toString());
                }
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Build & Save version.json'),
            ),
          ],
        ),
      ),
    );
    exeCtrl.dispose();
    versionCtrl.dispose();
    buildCtrl.dispose();
    downloadUrlCtrl.dispose();
    licenseCheckCtrl.dispose();
    notesCtrl.dispose();
  }

  void _loadRecordIntoForm(VendorLicenseRecord r) {
    setState(() {
      _clientNameCtrl.text = r.clientName;
      _contactCtrl.text = r.contactInfo;
      _macCtrl.text = r.machineId;
      _selectedBusinessType =
          _businessTypeOptions.any((opt) => opt['id'] == r.businessType)
              ? r.businessType
              : 'universal';
      _selectedAccessMode = LicenseService.normalizeAccessMode(r.accessMode);
      _selectedTier = r.tierCode;
      _allowUpdates = r.allowUpdates;
      _generatedKey = r.licenseKey;
      _calcExpiry = r.nextRenewalDate == 'Lifetime'
          ? null
          : DateTime.tryParse(r.nextRenewalDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _registrySearch.trim().toLowerCase();
    final filteredRecords = q.isEmpty
        ? _registryRecords
        : _registryRecords.where((r) {
            return r.clientName.toLowerCase().contains(q) ||
                r.businessType.toLowerCase().contains(q) ||
                r.machineId.toLowerCase().contains(q) ||
                r.tierLabel.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFF818CF8)),
            SizedBox(width: 12),
            Text(
              'Smart POS — Portable License Master (Vendor Only)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openVerifyKeyDialog,
            icon: const Icon(Icons.verified_user_outlined,
                size: 16, color: Color(0xFF34D399)),
            label: const Text('Inspect Key',
                style: TextStyle(color: Color(0xFF34D399), fontSize: 12)),
          ),
          TextButton.icon(
            onPressed: _openManifestBuilderDialog,
            icon: const Icon(Icons.system_update_alt_rounded,
                size: 16, color: Color(0xFFFBBF24)),
            label: const Text('Update Manifest',
                style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12)),
          ),
          TextButton.icon(
            onPressed: _openWebsiteSyncDialog,
            icon: const Icon(Icons.cloud_upload_outlined,
                size: 16, color: Color(0xFF38BDF8)),
            label: const Text('Website Sync / Export',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.computer_rounded,
                    size: 16, color: Color(0xFF38BDF8)),
                const SizedBox(width: 6),
                Text('Vendor HWID: $_hostHwId  •  MAC: $_hostMac',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Generator Form
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_fix_high_rounded,
                                color: Color(0xFF818CF8)),
                            SizedBox(width: 10),
                            Text(
                              'Generate Client License Key',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Generate cryptographically signed, machine-bound licenses for your SaaS clients.',
                          style:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const Divider(height: 32, color: Color(0xFF334155)),

                        // Client Name
                        const Text('1. Client Store / Business Name *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFCBD5E1))),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _clientNameCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Al-Madina Pharmacy & Medicos',
                            hintStyle:
                                const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.storefront_rounded,
                                color: Color(0xFF818CF8)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Business Type + Contact Row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Business Type *',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFFCBD5E1))),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedBusinessType,
                                    dropdownColor: const Color(0xFF0F172A),
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF0F172A),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                    ),
                                    items: _businessTypeOptions
                                        .map((opt) => DropdownMenuItem<String>(
                                              value: opt['id'],
                                              child: Text(
                                                opt['label']!,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(
                                            () => _selectedBusinessType = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Client WhatsApp / Phone',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFFCBD5E1))),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _contactCtrl,
                                    decoration: InputDecoration(
                                      hintText: '+92 300 0000000',
                                      hintStyle: const TextStyle(
                                          color: Color(0xFF64748B)),
                                      filled: true,
                                      fillColor: const Color(0xFF0F172A),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Machine ID / MAC Address
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                                '2. Client Hardware ID (HWID), MAC, or ANY *',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFFCBD5E1))),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.paste_rounded,
                                      size: 14, color: Color(0xFF38BDF8)),
                                  label: const Text('Paste ID',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF38BDF8))),
                                  onPressed: () async {
                                    final data = await Clipboard.getData(
                                        Clipboard.kTextPlain);
                                    if (data?.text != null) {
                                      _macCtrl.text = data!.text!.trim();
                                    }
                                  },
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.fingerprint_rounded,
                                      size: 14, color: Color(0xFF34D399)),
                                  label: const Text('My HWID',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF34D399))),
                                  onPressed: () {
                                    _macCtrl.text = _hostHwId;
                                  },
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.laptop_chromebook,
                                      size: 14, color: Color(0xFF818CF8)),
                                  label: const Text('My MAC',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF818CF8))),
                                  onPressed: () {
                                    _macCtrl.text = _hostMac;
                                  },
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.public_rounded,
                                      size: 14, color: Colors.amber),
                                  label: const Text('Universal (ANY)',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.amber)),
                                  onPressed: () {
                                    _macCtrl.text = 'ANY';
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _macCtrl,
                          style: const TextStyle(
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText:
                                'e.g. HWID-4C4C4544... or C8-3A-35-1C-4B-40 or ANY',
                            hintStyle:
                                const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.fingerprint_rounded,
                                color: Color(0xFF818CF8)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // License Tier Selection
                        const Text('3. License Subscription Tier & Duration *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFCBD5E1))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _tierChip('TRL', '30-Day Trial',
                                Icons.access_time_filled, Colors.amber),
                            _tierChip('QTR', 'Quarterly (90 Days)',
                                Icons.calendar_today_rounded, Colors.cyan),
                            _tierChip('HLF', 'Half-Yearly (180 Days)',
                                Icons.date_range_rounded, Colors.blue),
                            _tierChip('YRL', 'Yearly Plan (365 Days)',
                                Icons.star_rounded, Colors.indigoAccent),
                            _tierChip('CST', 'Custom Days / Date',
                                Icons.tune_rounded, Colors.purpleAccent),
                            _tierChip(
                                'LFT',
                                'Lifetime Commercial',
                                Icons.all_inclusive_rounded,
                                const Color(0xFF10B981)),
                          ],
                        ),

                        // If Custom Days / Date Selected
                        if (_selectedTier == 'CST') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _customDaysCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Duration in Days',
                                      hintText: 'e.g. 45 or 120',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) {
                                      if (_customExpiryDate != null) {
                                        setState(
                                            () => _customExpiryDate = null);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF334155),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.calendar_month,
                                      size: 16),
                                  label: Text(_customExpiryDate != null
                                      ? '${_customExpiryDate!.day}/${_customExpiryDate!.month}/${_customExpiryDate!.year}'
                                      : 'Pick Specific Date'),
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final today =
                                        DateTime(now.year, now.month, now.day);
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          today.add(const Duration(days: 30)),
                                      firstDate:
                                          today.add(const Duration(days: 1)),
                                      lastDate:
                                          today.add(const Duration(days: 3650)),
                                    );
                                    if (picked != null) {
                                      final pickedDay = DateTime(picked.year,
                                          picked.month, picked.day);
                                      setState(() {
                                        _customExpiryDate = pickedDay;
                                        _customDaysCtrl.text = pickedDay
                                            .difference(today)
                                            .inDays
                                            .toString();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        const Text('4. Software Deployment / Access Mode *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFCBD5E1))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _accessModeChip(
                              'offline',
                              'Offline Only (Local PC)',
                              Icons.desktop_windows_rounded,
                              const Color(0xFF94A3B8),
                            ),
                            _accessModeChip(
                              'hybrid',
                              'Hybrid (Desktop + Android Sync)',
                              Icons.sync_rounded,
                              const Color(0xFF38BDF8),
                            ),
                            _accessModeChip(
                              'online',
                              'Full Online (Cloud API Mode)',
                              Icons.cloud_done_rounded,
                              const Color(0xFF10B981),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _allowUpdates
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.4)
                                  : const Color(0xFFEF4444)
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeThumbColor: const Color(0xFF10B981),
                            title: const Text(
                              'Allow Future Safe Online Auto-Updates',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                            subtitle: Text(
                              _allowUpdates
                                  ? 'Client POS can download & apply verified updates without losing database.'
                                  : 'Client POS will keep running locally but cannot install future online updates.',
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                            value: _allowUpdates,
                            onChanged: (v) => setState(() => _allowUpdates = v),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Generate Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 4,
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded,
                                size: 20),
                            label: const Text(
                              'Generate SaaS License Key',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            onPressed: _generateKey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Right Column: Output Certificate & Actions
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      // Generated Key Certificate Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1E293B),
                              _generatedKey.isNotEmpty
                                  ? const Color(0xFF1E1B4B)
                                  : const Color(0xFF1E293B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _generatedKey.isNotEmpty
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF334155),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'License Certificate Output',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white),
                                ),
                                if (_generatedKey.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFF10B981)),
                                    ),
                                    child: const Text(
                                        'CRYPTOGRAPHICALLY SIGNED',
                                        style: TextStyle(
                                            color: Color(0xFF34D399),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const Divider(height: 24, color: Color(0xFF334155)),
                            if (_generatedKey.isEmpty) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 36),
                                  child: Column(
                                    children: [
                                      Icon(Icons.vpn_key_outlined,
                                          size: 48, color: Color(0xFF475569)),
                                      SizedBox(height: 12),
                                      Text(
                                          'Enter client details on the left and click\n"Generate SaaS License Key"',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              _metaRow('Client Store:', _clientNameCtrl.text),
                              _metaRow('Business Type:',
                                  _businessTypeLabel(_selectedBusinessType)),
                              _metaRow(
                                  'Access Mode:',
                                  LicenseService.getAccessModeLabel(
                                      _selectedAccessMode)),
                              _metaRow('Bound Machine ID:', _macCtrl.text),
                              _metaRow('Subscription Plan:',
                                  LicenseService.getTierLabel(_selectedTier)),
                              _metaRow(
                                'Generated / Next Renewal:',
                                _calcExpiry != null
                                    ? () {
                                        final now = DateTime.now();
                                        final today = DateTime(
                                            now.year, now.month, now.day);
                                        final exp = DateTime(
                                            _calcExpiry!.year,
                                            _calcExpiry!.month,
                                            _calcExpiry!.day);
                                        final daysLeft =
                                            exp.difference(today).inDays;
                                        return '${now.toIso8601String().split('T').first}  ->  ${exp.toIso8601String().split('T').first} ($daysLeft days)';
                                      }()
                                    : '${DateTime.now().toIso8601String().split('T').first}  ->  Lifetime',
                              ),
                              _metaRow(
                                'Auto-Updates:',
                                _allowUpdates ? 'Allowed' : 'Blocked',
                              ),
                              const SizedBox(height: 16),

                              const Text('Activation Key String:',
                                  style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF475569)),
                                ),
                                child: SelectableText(
                                  _generatedKey,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontFamily: 'Courier',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Quick Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF334155),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const Text('Copy Key'),
                                      onPressed: _copyKeyOnly,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                      icon: const Icon(Icons.send_rounded,
                                          size: 16),
                                      label: const Text(
                                          'Copy WhatsApp Template',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      onPressed: _copyWhatsAppTemplate,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Persistent Vendor Client License Registry
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Client License Registry (Saved)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white)),
                                Text(
                                    '${_registryRecords.length} total client(s)',
                                    style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _searchRegistryCtrl,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText:
                                    'Search client, business type, MAC/HWID...',
                                hintStyle:
                                    const TextStyle(color: Color(0xFF64748B)),
                                prefixIcon: const Icon(Icons.search,
                                    size: 16, color: Color(0xFF64748B)),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (v) =>
                                  setState(() => _registrySearch = v),
                            ),
                            const SizedBox(height: 12),
                            if (filteredRecords.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                    'No matching client license records stored yet.',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredRecords.length.clamp(0, 12),
                                separatorBuilder: (_, __) => const Divider(
                                    height: 12, color: Color(0xFF334155)),
                                itemBuilder: (ctx, idx) {
                                  final rec = filteredRecords[idx];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    rec.clientName,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                        color: Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: rec.accessMode ==
                                                            'online'
                                                        ? const Color(
                                                                0xFF38BDF8)
                                                            .withValues(
                                                                alpha: 0.2)
                                                        : rec.accessMode ==
                                                                'hybrid'
                                                            ? const Color(
                                                                    0xFF818CF8)
                                                                .withValues(
                                                                    alpha: 0.2)
                                                            : const Color(
                                                                    0xFF64748B)
                                                                .withValues(
                                                                    alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    rec.accessMode
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: rec.accessMode ==
                                                              'online'
                                                          ? const Color(
                                                              0xFF38BDF8)
                                                          : rec.accessMode ==
                                                                  'hybrid'
                                                              ? const Color(
                                                                  0xFFA5B4FC)
                                                              : const Color(
                                                                  0xFFCBD5E1),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: rec.allowUpdates
                                                        ? const Color(
                                                                0xFF10B981)
                                                            .withValues(
                                                                alpha: 0.2)
                                                        : const Color(
                                                                0xFFEF4444)
                                                            .withValues(
                                                                alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    rec.allowUpdates
                                                        ? 'UPD ON'
                                                        : 'UPD OFF',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: rec.allowUpdates
                                                          ? const Color(
                                                              0xFF34D399)
                                                          : const Color(
                                                              0xFFF87171),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_businessTypeLabel(rec.businessType)} • ${rec.machineId}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF94A3B8)),
                                            ),
                                            Text(
                                              'Gen: ${rec.generatedAt} • Renew: ${rec.nextRenewalDate} (${rec.statusLabel})',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Load / Renew',
                                        icon: const Icon(Icons.edit_note,
                                            size: 17, color: Color(0xFF38BDF8)),
                                        onPressed: () =>
                                            _loadRecordIntoForm(rec),
                                      ),
                                      IconButton(
                                        tooltip: 'Copy Key',
                                        icon: const Icon(Icons.copy,
                                            size: 15, color: Color(0xFF818CF8)),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(
                                              text: rec.licenseKey));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text('Key copied!')),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Record',
                                        icon: const Icon(Icons.delete_outline,
                                            size: 16, color: Color(0xFFEF4444)),
                                        onPressed: () async {
                                          final updated = await _registry
                                              .deleteRecord(rec.id);
                                          if (mounted) {
                                            setState(() =>
                                                _registryRecords = updated);
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          SelectableText(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _accessModeChip(
      String code, String label, IconData icon, Color color) {
    final isSelected = _selectedAccessMode == code;
    return InkWell(
      onTap: () => setState(() => _selectedAccessMode = code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: isSelected ? color : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierChip(String code, String label, IconData icon, Color color) {
    final isSelected = _selectedTier == code;
    return InkWell(
      onTap: () => setState(() => _selectedTier = code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: isSelected ? color : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
