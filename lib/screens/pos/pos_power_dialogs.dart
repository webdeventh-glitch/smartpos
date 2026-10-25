import 'package:flutter/material.dart';
import '../../models/models.dart';

// ==========================================
// 1. KITCHEN ORDER TICKET (KOT) DIALOG
// ==========================================
class KotTicketDialog extends StatelessWidget {
  final String table;
  final String waiter;
  final String diningMode;
  final List<CartItem> items;
  final BusinessSettings settings;

  const KotTicketDialog({
    super.key,
    required this.table,
    required this.waiter,
    required this.diningMode,
    required this.items,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded, color: Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KITCHEN ORDER TICKET',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                        ),
                        Text(
                          settings.businessName,
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Meta Info Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Table / Location: $table', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          diningMode.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Waiter: $waiter', style: const TextStyle(fontSize: 12)),
                      Text('Time: $dateStr $timeStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'ORDERED ITEMS',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),

            // Items List (Chef friendly: large quantity, clean names)
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (ctx, idx) {
                  final it = items[idx];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${it.quantity.toStringAsFixed(it.quantity.truncateToDouble() == it.quantity ? 0 : 2)}x',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          it.product.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Print Action
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('PRINT KOT TO KITCHEN', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFEA580C),
                    content: Text('KOT sent to kitchen printer for $table ($diningMode)!'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. X-REPORT & Z-REPORT MODAL
// ==========================================
class RegisterReportDialog extends StatelessWidget {
  final bool isZReport; // true = Z-Report (Shift Close), false = X-Report (Mid-shift reading)
  final CashRegister register;
  final BusinessSettings settings;
  final double? actualCash;
  final String? closeNote;

  const RegisterReportDialog({
    super.key,
    required this.isZReport,
    required this.register,
    required this.settings,
    this.actualCash,
    this.closeNote,
  });

  @override
  Widget build(BuildContext context) {
    final currency = settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');

    final expectedCash = register.totalCashInRegister;
    final actual = actualCash ?? expectedCash;
    final discrepancy = actual - expectedCash;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Text(
                      settings.businessName.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    Text(
                      settings.branchName,
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isZReport
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isZReport ? 'OFFICIAL Z-REPORT (SHIFT CLOSE)' : 'MID-DAY X-REPORT (AUDIT SNAPSHOT)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: isZReport ? Colors.red : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              _metaRow('Report Generated:', now, isDark),
              _metaRow('Shift Opened:', register.openedAt, isDark),
              _metaRow('Cashier:', register.cashierName, isDark),
              _metaRow('Register Shift ID:', '#REG-${register.id}', isDark),
              const Divider(height: 20),

              // Breakdown
              _amountRow('Opening Cash Float:', '$currency${register.openingAmount.toStringAsFixed(2)}', isDark),
              _amountRow('Total Cash Sales:', '$currency${register.totalSalesCash.toStringAsFixed(2)}', isDark),
              _amountRow('Total Card Sales:', '$currency${register.totalSalesCard.toStringAsFixed(2)}', isDark),
              _amountRow('Other / Bank Sales:', '$currency${register.totalSalesOther.toStringAsFixed(2)}', isDark),
              const Divider(height: 16),

              _amountRow(
                'NET REGISTER SALES:',
                '$currency${(register.totalSalesCash + register.totalSalesCard + register.totalSalesOther).toStringAsFixed(2)}',
                isDark,
                isBold: true,
              ),
              _amountRow(
                'EXPECTED CASH IN DRAWER:',
                '$currency${expectedCash.toStringAsFixed(2)}',
                isDark,
                isBold: true,
              ),

              if (isZReport) ...[
                const SizedBox(height: 8),
                _amountRow(
                  'ACTUAL COUNTED CASH:',
                  '$currency${actual.toStringAsFixed(2)}',
                  isDark,
                  isBold: true,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: discrepancy == 0
                        ? Colors.green.withValues(alpha: 0.15)
                        : (discrepancy > 0 ? Colors.blue.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        discrepancy == 0 ? 'STATUS: PERFECT BALANCE' : (discrepancy > 0 ? 'OVERAGE:' : 'SHORTAGE:'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: discrepancy == 0 ? Colors.green : (discrepancy > 0 ? Colors.blue : Colors.red),
                        ),
                      ),
                      Text(
                        discrepancy == 0 ? '$currency 0.00' : '$currency${discrepancy.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: discrepancy == 0 ? Colors.green : (discrepancy > 0 ? Colors.blue : Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                if (closeNote != null && closeNote!.isNotEmpty)
                  Text('Note: $closeNote', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: Text(isZReport ? 'PRINT Z-REPORT' : 'PRINT X-REPORT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isZReport ? 'Z-Report sent to thermal printer!' : 'X-Report printed successfully!'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, bool isDark, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 12 : 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isBold ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. SOLAR COMPOSITE / BOM BUNDLE DIALOG
// ==========================================
class SolarBundleDialog extends StatelessWidget {
  final BusinessSettings settings;
  final List<Product> products;
  final Function(List<CartItem>) onBundleSelected;

  const SolarBundleDialog({
    super.key,
    required this.settings,
    required this.products,
    required this.onBundleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currency = settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pre-defined Solar System BOM Packages
    final packages = [
      {
        'title': '3kW Hybrid Solar System (Residential)',
        'description': '6x 580W Tier-1 Panels + 3.2kW Hybrid Inverter + Battery + Structure',
        'price': 420000.0,
        'items': [
          {'name': '580W Tier-1 Mono Solar Panel', 'qty': 6.0, 'price': 16000.0},
          {'name': '3.2kW Hybrid Solar Inverter', 'qty': 1.0, 'price': 135000.0},
          {'name': '100Ah Tubular / Lithium Battery', 'qty': 1.0, 'price': 140000.0},
          {'name': 'Mounting Structure & AC/DC Protection', 'qty': 1.0, 'price': 49000.0},
        ],
      },
      {
        'title': '5kW Hybrid Solar Package (Standard Home)',
        'description': '10x 580W Panels + 5kW Dual MPPT Inverter + 2x Batteries + Structure + Testing',
        'price': 720000.0,
        'items': [
          {'name': '580W Tier-1 Mono Solar Panel', 'qty': 10.0, 'price': 15500.0},
          {'name': '5kW Dual MPPT Hybrid Inverter', 'qty': 1.0, 'price': 225000.0},
          {'name': '200Ah Lithium LiFePO4 Battery', 'qty': 1.0, 'price': 260000.0},
          {'name': 'GI Structure, Cables & Surge Protection', 'qty': 1.0, 'price': 80000.0},
        ],
      },
      {
        'title': '10kW Commercial 3-Phase Solar System',
        'description': '18x 580W Panels + 10kW 3-Phase Inverter + High Voltage Battery + Net Metering Pack',
        'price': 1350000.0,
        'items': [
          {'name': '580W Tier-1 Mono Solar Panel', 'qty': 18.0, 'price': 15000.0},
          {'name': '10kW 3-Phase Hybrid Inverter', 'qty': 1.0, 'price': 480000.0},
          {'name': '10kWh Lithium High Voltage Bank', 'qty': 1.0, 'price': 450000.0},
          {'name': 'Elevated Customized Heavy Structure', 'qty': 1.0, 'price': 150000.0},
        ],
      },
    ];

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solar System Packages (BOM)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('Bill of Materials & Composite Bundle Builder', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: packages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final pkg = packages[idx];
                  final itemsList = pkg['items'] as List<Map<String, dynamic>>;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pkg['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pkg['description'] as String,
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: itemsList.map((it) {
                                  return Chip(
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    visualDensity: VisualDensity.compact,
                                    label: Text('${it['qty']}x ${it['name']}', style: const TextStyle(fontSize: 10)),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$currency${(pkg['price'] as double).toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF059669)),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                final cartItems = itemsList.map((it) {
                                  return CartItem(
                                    product: Product(
                                      name: it['name'] as String,
                                      sku: 'SOL-${idx + 1}',
                                      barcode: 'SOL-BOM-${DateTime.now().millisecondsSinceEpoch}',
                                      purchasePrice: (it['price'] as double) * 0.8,
                                      sellingPrice: it['price'] as double,
                                      stockQuantity: 100.0,
                                    ),
                                    quantity: it['qty'] as double,
                                    unitPrice: it['price'] as double,
                                  );
                                }).toList();

                                onBundleSelected(cartItems);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Loaded ${pkg['title']} BOM bundle into cart!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              },
                              child: const Text('Add Package', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
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

// ==========================================
// 4. IMEI / SERIAL NUMBER PICKER DIALOG
// ==========================================
class ImeiPickerDialog extends StatefulWidget {
  final Product product;
  final List<ProductSerialBatch> serials;
  final Function(String) onSerialSelected;

  const ImeiPickerDialog({
    super.key,
    required this.product,
    required this.serials,
    required this.onSerialSelected,
  });

  @override
  State<ImeiPickerDialog> createState() => _ImeiPickerDialogState();
}

class _ImeiPickerDialogState extends State<ImeiPickerDialog> {
  final TextEditingController _customImeiController = TextEditingController();

  @override
  void dispose() {
    _customImeiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.indigo, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select IMEI / Serial', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text(widget.product.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 20),

            // Scan / Type Custom IMEI
            const Text('SCAN OR ENTER IMEI / SERIAL NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customImeiController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 352984102938475',
                      prefixIcon: Icon(Icons.dialpad, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _customImeiController.text.trim();
                    if (text.isNotEmpty) {
                      widget.onSerialSelected(text);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (widget.serials.isNotEmpty) ...[
              const Text('OR SELECT FROM IN-STOCK INVENTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.serials.length,
                  itemBuilder: (ctx, idx) {
                    final s = widget.serials[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_android_rounded, size: 20),
                      title: Text(s.serialNumber1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        s.serialNumber2.isNotEmpty ? 'IMEI 2: ${s.serialNumber2}' : 'Warranty: ${s.warrantyMonths} months',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        widget.onSerialSelected(s.serialNumber1);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
