import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../utils/currency_formatter.dart';

/// Full UltimatePOS-style Sell Details modal showing customer metadata,
/// itemized product breakdown, payment transactions, totals summary,
/// sell note, and activity audit trail.
class SellDetailsDialog extends StatefulWidget {
  final Sale sale;
  final BusinessSettings settings;
  final VoidCallback onPrintReceipt;
  final VoidCallback? onTransferToKhata;

  const SellDetailsDialog({
    super.key,
    required this.sale,
    required this.settings,
    required this.onPrintReceipt,
    this.onTransferToKhata,
  });

  @override
  State<SellDetailsDialog> createState() => _SellDetailsDialogState();
}

class _SellDetailsDialogState extends State<SellDetailsDialog> {
  bool _loading = true;
  List<SaleItem> _items = [];
  List<Map<String, dynamic>> _payments = [];
  List<ActivityLogEntry> _activities = [];
  Contact? _customer;
  String _locationName = '';

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final db = await DatabaseService.initialize();
    final s = widget.sale;

    final items = s.id != null ? await db.getSaleItems(s.id!) : <SaleItem>[];

    List<Map<String, dynamic>> payments = [];
    if (s.id != null) {
      final rows = await db.db.query(
        'payment_transactions',
        where: 'transaction_type = ? AND parent_id = ?',
        whereArgs: ['sale', s.id],
        orderBy: 'id ASC',
      );
      payments = rows.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    Contact? customer;
    if (s.customerId != null) {
      final contacts = await db.getContacts(type: 'customer');
      customer = contacts.where((c) => c.id == s.customerId).firstOrNull;
    }

    final locs = await db.getBusinessLocations();
    final locName = locs
            .where((l) => l.id == s.locationId)
            .map((l) => l.name)
            .firstOrNull ??
        widget.settings.branchName;

    List<ActivityLogEntry> acts = [];
    if (s.id != null) {
      final allActs = await db.getActivityLogs(entityType: 'sale', limit: 200);
      acts = allActs.where((a) => a.entityId == s.id).toList();
    }

    if (mounted) {
      setState(() {
        _items = items;
        _payments = payments;
        _customer = customer;
        _locationName = locName;
        _activities = acts;
        _loading = false;
      });
    }
  }

  bool get _isWalkIn {
    final n = widget.sale.customerName.toLowerCase();
    return n.contains('walk-in') ||
        n.contains('walk in') ||
        n.contains('walkin') ||
        widget.sale.customerId == null ||
        widget.sale.customerId == 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final altRowBg = isDark ? const Color(0xFF172033) : const Color(0xFFF1F5F9);
    final borderCol =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cur = '${widget.settings.currencySymbol} ';
    final s = widget.sale;

    final effectivePayments = _payments.isNotEmpty
        ? _payments
        : (s.paidAmount > 0
            ? [
                {
                  'transaction_date': s.createdAt,
                  'ref_no': s.invoiceNo,
                  'amount': s.paidAmount,
                  'payment_method': s.paymentMethod,
                  'note': s.note,
                }
              ]
            : <Map<String, dynamic>>[]);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 16, color: textPrimary),
                        children: [
                          TextSpan(
                            text:
                                '${PosLocalization.tr('Sell Details', settings: widget.settings)} ( ',
                          ),
                          TextSpan(
                            text:
                                '${PosLocalization.tr('Invoice No.', settings: widget.settings)}: ${s.invoiceNo}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' )'),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date top-right
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${PosLocalization.tr('Date', settings: widget.settings)}: ${s.createdAt}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 3-Column Metadata
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _metaLine(
                                        PosLocalization.tr('Invoice No.',
                                            settings: widget.settings),
                                        '#${s.invoiceNo}',
                                        textPrimary,
                                        textSecondary),
                                    _metaLine(
                                        PosLocalization.tr('Status',
                                            settings: widget.settings),
                                        s.saleStatus.toUpperCase(),
                                        textPrimary,
                                        textSecondary),
                                    _metaLine(
                                        PosLocalization.tr('Payment Status',
                                            settings: widget.settings),
                                        s.paymentStatus.toUpperCase(),
                                        textPrimary,
                                        textSecondary),
                                    if (s.userName?.isNotEmpty == true)
                                      _metaLine(
                                          PosLocalization.tr('Added By',
                                              settings: widget.settings),
                                          s.userName!,
                                          textPrimary,
                                          textSecondary),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _metaLine(
                                        PosLocalization.tr('Customer name',
                                            settings: widget.settings),
                                        s.customerName,
                                        textPrimary,
                                        textSecondary),
                                    if (_customer?.phone.isNotEmpty == true)
                                      _metaLine(
                                          PosLocalization.tr('Phone',
                                              settings: widget.settings),
                                          _customer!.phone,
                                          textPrimary,
                                          textSecondary),
                                    _metaLine(
                                        PosLocalization.tr('Address',
                                            settings: widget.settings),
                                        (_customer?.address.isNotEmpty == true)
                                            ? _customer!.address
                                            : (_isWalkIn
                                                ? 'Walk-In Customer'
                                                : _locationName),
                                        textPrimary,
                                        textSecondary),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _metaLine(
                                        PosLocalization.tr('Location',
                                            settings: widget.settings),
                                        _locationName,
                                        textPrimary,
                                        textSecondary),
                                    _metaLine(
                                        PosLocalization.tr('Payment Method',
                                            settings: widget.settings),
                                        s.paymentMethod.toUpperCase(),
                                        textPrimary,
                                        textSecondary),
                                    _metaLine(
                                        PosLocalization.tr('Shipping',
                                            settings: widget.settings),
                                        s.shipping > 0
                                            ? CurrencyFormatter.exact(
                                                s.shipping,
                                                currency: cur)
                                            : '--',
                                        textPrimary,
                                        textSecondary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Products Table
                          Text(
                            '${PosLocalization.tr('Products', settings: widget.settings)}:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderCol),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(40),
                                1: FlexColumnWidth(3.0),
                                2: FlexColumnWidth(1.2),
                                3: FlexColumnWidth(1.4),
                                4: FlexColumnWidth(1.2),
                                5: FlexColumnWidth(1.1),
                                6: FlexColumnWidth(1.4),
                                7: FlexColumnWidth(1.5),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                  ),
                                  children: [
                                    _greenTh('#'),
                                    _greenTh(PosLocalization.tr('Product',
                                        settings: widget.settings)),
                                    _greenTh(PosLocalization.tr('Quantity',
                                        settings: widget.settings)),
                                    _greenTh(PosLocalization.tr('Unit Price',
                                        settings: widget.settings)),
                                    _greenTh(PosLocalization.tr('Discount',
                                        settings: widget.settings)),
                                    _greenTh(PosLocalization.tr('Tax',
                                        settings: widget.settings)),
                                    _greenTh(PosLocalization.tr(
                                        'Price inc. tax',
                                        settings: widget.settings)),
                                    _greenTh(PosLocalization.tr('Subtotal',
                                        settings: widget.settings)),
                                  ],
                                ),
                                if (_items.isEmpty)
                                  TableRow(
                                    children: [
                                      _tdText('-', textSecondary),
                                      _tdText(
                                          PosLocalization.tr(
                                              'No line items found',
                                              settings: widget.settings),
                                          textSecondary),
                                      for (int i = 0; i < 6; i++)
                                        _tdText('', textSecondary),
                                    ],
                                  )
                                else
                                  ..._items.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final it = entry.value;
                                    final unitIncTax = it.unitPrice +
                                        (it.quantity > 0
                                            ? it.taxAmount / it.quantity
                                            : 0.0);
                                    final name =
                                        '${it.productName}${(it.variationName ?? '').isNotEmpty ? ' (${it.variationName})' : ''}${(it.batchNumber ?? '').isNotEmpty ? ' • Batch: ${it.batchNumber}' : ''}${(it.expiryDate ?? '').isNotEmpty ? ' • Exp: ${it.expiryDate}' : ''}';
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: idx.isOdd ? bg : altRowBg,
                                      ),
                                      children: [
                                        _tdText('${idx + 1}', textPrimary),
                                        _tdText(name, textPrimary, bold: true),
                                        _tdText(
                                            it.quantity % 1 == 0
                                                ? it.quantity.toInt().toString()
                                                : it.quantity
                                                    .toStringAsFixed(2),
                                            textPrimary),
                                        _tdText(
                                            CurrencyFormatter.exact(
                                                it.unitPrice,
                                                currency: cur),
                                            textPrimary),
                                        _tdText(
                                            CurrencyFormatter.exact(
                                                it.resolvedDiscountAmount,
                                                currency: cur),
                                            textPrimary),
                                        _tdText(
                                            CurrencyFormatter.exact(
                                                it.taxAmount,
                                                currency: cur),
                                            textPrimary),
                                        _tdText(
                                            CurrencyFormatter.exact(unitIncTax,
                                                currency: cur),
                                            textPrimary),
                                        _tdText(
                                            CurrencyFormatter.exact(it.subtotal,
                                                currency: cur),
                                            textPrimary,
                                            bold: true),
                                      ],
                                    );
                                  }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Payment Info (left) + Totals Breakdown (right)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${PosLocalization.tr('Payment info', settings: widget.settings)}:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: borderCol),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Table(
                                        columnWidths: const {
                                          0: FixedColumnWidth(34),
                                          1: FlexColumnWidth(1.5),
                                          2: FlexColumnWidth(1.3),
                                          3: FlexColumnWidth(1.3),
                                          4: FlexColumnWidth(1.2),
                                          5: FlexColumnWidth(1.3),
                                        },
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        children: [
                                          TableRow(
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                            ),
                                            children: [
                                              _greenTh('#'),
                                              _greenTh(PosLocalization.tr(
                                                  'Date',
                                                  settings: widget.settings)),
                                              _greenTh(PosLocalization.tr(
                                                  'Reference No',
                                                  settings: widget.settings)),
                                              _greenTh(PosLocalization.tr(
                                                  'Amount',
                                                  settings: widget.settings)),
                                              _greenTh(PosLocalization.tr(
                                                  'Payment mode',
                                                  settings: widget.settings)),
                                              _greenTh(PosLocalization.tr(
                                                  'Payment note',
                                                  settings: widget.settings)),
                                            ],
                                          ),
                                          if (effectivePayments.isEmpty)
                                            TableRow(
                                              children: [
                                                _tdText('-', textSecondary),
                                                _tdText(
                                                    PosLocalization.tr(
                                                        'No payments recorded',
                                                        settings:
                                                            widget.settings),
                                                    textSecondary),
                                                for (int i = 0; i < 4; i++)
                                                  _tdText('', textSecondary),
                                              ],
                                            )
                                          else
                                            ...effectivePayments
                                                .asMap()
                                                .entries
                                                .map((e) {
                                              final i = e.key;
                                              final p = e.value;
                                              final amt = (p['amount'] as num?)
                                                      ?.toDouble() ??
                                                  0.0;
                                              final note =
                                                  (p['note'] ?? '').toString();
                                              return TableRow(
                                                decoration: BoxDecoration(
                                                  color:
                                                      i.isOdd ? bg : altRowBg,
                                                ),
                                                children: [
                                                  _tdText(
                                                      '${i + 1}', textPrimary),
                                                  _tdText(
                                                      (p['transaction_date'] ??
                                                              s.createdAt)
                                                          .toString(),
                                                      textPrimary),
                                                  _tdText(
                                                      (p['ref_no'] ??
                                                              s.invoiceNo)
                                                          .toString(),
                                                      textPrimary),
                                                  _tdText(
                                                      CurrencyFormatter.exact(
                                                          amt,
                                                          currency: cur),
                                                      textPrimary,
                                                      bold: true),
                                                  _tdText(
                                                      (p['payment_method'] ??
                                                              s.paymentMethod)
                                                          .toString()
                                                          .toUpperCase(),
                                                      textPrimary),
                                                  _tdText(
                                                      note.isNotEmpty
                                                          ? note
                                                          : '--',
                                                      textSecondary),
                                                ],
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 26),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    border: Border.all(color: borderCol),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    children: [
                                      _summaryRow(
                                          'Total:',
                                          CurrencyFormatter.exact(s.subtotal,
                                              currency: cur),
                                          textPrimary,
                                          borderCol,
                                          altRowBg),
                                      _summaryRow(
                                          'Discount:',
                                          CurrencyFormatter.exact(s.discount,
                                              currency: cur),
                                          textPrimary,
                                          borderCol,
                                          bg,
                                          prefixSymbol: '(-)'),
                                      _summaryRow(
                                          'Order Tax:',
                                          CurrencyFormatter.exact(s.taxAmount,
                                              currency: cur),
                                          textPrimary,
                                          borderCol,
                                          altRowBg,
                                          prefixSymbol: '(+)'),
                                      _summaryRow(
                                          'Shipping:',
                                          CurrencyFormatter.exact(s.shipping,
                                              currency: cur),
                                          textPrimary,
                                          borderCol,
                                          bg,
                                          prefixSymbol: '(+)'),
                                      _summaryRow(
                                          'Total Payable:',
                                          CurrencyFormatter.exact(s.totalAmount,
                                              currency: cur),
                                          textPrimary,
                                          borderCol,
                                          altRowBg,
                                          bold: true),
                                      _summaryRow(
                                          'Total paid:',
                                          CurrencyFormatter.exact(s.paidAmount,
                                              currency: cur),
                                          const Color(0xFF059669),
                                          borderCol,
                                          bg,
                                          bold: true),
                                      _summaryRow(
                                          'Total remaining:',
                                          CurrencyFormatter.exact(s.dueAmount,
                                              currency: cur),
                                          s.dueAmount > 0
                                              ? const Color(0xFFDC2626)
                                              : textPrimary,
                                          borderCol,
                                          altRowBg,
                                          bold: true,
                                          isLast: true),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Sell Note
                          Text(
                            '${PosLocalization.tr('Sell note', settings: widget.settings)}:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: altRowBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: borderCol),
                            ),
                            child: Text(
                              s.note.isNotEmpty ? s.note : '--',
                              style: TextStyle(
                                  fontSize: 12.5, color: textSecondary),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Activities
                          Text(
                            '${PosLocalization.tr('Activities', settings: widget.settings)}:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderCol),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.5),
                                1: FlexColumnWidth(1.2),
                                2: FlexColumnWidth(1.2),
                                3: FlexColumnWidth(2.5),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: altRowBg),
                                  children: [
                                    _plainTh('Date', textPrimary),
                                    _plainTh('Action', textPrimary),
                                    _plainTh('By', textPrimary),
                                    _plainTh('Note', textPrimary),
                                  ],
                                ),
                                if (_activities.isEmpty)
                                  TableRow(
                                    children: [
                                      _tdText('', textSecondary),
                                      _tdText(
                                          'No records found', textSecondary),
                                      _tdText('', textSecondary),
                                      _tdText('', textSecondary),
                                    ],
                                  )
                                else
                                  ..._activities.map(
                                    (a) => TableRow(
                                      children: [
                                        _tdText(
                                            _formatActivityDate(a.createdAt),
                                            textPrimary),
                                        _tdText(a.action.toUpperCase(),
                                            textPrimary),
                                        _tdText(
                                            a.userName.isNotEmpty
                                                ? a.userName
                                                : 'System',
                                            textPrimary),
                                        _tdText(
                                            _formatActivityNote(
                                                a.newValues, cur),
                                            textSecondary),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Footer Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderCol)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isWalkIn && widget.onTransferToKhata != null) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded,
                          size: 16, color: Color(0xFF0D9488)),
                      label: Text(
                        PosLocalization.tr('Transfer to Khata',
                            settings: widget.settings),
                        style: const TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onTransferToKhata!();
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text(PosLocalization.tr('Print Invoice',
                        settings: widget.settings)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPrintReceipt();
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                        PosLocalization.tr('Close', settings: widget.settings)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaLine(
      String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12.5, color: textPrimary),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _greenTh(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _plainTh(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _tdText(String text, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    Color valueColor,
    Color borderCol,
    Color rowBg, {
    String? prefixSymbol,
    bool bold = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: rowBg,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: borderCol.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
          if (prefixSymbol != null)
            Expanded(
              flex: 1,
              child: Text(
                prefixSymbol,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatActivityDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '--';
    final dt = DateTime.tryParse(trimmed);
    if (dt == null) return trimmed;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  String _formatActivityNote(String raw, String cur) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '--';
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final parts = <String>[];
          for (final entry in decoded.entries) {
            final key = entry.key.toString();
            final val = entry.value;
            if (val == null || val.toString().trim().isEmpty) continue;
            switch (key) {
              case 'invoice_no':
                parts.add('Invoice: $val');
                break;
              case 'customer_name':
                parts.add('Customer: $val');
                break;
              case 'total_amount':
                final numVal =
                    val is num ? val.toDouble() : double.tryParse('$val');
                parts.add(numVal != null
                    ? 'Total: ${CurrencyFormatter.exact(numVal, currency: cur)}'
                    : 'Total: $val');
                break;
              case 'paid_amount':
                final numVal =
                    val is num ? val.toDouble() : double.tryParse('$val');
                parts.add(numVal != null
                    ? 'Paid: ${CurrencyFormatter.exact(numVal, currency: cur)}'
                    : 'Paid: $val');
                break;
              case 'sale_status':
              case 'status':
                parts.add('Status: ${val.toString().toUpperCase()}');
                break;
              case 'payment_status':
                parts.add('Payment: ${val.toString().toUpperCase()}');
                break;
              default:
                final label = key
                    .split('_')
                    .where((w) => w.isNotEmpty)
                    .map((w) => w[0].toUpperCase() + w.substring(1))
                    .join(' ');
                parts.add('$label: $val');
            }
          }
          if (parts.isNotEmpty) return parts.join(' • ');
        }
      } catch (_) {
        // Fall back to raw text when not valid JSON.
      }
    }
    return trimmed;
  }
}
