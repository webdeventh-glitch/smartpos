import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'receipt_dialog.dart';
import '../returns/sales_return_dialog.dart';

class RecentTransactionsDialog extends StatefulWidget {
  final BusinessSettings settings;

  const RecentTransactionsDialog({super.key, required this.settings});

  @override
  State<RecentTransactionsDialog> createState() => _RecentTransactionsDialogState();
}

class _RecentTransactionsDialogState extends State<RecentTransactionsDialog> {
  bool _loading = true;
  List<Sale> _allSales = [];
  List<Sale> _filteredSales = [];
  String _searchQuery = '';
  String _selectedMethod = 'all';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecentSales();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSales() async {
    setState(() => _loading = true);
    final db = await DatabaseService.initialize();
    final sales = await db.getSales();
    if (mounted) {
      setState(() {
        _allSales = sales;
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredSales = _allSales.where((s) {
        if (_selectedMethod != 'all' && s.paymentMethod.toLowerCase() != _selectedMethod) {
          return false;
        }
        if (query.isNotEmpty) {
          final inv = s.invoiceNo.toLowerCase();
          final cust = s.customerName.toLowerCase();
          return inv.contains(query) || cust.contains(query);
        }
        return true;
      }).toList();
    });
  }

  Future<void> _reprintReceipt(Sale summarySale) async {
    final db = await DatabaseService.initialize();
    final fullSale = await db.getSaleByInvoiceNo(summarySale.invoiceNo);
    if (!mounted) return;

    if (fullSale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load sale details for printing.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptDialog(
        sale: fullSale,
        settings: widget.settings,
        tenderedAmount: fullSale.paidAmount,
        changeReturn: 0.0,
      ),
    );
  }

  Future<void> _initiateReturn(Sale summarySale) async {
    final db = await DatabaseService.initialize();
    final fullSale = await db.getSaleByInvoiceNo(summarySale.invoiceNo);
    if (!mounted) return;

    if (fullSale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load sale items for return processing.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => SalesReturnDialog(
        settings: widget.settings,
        initialSale: fullSale,
        onReturnSuccess: () {
          _loadRecentSales();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Return processed successfully!'), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgHeader = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: 960,
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: bgHeader,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history_rounded, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent POS Transactions',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Review recent customer sales, reprint 80mm/58mm/A4 invoices, or initiate returns.',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Reload Transactions',
                      onPressed: _loadRecentSales,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Close (ESC)',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Filter & Search Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    // Search Field
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => _applyFilter(),
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by Invoice No (e.g. INV-1001) or Customer Name...',
                          hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Method Filter Chips
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildFilterChip('all', 'All Methods'),
                        _buildFilterChip('cash', 'Cash'),
                        _buildFilterChip('card', 'Card'),
                        _buildFilterChip('credit', 'Khata / Due'),
                        _buildFilterChip('split', 'Split Pay'),
                      ],
                    ),
                  ],
                ),
              ),

              // Transactions Table
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSales.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions found',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Completed sales made in the POS terminal will appear here.',
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredSales.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                            itemBuilder: (context, index) {
                              final sale = _filteredSales[index];
                              final isDue = sale.dueAmount > 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  children: [
                                    // Invoice Icon & No
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5B6DF0).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.receipt_rounded, color: Color(0xFF5B6DF0), size: 20),
                                    ),
                                    const SizedBox(width: 14),

                                    // Invoice & Date
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                sale.invoiceNo,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: sale.invoiceNo));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Invoice copied to clipboard'),
                                                      duration: Duration(seconds: 1),
                                                    ),
                                                  );
                                                },
                                                child: Icon(Icons.copy_rounded, size: 13, color: textSecondary),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            sale.createdAt,
                                            style: TextStyle(fontSize: 11, color: textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Customer
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sale.customerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          _methodPill(sale.paymentMethod),
                                        ],
                                      ),
                                    ),

                                    // Amount & Payment Status
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$currency${sale.totalAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          isDue
                                              ? Text(
                                                  'Due: $currency${sale.dueAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                )
                                              : const Text(
                                                  'Fully Paid',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),

                                    // Actions
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Reprint Button
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            side: BorderSide(color: const Color(0xFF4F46E5).withValues(alpha: 0.5)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.print_outlined, size: 15, color: Color(0xFF4F46E5)),
                                          label: const Text(
                                            'Reprint',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                          ),
                                          onPressed: () => _reprintReceipt(sale),
                                        ),
                                        const SizedBox(width: 8),

                                        // Return Button
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.keyboard_return_rounded, size: 15, color: Color(0xFFD97706)),
                                          label: const Text(
                                            'Refund',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                          ),
                                          onPressed: () => _initiateReturn(sale),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              // Bottom Stats Summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: bgHeader,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${_filteredSales.length} of ${_allSales.length} recorded transactions',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    Row(
                      children: [
                        Text(
                          'Total Filtered Volume: ',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        Text(
                          '$currency${_filteredSales.fold(0.0, (sum, s) => sum + s.totalAmount).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      ],
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

  Widget _buildFilterChip(String method, String label) {
    final isSelected = _selectedMethod == method;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedMethod = method;
          _applyFilter();
        });
      },
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _methodPill(String method) {
    Color bg;
    Color fg;
    String label = method.toUpperCase();

    switch (method.toLowerCase()) {
      case 'cash':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF059669);
        break;
      case 'card':
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        fg = const Color(0xFF2563EB);
        break;
      case 'credit':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        label = 'KHATA / CREDIT';
        break;
      case 'split':
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
        fg = const Color(0xFF7C3AED);
        label = 'SPLIT PAY';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.12);
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

