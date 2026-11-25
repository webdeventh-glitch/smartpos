import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared symbology helpers, visual mini-barcode icons, and dropdown builder
/// for consistent barcode type selection across Add Product and Settings.
class BarcodeTypeBadge {
  BarcodeTypeBadge._();

  static const String code128 = 'Code 128 (C128)';
  static const String code39 = 'Code 39';
  static const String ean13 = 'EAN-13';
  static const String upcA = 'UPC-A';

  static const List<String> supportedTypes = [
    code128,
    code39,
    ean13,
    upcA,
  ];

  /// Normalizes persisted/legacy values (e.g. 'Code 128') to canonical option labels.
  static String normalize(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'code 39' || v == 'code39') return code39;
    if (v == 'ean-13' || v == 'ean13') return ean13;
    if (v == 'upc-a' || v == 'upca') return upcA;
    return code128;
  }

  static String subtitleFor(String type) {
    switch (normalize(type)) {
      case code39:
        return 'Uppercase & Digits';
      case ean13:
        return '13 Digits • Retail';
      case upcA:
        return '12 Digits • Standard';
      case code128:
      default:
        return 'Alphanumeric • Fast';
    }
  }

  static String shortTagFor(String type) {
    switch (normalize(type)) {
      case code39:
        return 'C39';
      case ean13:
        return 'EAN13';
      case upcA:
        return 'UPCA';
      case code128:
      default:
        return 'C128';
    }
  }

  static pw.Barcode pwBarcodeFor(String? type, String data) {
    final norm = normalize(type);
    pw.Barcode candidate;
    switch (norm) {
      case code39:
        candidate = pw.Barcode.code39();
        break;
      case ean13:
        candidate = pw.Barcode.ean13();
        break;
      case upcA:
        candidate = pw.Barcode.upcA();
        break;
      case code128:
      default:
        return pw.Barcode.code128();
    }
    try {
      if (candidate.isValid(data)) return candidate;
    } catch (_) {}
    return pw.Barcode.code128();
  }

  static List<pw.BarcodeElement> _sampleBars(String type) {
    final norm = normalize(type);
    try {
      switch (norm) {
        case code39:
          return pw.Barcode.code39()
              .make('A12', width: 34, height: 15, drawText: false)
              .toList();
        case ean13:
          return pw.Barcode.ean13()
              .make('8961011000018', width: 34, height: 15, drawText: false)
              .toList();
        case upcA:
          return pw.Barcode.upcA()
              .make('012345678905', width: 34, height: 15, drawText: false)
              .toList();
        case code128:
        default:
          return pw.Barcode.code128()
              .make('POS-1', width: 34, height: 15, drawText: false)
              .toList();
      }
    } catch (_) {
      return const [];
    }
  }

  static final Map<String, List<pw.BarcodeElement>> _sampleCache = {};

  static List<pw.BarcodeElement> sampleElementsFor(String type) {
    final key = normalize(type);
    return _sampleCache.putIfAbsent(key, () => _sampleBars(key));
  }
}

/// Renders an authentic framed mini barcode graphic for the given symbology.
class BarcodeSymbologyIcon extends StatelessWidget {
  final String barcodeType;
  final double width;
  final double height;

  const BarcodeSymbologyIcon({
    super.key,
    required this.barcodeType,
    this.width = 40,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final norm = BarcodeTypeBadge.normalize(barcodeType);
    final elements = BarcodeTypeBadge.sampleElementsFor(norm);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: CustomPaint(
        painter: _MiniBarcodePainter(
          elements: elements,
          barColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _MiniBarcodePainter extends CustomPainter {
  final List<pw.BarcodeElement> elements;
  final Color barColor;

  const _MiniBarcodePainter({
    required this.elements,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elements.isEmpty) return;
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;
    final scaleX = size.width / 34.0;
    final scaleY = size.height / 15.0;
    for (final e in elements) {
      if (e is pw.BarcodeBar && e.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            e.left * scaleX,
            e.top * scaleY,
            (e.width * scaleX).clamp(0.7, size.width),
            e.height * scaleY,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBarcodePainter oldDelegate) =>
      oldDelegate.elements != elements || oldDelegate.barColor != barColor;
}

/// Reusable dropdown showing visual barcode preview icons and symbology hints.
class BarcodeTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration? decoration;
  final bool showSubtitlesInMenu;

  const BarcodeTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.decoration,
    this.showSubtitlesInMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalized = BarcodeTypeBadge.normalize(value);

    return DropdownButtonFormField<String>(
      key: ValueKey('barcode_type_$normalized'),
      initialValue: normalized,
      isExpanded: true,
      decoration: decoration ??
          const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
      selectedItemBuilder: (ctx) => BarcodeTypeBadge.supportedTypes
          .map(
            (t) => Row(
              children: [
                BarcodeSymbologyIcon(barcodeType: t, width: 36, height: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
      items: BarcodeTypeBadge.supportedTypes
          .map(
            (t) => DropdownMenuItem<String>(
              value: t,
              child: Row(
                children: [
                  BarcodeSymbologyIcon(barcodeType: t, width: 40, height: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (showSubtitlesInMenu)
                          Text(
                            BarcodeTypeBadge.subtitleFor(t),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}
