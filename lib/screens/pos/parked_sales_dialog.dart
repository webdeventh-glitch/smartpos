import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class ParkedSalesDialog extends StatefulWidget {
  final Function(ParkedSale) onResumeSale;

  const ParkedSalesDialog({super.key, required this.onResumeSale});

  @override
  State<ParkedSalesDialog> createState() => _ParkedSalesDialogState();
}

class _ParkedSalesDialogState extends State<ParkedSalesDialog> {
  List<ParkedSale> _parked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getParkedSales();
    if (mounted) {
      setState(() {
        _parked = list;
        _loading = false;
      });
    }
  }

  Future<void> _delete(int id) async {
    final db = await DatabaseService.initialize();
    await db.deleteParkedSale(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pause_circle_outline, color: Color(0xFFF59E0B), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Parked / Suspended Bills (${_parked.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _parked.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'No parked bills at this moment',
                                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _parked.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = _parked[index];
                            final items = p.getItems();
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isDark
                                        ? const Color(0xFF78350F).withValues(alpha: 0.5)
                                        : const Color(0xFFFEF3C7),
                                    child: Text(
                                      '${items.length}',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.customerName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${items.length} items • Parked: ${p.createdAt}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        if (p.note.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Note: ${p.note}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${p.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF004EEB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () {
                                      widget.onResumeSale(p);
                                      if (p.id != null) _delete(p.id!);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Resume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                    onPressed: () => _delete(p.id!),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
