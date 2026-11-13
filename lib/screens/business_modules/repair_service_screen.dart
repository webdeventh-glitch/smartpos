import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';

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
    } catch (e, st) {
      AppLogger.error('RepairService', 'Failed loading repair jobs', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
        await AppErrorHandler.showErrorDialog(
          context,
          title: 'Load Failed',
          message: 'Could not load repair job sheets.',
          error: e,
          stackTrace: st,
          tag: 'RepairService',
        );
      }
    }
  }

  Future<void> _updateJobStatus(
      Map<String, dynamic> job, String newStatus) async {
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
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Customer Name & Mobile No.*',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deviceCtrl,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText:
                          'Device Model / Item (e.g. iPhone 15, HP Laptop)*',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imeiCtrl,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'IMEI / Serial Number / Barcode',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: faultCtrl,
                    maxLines: 2,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Reported Fault / Problem Description*',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Estimated Cost',
                            labelStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: advCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Advance Received',
                            labelStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
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
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  foregroundColor: Colors.black),
              onPressed: () async {
                if (custCtrl.text.trim().isNotEmpty &&
                    deviceCtrl.text.trim().isNotEmpty) {
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
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.build_circle_rounded,
                color: Color(0xFFEAB308), size: 22),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  foregroundColor: Colors.black),
              onPressed: _showAddJobSheetModal,
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('New Job Sheet',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                      for (final filter in [
                        'All',
                        'Diagnosing',
                        'Waiting for Parts',
                        'Ready for Delivery',
                        'Delivered'
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _statusFilter == filter,
                            selectedColor: const Color(0xFFEAB308),
                            labelStyle: TextStyle(
                              color: _statusFilter == filter
                                  ? Colors.black
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
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
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
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
                        final status =
                            job['status']?.toString() ?? 'Diagnosing';
                        Color statusColor = const Color(0xFF3B82F6);
                        if (status == 'Diagnosing')
                          statusColor = const Color(0xFFEAB308);
                        if (status == 'Waiting for Parts')
                          statusColor = const Color(0xFFF97316);
                        if (status == 'Ready for Delivery')
                          statusColor = const Color(0xFF10B981);
                        if (status == 'Delivered')
                          statusColor = const Color(0xFF64748B);

                        final estCostVal = (job['est_cost'] is num)
                            ? (job['est_cost'] as num).toDouble()
                            : (job['estCost'] is num)
                                ? (job['estCost'] as num).toDouble()
                                : 0.0;
                        final advanceVal = (job['advance'] is num)
                            ? (job['advance'] as num).toDouble()
                            : 0.0;
                        final jobNoVal = job['job_no']?.toString() ??
                            job['jobNo']?.toString() ??
                            'JOB';

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.2 : 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAB308)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          jobNoVal,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFFCA8A04),
                                              fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        job['device']?.toString() ?? '',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customer: ${job['customer'] ?? ''} • IMEI/Serial: ${job['imei'] ?? 'N/A'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Fault: ${job['fault'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF334155)),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Estimate: $currency${estCostVal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Advance: $currency${advanceVal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: Color(0xFF10B981)),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Assigned: ${job['technician'] ?? 'General'}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact),
                                        onPressed: () {
                                          final html = _buildJobSheetHtml(
                                              job,
                                              jobNoVal,
                                              estCostVal,
                                              advanceVal,
                                              status,
                                              currency);
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                UniversalPrintPreviewDialog(
                                              title:
                                                  'Repair Job Slip • $jobNoVal',
                                              htmlContent: html,
                                              defaultPaperSize: 'a4',
                                              settings: widget.settings,
                                              pdfGenerator: (_) =>
                                                  PdfExportService
                                                      .generateReportPdf(
                                                title:
                                                    'Repair Job Slip ($jobNoVal)',
                                                subtitle:
                                                    '${job['customer'] ?? ''} • ${job['device'] ?? ''}',
                                                headers: const [
                                                  'Field',
                                                  'Value'
                                                ],
                                                rows: [
                                                  ['Job #', jobNoVal],
                                                  [
                                                    'Device',
                                                    '${job['device'] ?? ''}'
                                                  ],
                                                  [
                                                    'Customer',
                                                    '${job['customer'] ?? ''}'
                                                  ],
                                                  [
                                                    'IMEI/Serial',
                                                    '${job['imei'] ?? 'N/A'}'
                                                  ],
                                                  [
                                                    'Fault',
                                                    '${job['fault'] ?? ''}'
                                                  ],
                                                  [
                                                    'Technician',
                                                    '${job['technician'] ?? 'General'}'
                                                  ],
                                                  [
                                                    'Estimate',
                                                    '$currency${estCostVal.toStringAsFixed(2)}'
                                                  ],
                                                  [
                                                    'Advance Paid',
                                                    '$currency${advanceVal.toStringAsFixed(2)}'
                                                  ],
                                                  [
                                                    'Balance Due',
                                                    '$currency${(estCostVal - advanceVal).clamp(0, double.infinity).toStringAsFixed(2)}'
                                                  ],
                                                ],
                                                settings: widget.settings,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.print, size: 14),
                                        label: const Text('Print Slip',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      if (status != 'Delivered')
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () => _updateJobStatus(
                                              job, 'Delivered'),
                                          child: const Text('Mark Done',
                                              style: TextStyle(fontSize: 11)),
                                        )
                                      else
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () => _updateJobStatus(
                                              job, 'Diagnosing'),
                                          child: const Text('Re-open',
                                              style: TextStyle(fontSize: 11)),
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

  String _buildJobSheetHtml(
    Map<String, dynamic> job,
    String jobNoVal,
    double estCostVal,
    double advanceVal,
    String status,
    String currency,
  ) {
    final biz = widget.settings.businessName.isNotEmpty
        ? widget.settings.businessName
        : 'SmartPOS Service Center';
    final phone = widget.settings.phone.isNotEmpty ? widget.settings.phone : '';
    final address =
        widget.settings.address.isNotEmpty ? widget.settings.address : '';
    final dateStr = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    final balanceDue = (estCostVal - advanceVal).clamp(0, double.infinity);

    return '''
    <div style="font-family: Arial, sans-serif; color: #1e293b; max-width: 800px; margin: 0 auto; line-height: 1.5;">
      <div style="text-align: center; border-bottom: 2px solid #0f172a; padding-bottom: 12px; margin-bottom: 16px;">
        <h1 style="margin: 0 0 4px 0; font-size: 22px; color: #0f172a; text-transform: uppercase;">$biz</h1>
        <div style="font-size: 12px; color: #64748b;">$address ${phone.isNotEmpty ? '• Tel: $phone' : ''}</div>
        <div style="display: inline-block; margin-top: 8px; background: #0f172a; color: white; padding: 4px 16px; border-radius: 4px; font-weight: bold; font-size: 14px; letter-spacing: 1px;">
          REPAIR & SERVICE INTAKE VOUCHER (جاب شیٹ)
        </div>
      </div>

      <table style="width: 100%; margin-bottom: 16px; font-size: 13px; border-collapse: collapse;">
        <tr>
          <td style="width: 50%; padding: 4px 0;"><strong>Job Ticket #:</strong> <span style="font-size: 15px; color: #4f46e5; font-weight: bold;">$jobNoVal</span></td>
          <td style="width: 50%; padding: 4px 0; text-align: right;"><strong>Intake Date:</strong> $dateStr</td>
        </tr>
        <tr>
          <td style="padding: 4px 0;"><strong>Customer Name:</strong> ${job['customer'] ?? 'Walk-in'}</td>
          <td style="padding: 4px 0; text-align: right;"><strong>Status:</strong> <span style="background: #e0f2fe; color: #0369a1; padding: 2px 8px; border-radius: 3px; font-weight: bold;">$status</span></td>
        </tr>
      </table>

      <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px; margin-bottom: 16px;">
        <div style="font-weight: bold; font-size: 13px; color: #334155; margin-bottom: 8px; text-transform: uppercase; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;">Device & Hardware Specifications</div>
        <table style="width: 100%; font-size: 12px; border-collapse: collapse;">
          <tr>
            <td style="width: 25%; padding: 4px 0; color: #64748b;">Device Model:</td>
            <td style="width: 25%; padding: 4px 0; font-weight: bold;">${job['device'] ?? 'Unknown'}</td>
            <td style="width: 25%; padding: 4px 0; color: #64748b;">IMEI / Serial #:</td>
            <td style="width: 25%; padding: 4px 0; font-weight: bold; font-family: monospace;">${job['imei'] ?? 'N/A'}</td>
          </tr>
          <tr>
            <td style="padding: 4px 0; color: #64748b;">Assigned Tech:</td>
            <td style="padding: 4px 0; font-weight: bold;">${job['technician'] ?? 'General Lab'}</td>
            <td style="padding: 4px 0; color: #64748b;">Lock / Passcode:</td>
            <td style="padding: 4px 0; font-weight: bold;">Protected / Pattern</td>
          </tr>
        </table>
      </div>

      <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px; margin-bottom: 16px;">
        <div style="font-weight: bold; font-size: 13px; color: #334155; margin-bottom: 8px; text-transform: uppercase; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;">Intake Inspection & Condition Checklist</div>
        <div style="font-size: 12px; color: #334155; line-height: 1.8;">
          <strong>Accessories Received:</strong> [ &#10003; ] Device Body &nbsp;&nbsp; [ &nbsp; ] Charger / Adapter &nbsp;&nbsp; [ &nbsp; ] SIM / Memory Card &nbsp;&nbsp; [ &nbsp; ] Box / Bag<br>
          <strong>Physical Condition:</strong> [ &#10003; ] Normal Scratch & Wear &nbsp;&nbsp; [ &nbsp; ] Screen Crack &nbsp;&nbsp; [ &nbsp; ] Dent / Bent Frame &nbsp;&nbsp; [ &nbsp; ] Water / Liquid Signs
        </div>
      </div>

      <div style="border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px; margin-bottom: 16px;">
        <div style="font-weight: bold; font-size: 13px; color: #334155; margin-bottom: 4px;">Customer Reported Defect / Problems:</div>
        <div style="font-size: 13px; color: #0f172a; padding: 6px 0; min-height: 28px;">${job['fault'] ?? 'General hardware servicing'}</div>
      </div>

      <table style="width: 100%; border: 1px solid #cbd5e1; border-collapse: collapse; margin-bottom: 16px; font-size: 13px;">
        <tr style="background: #0f172a; color: white;">
          <th style="padding: 8px 12px; text-align: left;">Estimated Service Cost</th>
          <th style="padding: 8px 12px; text-align: right;">Advance Deposit Paid</th>
          <th style="padding: 8px 12px; text-align: right;">Remaining Due Balance</th>
        </tr>
        <tr>
          <td style="padding: 8px 12px; border-top: 1px solid #cbd5e1; font-weight: bold; font-size: 14px;">$currency${estCostVal.toStringAsFixed(2)}</td>
          <td style="padding: 8px 12px; border-top: 1px solid #cbd5e1; text-align: right; color: #10b981; font-weight: bold; font-size: 14px;">$currency${advanceVal.toStringAsFixed(2)}</td>
          <td style="padding: 8px 12px; border-top: 1px solid #cbd5e1; text-align: right; color: #ef4444; font-weight: bold; font-size: 14px;">$currency${balanceDue.toStringAsFixed(2)}</td>
        </tr>
      </table>

      <div style="border: 1px solid #e2e8f0; border-radius: 6px; padding: 10px; font-size: 10px; color: #64748b; line-height: 1.4; margin-bottom: 24px;">
        <strong>Terms & Conditions of Service (قوانین و شرائط):</strong><br>
        1. <strong>Data Backup:</strong> The customer is solely responsible for creating a complete backup of all personal data, photos, and files prior to repair. The service center accepts no liability for data loss or operating system reinstalls.<br>
        2. <strong>Diagnostic Changes:</strong> Repair cost estimates and turnaround times are provisional. If additional concealed defects (such as board corrosion or liquid damage) are found during internal inspection, a revised estimate will be provided before proceeding.<br>
        3. <strong>Unclaimed Devices:</strong> Devices not collected within 30 days of completion notification will incur daily storage charges and may be disposed of to recover service and spare parts costs.<br>
        4. <strong>Delivery:</strong> The original intake voucher or CNIC verification is mandatory for collecting the device.
      </div>

      <table style="width: 100%; margin-top: 30px; font-size: 12px;">
        <tr>
          <td style="width: 50%; text-align: center; padding-top: 25px; border-top: 1px dashed #94a3b8;">
            <strong>Customer Signature</strong><br>
            <span style="font-size: 10px; color: #64748b;">(I agree to the terms & reported faults)</span>
          </td>
          <td style="width: 10%;"></td>
          <td style="width: 40%; text-align: center; padding-top: 25px; border-top: 1px dashed #94a3b8;">
            <strong>Technician / Authorized Stamp</strong><br>
            <span style="font-size: 10px; color: #64748b;">${job['technician'] ?? 'Service Center Desk'}</span>
          </td>
        </tr>
      </table>
    </div>
    ''';
  }
}
