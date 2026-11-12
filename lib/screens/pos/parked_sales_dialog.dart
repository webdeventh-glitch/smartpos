import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/lan_realtime_service.dart';

class ParkedSalesDialog extends StatefulWidget {
  final Function(ParkedSale) onResumeSale;
  final String currencySymbol;
  final BusinessSettings? settings;

  const ParkedSalesDialog({
    super.key,
    required this.onResumeSale,
    this.currencySymbol = 'Rs',
    this.settings,
  });

  @override
  State<ParkedSalesDialog> createState() => _ParkedSalesDialogState();
}

class _ParkedSalesDialogState extends State<ParkedSalesDialog> {
  List<ParkedSale> _parked = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _lanSub;

  bool get _isLanSecondary =>
      widget.settings?.isLanSecondaryTerminal == true &&
      (widget.settings?.serverHost.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _load();
    _lanSub = LanRealtimeService.instance.events.listen((event) {
      if (event['type'] == 'drafts_updated' && mounted) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _lanSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<ParkedSale> list;
    if (_isLanSecondary) {
      list = await LanRealtimeService.instance.fetchCounterDrafts();
    } else {
      final db = await DatabaseService.initialize();
      list = await db.getParkedSales();
    }
    if (mounted) {
      setState(() {
        _parked = list;
        _loading = false;
      });
    }
  }

  Future<void> _delete(int id) async {
    if (_isLanSecondary) {
      await LanRealtimeService.instance.deleteCounterDraft(id);
    } else {
      final db = await DatabaseService.initialize();
      await db.deleteParkedSale(id);
    }
    await _load();
  }

  List<ParkedSale> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _parked;
    return _parked.where((p) {
      return p.customerName.toLowerCase().contains(q) ||
          p.note.toLowerCase().contains(q) ||
          p.createdAt.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visible = _filtered;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 660,
        height: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined,
                        color: Color(0xFFF59E0B), size: 24),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Held Bills & Counter Token Queue (${_parked.length})',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (_isLanSecondary)
                          const Text(
                            'Live LAN Queue synced with Primary Payment Counter',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981)),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Refresh Queue',
                      icon: Icon(Icons.refresh_rounded,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569)),
                      onPressed: _load,
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText:
                    'Filter by token (e.g. TKN-), counter, or customer...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            Divider(
                height: 20,
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 48,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                _parked.isEmpty
                                    ? 'No held bills or salesman tokens in queue'
                                    : 'No matching token or customer found',
                                style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = visible[index];
                            final items = p.getItems();
                            final hasToken = p.note.contains('TKN-');
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                border: Border.all(
                                    color: hasToken
                                        ? const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.5)
                                        : (isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0))),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isDark
                                        ? const Color(0xFF78350F)
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFFFEF3C7),
                                    child: Text(
                                      '${items.length}',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFFCD34D)
                                            : const Color(0xFFB45309),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                p.customerName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (hasToken) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  p.note
                                                      .split('•')
                                                      .first
                                                      .trim(),
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFB45309),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${items.length} items • Parked: ${p.createdAt}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                        if (p.note.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Token / Note: ${p.note}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${widget.currencySymbol} ${p.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF004EEB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                    onPressed: () async {
                                      if (p.id != null) await _delete(p.id!);
                                      widget.onResumeSale(p);
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: const Text('Load Bill',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Color(0xFFEF4444), size: 20),
                                    onPressed: () {
                                      if (p.id != null) _delete(p.id!);
                                    },
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
