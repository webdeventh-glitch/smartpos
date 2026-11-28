import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/business_settings.dart';
import '../services/localization_service.dart';
import '../services/print_service.dart';

/// In-app Windows Print Preview & Direct Printer Selection Dialog.
/// Renders the actual PDF pages via WinRT PdfDocument and dispatches straight to
/// the chosen Windows printer without launching any browser or showing
/// Windows 11's "This app doesn't support print preview" placeholder.
class NativePrintDialog extends StatefulWidget {
  final String title;
  final String htmlContent;
  final Future<Uint8List> Function()? pdfFallback;
  final BusinessSettings? settings;

  const NativePrintDialog({
    super.key,
    required this.title,
    required this.htmlContent,
    this.pdfFallback,
    this.settings,
  });

  static Future<PrintDispatchResult> show(
    BuildContext context, {
    required String title,
    required String htmlContent,
    Future<Uint8List> Function()? pdfFallback,
    BusinessSettings? settings,
  }) async {
    final res = await showDialog<PrintDispatchResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => NativePrintDialog(
        title: title,
        htmlContent: htmlContent,
        pdfFallback: pdfFallback,
        settings: settings,
      ),
    );
    return res ?? const PrintDispatchResult(printed: false, cancelled: true);
  }

  @override
  State<NativePrintDialog> createState() => _NativePrintDialogState();
}

class _NativePrintDialogState extends State<NativePrintDialog> {
  PrintPreviewBundle? _bundle;
  String? _loadError;
  bool _loading = true;
  bool _printing = false;

  String? _selectedPrinter;
  int _copies = 1;
  bool _landscape = false;
  bool _grayscale = false;
  int _currentPage = 0;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _preparePreview();
  }

  Future<void> _preparePreview() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cleanTitle =
          widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      var pdfBytes = await PrintService.htmlToPdfBytes(
        widget.htmlContent,
        title: cleanTitle,
      );
      if ((pdfBytes == null || pdfBytes.isEmpty) &&
          widget.pdfFallback != null) {
        pdfBytes = await widget.pdfFallback!();
      }
      if (pdfBytes == null || pdfBytes.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadError =
                'Could not render print preview PDF. Verify Microsoft Edge is available.';
          });
        }
        return;
      }

      final bundle = await PrintService.buildWindowsPrintPreview(pdfBytes);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _selectedPrinter = bundle.defaultPrinter ??
            (bundle.printers.isNotEmpty ? bundle.printers.first : null);
        _landscape = bundle.defaultLandscape;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Failed to load print preview: $e';
        });
      }
    }
  }

  Future<void> _printDirect({bool useSystemDialog = false}) async {
    final bundle = _bundle;
    if (bundle == null || _printing) return;
    setState(() {
      _printing = true;
      _loadError = null;
    });
    try {
      final res = await PrintService.directPrintPdfBytes(
        pdfBytes: bundle.pdfBytes,
        documentName: widget.title,
        printerName: _selectedPrinter,
        copies: _copies,
        landscape: _landscape,
        grayscale: _grayscale,
        showSystemDialog: useSystemDialog,
      );
      if (!mounted) return;
      if (res.printed) {
        Navigator.of(context).pop(res);
      } else if (res.cancelled) {
        setState(() => _printing = false);
      } else {
        setState(() {
          _printing = false;
          _loadError = res.error ?? 'Printing failed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _printing = false;
          _loadError = 'Print error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final sideBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final previewCanvasBg =
        isDark ? const Color(0xFF0B1120) : const Color(0xFFE2E8F0);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final pages = _bundle?.pagePngs ?? const <Uint8List>[];
    final totalPages = pages.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 740),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${PosLocalization.tr('Print Preview', settings: widget.settings)} — ${widget.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (totalPages > 0) ...[
                      IconButton(
                        tooltip: 'Previous Page',
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: Colors.white),
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                      ),
                      Text(
                        '${_currentPage + 1} / $totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next Page',
                        icon: const Icon(Icons.chevron_right_rounded,
                            color: Colors.white),
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Zoom Out',
                        icon: const Icon(Icons.zoom_out_rounded,
                            color: Colors.white70, size: 19),
                        onPressed: _zoom > 0.6
                            ? () => setState(
                                () => _zoom = (_zoom - 0.15).clamp(0.5, 2.0))
                            : null,
                      ),
                      Text(
                        '${(_zoom * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Zoom In',
                        icon: const Icon(Icons.zoom_in_rounded,
                            color: Colors.white70, size: 19),
                        onPressed: _zoom < 2.0
                            ? () => setState(
                                () => _zoom = (_zoom + 0.15).clamp(0.5, 2.0))
                            : null,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(
                        const PrintDispatchResult(
                            printed: false, cancelled: true),
                      ),
                    ),
                  ],
                ),
              ),

              if (_loadError != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadError!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Split Body: Left Printer Controls + Right Live Page Preview
              Expanded(
                child: Row(
                  children: [
                    // Left Controls Sidebar
                    Container(
                      width: 316,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: sideBg,
                        border: Border(right: BorderSide(color: borderColor)),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(13),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            PosLocalization.tr('Printer',
                                settings: widget.settings),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue:
                                (_bundle?.printers ?? const <String>[])
                                        .contains(_selectedPrinter)
                                    ? _selectedPrinter
                                    : null,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            style:
                                TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: cardBg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                            hint: Text(
                              'Select Windows Printer',
                              style:
                                  TextStyle(fontSize: 12, color: textSecondary),
                            ),
                            items: (_bundle?.printers ?? const <String>[])
                                .map((p) => DropdownMenuItem<String>(
                                      value: p,
                                      child: Text(
                                        p,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ))
                                .toList(),
                            onChanged: _loading || _printing
                                ? null
                                : (val) =>
                                    setState(() => _selectedPrinter = val),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            PosLocalization.tr('Copies',
                                settings: widget.settings),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(38, 36),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed:
                                    (_loading || _printing || _copies <= 1)
                                        ? null
                                        : () => setState(() => _copies--),
                                child: const Icon(Icons.remove, size: 16),
                              ),
                              Expanded(
                                child: Text(
                                  '$_copies',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(38, 36),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed:
                                    (_loading || _printing || _copies >= 99)
                                        ? null
                                        : () => setState(() => _copies++),
                                child: const Icon(Icons.add, size: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Orientation',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Portrait',
                                    style: TextStyle(fontSize: 11.5)),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Landscape',
                                    style: TextStyle(fontSize: 11.5)),
                              ),
                            ],
                            selected: {_landscape},
                            onSelectionChanged: _loading || _printing
                                ? null
                                : (s) => setState(() => _landscape = s.first),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Monochrome / B&W',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            value: _grayscale,
                            onChanged: _loading || _printing
                                ? null
                                : (v) => setState(() => _grayscale = v),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _printing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.print_rounded, size: 17),
                              label: Text(
                                _printing
                                    ? 'Printing...'
                                    : PosLocalization.tr('Print',
                                        settings: widget.settings),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              onPressed: (_loading ||
                                      _printing ||
                                      _bundle == null ||
                                      _selectedPrinter == null)
                                  ? null
                                  : () => _printDirect(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _printing
                                  ? null
                                  : () => Navigator.of(context).pop(
                                        const PrintDispatchResult(
                                            printed: false, cancelled: true),
                                      ),
                              child: Text(
                                PosLocalization.tr('Cancel',
                                    settings: widget.settings),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Live Document Preview Canvas
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: previewCanvasBg,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(13),
                          ),
                        ),
                        child: _loading
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Preparing print preview...',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : pages.isEmpty
                                ? Center(
                                    child: Text(
                                      _loadError ?? 'No preview available.',
                                      style: TextStyle(color: textSecondary),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.all(24),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Center(
                                        child: Container(
                                          width: 560 * _zoom,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 18,
                                                offset: Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: ColorFiltered(
                                            colorFilter: _grayscale
                                                ? const ColorFilter.matrix([
                                                    0.2126,
                                                    0.7152,
                                                    0.0722,
                                                    0,
                                                    0,
                                                    0.2126,
                                                    0.7152,
                                                    0.0722,
                                                    0,
                                                    0,
                                                    0.2126,
                                                    0.7152,
                                                    0.0722,
                                                    0,
                                                    0,
                                                    0,
                                                    0,
                                                    0,
                                                    1,
                                                    0,
                                                  ])
                                                : const ColorFilter.mode(
                                                    Colors.transparent,
                                                    BlendMode.dst,
                                                  ),
                                            child: Image.memory(
                                              pages[_currentPage],
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                      ),
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
