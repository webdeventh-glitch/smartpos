import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

/// Step 6.3: Cheque Management Screen (Due dates, Pending / Cleared / Bounced / Overdue workflow).
class ChequeManagementScreen extends StatefulWidget {
  final BusinessSettings settings;

  const ChequeManagementScreen({super.key, required this.settings});

  @override
  State<ChequeManagementScreen> createState() => _ChequeManagementScreenState();
}

class _ChequeManagementScreenState extends State<ChequeManagementScreen> {
  bool _loading = true;
  String _statusFilter = 'all'; // 'all', 'pending', 'overdue', 'cleared', 'bounced'
  String _search = '';
  List<PaymentTransaction> _cheques = [];
  Map<String, num> _summary = {};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final rows = await db.getCheques(status: _statusFilter, search: _search);
    final summary = await db.getChequeSummary();
    if (!mounted) return;
    setState(() {
      _cheques = rows;
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _changeStatus(PaymentTransaction txn, String newStatus) async {
    if (txn.id == null) return;
    final db = await DatabaseService.initialize();
    await db.updateChequeStatus(transactionId: txn.id!, newStatus: newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cheque ${txn.chequeNumber.isNotEmpty ? "#${txn.chequeNumber}" : txn.refNo} marked as ${newStatus.toUpperCase()}'),
          backgroundColor: newStatus == 'cleared' ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    }
    await _load();
  }

  Color _statusColor(PaymentTransaction t) {
    if (t.isOverdueCheque) return Colors.red;
    switch (t.chequeStatus) {
      case 'cleared':
        return const Color(0xFF10B981);
      case 'bounced':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0038B8), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cheque Management',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text('Track customer & supplier cheques, due dates, overdue alerts, and bank clearance status',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Cheques',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _metricCard('Pending Cheques', '${_summary['pendingCount'] ?? 0}', '$cur${(_summary['pendingAmount'] ?? 0.0).toDouble().toStringAsFixed(2)}', const Color(0xFFF59E0B), cardBg, borderColor),
                const SizedBox(width: 12),
                _metricCard('Overdue Cheques', '${_summary['overdueCount'] ?? 0}', '$cur${(_summary['overdueAmount'] ?? 0.0).toDouble().toStringAsFixed(2)}', Colors.red, cardBg, borderColor),
                const SizedBox(width: 12),
                _metricCard('Cleared Cheques', '${_summary['clearedCount'] ?? 0}', '$cur${(_summary['clearedAmount'] ?? 0.0).toDouble().toStringAsFixed(2)}', const Color(0xFF10B981), cardBg, borderColor),
                const SizedBox(width: 12),
                _metricCard('Bounced Cheques', '${_summary['bouncedCount'] ?? 0}', '$cur${(_summary['bouncedAmount'] ?? 0.0).toDouble().toStringAsFixed(2)}', Colors.deepOrange, cardBg, borderColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final f in const [
                  ('all', 'All'),
                  ('pending', 'Pending'),
                  ('overdue', 'Overdue'),
                  ('cleared', 'Cleared'),
                  ('bounced', 'Bounced'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _statusFilter == f.$1,
                      onSelected: (_) {
                        setState(() => _statusFilter = f.$1);
                        _load();
                      },
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search cheque #, bank, contact...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _search = v;
                      _load();
                    },
                  ),
                ),
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
                    : _cheques.isEmpty
                        ? const Center(child: Text('No cheque records found.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: _cheques.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                            itemBuilder: (_, idx) {
                              final c = _cheques[idx];
                              final col = _statusColor(c);
                              final statusText = c.isOverdueCheque ? 'OVERDUE' : c.chequeStatus.toUpperCase();
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: col.withValues(alpha: 0.14),
                                  child: Icon(Icons.article_outlined, color: col, size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      c.chequeNumber.isNotEmpty ? 'Cheque #${c.chequeNumber}' : 'Ref: ${c.refNo}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: col.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
                                    ),
                                    if (c.bankName.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text('• ${c.bankName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${c.contactName} (${c.transactionType.replaceAll('_', ' ')}) • Due: ${c.chequeDueDate.isNotEmpty ? c.chequeDueDate : "Not set"}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$cur${c.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                    const SizedBox(width: 12),
                                    if (c.chequeStatus != 'cleared')
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                                        onPressed: () => _changeStatus(c, 'cleared'),
                                        child: const Text('Clear'),
                                      ),
                                    if (c.chequeStatus == 'pending') ...[
                                      const SizedBox(width: 6),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        onPressed: () => _changeStatus(c, 'bounced'),
                                        child: const Text('Bounced'),
                                      ),
                                    ],
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

  Widget _metricCard(String title, String count, String amount, Color color, Color bg, Color border) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                Text('$count chq', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
