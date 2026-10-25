import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class RepairServiceScreen extends StatefulWidget {
  final BusinessSettings settings;

  const RepairServiceScreen({super.key, required this.settings});

  @override
  State<RepairServiceScreen> createState() => _RepairServiceScreenState();
}

class _RepairServiceScreenState extends State<RepairServiceScreen> {
  String _statusFilter = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobSheets = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.initialize();
      final rows = await db.getRepairJobs(status: _statusFilter);
      setState(() {
        _jobSheets = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateJobStatus(Map<String, dynamic> job, String newStatus) async {
    final id = job['id'] as int?;
    if (id == null) return;
    final db = await DatabaseService.initialize();
    await db.updateRepairJob(id, {'status': newStatus});
    _loadJobs();
  }

  void _showAddJobSheetModal() {
    final custCtrl = TextEditingController();
    final deviceCtrl = TextEditingController();
    final imeiCtrl = TextEditingController();
    final faultCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final advCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'New Repair Job Sheet',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: custCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Customer Name & Mobile No.*',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deviceCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Device Model / Item (e.g. iPhone 15, HP Laptop)*',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imeiCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'IMEI / Serial Number / Barcode',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: faultCtrl,
                    maxLines: 2,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Reported Fault / Problem Description*',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Estimated Cost',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: advCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Advance Received',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEAB308), foregroundColor: Colors.black),
              onPressed: () async {
                if (custCtrl.text.trim().isNotEmpty && deviceCtrl.text.trim().isNotEmpty) {
                  final db = await DatabaseService.initialize();
                  await db.addRepairJob({
                    'job_no': 'JOB-${9021 + _jobSheets.length}',
                    'customer': custCtrl.text.trim(),
                    'device': deviceCtrl.text.trim(),
                    'imei': imeiCtrl.text.trim(),
                    'fault': faultCtrl.text.trim(),
                    'technician': 'Senior Technician',
                    'est_cost': double.tryParse(costCtrl.text.trim()) ?? 0.0,
                    'advance': double.tryParse(advCtrl.text.trim()) ?? 0.0,
                    'status': 'Diagnosing',
                    'date': DateTime.now().toString().substring(0, 10),
                  });
                  if (mounted) Navigator.pop(ctx);
                  _loadJobs();
                }
              },
              child: const Text('Create Job Sheet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.build_circle_rounded, color: Color(0xFFEAB308), size: 22),
            const SizedBox(width: 10),
            Text(
              'Service & Repair Job Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload SQLite Jobs',
            onPressed: _loadJobs,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEAB308), foregroundColor: Colors.black),
              onPressed: _showAddJobSheetModal,
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('New Job Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips
                  Row(
                    children: [
                      for (final filter in ['All', 'Diagnosing', 'Waiting for Parts', 'Ready for Delivery', 'Delivered'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _statusFilter == filter,
                            selectedColor: const Color(0xFFEAB308),
                            labelStyle: TextStyle(
                              color: _statusFilter == filter ? Colors.black : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _statusFilter = filter);
                                _loadJobs();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Job Sheets List
                  if (_jobSheets.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No repair jobs match filter: $_statusFilter',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _jobSheets.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final job = _jobSheets[idx];
                        final status = job['status']?.toString() ?? 'Diagnosing';
                        Color statusColor = const Color(0xFF3B82F6);
                        if (status == 'Diagnosing') statusColor = const Color(0xFFEAB308);
                        if (status == 'Waiting for Parts') statusColor = const Color(0xFFF97316);
                        if (status == 'Ready for Delivery') statusColor = const Color(0xFF10B981);
                        if (status == 'Delivered') statusColor = const Color(0xFF64748B);

                        final estCostVal = (job['est_cost'] is num)
                            ? (job['est_cost'] as num).toDouble()
                            : (job['estCost'] is num)
                                ? (job['estCost'] as num).toDouble()
                                : 0.0;
                        final advanceVal = (job['advance'] is num) ? (job['advance'] as num).toDouble() : 0.0;
                        final jobNoVal = job['job_no']?.toString() ?? job['jobNo']?.toString() ?? 'JOB';

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          jobNoVal,
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFCA8A04), fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        job['device']?.toString() ?? '',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customer: ${job['customer'] ?? ''} • IMEI/Serial: ${job['imei'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Fault: ${job['fault'] ?? ''}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Estimate: $currency${estCostVal.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Advance: $currency${advanceVal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF10B981)),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Assigned: ${job['technician'] ?? 'General'}',
                                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Delivery / Job slip printed for $jobNoVal')),
                                          );
                                        },
                                        icon: const Icon(Icons.print, size: 14),
                                        label: const Text('Print Slip', style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      if (status != 'Delivered')
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: () => _updateJobStatus(job, 'Delivered'),
                                          child: const Text('Mark Done', style: TextStyle(fontSize: 11)),
                                        )
                                      else
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: () => _updateJobStatus(job, 'Diagnosing'),
                                          child: const Text('Re-open', style: TextStyle(fontSize: 11)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
