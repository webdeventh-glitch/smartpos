import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  final String status;
  final String? customLabel;

  const StatusPill({super.key, required this.status, this.customLabel});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = customLabel ?? status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'paid':
      case 'final':
      case 'received':
        bg = const Color(0xFFDEF7EC);
        fg = const Color(0xFF03543F);
        break;
      case 'partial':
      case 'pending':
        bg = const Color(0xFFFEF08A);
        fg = const Color(0xFF713F12);
        break;
      case 'due':
      case 'out_of_stock':
        bg = const Color(0xFFFDE8E8);
        fg = const Color(0xFF9B1C1C);
        break;
      case 'low_stock':
        bg = const Color(0xFFFED7AA);
        fg = const Color(0xFF9A3412);
        break;
      case 'in_stock':
        bg = const Color(0xFFE1EFFE);
        fg = const Color(0xFF1E429F);
        break;
      case 'draft':
      case 'quotation':
      case 'suspended':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF374151);
        break;
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF1F2937);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
