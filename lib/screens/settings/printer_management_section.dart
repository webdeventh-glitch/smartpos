import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/thermal_printer_service.dart';

/// Modular ESC/POS Thermal Printer Management & Auto-Print settings panel
/// embedded inside Settings -> Bill Customization & Printing (Step 4.1).
class PrinterManagementSection extends StatefulWidget {
  final BusinessSettings settings;
  final Function(BusinessSettings) onSettingsUpdated;

  const PrinterManagementSection({
    super.key,
    required this.settings,
    required this.onSettingsUpdated,
  });

  @override
  State<PrinterManagementSection> createState() =>
      _PrinterManagementSectionState();
}

class _PrinterManagementSectionState extends State<PrinterManagementSection> {
  List<ThermalPrinterConfig> _printers = [];
  bool _loading = true;
  late bool _autoPrintReceipt;
  late bool _autoPrintKot;

  @override
  void initState() {
    super.initState();
    _autoPrintReceipt = widget.settings.autoPrintReceipt;
    _autoPrintKot = widget.settings.autoPrintKot;
    _loadPrinters();
  }

  @override
  void didUpdateWidget(covariant PrinterManagementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.autoPrintReceipt !=
            widget.settings.autoPrintReceipt ||
        oldWidget.settings.autoPrintKot != widget.settings.autoPrintKot) {
      _autoPrintReceipt = widget.settings.autoPrintReceipt;
      _autoPrintKot = widget.settings.autoPrintKot;
    }
  }

  Future<void> _loadPrinters() async {
    try {
      final db = await DatabaseService.initialize();
      final list = await db.getPrinters();
      if (mounted) {
        setState(() {
          _printers = list;
        });
      }
    } catch (e, st) {
      AppLogger.warning(
          'PrinterManagementSection', 'Failed loading printers', e, st);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleAutoPrint({bool? receipt, bool? kot}) async {
    final nextReceipt = receipt ?? _autoPrintReceipt;
    final nextKot = kot ?? _autoPrintKot;
    setState(() {
      _autoPrintReceipt = nextReceipt;
      _autoPrintKot = nextKot;
    });
    final db = await DatabaseService.initialize();
    final updated = widget.settings.copyWith(
      autoPrintReceipt: nextReceipt,
      autoPrintKot: nextKot,
    );
    await db.updateBusinessSettings(updated);
    widget.onSettingsUpdated(updated);
  }

  Future<void> _showPrinterDialog([ThermalPrinterConfig? existing]) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? 'Counter POS Printer');
    String connType = existing?.connectionType ?? 'network';
    String capProfile = existing?.capabilityProfile ?? 'default';
    String paperWidth = existing?.paperWidth ?? '80mm';
    final ipCtrl =
        TextEditingController(text: existing?.ipAddress ?? '192.168.1.100');
    final portCtrl = TextEditingController(text: '${existing?.port ?? 9100}');
    final winPathCtrl = TextEditingController(
      text: existing?.windowsPrinterPath ??
          ThermalPrinterService.getDefaultWindowsPrinterName(),
    );
    bool isDefault = existing?.isDefault ?? _printers.isEmpty;
    bool isKot = existing?.isKotPrinter ?? false;
    bool autoCut = existing?.autoCut ?? true;
    bool openDrawer = existing?.openCashDrawer ?? false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.print_rounded, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(existing == null
                  ? 'Add Thermal ESC/POS Printer'
                  : 'Edit Printer Profile'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Printer Name *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: connType,
                          decoration: const InputDecoration(
                            labelText: 'Connection Type',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'network',
                                child: Text('Network (LAN TCP/IP)')),
                            DropdownMenuItem(
                                value: 'windows',
                                child: Text('Windows USB / Shared')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => connType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: paperWidth,
                          decoration: const InputDecoration(
                            labelText: 'Roll Width',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: '80mm', child: Text('80mm (48 chars)')),
                            DropdownMenuItem(
                                value: '58mm', child: Text('58mm (32 chars)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => paperWidth = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (connType == 'network') ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: ipCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Printer IP Address *',
                              hintText: '192.168.1.100',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: portCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '9100',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: winPathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Windows Printer Name or UNC Path *',
                        hintText: r'EPSON TM-T82  or  \\PC\POS80',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: capProfile,
                    decoration: const InputDecoration(
                      labelText: 'Capability Profile (ESC/POS)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: ThermalPrinterService.capabilityProfiles
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => capProfile = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Default Counter Receipt Printer',
                        style: TextStyle(fontSize: 13)),
                    value: isDefault,
                    onChanged: (v) => setDlgState(() => isDefault = v),
                  ),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use as Kitchen KOT Printer',
                        style: TextStyle(fontSize: 13)),
                    value: isKot,
                    onChanged: (v) => setDlgState(() => isKot = v),
                  ),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Cut Paper After Print',
                        style: TextStyle(fontSize: 13)),
                    value: autoCut,
                    onChanged: (v) => setDlgState(() => autoCut = v),
                  ),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open Cash Drawer Pulse (ESC p)',
                        style: TextStyle(fontSize: 13)),
                    value: openDrawer,
                    onChanged: (v) => setDlgState(() => openDrawer = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Save Printer'),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final config = ThermalPrinterConfig(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  connectionType: connType,
                  capabilityProfile: capProfile,
                  paperWidth: paperWidth,
                  charPerLine: paperWidth == '58mm' ? 32 : 48,
                  ipAddress: ipCtrl.text.trim(),
                  port: int.tryParse(portCtrl.text.trim()) ?? 9100,
                  windowsPrinterPath: winPathCtrl.text.trim(),
                  isDefault: isDefault,
                  isKotPrinter: isKot,
                  autoCut: autoCut,
                  openCashDrawer: openDrawer,
                );
                final db = await DatabaseService.initialize();
                final id = await db.savePrinter(config);
                if (isDefault) {
                  final nextSettings =
                      widget.settings.copyWith(defaultPrinterId: id);
                  await db.updateBusinessSettings(nextSettings);
                  widget.onSettingsUpdated(nextSettings);
                }
                await _loadPrinters();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPrint(ThermalPrinterConfig printer) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ThermalPrinterService.buildTestPageBytes(
        printer: printer,
        settings: widget.settings,
      );
      await ThermalPrinterService.sendBytes(printer, bytes);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Test ESC/POS receipt sent to ${printer.name} (${printer.endpointLabel})!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('Printer connection failed (${printer.endpointLabel}): $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.receipt_rounded,
                        color: Color(0xFF4F46E5), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESC/POS Thermal Printers & Auto-Print Setup',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Configure 58mm / 80mm network TCP or Windows USB/shared thermal printers & kitchen KOT routing.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Printer'),
                onPressed: () => _showPrinterDialog(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: _autoPrintReceipt,
                    onChanged: (v) => _toggleAutoPrint(receipt: v),
                  ),
                  const Text(
                    'Auto-Print Thermal Receipt on Sale Completion',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: _autoPrintKot,
                    onChanged: (v) => _toggleAutoPrint(kot: v),
                  ),
                  const Text(
                    'Auto-Print KOT to Kitchen Printer',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 22),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()))
          else if (_printers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF64748B)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No thermal printer configured yet. Click "Add Printer" to add an 80mm or 58mm Network / Windows ESC/POS printer.',
                      style:
                          TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _printers.map((pr) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          pr.isDefault ? const Color(0xFF4F46E5) : borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pr.connectionType == 'network'
                            ? Icons.wifi_tethering_rounded
                            : Icons.usb_rounded,
                        color: const Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  pr.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5),
                                ),
                                if (pr.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Default POS',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1D4ED8)),
                                    ),
                                  ),
                                if (pr.isKotPrinter)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDD5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'KOT Kitchen',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFC2410C)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pr.connectionType.toUpperCase()} • ${pr.endpointLabel} • ${pr.paperWidth} (${pr.charPerLine} cols) • ${pr.capabilityProfile}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.bolt_rounded, size: 15),
                        label: const Text('Test Print',
                            style: TextStyle(fontSize: 11.5)),
                        onPressed: () => _testPrint(pr),
                      ),
                      const SizedBox(width: 6),
                      if (!pr.isDefault && pr.id != null)
                        TextButton(
                          onPressed: () async {
                            final db = await DatabaseService.initialize();
                            await db.setDefaultPrinter(pr.id!);
                            final next = widget.settings
                                .copyWith(defaultPrinterId: pr.id);
                            await db.updateBusinessSettings(next);
                            widget.onSettingsUpdated(next);
                            _loadPrinters();
                          },
                          child: const Text('Set Default',
                              style: TextStyle(fontSize: 11.5)),
                        ),
                      IconButton(
                        tooltip: 'Edit Printer',
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: Color(0xFF4F46E5)),
                        onPressed: () => _showPrinterDialog(pr),
                      ),
                      IconButton(
                        tooltip: 'Delete Printer',
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFFEF4444)),
                        onPressed: () async {
                          if (pr.id == null) return;
                          final db = await DatabaseService.initialize();
                          await db.deletePrinter(pr.id!);
                          _loadPrinters();
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
