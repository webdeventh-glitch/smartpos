import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/messaging_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/searchable_select_dialog.dart';
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
          title: PosLocalization.tr('Load Failed', settings: widget.settings),
          message: PosLocalization.tr('Could not load repair job sheets.',
              settings: widget.settings),
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
    final lockCtrl = TextEditingController();

    bool powerOn = true;
    bool screenOk = true;
    bool scratches = false;
    bool cameraOk = true;
    bool audioOk = true;
    bool simRemoved = true;
    bool liquidDamage = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(
                PosLocalization.tr('New Repair Job Sheet',
                    settings: widget.settings),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: custCtrl,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: PosLocalization.tr(
                              'Customer Name & Mobile No.*',
                              settings: widget.settings),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: PosLocalization.tr(
                              'Device Model / Item (e.g. iPhone 15, HP Laptop)*',
                              settings: widget.settings),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: PosLocalization.tr(
                              'IMEI / Serial Number / Barcode',
                              settings: widget.settings),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: PosLocalization.tr(
                              'Reported Fault / Problem Description*',
                              settings: widget.settings),
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
                                labelText: PosLocalization.tr('Estimated Cost',
                                    settings: widget.settings),
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
                                labelText: PosLocalization.tr(
                                    'Advance Received',
                                    settings: widget.settings),
                                labelStyle: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 6),
                      Text(
                          PosLocalization.tr('Device Physical Intake Checklist',
                              settings: widget.settings),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: Text(
                                PosLocalization.tr('Power ON / Booting',
                                    settings: widget.settings),
                                style: const TextStyle(fontSize: 10.5)),
                            selected: powerOn,
                            onSelected: (v) => setModalState(() => powerOn = v),
                          ),
                          FilterChip(
                            label: Text(
                                PosLocalization.tr('Display / Touch Intact',
                                    settings: widget.settings),
                                style: const TextStyle(fontSize: 10.5)),
                            selected: screenOk,
                            onSelected: (v) =>
                                setModalState(() => screenOk = v),
                          ),
                          FilterChip(
                            label: Text(
                                PosLocalization.tr('Body Scratches / Dents',
                                    settings: widget.settings),
                                style: const TextStyle(fontSize: 10.5)),
                            selected: scratches,
                            onSelected: (v) =>
                                setModalState(() => scratches = v),
                          ),
                          FilterChip(
                            label: Text(
                                PosLocalization.tr('Camera OK',
                                    settings: widget.settings),
                                style: const TextStyle(fontSize: 10.5)),
                            selected: cameraOk,
                            onSelected: (v) =>
                                setModalState(() => cameraOk = v),
                          ),
                          FilterChip(
                            label: Text(
                                PosLocalization.tr('Audio / Mic OK',
                                    settings: widget.settings),
                                style: const TextStyle(fontSize: 10.5)),
                            selected: audioOk,
                            onSelected: (v) => setModalState(() => audioOk = v),
                          ),
                          FilterChip(
                            label: Text(
                                PosLocalization.tr('SIM / SD Removed',
                                    settings: widget.settings),
                                style: const TextStyle(fontSize: 10.5)),
                            selected: simRemoved,
                            onSelected: (v) =>
                                setModalState(() => simRemoved = v),
                          ),
                          FilterChip(
                            label: Text(
                                PosLocalization.tr('Water / Liquid Damage',
                                    settings: widget.settings),
                                style: const TextStyle(fontSize: 10.5)),
                            selected: liquidDamage,
                            onSelected: (v) =>
                                setModalState(() => liquidDamage = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: lockCtrl,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: PosLocalization.tr(
                              'Device PIN / Pattern / Password (Optional)',
                              settings: widget.settings),
                          hintText: PosLocalization.tr(
                              'e.g. 1234 or L-Shape pattern',
                              settings: widget.settings),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                      PosLocalization.tr('Cancel', settings: widget.settings),
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
                      final checklistData = {
                        'power_on': powerOn,
                        'screen_ok': screenOk,
                        'scratches': scratches,
                        'camera_ok': cameraOk,
                        'audio_ok': audioOk,
                        'sim_removed': simRemoved,
                        'liquid_damage': liquidDamage,
                        'lock_code': lockCtrl.text.trim(),
                      };
                      await db.addRepairJob({
                        'job_no': 'JOB-${9021 + _jobSheets.length}',
                        'customer': custCtrl.text.trim(),
                        'device': deviceCtrl.text.trim(),
                        'imei': imeiCtrl.text.trim(),
                        'fault': faultCtrl.text.trim(),
                        'technician': 'Senior Technician',
                        'est_cost':
                            double.tryParse(costCtrl.text.trim()) ?? 0.0,
                        'advance': double.tryParse(advCtrl.text.trim()) ?? 0.0,
                        'status': 'Diagnosing',
                        'date': DateTime.now().toString().substring(0, 10),
                        'checklist': jsonEncode(checklistData),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadJobs();
                    }
                  },
                  child: Text(PosLocalization.tr('Create Job Sheet',
                      settings: widget.settings)),
                ),
              ],
            );
          },
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
              PosLocalization.tr('Service & Repair Job Management',
                  settings: widget.settings),
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
            tooltip: PosLocalization.tr('Reload SQLite Jobs',
                settings: widget.settings),
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
              label: Text(
                  PosLocalization.tr('New Job Sheet',
                      settings: widget.settings),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            label: Text(PosLocalization.tr(filter,
                                settings: widget.settings)),
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
                        PosLocalization.trParams(
                            'No repair jobs match filter: {filter}',
                            {
                              'filter': PosLocalization.tr(_statusFilter,
                                  settings: widget.settings)
                            },
                            settings: widget.settings),
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
                        if (status == 'Diagnosing') {
                          statusColor = const Color(0xFFEAB308);
                        }
                        if (status == 'Waiting for Parts') {
                          statusColor = const Color(0xFFF97316);
                        }
                        if (status == 'Ready for Delivery') {
                          statusColor = const Color(0xFF10B981);
                        }
                        if (status == 'Delivered') {
                          statusColor = const Color(0xFF64748B);
                        }

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
                                      PosLocalization.tr(status,
                                          settings: widget.settings),
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
                                PosLocalization.trParams(
                                    'Customer: {customer} • IMEI/Serial: {imei}',
                                    {
                                      'customer': '${job['customer'] ?? ''}',
                                      'imei':
                                          '${job['imei'] ?? PosLocalization.tr('N/A', settings: widget.settings)}',
                                    },
                                    settings: widget.settings),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                PosLocalization.trParams('Fault: {fault}',
                                    {'fault': '${job['fault'] ?? ''}'},
                                    settings: widget.settings),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF334155)),
                              ),
                              if (job['used_parts'] != null &&
                                  (job['used_parts'] as String).isNotEmpty &&
                                  (job['used_parts'] as String) != '[]') ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    PosLocalization.trParams(
                                        'Parts Used: {parts}',
                                        {
                                          'parts': _formatPartsSummary(
                                              job['used_parts'])
                                        },
                                        settings: widget.settings),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF047857),
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
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
                                        PosLocalization.trParams(
                                            'Estimate: {currency}{amount}',
                                            {
                                              'currency': currency,
                                              'amount':
                                                  estCostVal.toStringAsFixed(2),
                                            },
                                            settings: widget.settings),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        PosLocalization.trParams(
                                            'Advance: {currency}{amount}',
                                            {
                                              'currency': currency,
                                              'amount':
                                                  advanceVal.toStringAsFixed(2),
                                            },
                                            settings: widget.settings),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: Color(0xFF10B981)),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        PosLocalization.trParams(
                                            'Assigned: {tech}',
                                            {
                                              'tech':
                                                  '${job['technician'] ?? PosLocalization.tr('General', settings: widget.settings)}',
                                            },
                                            settings: widget.settings),
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
                                          foregroundColor:
                                              const Color(0xFFF97316),
                                          side: const BorderSide(
                                              color: Color(0xFFF97316)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () =>
                                            _showSparePartsDialog(job),
                                        icon: const Icon(Icons.build_rounded,
                                            size: 14),
                                        label: Text(
                                            PosLocalization.tr('Spare Parts',
                                                settings: widget.settings),
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 6),
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
                                              title: PosLocalization.trParams(
                                                  'Repair Job Slip • {jobNo}',
                                                  {'jobNo': jobNoVal},
                                                  settings: widget.settings),
                                              htmlContent: html,
                                              defaultPaperSize: 'a4',
                                              settings: widget.settings,
                                              pdfGenerator: (_) =>
                                                  PdfExportService
                                                      .generateReportPdf(
                                                title: PosLocalization.trParams(
                                                    'Repair Job Slip ({jobNo})',
                                                    {'jobNo': jobNoVal},
                                                    settings: widget.settings),
                                                subtitle:
                                                    '${job['customer'] ?? ''} • ${job['device'] ?? ''}',
                                                headers: [
                                                  PosLocalization.tr('Field',
                                                      settings:
                                                          widget.settings),
                                                  PosLocalization.tr('Value',
                                                      settings:
                                                          widget.settings),
                                                ],
                                                rows: [
                                                  [
                                                    PosLocalization.tr('Job #',
                                                        settings:
                                                            widget.settings),
                                                    jobNoVal
                                                  ],
                                                  [
                                                    PosLocalization.tr('Device',
                                                        settings:
                                                            widget.settings),
                                                    '${job['device'] ?? ''}'
                                                  ],
                                                  [
                                                    PosLocalization.tr(
                                                        'Customer',
                                                        settings:
                                                            widget.settings),
                                                    '${job['customer'] ?? ''}'
                                                  ],
                                                  [
                                                    PosLocalization.tr(
                                                        'IMEI/Serial',
                                                        settings:
                                                            widget.settings),
                                                    '${job['imei'] ?? PosLocalization.tr('N/A', settings: widget.settings)}'
                                                  ],
                                                  [
                                                    PosLocalization.tr('Fault',
                                                        settings:
                                                            widget.settings),
                                                    '${job['fault'] ?? ''}'
                                                  ],
                                                  [
                                                    PosLocalization.tr(
                                                        'Technician',
                                                        settings:
                                                            widget.settings),
                                                    '${job['technician'] ?? PosLocalization.tr('General', settings: widget.settings)}'
                                                  ],
                                                  [
                                                    PosLocalization.tr(
                                                        'Estimate',
                                                        settings:
                                                            widget.settings),
                                                    '$currency${estCostVal.toStringAsFixed(2)}'
                                                  ],
                                                  [
                                                    PosLocalization.tr(
                                                        'Advance Paid',
                                                        settings:
                                                            widget.settings),
                                                    '$currency${advanceVal.toStringAsFixed(2)}'
                                                  ],
                                                  [
                                                    PosLocalization.tr(
                                                        'Balance Due',
                                                        settings:
                                                            widget.settings),
                                                    '$currency${(estCostVal - advanceVal).clamp(0, double.infinity).toStringAsFixed(2)}'
                                                  ],
                                                ],
                                                settings: widget.settings,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.print, size: 14),
                                        label: Text(
                                            PosLocalization.tr('Print Slip',
                                                settings: widget.settings),
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF25D366),
                                          side: const BorderSide(
                                              color: Color(0xFF25D366)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () =>
                                            _notifyCustomerRepairCompletion(
                                                job,
                                                jobNoVal,
                                                estCostVal,
                                                advanceVal,
                                                status,
                                                currency),
                                        icon: const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 14),
                                        label: Text(
                                            PosLocalization.tr('Notify',
                                                settings: widget.settings),
                                            style:
                                                const TextStyle(fontSize: 11)),
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
                                          child: Text(
                                              PosLocalization.tr('Mark Done',
                                                  settings: widget.settings),
                                              style: const TextStyle(
                                                  fontSize: 11)),
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
                                          child: Text(
                                              PosLocalization.tr('Re-open',
                                                  settings: widget.settings),
                                              style: const TextStyle(
                                                  fontSize: 11)),
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
          ${PosLocalization.tr('REPAIR & SERVICE INTAKE VOUCHER', settings: widget.settings)}
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
        <div style="font-weight: bold; font-size: 13px; color: #334155; margin-bottom: 8px; text-transform: uppercase; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;">Device Physical Checklist & Intake Inspection</div>
        <div style="font-size: 12px; color: #334155; line-height: 1.8;">
          ${_buildChecklistHtml(job['checklist']?.toString())}
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
        <strong>${PosLocalization.tr('Terms & Conditions of Service', settings: widget.settings)}:</strong><br>
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

  String _formatPartsSummary(dynamic usedPartsRaw) {
    try {
      if (usedPartsRaw == null) return '';
      final parts = usedPartsRaw is List
          ? usedPartsRaw
          : jsonDecode(usedPartsRaw.toString()) as List<dynamic>;
      return parts.map((p) => '${p['quantity']}x ${p['name']}').join(', ');
    } catch (_) {
      return '';
    }
  }

  String _buildChecklistHtml(String? checklistJson) {
    if (checklistJson == null || checklistJson.isEmpty) {
      return '<strong>Physical Condition:</strong> [ &#10003; ] Normal Wear &nbsp;&nbsp; [ &#10003; ] Power Booting';
    }
    try {
      final map = jsonDecode(checklistJson) as Map<String, dynamic>;
      final items = <String>[];
      items.add(
          'Power: ${map['power_on'] == true ? '[ &#10003; ] ON' : '[ &#10007; ] NO POWER'}');
      items.add(
          'Screen: ${map['screen_ok'] == true ? '[ &#10003; ] OK' : '[ &#10007; ] CRACKED/DEFECTIVE'}');
      items.add(
          'Body: ${map['scratches'] == true ? '[ &#9888; ] Scratches Noted' : '[ &#10003; ] Clean'}');
      items.add(
          'Camera: ${map['camera_ok'] == true ? '[ &#10003; ] OK' : '[ &#10007; ] Defective'}');
      items.add(
          'Audio: ${map['audio_ok'] == true ? '[ &#10003; ] OK' : '[ &#10007; ] Fault'}');
      items.add(
          'SIM/SD: ${map['sim_removed'] == true ? 'Removed' : 'Left with Device'}');
      if (map['liquid_damage'] == true) {
        items.add('[ &#9888; ] LIQUID DAMAGE SUSPECTED');
      }
      final lock = (map['lock_code'] ?? '').toString();
      if (lock.isNotEmpty) items.add('Lock/PIN: $lock');

      return items.join('&nbsp;&nbsp;|&nbsp;&nbsp;');
    } catch (_) {
      return 'Standard physical inspection completed.';
    }
  }

  Future<void> _showSparePartsDialog(Map<String, dynamic> job) async {
    final db = await DatabaseService.initialize();
    final allProducts = await db.getProducts();
    Product? selectedProduct =
        allProducts.isNotEmpty ? allProducts.first : null;
    final qtyCtrl = TextEditingController(text: '1');
    final currency = widget.settings.currencySymbol;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final currentPartsStr = (job['used_parts'] ?? '').toString();
          List<dynamic> currentParts = [];
          try {
            if (currentPartsStr.isNotEmpty && currentPartsStr != '[]') {
              currentParts = jsonDecode(currentPartsStr) as List<dynamic>;
            }
          } catch (_) {}

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.build_circle_rounded,
                    color: Color(0xFFF97316), size: 22),
                const SizedBox(width: 8),
                Text(
                    PosLocalization.trParams('Spare Parts & Stock • {job}',
                        {'job': '${job['job_no'] ?? job['device']}'},
                        settings: widget.settings),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      PosLocalization.tr(
                          'Select replacement spare part from inventory to deduct stock:',
                          settings: widget.settings),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SearchableDropdownField<Product>(
                    label: PosLocalization.tr(
                        'Select Spare Part (Screen, Battery, IC, Cable)',
                        settings: widget.settings),
                    selectedItem: selectedProduct,
                    items: allProducts,
                    labelBuilder: (p) =>
                        '${p.name} (Stock: ${p.stockQuantity.toInt()} • $currency${p.sellingPrice.toStringAsFixed(2)})',
                    filter: (p, q) =>
                        p.name.toLowerCase().contains(q) ||
                        p.sku.toLowerCase().contains(q) ||
                        p.barcode.toLowerCase().contains(q),
                    placeholder: 'Search & select spare part...',
                    searchHint: 'Search spare part...',
                    prefixIcon: Icons.build_outlined,
                    height: 40,
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedProduct = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: PosLocalization.tr('Quantity to Deduct',
                                settings: widget.settings),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: Text(PosLocalization.tr('Deduct & Attach',
                            settings: widget.settings)),
                        onPressed: selectedProduct == null
                            ? null
                            : () async {
                                final qty =
                                    double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                                if (qty <= 0) return;

                                // Atomically deduct stock from SQLite
                                await db.db.rawUpdate(
                                  'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                                  [qty, selectedProduct!.id],
                                );

                                final partCost =
                                    selectedProduct!.sellingPrice * qty;
                                final newEntry = {
                                  'product_id': selectedProduct!.id,
                                  'name': selectedProduct!.name,
                                  'quantity': qty,
                                  'cost': partCost,
                                };

                                currentParts.add(newEntry);
                                final currentCost = (job['est_cost'] is num)
                                    ? (job['est_cost'] as num).toDouble()
                                    : (job['estCost'] is num)
                                        ? (job['estCost'] as num).toDouble()
                                        : 0.0;
                                final updatedCost = currentCost + partCost;

                                final id = job['id'] as int?;
                                if (id != null) {
                                  await db.updateRepairJob(id, {
                                    'used_parts': jsonEncode(currentParts),
                                    'est_cost': updatedCost,
                                  });
                                }
                                job['used_parts'] = jsonEncode(currentParts);
                                job['est_cost'] = updatedCost;

                                setDlgState(() {});
                                await _loadJobs();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(PosLocalization.trParams(
                                        'Deducted {qty}x {name} from inventory! Attached to repair sheet.',
                                        {
                                          'qty': '${qty.toInt()}',
                                          'name': selectedProduct!.name
                                        },
                                        settings: widget.settings)),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                      PosLocalization.tr('Parts Attached to Job:',
                          settings: widget.settings),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  if (currentParts.isEmpty)
                    Text(
                        PosLocalization.tr(
                            'No spare parts attached yet. Labor only.',
                            settings: widget.settings),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentParts.length,
                        itemBuilder: (ctx, i) {
                          final p = currentParts[i] as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle,
                                color: Color(0xFF10B981), size: 18),
                            title: Text('${p['quantity']}x ${p['name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            trailing: Text('$currency ${p['cost']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981))),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                      PosLocalization.tr('Close', settings: widget.settings))),
            ],
          );
        },
      ),
    );
  }

  void _notifyCustomerRepairCompletion(
    Map<String, dynamic> job,
    String jobNoVal,
    double estCostVal,
    double advanceVal,
    String status,
    String currency,
  ) {
    final customerName = job['customer']?.toString() ?? 'Customer';
    final customerPhone =
        job['phone']?.toString() ?? job['customer_phone']?.toString() ?? '';
    final device = job['device']?.toString() ?? 'Device';
    final balanceDue = (estCostVal - advanceVal).clamp(0.0, double.infinity);
    final phoneCtrl = TextEditingController(text: customerPhone);
    final msgCtrl = TextEditingController(
      text:
          'Dear $customerName, your device "$device" (Repair Job #$jobNoVal) is now $status and ready for pickup at ${widget.settings.businessName}.\n\nTotal Due: $currency${balanceDue.toStringAsFixed(2)}.\n\nThank you for choosing ${widget.settings.businessName}!',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.chat_rounded,
                  color: Color(0xFF25D366), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
                PosLocalization.trParams('Notify {customer} ({jobNo})',
                    {'customer': customerName, 'jobNo': jobNoVal},
                    settings: widget.settings),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: PosLocalization.tr(
                      'Customer WhatsApp / Mobile Phone',
                      settings: widget.settings),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: PosLocalization.tr('Notification Message',
                      settings: widget.settings),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text(PosLocalization.tr('Cancel', settings: widget.settings)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(PosLocalization.tr('Send Notification',
                settings: widget.settings)),
            onPressed: () async {
              final phone = phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
              final text = msgCtrl.text;
              if (phone.isNotEmpty) {
                await MessagingService.sendWhatsAppDirect(
                  to: phone,
                  message: text,
                  recipientName: customerName,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(PosLocalization.trParams(
                        'Notification dispatched to {customer} ({phone})!',
                        {'customer': customerName, 'phone': phone},
                        settings: widget.settings)),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
