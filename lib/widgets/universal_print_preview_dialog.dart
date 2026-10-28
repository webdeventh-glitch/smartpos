import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/print_service.dart';

class UniversalPrintPreviewDialog extends StatefulWidget {
  final String title;
  final String Function(String paperSize)? htmlGenerator;
  final String? htmlContent;
  final String plainTextContent;
  final BusinessSettings settings;
  final String defaultPaperSize;

  const UniversalPrintPreviewDialog({
    super.key,
    required this.title,
    this.htmlGenerator,
    this.htmlContent,
    this.plainTextContent = '',
    required this.settings,
    this.defaultPaperSize = '80mm',
  });

  @override
  State<UniversalPrintPreviewDialog> createState() => _UniversalPrintPreviewDialogState();
}

class _UniversalPrintPreviewDialogState extends State<UniversalPrintPreviewDialog> {
  late String _selectedPaperSize;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _selectedPaperSize = widget.defaultPaperSize;
  }

  String _getHtml(String paperSize) {
    if (widget.htmlGenerator != null) {
      return widget.htmlGenerator!(paperSize);
    }
    return widget.htmlContent ?? '';
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    final html = _getHtml(_selectedPaperSize);
    final success = await PrintService.openPrintWindow(htmlContent: html, title: widget.title);
    if (mounted) {
      setState(() => _isPrinting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.print_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Document dispatched to Windows Print Manager!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isA4 = _selectedPaperSize == 'a4' || _selectedPaperSize == 'A4';
    final is58 = _selectedPaperSize == '58mm';
    final previewWidth = isA4 ? 680.0 : (is58 ? 320.0 : 420.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          width: previewWidth + 40,
          constraints: const BoxConstraints(maxHeight: 820),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 28, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Controls Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Paper Size Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPaperSize,
                              dropdownColor: const Color(0xFF0F172A),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: '80mm', child: Text('80mm Thermal (POS)')),
                                DropdownMenuItem(value: '58mm', child: Text('58mm Thermal (Mini)')),
                                DropdownMenuItem(value: 'a4', child: Text('A4 Standard Sheet')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPaperSize = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Preview Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: previewWidth,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: SelectableText(
                      widget.plainTextContent,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy Text'),
                          onPressed: () => PrintService.copyToClipboard(widget.plainTextContent, context),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.save_alt_rounded, size: 16),
                          label: const Text('Save HTML'),
                          onPressed: () {
                            final html = _getHtml(_selectedPaperSize);
                            PrintService.saveHtmlToFile(html, 'smartpos_doc', context);
                          },
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      icon: _isPrinting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text(_isPrinting ? 'Printing...' : 'Print to Windows Printer ($_selectedPaperSize)'),
                      onPressed: _isPrinting ? null : _handlePrint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
