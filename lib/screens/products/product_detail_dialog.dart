import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/print_service.dart';
import '../../widgets/product_thumbnail.dart';
import '../../services/localization_service.dart';

class ProductDetailDialog extends StatefulWidget {
  final Product product;
  final BusinessSettings settings;
  final VoidCallback? onEdit;
  final VoidCallback? onPrintLabels;

  const ProductDetailDialog({
    super.key,
    required this.product,
    required this.settings,
    this.onEdit,
    this.onPrintLabels,
  });

  @override
  State<ProductDetailDialog> createState() => _ProductDetailDialogState();
}

class _ProductDetailDialogState extends State<ProductDetailDialog> {
  List<ProductVariation> _variations = [];
  List<ProductSerialBatch> _serials = [];
  double _totalSold = 0.0;
  double _totalTransferred = 0.0;
  double _totalAdjusted = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.product.id != null) {
      final dbService = await DatabaseService.initialize();
      final vars = await dbService.getProductVariations(widget.product.id!);

      // 1. Calculate total units sold
      double sold = 0.0;
      try {
        final soldRes = await dbService.db.rawQuery(
          "SELECT SUM(si.quantity) as total_sold FROM sale_items si JOIN sales s ON si.sale_id = s.id WHERE si.product_id = ? AND s.sale_status = 'final'",
          [widget.product.id],
        );
        sold = (soldRes.first['total_sold'] as num?)?.toDouble() ?? 0.0;
      } catch (e, st) {
        AppLogger.warning(
            'ProductDetailDialog', 'Failed calculating sold units', e, st);
      }

      // 2. Calculate total transferred
      double transferred = 0.0;
      try {
        final transfers = await dbService.getStockTransfers();
        for (final t in transfers) {
          if (t.status == 'completed') {
            for (final item in t.getItems()) {
              if (item.productId == widget.product.id) {
                transferred += item.quantity;
              }
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning('ProductDetailDialog',
            'Failed calculating transferred units', e, st);
      }

      // 3. Calculate total adjusted
      double adjusted = 0.0;
      try {
        final adjustments = await dbService.getStockAdjustments();
        for (final a in adjustments) {
          for (final item in a.getItems()) {
            if (item.productId == widget.product.id) {
              adjusted += item.quantity;
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning(
            'ProductDetailDialog', 'Failed calculating adjusted units', e, st);
      }

      // 4. Load tracked serial numbers & lots
      List<ProductSerialBatch> serials = [];
      try {
        serials = await dbService.getProductSerialsBatches(widget.product.id!);
      } catch (e, st) {
        AppLogger.warning(
            'ProductDetailDialog', 'Failed loading serials/batches', e, st);
      }

      if (mounted) {
        setState(() {
          _variations = vars;
          _serials = serials;
          _totalSold = sold;
          _totalTransferred = transferred;
          _totalAdjusted = adjusted;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showLotSerialsModal(
      BuildContext context, String lotNo, List<ProductSerialBatch> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inStockCount = items.where((s) => s.status == 'in_stock').length;
    final soldCount = items.where((s) => s.status == 'sold').length;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lot / Pallet: $lotNo',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          'Total ${items.length} Units • $inStockCount Available In-Stock • $soldCount Dispatched/Sold',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = items[idx];
                    final isSold = item.status == 'sold';

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      leading: Icon(
                        isSold
                            ? Icons.check_circle_rounded
                            : Icons.solar_power_rounded,
                        size: 20,
                        color: isSold
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF10B981),
                      ),
                      title: Text(
                        item.serialNumber1.isNotEmpty
                            ? item.serialNumber1
                            : 'Serial #${item.id}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Warranty: ${item.warrantyMonths} Mos • ${item.notes.isNotEmpty ? item.notes : 'Standard Lot'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSold
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSold ? 'SOLD' : 'IN STOCK',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSold
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(PosLocalization.tr('Close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.product;
    final currency = widget.settings.currencySymbol.isNotEmpty
        ? widget.settings.currencySymbol
        : 'Rs';
    final margin = p.purchasePrice > 0
        ? (((p.sellingPrice - p.purchasePrice) / p.purchasePrice) * 100)
        : 0.0;

    final user = AuthService.currentUser;
    // Purchase price and cost margins are strictly confidential to the Super Admin (Owner)
    final canViewCost = user != null && user.isSuperAdmin;
    final locationName = widget.settings.businessName.isNotEmpty
        ? widget.settings.businessName
        : 'Main Branch HQ';

    const greenHeaderColor = Color(0xFF10B981);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final rowAltBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 20,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),

            // Modal Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Section: 3-column Specifications + Product Image
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Specifications Grid
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Column 1
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _specField('SKU', p.sku, isDark),
                                        const SizedBox(height: 8),
                                        _specField(
                                            'Brand',
                                            p.brandName.isNotEmpty
                                                ? p.brandName
                                                : 'Standard',
                                            isDark),
                                        const SizedBox(height: 8),
                                        _specField('Unit', p.unit, isDark),
                                        const SizedBox(height: 8),
                                        _specField('Barcode Type',
                                            p.barcodeType, isDark),
                                        const SizedBox(height: 8),
                                        _specField('Available in locations',
                                            locationName, isDark),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Column 2
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _specField(
                                            'Category', p.categoryName, isDark),
                                        const SizedBox(height: 8),
                                        _specField(
                                            'Sub category', 'None', isDark),
                                        const SizedBox(height: 8),
                                        _specField(
                                            'Manage Stock?', 'Yes', isDark),
                                        const SizedBox(height: 8),
                                        _specField(
                                            'Alert quantity',
                                            p.alertQuantity.toStringAsFixed(4),
                                            isDark),
                                        const SizedBox(height: 8),
                                        _specField(
                                            'Rack / Shelf Location',
                                            p.rackLocation?.isNotEmpty == true
                                                ? p.rackLocation!
                                                : 'Not Assigned',
                                            isDark),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Column 3
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (p.expiryDate?.isNotEmpty ==
                                            true) ...[
                                          _specField('Expires in',
                                              p.expiryDate!, isDark),
                                          const SizedBox(height: 8),
                                        ],
                                        _specField(
                                            'Applicable Tax', 'None', isDark),
                                        const SizedBox(height: 8),
                                        _specField('Selling Price Tax Type',
                                            'Exclusive', isDark),
                                        const SizedBox(height: 8),
                                        _specField(
                                            'Product Type',
                                            p.isVariable
                                                ? 'Variable'
                                                : 'Single',
                                            isDark),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Description / Additional details
                              Text(
                                p.warranty?.isNotEmpty == true
                                    ? 'Warranty Policy: ${p.warranty!}'
                                    : (p.batchNumber?.isNotEmpty == true
                                        ? 'Batch: ${p.batchNumber!}'
                                        : p.name),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 24),

                        // Right: Square Image Container
                        Container(
                          width: 175,
                          height: 175,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: ProductThumbnail(
                            imagePath: p.resolvedImagePath,
                            imageColor: p.imageColor,
                            size: 150,
                            borderRadius: 7,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Table 1: Pricing & Margin Table (Teal/Green header)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 880),
                            child: Table(
                              border: TableBorder(
                                horizontalInside:
                                    BorderSide(color: borderColor),
                                verticalInside: BorderSide(color: borderColor),
                              ),
                              columnWidths: const {
                                0: FlexColumnWidth(
                                    2.2), // Purchase Price (Exc. tax)
                                1: FlexColumnWidth(
                                    2.2), // Purchase Price (Inc. tax)
                                2: FlexColumnWidth(1.4), // Margin(%)
                                3: FlexColumnWidth(
                                    2.2), // Selling Price (Exc. tax)
                                4: FlexColumnWidth(
                                    2.2), // Selling Price (Inc. tax)
                                5: FlexColumnWidth(1.6), // Variation Images
                              },
                              children: [
                                // Green Table Header
                                TableRow(
                                  decoration: const BoxDecoration(
                                      color: greenHeaderColor),
                                  children: [
                                    _tableHeaderCell(
                                        'Default Purchase Price (Exc. tax)'),
                                    _tableHeaderCell(
                                        'Default Purchase Price (Inc. tax)'),
                                    _tableHeaderCell('x Margin(%)'),
                                    _tableHeaderCell(
                                        'Default Selling Price (Exc. tax)'),
                                    _tableHeaderCell(
                                        'Default Selling Price (Inc. tax)'),
                                    _tableHeaderCell('Variation Images'),
                                  ],
                                ),
                                // Main Product Row
                                TableRow(
                                  decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white),
                                  children: [
                                    _tableBodyCell(
                                      canViewCost
                                          ? '$currency ${p.purchasePrice.toStringAsFixed(2)}'
                                          : '••••••',
                                      isDark: isDark,
                                    ),
                                    _tableBodyCell(
                                      canViewCost
                                          ? '$currency ${p.purchasePrice.toStringAsFixed(2)}'
                                          : '••••••',
                                      isDark: isDark,
                                    ),
                                    _tableBodyCell(
                                      canViewCost
                                          ? margin.toStringAsFixed(2)
                                          : '••••••',
                                      isDark: isDark,
                                    ),
                                    _tableBodyCell(
                                      '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                                      isDark: isDark,
                                    ),
                                    _tableBodyCell(
                                      '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                                      isDark: isDark,
                                    ),
                                    _tableBodyImageCell(p.resolvedImagePath,
                                        p.imageColor, isDark),
                                  ],
                                ),
                                // Variation Rows (if variable product)
                                if (p.isVariable && _variations.isNotEmpty)
                                  ..._variations.map((v) {
                                    final vMargin = v.purchasePrice > 0
                                        ? (((v.sellingPrice - v.purchasePrice) /
                                                v.purchasePrice) *
                                            100)
                                        : 0.0;
                                    return TableRow(
                                      decoration:
                                          BoxDecoration(color: rowAltBg),
                                      children: [
                                        _tableBodyCell(
                                          canViewCost
                                              ? '${v.name} • $currency ${v.purchasePrice.toStringAsFixed(2)}'
                                              : '${v.name} (Stock: ${v.stockQuantity.toStringAsFixed(0)})',
                                          isDark: isDark,
                                        ),
                                        _tableBodyCell(
                                          canViewCost
                                              ? 'Stock: ${v.stockQuantity.toStringAsFixed(0)} • SKU: ${v.subSku}'
                                              : 'Stock: ${v.stockQuantity.toStringAsFixed(0)}',
                                          isDark: isDark,
                                        ),
                                        _tableBodyCell(
                                          canViewCost
                                              ? vMargin.toStringAsFixed(2)
                                              : '••••••',
                                          isDark: isDark,
                                        ),
                                        _tableBodyCell(
                                          '$currency ${v.sellingPrice.toStringAsFixed(2)}',
                                          isDark: isDark,
                                        ),
                                        _tableBodyCell(
                                          '$currency ${v.sellingPrice.toStringAsFixed(2)}',
                                          isDark: isDark,
                                        ),
                                        _tableBodyImageCell(p.resolvedImagePath,
                                            p.imageColor, isDark),
                                      ],
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Product Stock Details
                    Text(
                      'Product Stock Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Table 2: Product Stock Details Table (Teal/Green header)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 880),
                            child: Table(
                              border: TableBorder(
                                horizontalInside:
                                    BorderSide(color: borderColor),
                                verticalInside: BorderSide(color: borderColor),
                              ),
                              columnWidths: const {
                                0: FlexColumnWidth(1.2), // SKU
                                1: FlexColumnWidth(2.3), // Product
                                2: FlexColumnWidth(1.6), // Location
                                3: FlexColumnWidth(1.4), // Unit Price
                                4: FlexColumnWidth(1.3), // Current stock
                                5: FlexColumnWidth(1.7), // Current Stock Value
                                6: FlexColumnWidth(1.4), // Total unit sold
                                7: FlexColumnWidth(
                                    1.5), // Total Unit Transfered
                                8: FlexColumnWidth(1.4), // Total Unit Adjusted
                              },
                              children: [
                                // Green Table Header
                                TableRow(
                                  decoration: const BoxDecoration(
                                      color: greenHeaderColor),
                                  children: [
                                    _tableHeaderCell('SKU'),
                                    _tableHeaderCell('Product'),
                                    _tableHeaderCell('Location'),
                                    _tableHeaderCell('Unit Price'),
                                    _tableHeaderCell('Current stock'),
                                    _tableHeaderCell('Current Stock Value'),
                                    _tableHeaderCell('Total unit sold'),
                                    _tableHeaderCell('Total Unit Transfered'),
                                    _tableHeaderCell('Total Unit Adjusted'),
                                  ],
                                ),
                                // Main Stock Row
                                TableRow(
                                  decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white),
                                  children: [
                                    _tableBodyCell(p.sku, isDark: isDark),
                                    _tableBodyCell(p.name, isDark: isDark),
                                    _tableBodyCell(locationName,
                                        isDark: isDark),
                                    _tableBodyCell(
                                        '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                                        isDark: isDark),
                                    _tableBodyCell(
                                        '${p.stockQuantity.toStringAsFixed(2)}${p.unit}',
                                        isDark: isDark),
                                    _tableBodyCell(
                                        '$currency ${(p.stockQuantity * p.sellingPrice).toStringAsFixed(2)}',
                                        isDark: isDark),
                                    _tableBodyCell(
                                        '${_totalSold.toStringAsFixed(2)}${p.unit}',
                                        isDark: isDark),
                                    _tableBodyCell(
                                        '${_totalTransferred.toStringAsFixed(2)}${p.unit}',
                                        isDark: isDark),
                                    _tableBodyCell(
                                        '${_totalAdjusted.toStringAsFixed(2)}${p.unit}',
                                        isDark: isDark),
                                  ],
                                ),
                                // Variation Stock Rows (if variable product)
                                if (p.isVariable && _variations.isNotEmpty)
                                  ..._variations.map((v) {
                                    return TableRow(
                                      decoration:
                                          BoxDecoration(color: rowAltBg),
                                      children: [
                                        _tableBodyCell(v.subSku,
                                            isDark: isDark),
                                        _tableBodyCell('${p.name} - ${v.name}',
                                            isDark: isDark),
                                        _tableBodyCell(locationName,
                                            isDark: isDark),
                                        _tableBodyCell(
                                            '$currency ${v.sellingPrice.toStringAsFixed(2)}',
                                            isDark: isDark),
                                        _tableBodyCell(
                                            '${v.stockQuantity.toStringAsFixed(2)}${p.unit}',
                                            isDark: isDark),
                                        _tableBodyCell(
                                            '$currency ${(v.stockQuantity * v.sellingPrice).toStringAsFixed(2)}',
                                            isDark: isDark),
                                        _tableBodyCell('0.00${p.unit}',
                                            isDark: isDark),
                                        _tableBodyCell('0.00${p.unit}',
                                            isDark: isDark),
                                        _tableBodyCell('0.00${p.unit}',
                                            isDark: isDark),
                                      ],
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Table 3: Solar Pallet / Lot & Serial Range Tracking
                    if (_serials.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        PosLocalization.tr(
                            'Pallet / Lot & Serial Range Tracking'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 880),
                              child: Builder(
                                builder: (context) {
                                  final lotGroups =
                                      <String, List<ProductSerialBatch>>{};
                                  for (final s in _serials) {
                                    final key = s.batchNumber.isNotEmpty
                                        ? s.batchNumber
                                        : (s.notes.isNotEmpty
                                            ? s.notes
                                            : 'Lot Unassigned');
                                    lotGroups.putIfAbsent(key, () => []).add(s);
                                  }

                                  return Table(
                                    border: TableBorder(
                                      horizontalInside:
                                          BorderSide(color: borderColor),
                                      verticalInside:
                                          BorderSide(color: borderColor),
                                    ),
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.8), // Lot / Pallet
                                      1: FlexColumnWidth(2.2), // Start Serial
                                      2: FlexColumnWidth(2.2), // End Serial
                                      3: FlexColumnWidth(1.2), // Total
                                      4: FlexColumnWidth(1.4), // In Stock
                                      5: FlexColumnWidth(1.3), // Sold
                                      6: FlexColumnWidth(1.6), // Warranty
                                      7: FlexColumnWidth(1.4), // Action
                                    },
                                    children: [
                                      TableRow(
                                        decoration: const BoxDecoration(
                                            color: greenHeaderColor),
                                        children: [
                                          _tableHeaderCell('Pallet / Lot No.'),
                                          _tableHeaderCell(PosLocalization.tr(
                                              'Start Serial')),
                                          _tableHeaderCell(
                                              PosLocalization.tr('End Serial')),
                                          _tableHeaderCell('Total Units'),
                                          _tableHeaderCell('In Stock'),
                                          _tableHeaderCell('Sold'),
                                          _tableHeaderCell('Warranty'),
                                          _tableHeaderCell('Actions'),
                                        ],
                                      ),
                                      ...lotGroups.entries.map((entry) {
                                        final lotNo = entry.key;
                                        final items = entry.value;
                                        final startSn = items.isNotEmpty
                                            ? items.first.serialNumber1
                                            : '-';
                                        final endSn = items.isNotEmpty
                                            ? items.last.serialNumber1
                                            : '-';
                                        final inStock = items
                                            .where(
                                                (s) => s.status == 'in_stock')
                                            .length;
                                        final sold = items
                                            .where((s) => s.status == 'sold')
                                            .length;
                                        final warranty = items.isNotEmpty &&
                                                items.first.warrantyMonths > 0
                                            ? '${items.first.warrantyMonths} Mos'
                                            : 'Standard';

                                        return TableRow(
                                          decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white),
                                          children: [
                                            _tableBodyCell(lotNo,
                                                isDark: isDark),
                                            _tableBodyCell(startSn,
                                                isDark: isDark),
                                            _tableBodyCell(endSn,
                                                isDark: isDark),
                                            _tableBodyCell(
                                                '${items.length} Panels',
                                                isDark: isDark),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                              child: Text(
                                                '$inStock Avail',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF10B981),
                                                    fontSize: 12),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                              child: Text(
                                                '$sold Sold',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF2563EB),
                                                    fontSize: 12),
                                              ),
                                            ),
                                            _tableBodyCell(warranty,
                                                isDark: isDark),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4),
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF4F46E5),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  minimumSize:
                                                      const Size(60, 28),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4)),
                                                ),
                                                onPressed: () =>
                                                    _showLotSerialsModal(
                                                        context, lotNo, items),
                                                child: const Text(
                                                  'View Serials',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      final html = PrintService.generateProductDetailHtml(
                        product: p,
                        settings: widget.settings,
                        variations: _variations,
                        totalSold: _totalSold,
                        totalTransferred: _totalTransferred,
                        totalAdjusted: _totalAdjusted,
                        canViewCost: canViewCost,
                      );
                      PrintService.openPrintWindow(
                        context: context,
                        settings: widget.settings,
                        htmlContent: html,
                        title: 'Product_${p.sku}',
                      );
                    },
                  ),
                  if (widget.onPrintLabels != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                      label: const Text('Print Labels',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onPrintLabels!();
                      },
                    ),
                  ],
                  if (widget.onEdit != null) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit Product',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit!();
                      },
                    ),
                  ],
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specField(String label, String value, bool isDark) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _tableBodyCell(String text, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _tableBodyImageCell(
      String? imagePath, String? imageColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Center(
        child: ProductThumbnail(
          imagePath: imagePath,
          imageColor: imageColor,
          size: 28,
          borderRadius: 4,
          fallbackIcon: Icons.image_outlined,
        ),
      ),
    );
  }
}
