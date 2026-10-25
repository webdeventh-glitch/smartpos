import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/qulop_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QulopGeneratorApp());
}

class QulopGeneratorApp extends StatelessWidget {
  const QulopGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qulop — SaaS License Generator (Vendor Suite)',
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
      home: const QulopGeneratorScreen(),
    );
  }
}

class QulopGeneratorScreen extends StatefulWidget {
  const QulopGeneratorScreen({super.key});

  @override
  State<QulopGeneratorScreen> createState() => _QulopGeneratorScreenState();
}

class _QulopGeneratorScreenState extends State<QulopGeneratorScreen> {
  final TextEditingController _clientNameCtrl = TextEditingController();
  final TextEditingController _macCtrl = TextEditingController();
  final TextEditingController _customDaysCtrl = TextEditingController(text: '30');

  String _selectedTier = 'YRL'; // TRL, QTR, HLF, YRL, CST, LFT
  DateTime? _customExpiryDate;

  String _generatedKey = '';
  DateTime? _calcExpiry;
  String _hostMac = 'Loading...';

  // Recent generated keys log
  final List<Map<String, dynamic>> _recentKeys = [];

  @override
  void initState() {
    super.initState();
    _loadHostMac();
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _macCtrl.dispose();
    _customDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHostMac() async {
    final mac = await QulopService.getDeviceMacAddress();
    if (mounted) {
      setState(() => _hostMac = mac);
    }
  }

  void _generateKey() {
    final client = _clientNameCtrl.text.trim();
    final mac = _macCtrl.text.trim();

    if (client.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter client business or customer name'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (mac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter client machine MAC address'), backgroundColor: Colors.orange),
      );
      return;
    }

    int days = 365;
    if (_selectedTier == 'TRL') days = 30;
    if (_selectedTier == 'QTR') days = 90;
    if (_selectedTier == 'HLF') days = 180;
    if (_selectedTier == 'YRL') days = 365;
    if (_selectedTier == 'CST') {
      days = int.tryParse(_customDaysCtrl.text.trim()) ?? 30;
    }

    final now = DateTime.now();
    DateTime? expiry;
    if (_selectedTier == 'LFT') {
      expiry = null;
    } else if (_customExpiryDate != null && _selectedTier == 'CST') {
      expiry = _customExpiryDate;
    } else {
      expiry = now.add(Duration(days: days));
    }

    final key = QulopService.generatePurchaseKey(
      macAddress: mac,
      clientName: client,
      tierCode: _selectedTier,
      customDays: days,
      customExpiryDate: expiry,
    );

    setState(() {
      _generatedKey = key;
      _calcExpiry = expiry;
      _recentKeys.insert(0, {
        'client': client,
        'mac': mac,
        'tier': QulopService.getTierLabel(_selectedTier),
        'key': key,
        'expiry': expiry != null ? '${expiry.day}/${expiry.month}/${expiry.year}' : 'Lifetime',
        'generatedAt': DateTime.now().toIso8601String(),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Qulop SaaS License Key Generated Successfully!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _copyKeyOnly() {
    if (_generatedKey.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _generatedKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Qulop License Key copied to clipboard!')),
    );
  }

  void _copyWhatsAppTemplate() {
    if (_generatedKey.isEmpty) return;
    final client = _clientNameCtrl.text.trim();
    final mac = _macCtrl.text.trim();
    final tier = QulopService.getTierLabel(_selectedTier);
    final expiryStr = _calcExpiry != null
        ? '${_calcExpiry!.day.toString().padLeft(2, '0')}/${_calcExpiry!.month.toString().padLeft(2, '0')}/${_calcExpiry!.year}'
        : 'Lifetime (Never Expires)';

    final msg = QulopService.generateWhatsAppTemplate(
      clientName: client,
      macAddress: mac,
      tierLabel: tier,
      key: _generatedKey,
      expiryDateStr: expiryStr,
    );

    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WhatsApp Template copied! You can now paste and send to customer.'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFF818CF8)),
            SizedBox(width: 12),
            Text(
              'Qulop — SaaS License Key Generator (Vendor Suite)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        actions: [
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
                const Icon(Icons.computer_rounded, size: 16, color: Color(0xFF38BDF8)),
                const SizedBox(width: 6),
                Text('Vendor PC MAC: $_hostMac', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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
                            Icon(Icons.auto_fix_high_rounded, color: Color(0xFF818CF8)),
                            SizedBox(width: 10),
                            Text(
                              'Generate Qulop License Key',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Generate cryptographically signed, machine-bound Qulop licenses for your SaaS clients.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const Divider(height: 32, color: Color(0xFF334155)),

                        // Client Name
                        const Text('1. Client Store / Business Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFCBD5E1))),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _clientNameCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Al-Madina Pharmacy & Medicos',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFF818CF8)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Machine MAC Address
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('2. Client Hardware Machine ID (MAC Address) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFCBD5E1))),
                            Row(
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.paste_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  label: const Text('Paste MAC', style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
                                  onPressed: () async {
                                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                                    if (data?.text != null) {
                                      _macCtrl.text = data!.text!.trim();
                                    }
                                  },
                                ),
                                const SizedBox(width: 10),
                                TextButton.icon(
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.laptop_chromebook, size: 14, color: Color(0xFF34D399)),
                                  label: const Text('Use My PC MAC', style: TextStyle(fontSize: 12, color: Color(0xFF34D399))),
                                  onPressed: () {
                                    _macCtrl.text = _hostMac;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _macCtrl,
                          style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'e.g. C8-3A-35-1C-4B-40',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF818CF8)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // License Tier Selection
                        const Text('3. Qulop Subscription Tier & Duration *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFCBD5E1))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _tierChip('TRL', '30-Day Trial', Icons.access_time_filled, Colors.amber),
                            _tierChip('QTR', 'Quarterly (90 Days)', Icons.calendar_today_rounded, Colors.cyan),
                            _tierChip('HLF', 'Half-Yearly (180 Days)', Icons.date_range_rounded, Colors.blue),
                            _tierChip('YRL', 'Yearly Plan (365 Days)', Icons.star_rounded, Colors.indigoAccent),
                            _tierChip('CST', 'Custom Days / Date', Icons.tune_rounded, Colors.purpleAccent),
                            _tierChip('LFT', 'Lifetime Commercial', Icons.all_inclusive_rounded, Colors.green),
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
                              border: Border.all(color: const Color(0xFF334155)),
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
                                  ),
                                ),
                                const SizedBox(width: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF334155),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.calendar_month, size: 16),
                                  label: Text(_customExpiryDate != null
                                      ? '${_customExpiryDate!.day}/${_customExpiryDate!.month}/${_customExpiryDate!.year}'
                                      : 'Pick Specific Date'),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().add(const Duration(days: 30)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _customExpiryDate = picked;
                                        _customDaysCtrl.text = picked.difference(DateTime.now()).inDays.toString();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Generate Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 4,
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                            label: const Text(
                              'Generate Qulop License Key',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                              _generatedKey.isNotEmpty ? const Color(0xFF1E1B4B) : const Color(0xFF1E293B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _generatedKey.isNotEmpty ? const Color(0xFF6366F1) : const Color(0xFF334155),
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
                                  'Qulop Certificate Output',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                                if (_generatedKey.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF10B981)),
                                    ),
                                    child: const Text('CRYPTOGRAPHICALLY SIGNED', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
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
                                      Icon(Icons.vpn_key_outlined, size: 48, color: Color(0xFF475569)),
                                      SizedBox(height: 12),
                                      Text('Enter client details on the left and click\n"Generate Qulop License Key"',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              _metaRow('Client Store:', _clientNameCtrl.text),
                              _metaRow('Bound Machine ID:', _macCtrl.text),
                              _metaRow('Subscription Plan:', QulopService.getTierLabel(_selectedTier)),
                              _metaRow(
                                'Expiry Date:',
                                _calcExpiry != null
                                    ? '${_calcExpiry!.day}/${_calcExpiry!.month}/${_calcExpiry!.year} (${_calcExpiry!.difference(DateTime.now()).inDays + 1} days left)'
                                    : 'Lifetime (Never Expires)',
                              ),
                              const SizedBox(height: 16),

                              const Text('Qulop Activation Key String:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF475569)),
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
                                        backgroundColor: const Color(0xFF334155),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.send_rounded, size: 16),
                                      label: const Text('Copy WhatsApp Template', style: TextStyle(fontWeight: FontWeight.bold)),
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

                      // Recent Keys Generated (Vendor Session History)
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
                                const Text('Generated Keys History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                Text('${_recentKeys.length} keys issued', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_recentKeys.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No keys generated in this session yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recentKeys.length.clamp(0, 5),
                                separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFF334155)),
                                itemBuilder: (ctx, idx) {
                                  final item = _recentKeys[idx];
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['client'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                          Text('${item['tier']} • Expires: ${item['expiry']}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                        ],
                                      ),
                                      IconButton(
                                        tooltip: 'Copy Key',
                                        icon: const Icon(Icons.copy, size: 15, color: Color(0xFF818CF8)),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: item['key']));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Key copied!')),
                                          );
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
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
        ],
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
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : const Color(0xFF64748B)),
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
