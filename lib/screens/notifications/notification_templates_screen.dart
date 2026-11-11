import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/messaging_service.dart';

class NotificationTemplatesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const NotificationTemplatesScreen({super.key, required this.settings});

  @override
  State<NotificationTemplatesScreen> createState() => _NotificationTemplatesScreenState();
}

class _NotificationTemplatesScreenState extends State<NotificationTemplatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  List<SmsGateway> _gateways = [];
  List<MessageLog> _logs = [];
  List<Contact> _customers = [];

  // Bulk SMS State
  String _targetAudience = 'all'; // 'all', 'dues', 'vip'
  final TextEditingController _bulkMsgCtrl = TextEditingController(
    text: 'Dear {customer_name}, thank you for choosing {business_name}! Enjoy special discounts this week on our latest arrivals. Contact: {business_name}',
  );
  bool _isSendingBulk = false;
  int _bulkSentCount = 0;
  int _bulkTotalCount = 0;

  // WhatsApp Quick Send State
  final TextEditingController _waPhoneCtrl = TextEditingController();
  final TextEditingController _waNameCtrl = TextEditingController();
  final TextEditingController _waMsgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bulkMsgCtrl.dispose();
    _waPhoneCtrl.dispose();
    _waNameCtrl.dispose();
    _waMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseService.initialize();
      final gws = await db.getSmsGateways();
      final lgs = await db.getMessageLogs(limit: 100);
      final custs = await db.getCustomers();

      if (mounted) {
        setState(() {
          _gateways = gws;
          _logs = lgs;
          _customers = custs;
          _loading = false;
        });
      }
    } catch (e, st) {
      AppLogger.error('NotificationTemplates', 'Failed loading notification templates data', e, st);
      if (mounted) {
        setState(() => _loading = false);
        await AppErrorHandler.showErrorDialog(
          context,
          title: 'Load Failed',
          message: 'Could not load SMS gateways and notification logs.',
          error: e,
          stackTrace: st,
          tag: 'NotificationTemplates',
        );
      }
    }
  }

  List<Contact> get _filteredBulkRecipients {
    switch (_targetAudience) {
      case 'dues':
        return _customers.where((c) => c.balance > 0).toList();
      case 'vip':
        return _customers.where((c) => c.loyaltyPoints > 50 || c.balance < 0).toList();
      default:
        return _customers;
    }
  }

  // =========================================================================
  // 1. GATEWAY DIALOGS
  // =========================================================================
  void _showAddGatewayDialog({SmsGateway? gatewayToEdit}) {
    final nameCtrl = TextEditingController(text: gatewayToEdit?.name ?? 'Zong Branded SMS');
    final urlCtrl = TextEditingController(
      text: gatewayToEdit?.apiUrl ?? 'https://api.domain.com/sms/send?to={to}&message={message}&mask={mask}&key={key}',
    );
    final keyCtrl = TextEditingController(text: gatewayToEdit?.apiKey ?? '');
    final secretCtrl = TextEditingController(text: gatewayToEdit?.apiSecret ?? '');
    final senderCtrl = TextEditingController(text: gatewayToEdit?.senderId ?? widget.settings.businessName.replaceAll(RegExp(r'\s+'), '').toUpperCase().padRight(8, 'X').substring(0, 8));
    String provider = gatewayToEdit?.provider ?? 'zong';
    String method = gatewayToEdit?.httpMethod ?? 'GET';
    bool isActive = gatewayToEdit?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.settings_input_antenna_rounded, color: Color(0xFF0038B8)),
              const SizedBox(width: 10),
              Text(
                gatewayToEdit == null ? 'Add SMS / Messaging Gateway' : 'Edit Gateway: ${gatewayToEdit.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: provider,
                          decoration: const InputDecoration(labelText: 'Provider / Network Preset', isDense: true, border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'zong', child: Text('Zong Corporate Branded SMS')),
                            DropdownMenuItem(value: 'ufone', child: Text('Ufone Corporate SMS')),
                            DropdownMenuItem(value: 'jazz', child: Text('Jazz / Mobilink Business')),
                            DropdownMenuItem(value: 'telenor', child: Text('Telenor Corporate SMS')),
                            DropdownMenuItem(value: 'sendpk', child: Text('SendPK / Pakistan Aggregator')),
                            DropdownMenuItem(value: 'generic_http', child: Text('Generic Custom REST API')),
                            DropdownMenuItem(value: 'twilio', child: Text('Twilio International API')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                provider = val;
                                if (val == 'sendpk') {
                                  urlCtrl.text = 'https://sendpk.com/api/sms.php?username={key}&password={secret}&sender={mask}&mobile={to}&message={message}';
                                  method = 'GET';
                                } else if (val == 'twilio') {
                                  urlCtrl.text = 'https://api.twilio.com/2010-04-01/Accounts/{key}/Messages.json';
                                  method = 'POST';
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: method,
                          decoration: const InputDecoration(labelText: 'HTTP Method', isDense: true, border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'GET', child: Text('GET (Query URL)')),
                            DropdownMenuItem(value: 'POST', child: Text('POST (JSON Body)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => method = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Gateway Label Name *', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Endpoint URL (supports {to}, {message}, {mask}, {key}) *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: keyCtrl,
                          decoration: const InputDecoration(labelText: 'API Key / Username', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: secretCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'API Secret / Password', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: senderCtrl,
                          decoration: const InputDecoration(labelText: 'Branded Mask / Sender ID (e.g. SMARTPOS)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text('Active:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Switch(
                            value: isActive,
                            activeColor: const Color(0xFF0038B8),
                            onChanged: (v) => setDlgState(() => isActive = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final url = urlCtrl.text.trim();
                if (name.isEmpty || url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter gateway name and API URL!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final db = await DatabaseService.initialize();
                if (gatewayToEdit == null) {
                  final gw = SmsGateway(
                    name: name,
                    provider: provider,
                    apiUrl: url,
                    apiKey: keyCtrl.text.trim(),
                    apiSecret: secretCtrl.text.trim(),
                    senderId: senderCtrl.text.trim(),
                    httpMethod: method,
                    isActive: isActive,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  await db.addSmsGateway(gw);
                } else {
                  final updated = gatewayToEdit.copyWith(
                    name: name,
                    provider: provider,
                    apiUrl: url,
                    apiKey: keyCtrl.text.trim(),
                    apiSecret: secretCtrl.text.trim(),
                    senderId: senderCtrl.text.trim(),
                    httpMethod: method,
                    isActive: isActive,
                  );
                  await db.updateSmsGateway(updated);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Save Gateway'),
            ),
          ],
        ),
      ),
    );
  }

  void _testGateway(SmsGateway gw) {
    final phoneCtrl = TextEditingController(text: '03001234567');
    bool testing = false;
    String resultMsg = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Test SMS Gateway: ${gw.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Recipient Phone Number (e.g. 03001234567)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              if (testing) const LinearProgressIndicator(),
              if (resultMsg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(resultMsg, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
              onPressed: testing
                  ? null
                  : () async {
                      setDlgState(() {
                        testing = true;
                        resultMsg = 'Dispatching test SMS...';
                      });

                      final ok = await MessagingService.sendSms(
                        to: phoneCtrl.text.trim(),
                        message: 'Smart POS Test SMS: Gateway connection verified successfully!',
                        recipientName: 'Test Recipient',
                        gatewayOverride: gw,
                      );

                      setDlgState(() {
                        testing = false;
                        resultMsg = ok
                            ? 'SUCCESS: Test SMS dispatched! Check message logs.'
                            : 'FAILED: Gateway returned error or timeout. Check logs for details.';
                      });
                      _loadData();
                    },
              child: const Text('Send Test SMS'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. BULK SMS CAMPAIGN DISPATCHER
  // =========================================================================
  Future<void> _startBulkCampaign() async {
    final recipients = _filteredBulkRecipients;
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers found in selected target audience!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk SMS Campaign'),
        content: Text(
          'Are you sure you want to broadcast this message to ${recipients.length} customers?\n\n'
          'Estimated SMS units: ${recipients.length}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Launch Campaign'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSendingBulk = true;
      _bulkSentCount = 0;
      _bulkTotalCount = recipients.length;
    });

    final List<Map<String, dynamic>> contactsList = recipients
        .map((c) => <String, dynamic>{
              'name': c.name,
              'phone': c.phone,
              'due': c.balance,
            })
        .toList();

    final result = await MessagingService.sendBulkSms(
      contacts: contactsList,
      messageTemplate: _bulkMsgCtrl.text,
      businessName: widget.settings.businessName,
      onProgress: (sent, total) {
        if (mounted) {
          setState(() {
            _bulkSentCount = sent;
            _bulkTotalCount = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _isSendingBulk = false);
      _loadData();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Campaign Summary'),
          content: Text(
            'Campaign completed!\n\n'
            'Total Contacts: ${result['total']}\n'
            'Successful Sent: ${result['successful']}\n'
            'Failed: ${result['failed']}',
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
    }
  }

  // =========================================================================
  // BUILD METHOD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Column(
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
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF0038B8), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SMS & WhatsApp Messaging Hub',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Bulk Marketing, Pakistani Telco SMS Gateways (Zong/Ufone/Jazz), and WhatsApp Direct Billing',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0038B8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Gateway', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _showAddGatewayDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF0038B8),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0038B8),
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: const Icon(Icons.cell_tower_rounded, size: 18), text: 'SMS Gateways (${_gateways.length})'),
                    Tab(icon: const Icon(Icons.campaign_rounded, size: 18), text: 'Bulk SMS Marketing (${_filteredBulkRecipients.length} Target)'),
                    const Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'WhatsApp Quick Dispatch'),
                    Tab(icon: const Icon(Icons.history_rounded, size: 18), text: 'Outgoing Logs (${_logs.length})'),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGatewaysTab(isDark),
                      _buildBulkTab(isDark),
                      _buildWhatsAppTab(isDark),
                      _buildLogsTab(isDark),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: SMS GATEWAYS
  // =========================================================================
  Widget _buildGatewaysTab(bool isDark) {
    if (_gateways.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_cellular_connected_no_internet_0_bar_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No SMS Gateways configured yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Add your Zong, Ufone, Jazz, or Generic REST SMS API credentials to enable customer billing SMS.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add SMS Gateway'),
              onPressed: () => _showAddGatewayDialog(),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _gateways.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, i) {
        final gw = _gateways[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cell_tower_rounded, color: Color(0xFF0038B8), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(gw.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(gw.provider.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Mask: ${gw.senderId}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('URL: ${gw.apiUrl}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gw.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    gw.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(color: gw.isActive ? const Color(0xFF16A34A) : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Test SMS'),
                  onPressed: () => _testGateway(gw),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Gateway',
                  onPressed: () => _showAddGatewayDialog(gatewayToEdit: gw),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  tooltip: 'Delete Gateway',
                  onPressed: () async {
                    final db = await DatabaseService.initialize();
                    await db.deleteSmsGateway(gw.id!);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 2: BULK SMS MARKETING
  // =========================================================================
  Widget _buildBulkTab(bool isDark) {
    final recipients = _filteredBulkRecipients;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          Row(
            children: [
              const Text('Target Audience:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text('All Customers (${_customers.length})'),
                selected: _targetAudience == 'all',
                onSelected: (s) => setState(() => _targetAudience = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Customers with Due Khata (${_customers.where((c) => c.balance > 0).length})'),
                selected: _targetAudience == 'dues',
                onSelected: (s) => setState(() => _targetAudience = 'dues'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('VIP / High Value'),
                selected: _targetAudience == 'vip',
                onSelected: (s) => setState(() => _targetAudience = 'vip'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Message Composer Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Campaign Message Composer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Insert dynamic personalized tags into your campaign message:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.person, size: 14),
                        label: const Text('{customer_name}'),
                        onPressed: () {
                          _bulkMsgCtrl.text += ' {customer_name}';
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.store, size: 14),
                        label: const Text('{business_name}'),
                        onPressed: () {
                          _bulkMsgCtrl.text += ' {business_name}';
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.payments, size: 14),
                        label: const Text('{due_amount}'),
                        onPressed: () {
                          _bulkMsgCtrl.text += ' {due_amount}';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bulkMsgCtrl,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Type your promotional or recovery announcement...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Characters: ${_bulkMsgCtrl.text.length} (Approx ${((_bulkMsgCtrl.text.length / 160).ceil()).clamp(1, 10)} SMS credit / recipient)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(_isSendingBulk ? 'Sending ($_bulkSentCount/$_bulkTotalCount)...' : 'Dispatch to ${recipients.length} Customers'),
                        onPressed: _isSendingBulk ? null : _startBulkCampaign,
                      ),
                    ],
                  ),
                  if (_isSendingBulk) ...[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: _bulkTotalCount > 0 ? _bulkSentCount / _bulkTotalCount : null),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: WHATSAPP QUICK DISPATCH
  // =========================================================================
  Widget _buildWhatsAppTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 24),
                      SizedBox(width: 10),
                      Text('Direct WhatsApp Dispatcher (Zero API Cost)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Opens WhatsApp Web or WhatsApp Desktop on your PC and sends bills, invoice links, or recovery notices without paid API keys.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _waPhoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'WhatsApp Mobile Number (e.g. 03001234567) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_iphone_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _waNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quick Template:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Store Welcome & Greeting'),
                        onPressed: () {
                          _waMsgCtrl.text = 'Assalam-o-Alaikum ${_waNameCtrl.text.isNotEmpty ? _waNameCtrl.text : "Valued Customer"}!\n\nThank you for choosing ${widget.settings.businessName}. We are at your service for high quality products and best wholesale prices.\nContact us: ${widget.settings.phone}';
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Payment Due Reminder'),
                        onPressed: () {
                          _waMsgCtrl.text = 'Assalam-o-Alaikum ${_waNameCtrl.text.isNotEmpty ? _waNameCtrl.text : "Muhtaram Customer"}!\n\nThis is a gentle payment reminder from ${widget.settings.businessName}. Kindly settle your pending ledger balance at your earliest convenience.\nThank you! ${widget.settings.phone}';
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _waMsgCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Message Body *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Launch WhatsApp & Send Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final phone = _waPhoneCtrl.text.trim();
                        final text = _waMsgCtrl.text.trim();
                        if (phone.isEmpty || text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter phone number and message body!'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        final ok = await MessagingService.sendWhatsAppDirect(
                          to: phone,
                          message: text,
                          recipientName: _waNameCtrl.text.trim().isNotEmpty ? _waNameCtrl.text.trim() : 'Customer',
                        );

                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('WhatsApp launched!'), backgroundColor: Color(0xFF25D366)),
                          );
                          _loadData();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: DISPATCH LOGS
  // =========================================================================
  Widget _buildLogsTab(bool isDark) {
    if (_logs.isEmpty) {
      return const Center(child: Text('No outgoing messages recorded yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final log = _logs[i];
        final isSuccess = log.status == 'sent' || log.status == 'delivered';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: Icon(
              log.channel == 'whatsapp' ? Icons.chat_rounded : Icons.sms_rounded,
              color: log.channel == 'whatsapp' ? const Color(0xFF25D366) : const Color(0xFF0038B8),
            ),
            title: Text('${log.recipientName} (${log.phoneNumber})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${log.messageBody}\n${log.errorDetails.isNotEmpty ? "[Details: ${log.errorDetails}]" : ""}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.status.toUpperCase(),
                    style: TextStyle(
                      color: isSuccess ? const Color(0xFF16A34A) : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(log.createdAt.length >= 16 ? log.createdAt.substring(0, 16) : log.createdAt, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
