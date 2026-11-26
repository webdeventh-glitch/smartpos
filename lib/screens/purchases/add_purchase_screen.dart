import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../utils/serial_helper.dart';
import 'product_search_dialog.dart';
import 'quick_add_supplier_dialog.dart';
import 'quick_add_product_dialog.dart';
import 'purchase_receipt_dialog.dart';
import '../../services/localization_service.dart';

class AddPurchaseScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback onPurchaseSaved;
  final VoidCallback? onBackToList;
  final Purchase? purchaseToEdit;

  const AddPurchaseScreen({
    super.key,
    required this.settings,
    required this.onPurchaseSaved,
    this.onBackToList,
    this.purchaseToEdit,
  });

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _PurchaseLineItem {
  final Product product;
  double quantity;
  double bonusQty;
  double unitCostBeforeDiscount;
  double discountPercent;
  double profitMarginPercent;
  double sellingPrice;
  String batchNumber;
  String mfgDate;
  String expDate;
  List<String> serials = [];
  String startSerial = '';
  String endSerial = '';
  int warrantyMonths = 144;

  final TextEditingController qtyCtrl;
  final TextEditingController bonusCtrl;
  final TextEditingController costBeforeDiscCtrl;
  final TextEditingController discPercentCtrl;
  final TextEditingController marginCtrl;
  final TextEditingController sellingCtrl;
  final TextEditingController batchCtrl;

  _PurchaseLineItem({
    required this.product,
    this.quantity = 1.0,
    this.bonusQty = 0.0,
    required this.unitCostBeforeDiscount,
    this.discountPercent = 0.0,
    required this.profitMarginPercent,
    required this.sellingPrice,
    this.batchNumber = '',
    this.expDate = '',
  })  : mfgDate = '',
        qtyCtrl = TextEditingController(
            text: quantity % 1 == 0
                ? quantity.toInt().toString()
                : quantity.toStringAsFixed(1)),
        bonusCtrl = TextEditingController(
            text: bonusQty > 0 ? bonusQty.toInt().toString() : '0'),
        costBeforeDiscCtrl = TextEditingController(
            text: unitCostBeforeDiscount.toStringAsFixed(2)),
        discPercentCtrl =
            TextEditingController(text: discountPercent.toStringAsFixed(1)),
        marginCtrl =
            TextEditingController(text: profitMarginPercent.toStringAsFixed(1)),
        sellingCtrl =
            TextEditingController(text: sellingPrice.toStringAsFixed(2)),
        batchCtrl = TextEditingController(text: batchNumber);

  static double _round2(double v) =>
      v.isFinite ? double.parse(v.toStringAsFixed(2)) : 0.0;

  double get netUnitCost {
    final discount = (unitCostBeforeDiscount * (discountPercent / 100));
    final net = unitCostBeforeDiscount - discount;
    return net > 0 ? net : 0.0;
  }

  double get lineTotal => _round2(quantity * netUnitCost);

  void dispose() {
    qtyCtrl.dispose();
    bonusCtrl.dispose();
    costBeforeDiscCtrl.dispose();
    discPercentCtrl.dispose();
    marginCtrl.dispose();
    sellingCtrl.dispose();
    batchCtrl.dispose();
  }
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _hTableScroll = ScrollController();

  Contact? _selectedSupplier;
  BusinessLocation? _selectedLocation;
  PaymentAccount? _selectedPaymentAccount;

  List<Contact> _suppliers = [];
  List<Product> _allProducts = [];
  List<BusinessLocation> _locations = [];
  List<PaymentAccount> _paymentAccounts = [];

  final List<_PurchaseLineItem> _lineItems = [];

  // General Details
  final TextEditingController _refNoCtrl = TextEditingController();
  DateTime _purchaseDateTime = DateTime.now();
  String _status = 'received'; // 'received', 'pending', 'ordered'
  final TextEditingController _payTermNumberCtrl = TextEditingController();
  String _payTermType = 'days'; // 'days', 'months'
  final TextEditingController _documentCtrl = TextEditingController();

  // Search & Barcode
  final TextEditingController _barcodeSearchCtrl = TextEditingController();

  // Modifiers & Taxes
  String _discountType = 'none'; // 'none', 'fixed', 'percentage'
  final TextEditingController _discountAmountCtrl =
      TextEditingController(text: '0');
  double _taxRate = 0.0; // 0, 5, 16, 18
  final TextEditingController _shippingDetailsCtrl = TextEditingController();
  final TextEditingController _shippingChargesCtrl =
      TextEditingController(text: '0');
  final TextEditingController _additionalExpensesCtrl =
      TextEditingController(text: '0');
  final TextEditingController _notesCtrl = TextEditingController();

  // Payment
  final TextEditingController _paidAmountCtrl = TextEditingController();
  String _paymentMethod = 'cash'; // 'cash', 'bank_transfer', 'cheque', 'card'
  final TextEditingController _paymentNoteCtrl = TextEditingController();

  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    for (final item in _lineItems) {
      item.dispose();
    }
    _hTableScroll.dispose();
    _refNoCtrl.dispose();
    _payTermNumberCtrl.dispose();
    _documentCtrl.dispose();
    _barcodeSearchCtrl.dispose();
    _discountAmountCtrl.dispose();
    _shippingDetailsCtrl.dispose();
    _shippingChargesCtrl.dispose();
    _additionalExpensesCtrl.dispose();
    _notesCtrl.dispose();
    _paidAmountCtrl.dispose();
    _paymentNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final db = await DatabaseService.initialize();
    final sups = await db.getContacts(type: 'supplier');
    final prods = await db.getProducts();
    final locs = await db.getBusinessLocations();
    final accounts = await db.getPaymentAccounts();
    final autoRef = await db.generateNextPurchaseRef();

    if (mounted) {
      setState(() {
        _suppliers = sups;
        _allProducts = prods;
        _locations = locs;
        _paymentAccounts = accounts;
        _refNoCtrl.text = autoRef;

        if (locs.isNotEmpty) _selectedLocation = locs.first;
        if (sups.isNotEmpty) _selectedSupplier = sups.first;
        if (accounts.isNotEmpty) {
          _selectedPaymentAccount = accounts.firstWhere(
            (a) => a.accountType.toLowerCase() == 'cash',
            orElse: () => accounts.first,
          );
        }

        final editP = widget.purchaseToEdit;
        if (editP != null) {
          _refNoCtrl.text = editP.refNo;
          _purchaseDateTime =
              DateTime.tryParse(editP.purchaseDate.replaceFirst(' ', 'T')) ??
                  DateTime.tryParse(editP.createdAt.replaceFirst(' ', 'T')) ??
                  DateTime.now();
          _status = editP.status.toLowerCase();
          if (editP.supplierId != null) {
            _selectedSupplier =
                sups.where((s) => s.id == editP.supplierId).firstOrNull ??
                    _selectedSupplier;
          }
          _selectedLocation =
              locs.where((l) => l.id == editP.locationId).firstOrNull ??
                  _selectedLocation;
          if (editP.paymentAccountId != null) {
            _selectedPaymentAccount = accounts
                    .where((a) => a.id == editP.paymentAccountId)
                    .firstOrNull ??
                _selectedPaymentAccount;
          }
          _payTermNumberCtrl.text = editP.payTermNumber?.toString() ?? '';
          _payTermType =
              editP.payTermType.isNotEmpty ? editP.payTermType : 'days';
          _documentCtrl.text = editP.documentPath;
          _discountType = editP.discountType;
          _taxRate = editP.taxRate;
          _shippingChargesCtrl.text = editP.shippingCharges > 0
              ? editP.shippingCharges.toStringAsFixed(2)
              : '0';
          _shippingDetailsCtrl.text = editP.shippingDetails;
          _additionalExpensesCtrl.text = editP.additionalExpenses > 0
              ? editP.additionalExpenses.toStringAsFixed(2)
              : '0';
          _notesCtrl.text = editP.note;
          _paymentMethod = editP.paymentMethod;
          _paymentNoteCtrl.text = editP.paymentNote;

          _lineItems.clear();
          double goodsSum = 0.0;
          for (final raw in editP.getItems()) {
            final pid = raw['product_id'] as int?;
            final matchedProd = pid != null
                ? prods.where((p) => p.id == pid).firstOrNull
                : null;
            final netCost = (raw['purchase_price'] as num?)?.toDouble() ??
                (raw['unit_cost'] as num?)?.toDouble() ??
                0.0;
            final unitCostBeforeDisc =
                (raw['unit_cost_before_discount'] as num?)?.toDouble() ??
                    netCost;
            final discPct =
                (raw['discount_percent'] as num?)?.toDouble() ?? 0.0;
            final sellPrice = (raw['selling_price'] as num?)?.toDouble() ??
                matchedProd?.sellingPrice ??
                (netCost * 1.25);
            final margin = (raw['profit_margin'] as num?)?.toDouble() ??
                (netCost > 0
                    ? (((sellPrice - netCost) / netCost) * 100)
                    : 25.0);
            final qty = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
            final bonusQty = (raw['bonus_quantity'] as num?)?.toDouble() ?? 0.0;
            final prod = matchedProd ??
                Product(
                  id: pid,
                  name: raw['product_name']?.toString() ?? 'Product',
                  sku: raw['sku']?.toString() ?? '',
                  barcode: raw['sku']?.toString() ?? '',
                  categoryName: 'General',
                  purchasePrice: netCost,
                  sellingPrice: sellPrice,
                  stockQuantity: 0.0,
                );
            final line = _PurchaseLineItem(
              product: prod,
              quantity: qty,
              bonusQty: bonusQty,
              unitCostBeforeDiscount: unitCostBeforeDisc,
              discountPercent: discPct,
              profitMarginPercent: margin,
              sellingPrice: sellPrice,
              batchNumber:
                  (raw['batch_number'] ?? raw['lot_number'])?.toString() ?? '',
              expDate:
                  (raw['expiry_date'] ?? raw['exp_date'])?.toString() ?? '',
            );
            line.mfgDate = raw['manufacturing_date']?.toString() ?? '';
            line.serials =
                (raw['serials'] as List?)?.map((e) => e.toString()).toList() ??
                    [];
            line.startSerial = raw['start_serial']?.toString() ?? '';
            line.endSerial = raw['end_serial']?.toString() ?? '';
            line.warrantyMonths =
                (raw['warranty_months'] as num?)?.toInt() ?? 144;
            goodsSum += line.lineTotal;
            _lineItems.add(line);
          }

          if (_discountType == 'percentage' && goodsSum > 0) {
            final pct = (editP.discountAmount / goodsSum) * 100;
            _discountAmountCtrl.text = pct.toStringAsFixed(2);
          } else if (editP.discountAmount > 0) {
            _discountAmountCtrl.text = editP.discountAmount.toStringAsFixed(2);
          } else {
            _discountAmountCtrl.text = '0';
          }
          _paidAmountCtrl.text = editP.paidAmount.toStringAsFixed(2);
        }
        _loading = false;
      });
    }
  }

  // ================= Calculations =================
  static double _round2(double v) =>
      v.isFinite ? double.parse(v.toStringAsFixed(2)) : 0.0;

  double get _totalGoodsSubtotal =>
      _round2(_lineItems.fold(0.0, (sum, it) => sum + it.lineTotal));
  double get _totalUnitsCount =>
      _lineItems.fold(0.0, (sum, it) => sum + it.quantity);

  double get _orderDiscountCalculated {
    final val = double.tryParse(_discountAmountCtrl.text.trim()) ?? 0.0;
    if (_discountType == 'fixed') {
      return _round2(val.clamp(0.0, _totalGoodsSubtotal));
    } else if (_discountType == 'percentage') {
      return _round2(
          (_totalGoodsSubtotal * (val / 100)).clamp(0.0, _totalGoodsSubtotal));
    }
    return 0.0;
  }

  double get _orderTaxCalculated {
    final netAfterDiscount = _totalGoodsSubtotal - _orderDiscountCalculated;
    if (netAfterDiscount <= 0 || _taxRate <= 0) return 0.0;
    return _round2(netAfterDiscount * (_taxRate / 100));
  }

  double get _shippingCharges =>
      double.tryParse(_shippingChargesCtrl.text.trim()) ?? 0.0;
  double get _additionalExpenses =>
      double.tryParse(_additionalExpensesCtrl.text.trim()) ?? 0.0;

  double get _grandTotal {
    final total = _totalGoodsSubtotal -
        _orderDiscountCalculated +
        _orderTaxCalculated +
        _shippingCharges +
        _additionalExpenses;
    return total > 0 ? _round2(total) : 0.0;
  }

  double get _amountPaid {
    final paid = double.tryParse(_paidAmountCtrl.text.trim());
    return paid ?? _grandTotal;
  }

  double get _balanceDue =>
      _grandTotal > _amountPaid ? _round2(_grandTotal - _amountPaid) : 0.0;

  DateTime? get _calculatedDueDate {
    final termNum = int.tryParse(_payTermNumberCtrl.text.trim());
    if (termNum == null || termNum <= 0) return null;
    if (_payTermType == 'months') {
      return DateTime(_purchaseDateTime.year, _purchaseDateTime.month + termNum,
          _purchaseDateTime.day);
    } else {
      return _purchaseDateTime.add(Duration(days: termNum));
    }
  }

  void _recalcPaidAmount({bool forceFull = false}) {
    if (forceFull || _paidAmountCtrl.text.trim().isEmpty) {
      _paidAmountCtrl.text = _grandTotal.toStringAsFixed(2);
    }
    setState(() {});
  }

  // ================= Item Operations =================
  void _addProductToBill(Product p) {
    final existingIndex = _lineItems.indexWhere((it) => it.product.id == p.id);
    if (existingIndex >= 0) {
      setState(() {
        final it = _lineItems[existingIndex];
        it.quantity += 1.0;
        it.qtyCtrl.text = it.quantity % 1 == 0
            ? it.quantity.toInt().toString()
            : it.quantity.toStringAsFixed(1);
        _recalcPaidAmount(forceFull: true);
      });
      return;
    }

    final cost = p.purchasePrice > 0 ? p.purchasePrice : 100.0;
    final selling = p.sellingPrice > 0 ? p.sellingPrice : (cost * 1.25);
    final margin = cost > 0 ? (((selling - cost) / cost) * 100) : 25.0;

    final item = _PurchaseLineItem(
      product: p,
      quantity: 1.0,
      unitCostBeforeDiscount: cost,
      discountPercent: 0.0,
      profitMarginPercent: margin,
      sellingPrice: selling,
      batchNumber: p.batchNumber ?? '',
      expDate: p.expiryDate ?? '',
    );

    setState(() {
      _lineItems.add(item);
      _recalcPaidAmount(forceFull: true);
    });
  }

  void _onQuickSearch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return;

    final match = _allProducts.cast<Product?>().firstWhere(
          (p) =>
              p!.barcode.toLowerCase() == clean ||
              p.sku.toLowerCase() == clean ||
              p.name.toLowerCase() == clean ||
              p.name.toLowerCase().contains(clean),
          orElse: () => null,
        );
    if (match != null) {
      _addProductToBill(match);
      _barcodeSearchCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product matched barcode/SKU: "$query"'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openProductCatalog() {
    showDialog(
      context: context,
      builder: (ctx) => ProductSearchDialog(
        products: _allProducts,
        selectedProduct: null,
        currencySymbol: widget.settings.currencySymbol,
        onProductSelected: (p) => _addProductToBill(p),
      ),
    );
  }

  Future<void> _openQuickAddProduct() async {
    final newProduct = await showDialog<Product>(
      context: context,
      builder: (_) => QuickAddProductDialog(settings: widget.settings),
    );
    if (newProduct != null) {
      setState(() {
        _allProducts.insert(0, newProduct);
      });
      _addProductToBill(newProduct);
    }
  }

  Future<void> _openQuickAddSupplier() async {
    final newSup = await showDialog<Contact>(
      context: context,
      builder: (_) => QuickAddSupplierDialog(settings: widget.settings),
    );
    if (newSup != null) {
      setState(() {
        _suppliers.insert(0, newSup);
        _selectedSupplier = newSup;
      });
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_purchaseDateTime),
      );
      setState(() {
        _purchaseDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? _purchaseDateTime.hour,
          pickedTime?.minute ?? _purchaseDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickLineDate(_PurchaseLineItem item, bool isExpiry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? now.add(const Duration(days: 365)) : now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        if (isExpiry) {
          item.expDate = formatted;
        } else {
          item.mfgDate = formatted;
        }
      });
    }
  }

  void _openLotSerialRangeDialog(_PurchaseLineItem it) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lotCtrl = TextEditingController(
      text: it.batchCtrl.text.isNotEmpty
          ? it.batchCtrl.text
          : 'PLT-${DateTime.now().year}-01',
    );
    final startCtrl = TextEditingController(
      text: it.startSerial.isNotEmpty ? it.startSerial : 'CS-550-00101',
    );
    final countCtrl = TextEditingController(
      text: it.quantity > 0 ? it.quantity.toInt().toString() : '36',
    );
    final endCtrl = TextEditingController(
      text: it.endSerial.isNotEmpty
          ? it.endSerial
          : SerialHelper.calculateEndSerial(
              startCtrl.text, int.tryParse(countCtrl.text) ?? 36),
    );
    int selectedWarranty = it.warrantyMonths > 0 ? it.warrantyMonths : 144;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final count = int.tryParse(countCtrl.text.trim()) ?? 0;
          final previewSerials =
              SerialHelper.generateRange(startCtrl.text.trim(), count);

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 520,
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
                          color:
                              const Color(0xFF4F46E5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.solar_power_rounded,
                            color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Solar Pallet & Serial Range Tracker',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              PosLocalization.trParams(
                                  '{name} — Pallet & Serial Range',
                                  {'name': it.product.name},
                                  settings: widget.settings),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lotCtrl,
                          decoration: InputDecoration(
                            labelText:
                                '${PosLocalization.tr('Pallet / Lot No.', settings: widget.settings)} *',
                            hintText: 'e.g. PLT-LONG-550-A1',
                            prefixIcon: const Icon(Icons.inventory_2_outlined,
                                size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: countCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Panels Qty *',
                            hintText: '36',
                            prefixIcon: Icon(Icons.numbers_rounded, size: 18),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final cnt = int.tryParse(val.trim()) ?? 0;
                            if (cnt > 0) {
                              endCtrl.text = SerialHelper.calculateEndSerial(
                                  startCtrl.text.trim(), cnt);
                            }
                            setDlgState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: InputDecoration(
                            labelText:
                                '${PosLocalization.tr('Start Serial', settings: widget.settings)} *',
                            hintText: 'e.g. LR5-72HBD-550M-2401001',
                            prefixIcon:
                                const Icon(Icons.barcode_reader, size: 18),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final cnt =
                                int.tryParse(countCtrl.text.trim()) ?? 0;
                            if (cnt > 0) {
                              endCtrl.text = SerialHelper.calculateEndSerial(
                                  val.trim(), cnt);
                            }
                            setDlgState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: InputDecoration(
                            labelText:
                                '${PosLocalization.tr('End Serial', settings: widget.settings)} *',
                            hintText: 'e.g. LR5-72HBD-550M-2401036',
                            prefixIcon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final cnt = SerialHelper.calculateCount(
                                startCtrl.text.trim(), val.trim());
                            if (cnt > 0) {
                              countCtrl.text = cnt.toString();
                            }
                            setDlgState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedWarranty,
                    decoration: InputDecoration(
                      labelText: PosLocalization.tr('Warranty Period',
                          settings: widget.settings),
                      prefixIcon:
                          const Icon(Icons.verified_user_outlined, size: 18),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 144,
                          child: Text('12 Years (144 Mos) - Product Warranty')),
                      DropdownMenuItem(
                          value: 300,
                          child: Text(
                              '25 Years (300 Mos) - Performance Warranty')),
                      DropdownMenuItem(
                          value: 60,
                          child: Text('5 Years (60 Mos) - Inverter Warranty')),
                      DropdownMenuItem(
                          value: 120,
                          child:
                              Text('10 Years (120 Mos) - Inverter / Battery')),
                      DropdownMenuItem(
                          value: 12, child: Text('1 Year (12 Mos) - Standard')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedWarranty = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview Generated Sequence (${previewSerials.length} Panels):',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          previewSerials.length <= 4
                              ? previewSerials.join(', ')
                              : '${previewSerials.take(2).join(', ')} ... ➔ ... ${previewSerials.reversed.take(2).toList().reversed.join(', ')}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Apply Lot & Serials'),
                        onPressed: () {
                          final lot = lotCtrl.text.trim();
                          final start = startCtrl.text.trim();
                          final end = endCtrl.text.trim();
                          final cnt = int.tryParse(countCtrl.text.trim()) ?? 0;
                          if (lot.isEmpty || start.isEmpty || cnt <= 0) return;

                          final generated =
                              SerialHelper.generateRange(start, cnt);
                          setState(() {
                            it.batchCtrl.text = lot;
                            it.batchNumber = lot;
                            it.startSerial = start;
                            it.endSerial = end.isNotEmpty
                                ? end
                                : (generated.isNotEmpty
                                    ? generated.last
                                    : start);
                            it.quantity = cnt.toDouble();
                            it.qtyCtrl.text = cnt.toString();
                            it.serials = generated;
                            it.warrantyMonths = selectedWarranty;
                            _recalcPaidAmount(forceFull: true);
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= Save Purchase =================
  Future<void> _savePurchase({bool andPrint = false}) async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a supplier.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one product item to restock.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final invalidQtyItem = _lineItems.cast<_PurchaseLineItem?>().firstWhere(
          (it) => it!.quantity <= 0,
          orElse: () => null,
        );
    if (invalidQtyItem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Invalid quantity for "${invalidQtyItem.product.name}". Quantity must be greater than 0.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final invalidCostItem = _lineItems.cast<_PurchaseLineItem?>().firstWhere(
          (it) => it!.netUnitCost < 0,
          orElse: () => null,
        );
    if (invalidCostItem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Invalid purchase cost for "${invalidCostItem.product.name}". Cost cannot be negative.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final belowCostItem = _lineItems.cast<_PurchaseLineItem?>().firstWhere(
          (it) => it!.sellingPrice > 0 && it.sellingPrice < it.netUnitCost,
          orElse: () => null,
        );
    if (belowCostItem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Loss Guard Warning: "${belowCostItem.product.name}" selling price (${widget.settings.currencySymbol}${belowCostItem.sellingPrice.toStringAsFixed(2)}) is less than purchase cost (${widget.settings.currencySymbol}${belowCostItem.netUnitCost.toStringAsFixed(2)})! Please increase selling price to avoid losses.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paid amount cannot be negative.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_amountPaid > _grandTotal + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Paid amount (${widget.settings.currencySymbol}$_amountPaid) exceeds grand total (${widget.settings.currencySymbol}$_grandTotal).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final total = _grandTotal;
      final paid = _amountPaid;
      final paymentStatus =
          paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'due');
      final dateStr =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(_purchaseDateTime);

      final itemsPayload = _lineItems.map((it) {
        return {
          'product_id': it.product.id,
          'product_name': it.product.name,
          'sku': it.product.sku,
          'quantity': it.quantity,
          'bonus_quantity': it.bonusQty,
          'unit_cost_before_discount': it.unitCostBeforeDiscount,
          'discount_percent': it.discountPercent,
          'purchase_price': it.netUnitCost,
          'profit_margin': it.profitMarginPercent,
          'selling_price': it.sellingPrice,
          'subtotal': it.lineTotal,
          'batch_number': it.batchNumber.trim(),
          'manufacturing_date': it.mfgDate,
          'expiry_date': it.expDate,
          'serials': it.serials,
          'start_serial': it.startSerial,
          'end_serial': it.endSerial,
          'warranty_months': it.warrantyMonths,
        };
      }).toList();

      final ref = _refNoCtrl.text.trim().isNotEmpty
          ? _refNoCtrl.text.trim()
          : await db.generateNextPurchaseRef();

      final isEdit =
          widget.purchaseToEdit != null && widget.purchaseToEdit!.id != null;
      final purchase = Purchase(
        id: widget.purchaseToEdit?.id,
        refNo: ref,
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        locationId: _selectedLocation?.id ?? 1,
        locationName: _selectedLocation?.name ?? 'Main Branch HQ',
        totalAmount: total,
        paidAmount: paid,
        status: _status,
        paymentStatus: paymentStatus,
        createdAt: isEdit ? widget.purchaseToEdit!.createdAt : dateStr,
        purchaseDate: dateStr,
        note: _notesCtrl.text.trim(),
        itemsJson: jsonEncode(itemsPayload),
        discountType: _discountType,
        discountAmount: _orderDiscountCalculated,
        taxRate: _taxRate,
        taxAmount: _orderTaxCalculated,
        shippingCharges: _shippingCharges,
        shippingDetails: _shippingDetailsCtrl.text.trim(),
        additionalExpenses: _additionalExpenses,
        paymentMethod: _paymentMethod,
        paymentAccountId: _selectedPaymentAccount?.id,
        paymentNote: _paymentNoteCtrl.text.trim(),
        payTermNumber: int.tryParse(_payTermNumberCtrl.text.trim()),
        payTermType: _payTermType,
        documentPath: _documentCtrl.text.trim(),
        isPurchaseOrder: widget.purchaseToEdit?.isPurchaseOrder ?? false,
        convertedFromPoId: widget.purchaseToEdit?.convertedFromPoId,
      );

      late final int purchaseId;
      if (isEdit) {
        await db.updatePurchase(purchase: purchase, items: itemsPayload);
        purchaseId = purchase.id!;
      } else {
        purchaseId =
            await db.createPurchase(purchase: purchase, items: itemsPayload);
      }

      widget.onPurchaseSaved();

      if (mounted) {
        if (andPrint) {
          final savedPurchase = Purchase(
            id: purchaseId,
            refNo: purchase.refNo,
            supplierId: purchase.supplierId,
            supplierName: purchase.supplierName,
            locationId: purchase.locationId,
            locationName: purchase.locationName,
            totalAmount: purchase.totalAmount,
            paidAmount: purchase.paidAmount,
            status: purchase.status,
            paymentStatus: purchase.paymentStatus,
            createdAt: purchase.createdAt,
            purchaseDate: purchase.purchaseDate,
            note: purchase.note,
            itemsJson: purchase.itemsJson,
            discountType: purchase.discountType,
            discountAmount: purchase.discountAmount,
            taxRate: purchase.taxRate,
            taxAmount: purchase.taxAmount,
            shippingCharges: purchase.shippingCharges,
            shippingDetails: purchase.shippingDetails,
            additionalExpenses: purchase.additionalExpenses,
            paymentMethod: purchase.paymentMethod,
            paymentAccountId: purchase.paymentAccountId,
            paymentNote: purchase.paymentNote,
            payTermNumber: purchase.payTermNumber,
            payTermType: purchase.payTermType,
            documentPath: purchase.documentPath,
          );

          await showDialog(
            context: context,
            builder: (_) => PurchaseReceiptDialog(
              purchase: savedPurchase,
              settings: widget.settings,
            ),
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Purchase Invoice $ref saved successfully (${_lineItems.length} products restocked).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        if (widget.onBackToList != null) {
          widget.onBackToList!();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save purchase: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ================= UI Builder =================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgHeader = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final inputDeco = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
    );

    if (_loading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!_isSaving) _savePurchase(andPrint: false);
        },
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ================= Header Navigation Bar =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (widget.onBackToList != null ||
                              Navigator.of(context).canPop())
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 22),
                              onPressed: () {
                                if (widget.onBackToList != null) {
                                  widget.onBackToList!();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              tooltip: 'Back to Purchases List',
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      PosLocalization.tr(
                                          widget.purchaseToEdit != null
                                              ? 'Edit Purchase'
                                              : 'Add Purchase'),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Restock & Ledger',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4F46E5)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Add incoming shipment, assign batch & expiry dates, update selling prices, and settle supplier khata.',
                                  style: TextStyle(
                                      fontSize: 13, color: textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textSecondary,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.list_alt_rounded, size: 16),
                          label: const Text('Purchases List'),
                          onPressed: () {
                            if (widget.onBackToList != null) {
                              widget.onBackToList!();
                            } else if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ================= CARD 1: General Details =================
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFF4F46E5), size: 19),
                          const SizedBox(width: 8),
                          Text(
                            'Purchase & Supplier Details',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          return Column(
                            children: [
                              // Row 1: Supplier, Ref No, Date, Status
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Supplier
                                    Expanded(
                                        flex: 3,
                                        child: _buildSupplierField(
                                            cardBg,
                                            borderColor,
                                            textPrimary,
                                            textSecondary,
                                            inputDeco,
                                            currency)),
                                    const SizedBox(width: 14),
                                    // Reference No
                                    Expanded(
                                        flex: 2,
                                        child: _buildRefNoField(
                                            textPrimary, inputDeco)),
                                    const SizedBox(width: 14),
                                    // Purchase Date
                                    Expanded(
                                        flex: 2,
                                        child: _buildDateField(textPrimary,
                                            textSecondary, borderColor)),
                                    const SizedBox(width: 14),
                                    // Purchase Status
                                    Expanded(
                                        flex: 2,
                                        child: _buildStatusField(
                                            cardBg, textPrimary, inputDeco)),
                                  ],
                                )
                              else ...[
                                _buildSupplierField(
                                    cardBg,
                                    borderColor,
                                    textPrimary,
                                    textSecondary,
                                    inputDeco,
                                    currency),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildRefNoField(
                                            textPrimary, inputDeco)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: _buildDateField(textPrimary,
                                            textSecondary, borderColor)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildStatusField(
                                    cardBg, textPrimary, inputDeco),
                              ],
                              const SizedBox(height: 14),

                              // Row 2: Location, Pay Term, Document Attachment
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        flex: 3,
                                        child: _buildLocationField(
                                            cardBg, textPrimary, inputDeco)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        flex: 3,
                                        child: _buildPayTermField(
                                            cardBg,
                                            textPrimary,
                                            textSecondary,
                                            inputDeco)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        flex: 3,
                                        child: _buildDocumentField(
                                            textPrimary, inputDeco)),
                                  ],
                                )
                              else ...[
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildLocationField(
                                            cardBg, textPrimary, inputDeco)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: _buildDocumentField(
                                            textPrimary, inputDeco)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildPayTermField(cardBg, textPrimary,
                                    textSecondary, inputDeco),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ================= CARD 2: Products Restock Table =================
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Bar Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: bgHeader,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          border:
                              Border(bottom: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _barcodeSearchCtrl,
                                onSubmitted: _onQuickSearch,
                                style:
                                    TextStyle(fontSize: 13, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText:
                                      'Enter Product name / SKU / Scan barcode (Press Enter to add)...',
                                  hintStyle: TextStyle(
                                      fontSize: 13, color: textSecondary),
                                  prefixIcon: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                      size: 19),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: borderColor)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: borderColor)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add_box_rounded, size: 17),
                              label: const Text('Add New Product',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              onPressed: _openQuickAddProduct,
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side:
                                    const BorderSide(color: Color(0xFF4F46E5)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.inventory_2_outlined,
                                  size: 17),
                              label: const Text('Browse Catalog',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              onPressed: _openProductCatalog,
                            ),
                          ],
                        ),
                      ),

                      // Products Table
                      if (_lineItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 48, horizontal: 20),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_bag_outlined,
                                    size: 54,
                                    color:
                                        textSecondary.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'No products added to purchase invoice yet',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Scan barcode, enter SKU, or click "+ Add New Product" or "Browse Catalog" above.',
                                  style: TextStyle(
                                      fontSize: 13, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Scrollbar(
                          controller: _hTableScroll,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 8,
                          child: SingleChildScrollView(
                            controller: _hTableScroll,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 1410,
                              child: Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(40), // #
                                  1: FlexColumnWidth(2.6), // Product Name
                                  2: FixedColumnWidth(110), // Quantity
                                  3: FixedColumnWidth(85), // Bonus Qty
                                  4: FixedColumnWidth(110), // Cost Before Disc
                                  5: FixedColumnWidth(90), // Disc %
                                  6: FixedColumnWidth(100), // Net Cost
                                  7: FixedColumnWidth(110), // Line Total
                                  8: FixedColumnWidth(95), // Profit Margin %
                                  9: FixedColumnWidth(
                                      115), // Unit Selling Price
                                  10: FixedColumnWidth(130), // Lot / Batch No
                                  11: FixedColumnWidth(140), // MFG / EXP Date
                                  12: FixedColumnWidth(50), // Delete
                                },
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  // Green Table Header (Ultimate POS Style)
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: Color(
                                          0xFF0F766E), // Dark Teal / Emerald
                                    ),
                                    children: [
                                      _th('#'),
                                      _th('Product Name & SKU'),
                                      _th('Purchase Qty'),
                                      _th('Bonus (Free)'),
                                      _th('Unit Cost (Gross)'),
                                      _th('Disc %'),
                                      _th('Net Unit Cost'),
                                      _th('Line Total'),
                                      _th('Margin %'),
                                      _th('Selling Price'),
                                      _th('Batch / Lot No'),
                                      _th('MFG / EXP Date'),
                                      _th(''),
                                    ],
                                  ),
                                  ..._lineItems.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final it = entry.value;
                                    final rowBg = idx.isOdd
                                        ? (isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white)
                                        : (isDark
                                            ? const Color(0xFF172033)
                                            : const Color(0xFFF8FAFC));

                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: rowBg,
                                        border: Border(
                                            bottom: BorderSide(
                                                color: borderColor.withValues(
                                                    alpha: 0.7))),
                                      ),
                                      children: [
                                        // 0: #
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          child: Center(
                                            child: Text('${idx + 1}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: textSecondary)),
                                          ),
                                        ),

                                        // 1: Product Name & SKU
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it.product.name,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: textPrimary),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'SKU: ${it.product.sku} • Stock: ${it.product.stockQuantity.toInt()} ${it.product.unit}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 2: Quantity
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: TextFormField(
                                            controller: it.qtyCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary),
                                            decoration: inputDeco.copyWith(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              final qty =
                                                  double.tryParse(val.trim()) ??
                                                      1.0;
                                              it.quantity = qty > 0 ? qty : 1.0;
                                              _recalcPaidAmount(
                                                  forceFull: true);
                                            },
                                          ),
                                        ),

                                        // 3: Bonus / Free Qty
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: TextFormField(
                                            controller: it.bonusCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669)),
                                            decoration: inputDeco.copyWith(
                                              hintText: '0',
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              final b =
                                                  double.tryParse(val.trim()) ??
                                                      0.0;
                                              it.bonusQty = b > 0 ? b : 0.0;
                                              setState(() {});
                                            },
                                          ),
                                        ),

                                        // 4: Unit Cost (Before Discount)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: TextFormField(
                                            controller: it.costBeforeDiscCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            decoration: inputDeco.copyWith(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              final cost =
                                                  double.tryParse(val.trim()) ??
                                                      0.0;
                                              it.unitCostBeforeDiscount = cost;
                                              if (cost > 0 &&
                                                  it.profitMarginPercent > 0) {
                                                final sell = it.netUnitCost *
                                                    (1 +
                                                        (it.profitMarginPercent /
                                                            100));
                                                it.sellingPrice = sell;
                                                it.sellingCtrl.text =
                                                    sell.toStringAsFixed(2);
                                              }
                                              _recalcPaidAmount(
                                                  forceFull: true);
                                            },
                                          ),
                                        ),

                                        // 4: Disc %
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: TextFormField(
                                            controller: it.discPercentCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            decoration: inputDeco.copyWith(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              final disc =
                                                  double.tryParse(val.trim()) ??
                                                      0.0;
                                              it.discountPercent =
                                                  disc.clamp(0.0, 100.0);
                                              _recalcPaidAmount(
                                                  forceFull: true);
                                            },
                                          ),
                                        ),

                                        // 5: Net Unit Cost
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          child: Text(
                                            '$currency${it.netUnitCost.toStringAsFixed(2)}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary),
                                          ),
                                        ),

                                        // 6: Line Total
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          child: Text(
                                            '$currency${it.lineTotal.toStringAsFixed(2)}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF10B981)),
                                          ),
                                        ),

                                        // 7: Profit Margin %
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: TextFormField(
                                            controller: it.marginCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            decoration: inputDeco.copyWith(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              final margin =
                                                  double.tryParse(val.trim()) ??
                                                      0.0;
                                              it.profitMarginPercent = margin;
                                              if (it.netUnitCost > 0) {
                                                final sell = it.netUnitCost *
                                                    (1 + (margin / 100));
                                                it.sellingPrice = sell;
                                                it.sellingCtrl.text =
                                                    sell.toStringAsFixed(2);
                                              }
                                              setState(() {});
                                            },
                                          ),
                                        ),

                                        // 8: Selling Price
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: TextFormField(
                                            controller: it.sellingCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary),
                                            decoration: inputDeco.copyWith(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              final sell =
                                                  double.tryParse(val.trim()) ??
                                                      0.0;
                                              it.sellingPrice = sell;
                                              if (it.netUnitCost > 0 &&
                                                  sell > it.netUnitCost) {
                                                final margin =
                                                    ((sell - it.netUnitCost) /
                                                            it.netUnitCost) *
                                                        100;
                                                it.profitMarginPercent = margin;
                                                it.marginCtrl.text =
                                                    margin.toStringAsFixed(1);
                                              }
                                              setState(() {});
                                            },
                                          ),
                                        ),

                                        // 9: Lot / Batch No
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: it.batchCtrl,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: textPrimary),
                                                      decoration:
                                                          inputDeco.copyWith(
                                                        hintText: 'e.g. PLT-01',
                                                        hintStyle: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                textSecondary),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 8),
                                                      ),
                                                      onChanged: (val) =>
                                                          it.batchNumber = val,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                            minWidth: 26,
                                                            minHeight: 26),
                                                    tooltip: PosLocalization.tr(
                                                        'Solar Pallet & Serial Range',
                                                        settings:
                                                            widget.settings),
                                                    icon: const Icon(
                                                        Icons
                                                            .solar_power_rounded,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF4F46E5)),
                                                    onPressed: () =>
                                                        _openLotSerialRangeDialog(
                                                            it),
                                                  ),
                                                ],
                                              ),
                                              if (it.serials.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 3),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF10B981)
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      '${it.startSerial}..${it.endSerial.split('-').last} (${it.serials.length})',
                                                      style: const TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            Color(0xFF047857),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // 10: MFG / EXP Date
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 6),
                                          child: Column(
                                            children: [
                                              InkWell(
                                                onTap: () =>
                                                    _pickLineDate(it, true),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: borderColor),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .event_busy_rounded,
                                                          size: 12,
                                                          color: Color(
                                                              0xFFEF4444)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        it.expDate.isNotEmpty
                                                            ? it.expDate
                                                            : 'Set Expiry',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: it.expDate
                                                                    .isNotEmpty
                                                                ? textPrimary
                                                                : textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 11: Delete Action
                                        Center(
                                          child: IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFEF4444),
                                                size: 18),
                                            onPressed: () {
                                              setState(() {
                                                it.dispose();
                                                _lineItems.removeAt(idx);
                                                _recalcPaidAmount(
                                                    forceFull: true);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Table Footer Summary Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: bgHeader,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total Line Items: ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary),
                                ),
                                Text(
                                  '${_lineItems.length} products (${_totalUnitsCount.toInt()} units)',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'Net Goods Total: ',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textSecondary),
                                ),
                                Text(
                                  '$currency${_totalGoodsSubtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ================= CARD 3: Modifiers, Discounts, Taxes, Shipping =================
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded,
                              color: Color(0xFF4F46E5), size: 19),
                          const SizedBox(width: 8),
                          Text('Discounts, Taxes & Freight Charges',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary)),
                        ],
                      ),
                      const Divider(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          return Column(
                            children: [
                              // Row: Discount Type, Discount Amount, Tax Rate
                              if (isWide)
                                Row(
                                  children: [
                                    // Discount Type
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Discount Type',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary)),
                                          const SizedBox(height: 5),
                                          DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            dropdownColor: cardBg,
                                            decoration: inputDeco,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            initialValue: _discountType,
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'none',
                                                  child: Text(
                                                      'None (No Discount)')),
                                              DropdownMenuItem(
                                                  value: 'fixed',
                                                  child: Text('Fixed Amount')),
                                              DropdownMenuItem(
                                                  value: 'percentage',
                                                  child:
                                                      Text('Percentage (%)')),
                                            ],
                                            onChanged: (val) {
                                              setState(() {
                                                _discountType = val ?? 'none';
                                                _recalcPaidAmount(
                                                    forceFull: true);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Discount Amount
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _discountType == 'percentage'
                                                ? 'Discount Rate (%)'
                                                : 'Discount Amount ($currency)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary),
                                          ),
                                          const SizedBox(height: 5),
                                          TextFormField(
                                            controller: _discountAmountCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            decoration: inputDeco,
                                            onChanged: (_) => _recalcPaidAmount(
                                                forceFull: true),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Purchase Tax
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Purchase Tax Rate',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary)),
                                          const SizedBox(height: 5),
                                          DropdownButtonFormField<double>(
                                            isExpanded: true,
                                            dropdownColor: cardBg,
                                            decoration: inputDeco,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            initialValue: _taxRate,
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 0.0,
                                                  child: Text('None (0%)')),
                                              DropdownMenuItem(
                                                  value: 5.0,
                                                  child:
                                                      Text('5% Standard Tax')),
                                              DropdownMenuItem(
                                                  value: 16.0,
                                                  child: Text(
                                                      '16% Provincial Tax')),
                                              DropdownMenuItem(
                                                  value: 18.0,
                                                  child:
                                                      Text('18% Federal GST')),
                                            ],
                                            onChanged: (val) {
                                              setState(() {
                                                _taxRate = val ?? 0.0;
                                                _recalcPaidAmount(
                                                    forceFull: true);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        dropdownColor: cardBg,
                                        decoration: inputDeco,
                                        initialValue: _discountType,
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'none',
                                              child: Text('No Disc')),
                                          DropdownMenuItem(
                                              value: 'fixed',
                                              child: Text('Fixed')),
                                          DropdownMenuItem(
                                              value: 'percentage',
                                              child: Text('Percent (%)')),
                                        ],
                                        onChanged: (val) => setState(() {
                                          _discountType = val ?? 'none';
                                          _recalcPaidAmount(forceFull: true);
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _discountAmountCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: inputDeco.copyWith(
                                            hintText: 'Disc Val'),
                                        onChanged: (_) =>
                                            _recalcPaidAmount(forceFull: true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<double>(
                                  isExpanded: true,
                                  dropdownColor: cardBg,
                                  decoration: inputDeco,
                                  initialValue: _taxRate,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 0.0, child: Text('No Tax (0%)')),
                                    DropdownMenuItem(
                                        value: 5.0, child: Text('5% Tax')),
                                    DropdownMenuItem(
                                        value: 18.0, child: Text('18% GST')),
                                  ],
                                  onChanged: (val) => setState(() {
                                    _taxRate = val ?? 0.0;
                                    _recalcPaidAmount(forceFull: true);
                                  }),
                                ),
                              ],
                              const SizedBox(height: 14),

                              // Row: Shipping Details & Charges
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Shipping / Freight Details',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary)),
                                        const SizedBox(height: 5),
                                        TextFormField(
                                          controller: _shippingDetailsCtrl,
                                          style: TextStyle(
                                              fontSize: 13, color: textPrimary),
                                          decoration: inputDeco.copyWith(
                                              hintText:
                                                  'e.g. Bilty / Cargo / Courier reference'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Shipping Charges ($currency)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary)),
                                        const SizedBox(height: 5),
                                        TextFormField(
                                          controller: _shippingChargesCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          style: TextStyle(
                                              fontSize: 13, color: textPrimary),
                                          decoration: inputDeco,
                                          onChanged: (_) => _recalcPaidAmount(
                                              forceFull: true),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Notes
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Additional Purchase Notes',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary)),
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    controller: _notesCtrl,
                                    maxLines: 2,
                                    style: TextStyle(
                                        fontSize: 13, color: textPrimary),
                                    decoration: inputDeco.copyWith(
                                        hintText:
                                            'Any special remarks, vendor warranty terms, or delivery conditions...'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Calculations Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _calcChip(
                                    'Goods Subtotal',
                                    '$currency${_totalGoodsSubtotal.toStringAsFixed(2)}',
                                    textSecondary,
                                    textPrimary),
                                if (_orderDiscountCalculated > 0)
                                  _calcChip(
                                      'Discount (-)',
                                      '$currency${_orderDiscountCalculated.toStringAsFixed(2)}',
                                      textSecondary,
                                      const Color(0xFFEF4444)),
                                if (_orderTaxCalculated > 0)
                                  _calcChip(
                                      'Tax (+)',
                                      '$currency${_orderTaxCalculated.toStringAsFixed(2)}',
                                      textSecondary,
                                      const Color(0xFFF59E0B)),
                                if (_shippingCharges > 0)
                                  _calcChip(
                                      'Shipping (+)',
                                      '$currency${_shippingCharges.toStringAsFixed(2)}',
                                      textSecondary,
                                      const Color(0xFF3B82F6)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('GRAND TOTAL PAYABLE',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '$currency${_grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ================= CARD 4: Payment & Account Settlement =================
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              color: Color(0xFF10B981), size: 19),
                          const SizedBox(width: 8),
                          Text('Payment & Supplier Settlement',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary)),
                        ],
                      ),
                      const Divider(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          return Column(
                            children: [
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Amount Paid
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Amount Paid ($currency) *',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary)),
                                          const SizedBox(height: 5),
                                          TextFormField(
                                            controller: _paidAmountCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary),
                                            decoration: inputDeco,
                                            onChanged: (_) => setState(() {}),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _quickPayChip('Full Paid', () {
                                                _paidAmountCtrl.text =
                                                    _grandTotal
                                                        .toStringAsFixed(2);
                                                setState(() {});
                                              }),
                                              const SizedBox(width: 6),
                                              _quickPayChip('Full Due', () {
                                                _paidAmountCtrl.text = '0.00';
                                                setState(() {});
                                              }),
                                              const SizedBox(width: 6),
                                              _quickPayChip('50% Half', () {
                                                _paidAmountCtrl.text =
                                                    (_grandTotal / 2)
                                                        .toStringAsFixed(2);
                                                setState(() {});
                                              }),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Remaining Balance Due Badge
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: _balanceDue > 0
                                              ? const Color(0xFFEF4444)
                                                  .withValues(alpha: 0.08)
                                              : const Color(0xFF10B981)
                                                  .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _balanceDue > 0
                                                ? const Color(0xFFEF4444)
                                                    .withValues(alpha: 0.3)
                                                : const Color(0xFF10B981)
                                                    .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _balanceDue > 0
                                                  ? 'SUPPLIER PAYABLE DUE'
                                                  : 'ACCOUNT CLEARED',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                                color: _balanceDue > 0
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF10B981),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$currency${_balanceDue.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: _balanceDue > 0
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF10B981),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _balanceDue > 0
                                                  ? 'Will be added to vendor ledger khata'
                                                  : 'Zero balance carried forward',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Payment Method
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Payment Method',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary)),
                                          const SizedBox(height: 5),
                                          DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            dropdownColor: cardBg,
                                            decoration: inputDeco,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            initialValue: _paymentMethod,
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'cash',
                                                  child: Text('Cash in Hand')),
                                              DropdownMenuItem(
                                                  value: 'bank_transfer',
                                                  child: Text('Bank Transfer')),
                                              DropdownMenuItem(
                                                  value: 'cheque',
                                                  child: Text('Cheque')),
                                              DropdownMenuItem(
                                                  value: 'card',
                                                  child: Text('Card / Online')),
                                            ],
                                            onChanged: (val) => setState(() =>
                                                _paymentMethod = val ?? 'cash'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Payment Account
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Payment Account',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary)),
                                          const SizedBox(height: 5),
                                          DropdownButtonFormField<
                                              PaymentAccount>(
                                            isExpanded: true,
                                            dropdownColor: cardBg,
                                            decoration: inputDeco,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: textPrimary),
                                            initialValue:
                                                _selectedPaymentAccount,
                                            items: _paymentAccounts
                                                .map((a) => DropdownMenuItem(
                                                      value: a,
                                                      child: Text(
                                                        '${a.name} ($currency${a.currentBalance.toStringAsFixed(0)})',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: textPrimary),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ))
                                                .toList(),
                                            onChanged: (val) => setState(() =>
                                                _selectedPaymentAccount = val),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                TextFormField(
                                  controller: _paidAmountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: inputDeco.copyWith(
                                      labelText: 'Amount Paid ($currency)'),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  dropdownColor: cardBg,
                                  decoration: inputDeco.copyWith(
                                      labelText: 'Payment Method'),
                                  initialValue: _paymentMethod,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'cash', child: Text('Cash')),
                                    DropdownMenuItem(
                                        value: 'bank_transfer',
                                        child: Text('Bank Transfer')),
                                    DropdownMenuItem(
                                        value: 'cheque', child: Text('Cheque')),
                                  ],
                                  onChanged: (val) => setState(
                                      () => _paymentMethod = val ?? 'cash'),
                                ),
                              ],
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _paymentNoteCtrl,
                                style:
                                    TextStyle(fontSize: 13, color: textPrimary),
                                decoration: inputDeco.copyWith(
                                  hintText:
                                      'Payment note, Cheque number, or Bank transfer reference ID...',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ================= Action Footer Bar =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (widget.onBackToList != null) {
                          widget.onBackToList!();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Cancel / Discard',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Save & Print GRN (F2)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isSaving
                          ? null
                          : () => _savePurchase(andPrint: true),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                          PosLocalization.tr(widget.purchaseToEdit != null
                              ? 'Update Purchase Invoice'
                              : 'Save Purchase Invoice'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: _isSaving
                          ? null
                          : () => _savePurchase(andPrint: false),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= Sub-Field Widgets =================
  Widget _buildSupplierField(Color cardBg, Color borderColor, Color textPrimary,
      Color textSecondary, InputDecoration inputDeco, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Supplier *',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimary)),
            InkWell(
              onTap: _openQuickAddSupplier,
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      size: 14, color: Color(0xFF4F46E5)),
                  SizedBox(width: 4),
                  Text('Add Supplier',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<Contact>(
          isExpanded: true,
          dropdownColor: cardBg,
          decoration: inputDeco,
          style: TextStyle(fontSize: 13, color: textPrimary),
          initialValue: _selectedSupplier,
          items: _suppliers
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.name} ${s.balance > 0 ? "(Due: $currency${s.balance.toStringAsFixed(0)})" : ""}',
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _selectedSupplier = val),
        ),
        if (_selectedSupplier != null &&
            (_selectedSupplier!.phone.isNotEmpty ||
                _selectedSupplier!.address.isNotEmpty)) ...[
          const SizedBox(height: 4),
          Text(
            '${_selectedSupplier!.phone.isNotEmpty ? "Ph: ${_selectedSupplier!.phone} • " : ""}${_selectedSupplier!.address}',
            style: TextStyle(fontSize: 11, color: textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildRefNoField(Color textPrimary, InputDecoration inputDeco) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reference No',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 5),
        TextFormField(
          controller: _refNoCtrl,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration:
              inputDeco.copyWith(hintText: 'PO-2026-0001 / Vendor Inv No'),
        ),
      ],
    );
  }

  Widget _buildDateField(
      Color textPrimary, Color textSecondary, Color borderColor) {
    final formatted =
        DateFormat('dd MMM yyyy, hh:mm a').format(_purchaseDateTime);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Purchase Date *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 5),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatted,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField(
      Color cardBg, Color textPrimary, InputDecoration inputDeco) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Purchase Status *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          isExpanded: true,
          dropdownColor: cardBg,
          decoration: inputDeco,
          style: TextStyle(fontSize: 13, color: textPrimary),
          initialValue: _status,
          items: const [
            DropdownMenuItem(
                value: 'received', child: Text('Received (Stock Added)')),
            DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
            DropdownMenuItem(value: 'ordered', child: Text('Ordered')),
          ],
          onChanged: (val) => setState(() => _status = val ?? 'received'),
        ),
      ],
    );
  }

  Widget _buildLocationField(
      Color cardBg, Color textPrimary, InputDecoration inputDeco) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receiving Business Location *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 5),
        DropdownButtonFormField<BusinessLocation>(
          isExpanded: true,
          dropdownColor: cardBg,
          decoration: inputDeco,
          style: TextStyle(fontSize: 13, color: textPrimary),
          initialValue: _selectedLocation,
          items: _locations
              .map((loc) => DropdownMenuItem(
                    value: loc,
                    child: Text(loc.name,
                        style: TextStyle(fontSize: 13, color: textPrimary)),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _selectedLocation = val),
        ),
      ],
    );
  }

  Widget _buildPayTermField(Color cardBg, Color textPrimary,
      Color textSecondary, InputDecoration inputDeco) {
    final dueDate = _calculatedDueDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pay Term / Credit Period',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimary)),
            if (dueDate != null)
              Text(
                'Due: ${DateFormat('dd MMM yyyy').format(dueDate)}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444)),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _payTermNumberCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: inputDeco.copyWith(hintText: 'e.g. 30'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: cardBg,
                decoration: inputDeco,
                style: TextStyle(fontSize: 13, color: textPrimary),
                initialValue: _payTermType,
                items: const [
                  DropdownMenuItem(value: 'days', child: Text('Days')),
                  DropdownMenuItem(value: 'months', child: Text('Months')),
                ],
                onChanged: (val) =>
                    setState(() => _payTermType = val ?? 'days'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentField(Color textPrimary, InputDecoration inputDeco) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vendor Bill / Document Reference',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 5),
        TextFormField(
          controller: _documentCtrl,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration: inputDeco.copyWith(
              hintText: 'e.g. Physical Invoice / Bilty / Receipt No'),
        ),
      ],
    );
  }

  Widget _th(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2),
      ),
    );
  }

  Widget _calcChip(
      String label, String value, Color textSecondary, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
        const SizedBox(height: 1),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _quickPayChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4F46E5)),
        ),
      ),
    );
  }
}
