import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

/// Step 6.4: Commission Agents Directory & Live Sales Commission Report.
class CommissionAgentsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const CommissionAgentsScreen({super.key, required this.settings});

  @override
  State<CommissionAgentsScreen> createState() => _CommissionAgentsScreenState();
}

class _CommissionAgentsScreenState extends State<CommissionAgentsScreen> {
  bool _loading = true;
  List<CommissionAgent> _agents = [];
  List<Map<String, dynamic>> _reportRows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final agents = await db.getCommissionAgents();
    final report = await db.getCommissionReport();
    if (!mounted) return;
    setState(() {
      _agents = agents;
      _reportRows = report;
      _loading = false;
    });
  }

  Future<void> _showAgentDialog([CommissionAgent? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final pctCtrl = TextEditingController(
      text: (existing?.commissionPercent ?? 2.5).toStringAsFixed(2),
    );
    bool isActive = existing?.isActive ?? true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Add Commission Agent' : 'Edit Commission Agent',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Agent Name *', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: pctCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Commission % *', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Territory / Address', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Agent', style: TextStyle(fontSize: 13)),
                  value: isActive,
                  onChanged: (v) => setDlg(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setDlg(() => saving = true);
                      final pct = double.tryParse(pctCtrl.text.trim()) ?? 0.0;
                      final db = await DatabaseService.initialize();
                      final agent = CommissionAgent(
                        id: existing?.id,
                        name: name,
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        commissionPercent: pct,
                        isActive: isActive,
                        createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
                      );
                      if (existing == null) {
                        await db.addCommissionAgent(agent);
                      } else {
                        await db.updateCommissionAgent(agent);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
              child: Text(saving ? 'Saving...' : 'Save Agent'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final totalEarned = _reportRows.fold<double>(
      0.0,
      (s, r) => s + ((r['totalCommission'] as double?) ?? 0.0),
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, color: Color(0xFF4F46E5), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commission Agents & Payouts',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text('Assign sales agents at POS checkout and track % commission earnings per invoice',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                  onPressed: () => _showAgentDialog(),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Agent'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _chip('Total Agents', '${_agents.length}', const Color(0xFF4F46E5), cardBg, borderColor),
                const SizedBox(width: 12),
                _chip('Total Commission Earned', '$cur${totalEarned.toStringAsFixed(2)}', const Color(0xFF10B981), cardBg, borderColor),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _reportRows.isEmpty
                        ? const Center(child: Text('No commission agents added yet.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: _reportRows.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                            itemBuilder: (_, idx) {
                              final r = _reportRows[idx];
                              final agent = _agents.firstWhere(
                                (a) => a.id == r['agentId'],
                                orElse: () => CommissionAgent(
                                  id: r['agentId'] as int?,
                                  name: r['agentName'] as String? ?? '',
                                  commissionPercent: (r['commissionPercent'] as double?) ?? 0.0,
                                  createdAt: '',
                                ),
                              );
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.14),
                                  child: const Icon(Icons.person_outline, color: Color(0xFF4F46E5), size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Text(agent.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('${agent.commissionPercent.toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Invoices: ${r['saleCount']} • Sales: $cur${((r['totalSales'] as double?) ?? 0.0).toStringAsFixed(2)} • Earned: $cur${((r['totalCommission'] as double?) ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit Agent',
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showAgentDialog(agent),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Agent',
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: agent.id == null
                                          ? null
                                          : () async {
                                              final db = await DatabaseService.initialize();
                                              await db.deleteCommissionAgent(agent.id!);
                                              await _load();
                                            },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String val, Color col, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
        ],
      ),
    );
  }
}

