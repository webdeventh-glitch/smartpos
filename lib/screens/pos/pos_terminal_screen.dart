import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/keyboard_shortcuts_service.dart';
import '../../services/lan_realtime_service.dart';
import '../../services/local_api_service.dart';
import '../../services/theme_service.dart';
import 'quick_customer_dialog.dart';
import 'customer_search_dialog.dart';
import '../expenses/add_expense_dialog.dart';
import 'payment_modal.dart';
import 'receipt_dialog.dart';
import 'parked_sales_dialog.dart';
import 'register_details_dialog.dart';
import 'open_register_dialog.dart';
import 'pos_power_dialogs.dart';
import 'recent_transactions_dialog.dart';
import '../../widgets/calculator_dialog.dart';
import '../products/add_product_dialog.dart';
import '../../services/currency_rate_service.dart';
import '../../services/number_to_words_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/product_thumbnail.dart';
import '../returns/sales_return_dialog.dart';

class PosTerminalScreen extends ConsumerStatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onBackToDashboard;
  final Sale? initialSaleToResume;

  const PosTerminalScreen({
    super.key,
    required this.settings,
    this.onBackToDashboard,
    this.initialSaleToResume,
  });

  /// Parses POS quantity-prefix barcode syntax like `2*890123` or `0.5xAPPLE`.
  static ({double quantity, String code}) parseBarcodeQuantityPrefix(
    String input,
  ) {
    final trimmed = input.trim();
    final match =
        RegExp(r'^(\d+(?:\.\d+)?)\s*[*xX]\s*(.+)$').firstMatch(trimmed);
    if (match == null) {
      return (quantity: 1.0, code: trimmed);
    }
    final parsedQty = double.tryParse(match.group(1)!) ?? 1.0;
    final cleanCode = match.group(2)!.trim();
    if (parsedQty <= 0 || cleanCode.isEmpty) {
      return (quantity: 1.0, code: trimmed);
    }
    return (quantity: parsedQty, code: cleanCode);
  }

  /// Parses EAN-13 scale barcodes: `20`/`02` = weight (grams/1000), `21`..`29` = price (cents/100).
  static ({bool isPriceEmbedded, String itemCode, double value})?
      parseScaleBarcode(String code) {
    final trimmed = code.trim();
    if (trimmed.length != 13 || int.tryParse(trimmed) == null) {
      return null;
    }
    final prefix = int.tryParse(trimmed.substring(0, 2));
    if (prefix == null) return null;
    final itemCode = trimmed.substring(2, 7);
    final rawVal = int.tryParse(trimmed.substring(7, 12)) ?? 0;
    if (rawVal <= 0) return null;
    if (prefix == 20 || prefix == 2) {
      return (
        isPriceEmbedded: false,
        itemCode: itemCode,
        value: rawVal / 1000.0
      );
    }
    if (prefix >= 21 && prefix <= 29) {
      return (isPriceEmbedded: true, itemCode: itemCode, value: rawVal / 100.0);
    }
    return null;
  }

  @override
  ConsumerState<PosTerminalScreen> createState() => _PosTerminalScreenState();
}

class _PosTerminalScreenState extends ConsumerState<PosTerminalScreen> {
  late Future<DatabaseService> _dbFuture;

  // Resumed Draft / Quotation Tracking
  int? _resumedSaleId;
  String? _resumedInvoiceNo;

  // Reactive Cart State via Riverpod [cartProvider]
  List<CartItem> get _cart => ref.read(cartProvider).items;
  String get _discountType => ref.read(cartProvider).discountType;
  double get _discountValue => ref.read(cartProvider).discountValue;
  double get _orderTax => ref.read(cartProvider).orderTax;
  double get _shippingCharge => ref.read(cartProvider).shippingCharge;
  bool get _isWholesaleMode => ref.read(cartProvider).isWholesaleMode;
  double get _wholesaleDiscountPercent =>
      ref.read(cartProvider).wholesaleDiscountPercent;

  Contact? _selectedCustomer;
  List<Contact> _customers = [];
  List<CustomerGroup> _customerGroups = [];
  List<BusinessLocation> _locations = [];
  int _selectedLocationId = 1;
  List<TaxRate> _taxRates = [];
  List<TaxGroup> _taxGroups = [];

  // Industry Mode Extensions
  String _diningMode = 'Dine-In'; // 'Dine-In', 'Takeaway', 'Delivery'
  String _selectedTable = 'Table 1';
  String _assignedWaiter = 'Waiter 1';
  bool _isQuotationMode = false;

  // Search & Catalog (Cursor-Paged for 50,000+ SKU scale)
  static const int _posPageSize = 50;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _catalogScrollController = ScrollController();
  List<Category> _categories = [];
  List<Brand> _brands = [];
  int? _selectedCategoryId;
  int? _selectedBrandId;
  bool _filterFeatured = false;
  List<Product> _products = [];
  String? _catalogCursorName;
  int? _catalogCursorId;
  bool _catalogHasMore = true;
  bool _loadingCatalog = true;
  bool _loadingMoreCatalog = false;
  int _catalogQueryToken = 0;
  Timer? _catalogSearchDebounce;
  bool _isGridView =
      false; // Switchable layout: Grid vs List view (Default List view)
  bool _showProductPanel = true;
  bool _isFullscreen = false;
  int _mobileTabIndex =
      1; // For <1050px tablet compact toggle: 0 = Cart, 1 = Catalog

  // Parked bills & LAN real-time counter queue
  int _parkedCount = 0;
  StreamSubscription<Map<String, dynamic>>? _lanEventSub;
  bool _lanWsConnected = false;

  // Phase 6: Commission Agents & Scheduled Promo Discounts
  List<CommissionAgent> _commissionAgents = [];
  CommissionAgent? _selectedCommissionAgent;
  List<DiscountRule> _discountRules = [];
  String _appliedPromoRuleName = '';
  bool _manualOrderDiscountOverride = false;

  late String _wordsLanguage;
  late String _shortcutsJson;
  late Map<String, String> _shortcutBindings;

  @override
  void initState() {
    super.initState();
    _wordsLanguage = widget.settings.totalInWordsLanguage.isNotEmpty
        ? widget.settings.totalInWordsLanguage
        : 'ur';
    _showProductPanel = widget.settings.showPosProductPanel;
    _shortcutsJson = widget.settings.keyboardShortcutsJson;
    _shortcutBindings =
        KeyboardShortcutsService.resolveBindings(_shortcutsJson);
    _dbFuture = DatabaseService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(settingsProvider.notifier).setSettings(widget.settings);
      }
    });
    _catalogScrollController.addListener(_onCatalogScroll);
    _initLanRealtimeSync();
    _loadInitialData();
  }

  void _initLanRealtimeSync() {
    _lanWsConnected = LanRealtimeService.instance.wsConnected.value;
    LanRealtimeService.instance.wsConnected
        .addListener(_onLanConnectionStateChanged);
    _lanEventSub = LanRealtimeService.instance.events.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String? ?? '';
      if (type == 'drafts_updated') {
        _refreshParkedCounterQueue();
      } else if (type == 'stock_changed') {
        _reloadCatalogFromScratch();
      }
    });
    unawaited(LanRealtimeService.instance.configure(widget.settings));
  }

  void _onLanConnectionStateChanged() {
    if (!mounted) return;
    setState(() {
      _lanWsConnected = LanRealtimeService.instance.wsConnected.value;
    });
  }

  @override
  void dispose() {
    LanRealtimeService.instance.wsConnected
        .removeListener(_onLanConnectionStateChanged);
    _lanEventSub?.cancel();
    _catalogSearchDebounce?.cancel();
    _catalogScrollController.removeListener(_onCatalogScroll);
    _catalogScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onCatalogScroll() {
    if (!_catalogScrollController.hasClients ||
        _loadingCatalog ||
        _loadingMoreCatalog ||
        !_catalogHasMore) {
      return;
    }
    final pos = _catalogScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 220) {
      _loadMoreCatalogProducts();
    }
  }

  @override
  void didUpdateWidget(covariant PosTerminalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.showPosProductPanel !=
        widget.settings.showPosProductPanel) {
      setState(() {
        _showProductPanel = widget.settings.showPosProductPanel;
      });
    }
    if (oldWidget.settings.deploymentMode != widget.settings.deploymentMode ||
        oldWidget.settings.serverHost != widget.settings.serverHost ||
        oldWidget.settings.serverPort != widget.settings.serverPort) {
      unawaited(LanRealtimeService.instance.configure(widget.settings));
    }
    if (oldWidget.settings.totalInWordsLanguage !=
        widget.settings.totalInWordsLanguage) {
      if (widget.settings.totalInWordsLanguage.isNotEmpty) {
        setState(() {
          _wordsLanguage = widget.settings.totalInWordsLanguage;
        });
      }
    }
  }

  void _showWordsLanguageDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.translate, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 10),
            Text(
              'Amount in Words Language',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: NumberToWordsService.supportedLanguages.map((lang) {
              final isSelected = _wordsLanguage == lang.code;
              final previewVal = _grandTotal > 0 ? _grandTotal : 865.0;
              final previewText = NumberToWordsService.convert(
                previewVal,
                language: lang.code,
                currencySymbol: widget.settings.currencySymbol,
                currencyCode: widget.settings.currencyCode,
              );
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                tileColor: isSelected
                    ? (isDark
                        ? const Color(0xFF064E3B)
                        : const Color(0xFFDCFCE7))
                    : null,
                title: Text(
                  '${lang.name} (${lang.nativeName})',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF16A34A)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                subtitle: Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? (isDark
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF15803D))
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF16A34A), size: 20)
                    : null,
                onTap: () async {
                  setState(() => _wordsLanguage = lang.code);
                  Navigator.pop(ctx);
                  try {
                    final db = await _dbFuture;
                    final updated = widget.settings
                        .copyWith(totalInWordsLanguage: lang.code);
                    await db.updateBusinessSettings(updated);
                  } catch (e, st) {
                    AppLogger.warning('PosTerminal',
                        'Failed saving words language setting', e, st);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    final db = await _dbFuture;
    if (!mounted) return;
    // Await sequentially so sqflite never hits lock-contention watchdog timers in tests.
    final categories = await db.getCategories();
    if (!mounted) return;
    final brands = await db.getBrands();
    if (!mounted) return;
    final firstPage = await db.getProductsPaged(
      categoryId: _selectedCategoryId,
      brandId: _selectedBrandId,
      search: _searchController.text.trim(),
      featuredOnly: _filterFeatured,
      page: 1,
      pageSize: _posPageSize,
      includeTotalCount: false,
    );
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _brands = brands;
      _products = firstPage.items;
      _catalogCursorName = firstPage.nextCursorSortValue;
      _catalogCursorId = firstPage.nextCursorId;
      _catalogHasMore = firstPage.hasMore;
      _loadingMoreCatalog = false;
      _loadingCatalog = false;
    });

    final customers = await db.getContacts(type: 'customer');
    if (!mounted) return;
    final customerGroups = await db.getCustomerGroups();
    if (!mounted) return;
    final taxRates = await db.getTaxRates();
    if (!mounted) return;
    final taxGroups = await db.getTaxGroups();
    if (!mounted) return;
    final List<ParkedSale> parked = (widget.settings.isLanSecondaryTerminal &&
            widget.settings.serverHost.trim().isNotEmpty &&
            !Platform.environment.containsKey('FLUTTER_TEST'))
        ? await LanRealtimeService.instance.fetchCounterDrafts()
        : await db.getParkedSales();
    if (!mounted) return;
    final activeReg = await ref.read(activeRegisterProvider.future);
    if (!mounted) return;
    final commissionAgents = await db.getCommissionAgents(activeOnly: true);
    if (!mounted) return;
    final discountRules = await db.getDiscountRules(activeOnly: true);
    if (!mounted) return;
    final locations = await db.getBusinessLocations();
    if (!mounted) return;

    final Contact? defaultCust = customers.cast<Contact?>().firstWhere(
          (c) =>
              c!.name.toLowerCase().contains('walk-in') ||
              c.name.toLowerCase().contains('walk in'),
          orElse: () => customers.isNotEmpty ? customers.first : null,
        );

    final validLocId = locations.any((l) => l.id == _selectedLocationId)
        ? _selectedLocationId
        : (locations.isNotEmpty && locations.first.id != null
            ? locations.first.id!
            : 1);

    setState(() {
      _customers = customers;
      _customerGroups = customerGroups;
      _locations = locations;
      _selectedLocationId = validLocId;
      _taxRates = taxRates;
      _taxGroups = taxGroups;
      _selectedCustomer = defaultCust;
      _parkedCount = parked.length;
      _commissionAgents = commissionAgents;
      _discountRules = discountRules;
    });

    if (widget.initialSaleToResume != null && _resumedSaleId == null) {
      _loadResumedSale(widget.initialSaleToResume!);
    }

    if (activeReg == null) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _promptOpenRegister();
          }
        });
      }
    }
  }

  Future<void> _promptOpenRegister({bool isDismissible = true}) async {
    if (!mounted) return;
    await ref.read(activeRegisterProvider.notifier).refresh();
    if (!mounted) return;
    final active = ref.read(activeRegisterProvider).value;
    if (active != null) return;

    await showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => OpenRegisterDialog(
        settings: widget.settings,
        isDismissible: isDismissible,
        onOpened: () async {
          if (!mounted) return;
          await ref.read(activeRegisterProvider.notifier).refresh();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  /// Server-side cursor-paged catalog query (keeps UI fast across 50,000+ SKUs).
  Future<void> _reloadCatalogFromScratch() async {
    final token = ++_catalogQueryToken;
    final db = await _dbFuture;
    final page = await db.getProductsPaged(
      categoryId: _selectedCategoryId,
      brandId: _selectedBrandId,
      search: _searchController.text.trim(),
      featuredOnly: _filterFeatured,
      page: 1,
      pageSize: _posPageSize,
      includeTotalCount: false,
    );
    if (!mounted || token != _catalogQueryToken) return;
    setState(() {
      _products = page.items;
      _catalogCursorName = page.nextCursorSortValue;
      _catalogCursorId = page.nextCursorId;
      _catalogHasMore = page.hasMore;
      _loadingMoreCatalog = false;
      _loadingCatalog = false;
    });
    if (_catalogScrollController.hasClients &&
        _catalogScrollController.position.pixels > 0) {
      _catalogScrollController.jumpTo(0);
    }
  }

  Future<void> _loadMoreCatalogProducts() async {
    if (_loadingMoreCatalog || !_catalogHasMore || _catalogCursorId == null) {
      return;
    }
    final token = _catalogQueryToken;
    setState(() => _loadingMoreCatalog = true);
    final db = await _dbFuture;
    final page = await db.getProductsPaged(
      categoryId: _selectedCategoryId,
      brandId: _selectedBrandId,
      search: _searchController.text.trim(),
      featuredOnly: _filterFeatured,
      page: 1,
      pageSize: _posPageSize,
      cursorName: _catalogCursorName,
      cursorId: _catalogCursorId,
      includeTotalCount: false,
    );
    if (!mounted || token != _catalogQueryToken) return;
    final existingIds = _products.map((p) => p.id).whereType<int>().toSet();
    final nextItems = page.items.where((p) {
      if (p.id != null && existingIds.contains(p.id)) return false;
      return true;
    }).toList();
    setState(() {
      _products = [..._products, ...nextItems];
      _catalogCursorName = page.nextCursorSortValue;
      _catalogCursorId = page.nextCursorId;
      _catalogHasMore = page.hasMore;
      _loadingMoreCatalog = false;
    });
  }

  void _applyProductFilter({bool immediate = false}) {
    _catalogSearchDebounce?.cancel();
    if (immediate || Platform.environment.containsKey('FLUTTER_TEST')) {
      _reloadCatalogFromScratch();
      return;
    }
    _catalogSearchDebounce = Timer(
      const Duration(milliseconds: 180),
      _reloadCatalogFromScratch,
    );
  }

  void _toggleProductLayout() {
    setState(() {
      _isGridView = !_isGridView;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isGridView
                  ? Icons.grid_view_rounded
                  : Icons.format_list_bulleted_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              _isGridView
                  ? 'Switched to Grid View [F5]'
                  : 'Switched to List View [F5]',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        width: 270,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCategoryFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            const Icon(Icons.grid_view_outlined,
                color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text('Filter by Category',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: textSecondary),
              onPressed: () => Navigator.pop(ctx),
              splashRadius: 16,
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.all_inclusive, color: Color(0xFF4F46E5)),
                title: Text('All Categories',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textPrimary)),
                trailing: _selectedCategoryId == null
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF4F46E5), size: 20)
                    : null,
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  _applyProductFilter();
                  Navigator.pop(ctx);
                },
              ),
              Divider(height: 1, color: borderColor),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: borderColor),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final isSel = _selectedCategoryId == cat.id;
                    return ListTile(
                      title: Text(cat.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.w500,
                              color: textPrimary)),
                      trailing: isSel
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF4F46E5), size: 20)
                          : null,
                      onTap: () {
                        setState(() => _selectedCategoryId = cat.id);
                        _applyProductFilter();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrandFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            const Icon(Icons.branding_watermark_outlined,
                color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text('Filter by Brand',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: textSecondary),
              onPressed: () => Navigator.pop(ctx),
              splashRadius: 16,
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.all_inclusive, color: Color(0xFF4F46E5)),
                title: Text('All Brands',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textPrimary)),
                trailing: _selectedBrandId == null
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF4F46E5), size: 20)
                    : null,
                onTap: () {
                  setState(() => _selectedBrandId = null);
                  _applyProductFilter();
                  Navigator.pop(ctx);
                },
              ),
              Divider(height: 1, color: borderColor),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _brands.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: borderColor),
                  itemBuilder: (_, i) {
                    final b = _brands[i];
                    final isSel = _selectedBrandId == b.id;
                    return ListTile(
                      title: Text(b.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.w500,
                              color: textPrimary)),
                      trailing: isSel
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF4F46E5), size: 20)
                          : null,
                      onTap: () {
                        setState(() => _selectedBrandId = b.id);
                        _applyProductFilter();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDiscountDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please add products to cart before applying discount.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = AuthService.currentUser;
    final canGiveDiscount = currentUser == null
        ? true
        : currentUser.hasPermission('pos.give_discount');
    final maxDiscPercent = currentUser?.maxDiscountPercent ??
        ((currentUser?.isAdmin == true) ? 100.0 : 5.0);

    if (!canGiveDiscount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Permission Denied: Discounting is disabled for this salesman account by the Owner.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final subtleBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    String tempType = _discountType;
    final controller = TextEditingController(
      text: _discountValue > 0
          ? (_discountValue.truncateToDouble() == _discountValue
              ? _discountValue.toInt().toString()
              : _discountValue.toString())
          : '',
    );
    final currency = widget.settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final inputVal = double.tryParse(controller.text.trim()) ?? 0.0;
          double calcDiscAmt = 0.0;
          if (tempType == 'percentage') {
            calcDiscAmt =
                (_subtotal * (inputVal / 100.0)).clamp(0.0, _subtotal);
          } else {
            calcDiscAmt = inputVal.clamp(0.0, _subtotal);
          }
          final newTotal =
              (_subtotal - calcDiscAmt + _orderTax + _shippingCharge)
                  .clamp(0.0, double.infinity);

          return AlertDialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF312E81)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.discount_outlined,
                      color: isDark
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFF4F46E5),
                      size: 20),
                ),
                const SizedBox(width: 10),
                Text('Order Discount System',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary)),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  splashRadius: 16,
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discount Type',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textSecondary)),
                  const SizedBox(height: 8),

                  // Segmented Switcher: [ % Percentage ] [ Fixed Amount ]
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: inputBorder),
                    ),
                    child: Row(
                      children: [
                        // Percentage Button
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDlgState(() => tempType = 'percentage'),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tempType == 'percentage'
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: tempType == 'percentage'
                                    ? [
                                        BoxShadow(
                                            color: const Color(0xFF4F46E5)
                                                .withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1))
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.percent,
                                      size: 14,
                                      color: tempType == 'percentage'
                                          ? Colors.white
                                          : textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Percentage (%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tempType == 'percentage'
                                          ? Colors.white
                                          : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Fixed Amount Button
                        Expanded(
                          child: InkWell(
                            onTap: () => setDlgState(() => tempType = 'fixed'),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tempType == 'fixed'
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: tempType == 'fixed'
                                    ? [
                                        BoxShadow(
                                            color: const Color(0xFF4F46E5)
                                                .withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1))
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.payments_outlined,
                                      size: 14,
                                      color: tempType == 'fixed'
                                          ? Colors.white
                                          : textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fixed ($currency)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tempType == 'fixed'
                                          ? Colors.white
                                          : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Discount Value Input Field
                  Text(
                    tempType == 'percentage'
                        ? 'Enter Percentage Rate (%)'
                        : 'Enter Fixed Discount Amount ($currency)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 14, color: textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBg,
                      prefixIcon: Icon(
                        tempType == 'percentage'
                            ? Icons.percent
                            : Icons.attach_money,
                        size: 18,
                        color: const Color(0xFF4F46E5),
                      ),
                      suffixText: tempType == 'percentage' ? '%' : currency,
                      suffixStyle: TextStyle(
                          fontWeight: FontWeight.bold, color: textSecondary),
                      hintText:
                          tempType == 'percentage' ? 'e.g. 10' : 'e.g. 150',
                      hintStyle: TextStyle(color: textSecondary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF4F46E5), width: 1.5)),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Quick Preset Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tempType == 'percentage'
                        ? [
                            _presetChip(
                                '0%', 0, controller, setDlgState, isDark),
                            _presetChip(
                                '5%', 5, controller, setDlgState, isDark),
                            _presetChip(
                                '10%', 10, controller, setDlgState, isDark),
                            _presetChip(
                                '15%', 15, controller, setDlgState, isDark),
                            _presetChip(
                                '20%', 20, controller, setDlgState, isDark),
                            _presetChip(
                                '25%', 25, controller, setDlgState, isDark),
                            _presetChip(
                                '50%', 50, controller, setDlgState, isDark),
                          ]
                        : [
                            _presetChip(
                                'Clear', 0, controller, setDlgState, isDark),
                            _presetChip(
                                '50', 50, controller, setDlgState, isDark),
                            _presetChip(
                                '100', 100, controller, setDlgState, isDark),
                            _presetChip(
                                '200', 200, controller, setDlgState, isDark),
                            _presetChip(
                                '500', 500, controller, setDlgState, isDark),
                            _presetChip(
                                '1000', 1000, controller, setDlgState, isDark),
                          ],
                  ),
                  const SizedBox(height: 14),

                  // Live Calculation Preview Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: subtleBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal:',
                                style: TextStyle(
                                    fontSize: 12, color: textSecondary)),
                            Text('$currency ${_subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount (${tempType == 'percentage' ? '${inputVal.toStringAsFixed(0)}%' : 'Fixed'}):',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                                '- $currency ${calcDiscAmt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFEF4444))),
                          ],
                        ),
                        Divider(height: 12, color: borderColor),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('New Total Payable:',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A))),
                            Text('$currency ${newTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF16A34A))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref
                      .read(cartProvider.notifier)
                      .setOrderDiscount('fixed', 0.0);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Discount removed.'),
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFF475569),
                      duration: const Duration(milliseconds: 900),
                    ),
                  );
                },
                child: const Text('Clear Discount',
                    style: TextStyle(
                        color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final parsed = double.tryParse(controller.text.trim()) ?? 0.0;

                  if (tempType == 'percentage' && parsed > maxDiscPercent) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Limit Exceeded: Maximum authorized discount for this salesman is ${maxDiscPercent.toStringAsFixed(0)}%!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (tempType == 'fixed' && _subtotal > 0) {
                    final effectivePct = (parsed / _subtotal) * 100.0;
                    if (effectivePct > maxDiscPercent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Fixed discount exceeds your maximum authorized rate of ${maxDiscPercent.toStringAsFixed(0)}%!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  ref
                      .read(cartProvider.notifier)
                      .setOrderDiscount(tempType, parsed);
                  Navigator.pop(ctx);

                  final saved = _calculatedDiscount;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _discountValue > 0
                            ? 'Discount applied: $currency ${saved.toStringAsFixed(2)} saved!'
                            : 'Discount updated.',
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text('Apply Discount',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _presetChip(String label, double val, TextEditingController c,
      StateSetter setDlgState,
      [bool isDark = false]) {
    return InkWell(
      onTap: () {
        setDlgState(() {
          c.text = val > 0
              ? (val.truncateToDouble() == val
                  ? val.toInt().toString()
                  : val.toString())
              : '';
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFA5B4FC)
                    : const Color(0xFF4F46E5))),
      ),
    );
  }

  void _toggleWholesaleMode() {
    ref.read(cartProvider.notifier).toggleWholesaleMode();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isWholesaleMode
                  ? Icons.inventory_2_rounded
                  : Icons.storefront_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isWholesaleMode
                    ? 'Wholesale Tier Mode: Activated (${_wholesaleDiscountPercent.toInt()}% Bulk Markdown)'
                    : 'Retail Mode: Activated',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: _isWholesaleMode
            ? const Color(0xFF0891B2)
            : const Color(0xFF1E293B),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openCustomProductDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUnit = 'Pc';
    final currency = widget.settings.currencySymbol;

    final commonUnits = [
      'Pc',
      'Kg',
      'Ltr',
      'Mtr',
      'Box',
      'Ctn',
      'Pkt',
      'Bag',
      'Dzn',
      'Sq Ft',
      'Roll'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x1F4F46E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on_rounded,
                      color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Custom Item',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary),
                      ),
                      Text(
                        'Sell uncataloged walk-in item, loose weight, cut or service directly',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item Description / Name *',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 14, color: textPrimary),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Loose Sugar, Cut Iron 10m, Labor Charge, Custom Part',
                        hintStyle:
                            TextStyle(fontSize: 12, color: textSecondary),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorder)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit Price ($currency) *',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style:
                                    TextStyle(fontSize: 14, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: TextStyle(
                                      fontSize: 12, color: textSecondary),
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: inputBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: inputBorder)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quantity (Decimals OK) *',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: qtyCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style:
                                    TextStyle(fontSize: 14, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: '1.0',
                                  hintStyle: TextStyle(
                                      fontSize: 12, color: textSecondary),
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: inputBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: inputBorder)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick decimal quantity presets
                    Row(
                      children: [
                        Text('Quick Qty: ',
                            style:
                                TextStyle(fontSize: 11, color: textSecondary)),
                        Wrap(
                          spacing: 5,
                          children: [0.25, 0.5, 1.0, 1.5, 2.5, 5.0].map((q) {
                            return InkWell(
                              onTap: () {
                                qtyCtrl.text = q == q.toInt()
                                    ? q.toInt().toString()
                                    : q.toString();
                                setDlgState(() {});
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: borderColor, width: 0.8),
                                ),
                                child: Text(
                                  q == q.toInt()
                                      ? q.toInt().toString()
                                      : q.toString(),
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text('Measurement Unit',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: commonUnits.map((u) {
                        final isSel = selectedUnit == u;
                        return InkWell(
                          onTap: () => setDlgState(() => selectedUnit = u),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF4F46E5)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter an item description.')),
                    );
                    return;
                  }
                  if (price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a valid price.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final customProduct = Product(
                    id: null,
                    name: name,
                    sku:
                        'OPEN-${DateTime.now().millisecondsSinceEpoch % 100000}',
                    barcode: '',
                    unit: selectedUnit,
                    purchasePrice: price,
                    sellingPrice: price,
                    stockQuantity: 9999.0,
                  );
                  ref.read(cartProvider.notifier).addCustomItem(
                        CartItem(
                          product: customProduct,
                          quantity: qty,
                          unitPrice: price,
                          packDiscount: _isWholesaleMode
                              ? _wholesaleDiscountPercent
                              : 0.0,
                        ),
                      );
                },
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openQuantityDialog(CartItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final initialQty = item.quantity == item.quantity.toInt()
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    final qtyCtrl = TextEditingController(text: initialQty);

    final rawUnit = item.product.unit.toLowerCase().trim();

    // 1. Weight / Weighed items (تولنے والا وزن - کلو، گرام، من، دھڑی)
    final isWeight = rawUnit.contains('kg') ||
        rawUnit.contains('kilo') ||
        rawUnit.contains('gram') ||
        rawUnit.contains('gm') ||
        rawUnit == 'g' ||
        rawUnit.contains('mann') ||
        rawUnit.contains('maund') ||
        rawUnit.contains('dhari') ||
        rawUnit.contains('pao') ||
        rawUnit.contains('ton') ||
        rawUnit.contains('bori') ||
        rawUnit.contains('sack');

    // 2. Liquid / Volume items (مائع پیمائش - لیٹر، ملی لیٹر)
    final isLiquid = rawUnit.contains('liter') ||
        rawUnit.contains('litre') ||
        rawUnit.contains('ltr') ||
        rawUnit.contains('ml') ||
        rawUnit.contains('gallon') ||
        rawUnit.contains('gal');

    // 3. Length / Fabric / Measurement (پیمائش - میٹر، گز، فٹ، انچ)
    final isMeasurement = rawUnit.contains('meter') ||
        rawUnit.contains('mtr') ||
        rawUnit == 'm' ||
        rawUnit.contains('ghaz') ||
        rawUnit.contains('guz') ||
        rawUnit.contains('yard') ||
        rawUnit.contains('yd') ||
        rawUnit.contains('foot') ||
        rawUnit.contains('feet') ||
        rawUnit.contains('ft') ||
        rawUnit.contains('inch') ||
        rawUnit.contains('sqft') ||
        rawUnit.contains('sqm') ||
        rawUnit.contains('marla');

    // Dynamic Headers, Colors, and Presets
    final String dlgTitle;
    final String dlgSubTitle;
    final IconData dlgIcon;
    final Color dlgColor;
    final String inputLabel;
    final String badgeLabel;
    final List<Map<String, dynamic>> presets;

    final s = widget.settings;

    if (isWeight) {
      dlgTitle = PosLocalization.tr('Adjust Weight', settings: s);
      dlgSubTitle =
          '${PosLocalization.tr('Weight Scale', settings: s)} • ${item.product.name}';
      dlgIcon = Icons.scale_rounded;
      dlgColor = const Color(0xFFD97706);
      inputLabel =
          '${PosLocalization.tr('Adjust Weight', settings: s)} (${item.product.unit.isNotEmpty ? item.product.unit : "Kg"})';
      badgeLabel = PosLocalization.tr('Weight Scale', settings: s);
      presets = [
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 0.25, unitCategory: 'weight', settings: s),
          'val': 0.25
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 0.50, unitCategory: 'weight', settings: s),
          'val': 0.50
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 0.75, unitCategory: 'weight', settings: s),
          'val': 0.75
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 1.0, unitCategory: 'weight', settings: s),
          'val': 1.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 1.5, unitCategory: 'weight', settings: s),
          'val': 1.5
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 2.0, unitCategory: 'weight', settings: s),
          'val': 2.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 2.5, unitCategory: 'weight', settings: s),
          'val': 2.5
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 5.0, unitCategory: 'weight', settings: s),
          'val': 5.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 10.0, unitCategory: 'weight', settings: s),
          'val': 10.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 20.0, unitCategory: 'weight', settings: s),
          'val': 20.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 40.0, unitCategory: 'weight', settings: s),
          'val': 40.0
        },
      ];
    } else if (isMeasurement) {
      dlgTitle = PosLocalization.tr('Adjust Measurement', settings: s);
      dlgSubTitle =
          '${PosLocalization.tr('Measurement / Fabric', settings: s)} • ${item.product.name}';
      dlgIcon = Icons.straighten_rounded;
      dlgColor = const Color(0xFF0D9488);
      inputLabel =
          '${PosLocalization.tr('Adjust Measurement', settings: s)} (${item.product.unit.isNotEmpty ? item.product.unit : "Meter"})';
      badgeLabel = PosLocalization.tr('Measurement / Fabric', settings: s);
      presets = [
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 0.50, unitCategory: 'length', settings: s),
          'val': 0.50
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 1.0, unitCategory: 'length', settings: s),
          'val': 1.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 1.5, unitCategory: 'length', settings: s),
          'val': 1.5
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 2.0, unitCategory: 'length', settings: s),
          'val': 2.0
        },
        {'label': '2.25', 'val': 2.25},
        {'label': '2.50', 'val': 2.50},
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 3.0, unitCategory: 'length', settings: s),
          'val': 3.0
        },
        {'label': '4.0', 'val': 4.0},
        {'label': '4.50', 'val': 4.50},
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 5.0, unitCategory: 'length', settings: s),
          'val': 5.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 10.0, unitCategory: 'length', settings: s),
          'val': 10.0
        },
        {'label': '25.0', 'val': 25.0},
      ];
    } else if (isLiquid) {
      dlgTitle = PosLocalization.tr('Adjust Volume', settings: s);
      dlgSubTitle =
          '${PosLocalization.tr('Liquid Volume', settings: s)} • ${item.product.name}';
      dlgIcon = Icons.water_drop_outlined;
      dlgColor = const Color(0xFF0284C7);
      inputLabel =
          '${PosLocalization.tr('Adjust Volume', settings: s)} (${item.product.unit.isNotEmpty ? item.product.unit : "Liter"})';
      badgeLabel = PosLocalization.tr('Liquid Volume', settings: s);
      presets = [
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 0.25, unitCategory: 'volume', settings: s),
          'val': 0.25
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 0.50, unitCategory: 'volume', settings: s),
          'val': 0.50
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 0.75, unitCategory: 'volume', settings: s),
          'val': 0.75
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 1.0, unitCategory: 'volume', settings: s),
          'val': 1.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 1.5, unitCategory: 'volume', settings: s),
          'val': 1.5
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 2.0, unitCategory: 'volume', settings: s),
          'val': 2.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 2.5, unitCategory: 'volume', settings: s),
          'val': 2.5
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 5.0, unitCategory: 'volume', settings: s),
          'val': 5.0
        },
        {
          'label': PosLocalization.quickQuantityLabel(
              val: 10.0, unitCategory: 'volume', settings: s),
          'val': 10.0
        },
        {'label': '16.0', 'val': 16.0},
      ];
    } else {
      // Discrete / Count Units
      dlgTitle = PosLocalization.tr('Adjust Quantity', settings: s);
      dlgSubTitle =
          '${PosLocalization.tr('Count / Discrete Item', settings: s)} • ${item.product.name}';
      dlgIcon = Icons.inventory_2_outlined;
      dlgColor = const Color(0xFF4F46E5);
      inputLabel =
          '${PosLocalization.tr('Adjust Quantity', settings: s)} (${item.product.unit.isNotEmpty ? item.product.unit : "Pieces"})';
      badgeLabel = PosLocalization.tr('Count / Discrete Item', settings: s);
      presets = [
        {'label': '1', 'val': 1.0},
        {'label': '2', 'val': 2.0},
        {'label': '3', 'val': 3.0},
        {'label': '4', 'val': 4.0},
        {'label': '5', 'val': 5.0},
        {'label': '6 (½ Dozen)', 'val': 6.0},
        {'label': '10', 'val': 10.0},
        {'label': '12 (1 Dozen)', 'val': 12.0},
        {'label': '20', 'val': 20.0},
        {'label': '24 (2 Dozen)', 'val': 24.0},
        {'label': '50 (Pack)', 'val': 50.0},
        {'label': '100 (Carton)', 'val': 100.0},
      ];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final curQty = double.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
          final totalVal = curQty * item.unitPrice;

          return Dialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                color: dlgColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(dlgIcon, color: dlgColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dlgTitle,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textPrimary),
                                ),
                                Text(
                                  dlgSubTitle,
                                  style: TextStyle(
                                      fontSize: 11, color: textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.close, size: 20, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Product & Current Unit Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                PosLocalization.tr('Unit of Measure',
                                    settings: widget.settings),
                                style: TextStyle(
                                    fontSize: 10, color: textSecondary),
                              ),
                              Text(
                                  item.selectedUnitName ??
                                      (item.product.unit.isNotEmpty
                                          ? item.product.unit
                                          : 'Standard Unit'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: textPrimary)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: dlgColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: dlgColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(badgeLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: dlgColor)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Rate / Unit',
                                  style: TextStyle(
                                      fontSize: 10, color: textSecondary)),
                              Text(
                                  '${widget.settings.currencySymbol} ${item.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF10B981))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Active Selling Sub-Unit Switcher Chips
                    FutureBuilder<List<Unit>>(
                      future: DatabaseService.initialize().then((db) =>
                          db.getConversionUnitsForProduct(item.product)),
                      builder: (ctx, snapshot) {
                        final uList = snapshot.data ?? [];
                        if (uList.length <= 1) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                PosLocalization.tr('Change Active Selling Unit',
                                    settings: widget.settings),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: uList.map((u) {
                                  final isCur = (item.selectedUnitName ??
                                              item.product.unit)
                                          .toLowerCase()
                                          .trim() ==
                                      u.actualName.toLowerCase().trim();
                                  final rate =
                                      item.basePrice * u.baseUnitMultiplier;
                                  return ChoiceChip(
                                    label: Text(
                                      '${u.actualName} (${widget.settings.currencySymbol} ${rate.toStringAsFixed(2)})',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isCur
                                              ? FontWeight.bold
                                              : FontWeight.normal),
                                    ),
                                    selected: isCur,
                                    selectedColor: dlgColor,
                                    labelStyle: TextStyle(
                                        color:
                                            isCur ? Colors.white : textPrimary),
                                    onSelected: (selected) {
                                      if (selected) {
                                        ref
                                            .read(cartProvider.notifier)
                                            .changeItemUnit(
                                              index,
                                              u.actualName,
                                              u.baseUnitMultiplier,
                                            );
                                        setDlgState(() {
                                          item.changeUnit(u.actualName,
                                              u.baseUnitMultiplier);
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Direct input field with Step Buttons [-] and [+]
                    Text(inputLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Decrease',
                          onPressed: () {
                            double q =
                                double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                            final step =
                                (!isWeight && !isMeasurement && !isLiquid)
                                    ? 1.0
                                    : (isWeight ? 0.25 : 0.5);
                            q = (q - step).clamp(0.0, 99999.0);
                            qtyCtrl.text = q == q.toInt()
                                ? q.toInt().toString()
                                : q.toString();
                            setDlgState(() {});
                          },
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 28, color: Colors.red),
                        ),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: inputBg,
                              suffixText: item.product.unit,
                              suffixStyle: TextStyle(
                                  fontWeight: FontWeight.bold, color: dlgColor),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Increase',
                          onPressed: () {
                            double q =
                                double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                            final step =
                                (!isWeight && !isMeasurement && !isLiquid)
                                    ? 1.0
                                    : (isWeight ? 0.25 : 0.5);
                            q = q + step;
                            qtyCtrl.text = q == q.toInt()
                                ? q.toInt().toString()
                                : q.toString();
                            setDlgState(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline,
                              size: 28, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Smart Context-Aware Quick Presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((p) {
                        return InkWell(
                          onTap: () {
                            final val = p['val'] as num;
                            qtyCtrl.text = val == val.toInt()
                                ? val.toInt().toString()
                                : val.toString();
                            setDlgState(() {});
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              p['label'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Total Calculation Preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Calculated Line Total:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: textPrimary)),
                          Text(
                            '${widget.settings.currencySymbol} ${totalVal.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel',
                              style: TextStyle(color: textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            final newQty =
                                double.tryParse(qtyCtrl.text.trim()) ??
                                    item.quantity;
                            ref
                                .read(cartProvider.notifier)
                                .setQuantity(index, newQty);
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Apply Quantity'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dlgColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openUnitSelectorForCartItem(CartItem item, int index) async {
    final db = await DatabaseService.initialize();
    final units = await db.getConversionUnitsForProduct(item.product);
    if (!mounted || units.length <= 1) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select Unit: ${item.product.name}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            ...units.map((u) {
              final isCur = (item.selectedUnitName ?? item.product.unit)
                      .toLowerCase()
                      .trim() ==
                  u.actualName.toLowerCase().trim();
              final rate = item.basePrice * u.baseUnitMultiplier;
              return ListTile(
                dense: true,
                leading: Icon(
                    isCur
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: isCur ? const Color(0xFF10B981) : Colors.grey),
                title: Text(u.actualName,
                    style: TextStyle(
                        fontWeight:
                            isCur ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(
                    'Multiplier: ${u.baseUnitMultiplier}x  •  Base: ${item.product.unit}'),
                trailing: Text(
                  '${widget.settings.currencySymbol} ${rate.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                      fontSize: 13),
                ),
                onTap: () {
                  ref.read(cartProvider.notifier).changeItemUnit(
                        index,
                        u.actualName,
                        u.baseUnitMultiplier,
                      );
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showItemDiscountDialog(CartItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final subtleBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final currentUser = AuthService.currentUser;
    final canEditPrice = currentUser == null
        ? false
        : currentUser.hasPermission('pos.edit_price');
    final canGiveDiscount = currentUser == null
        ? true
        : currentUser.hasPermission('pos.give_discount');
    final maxDiscPercent = currentUser?.maxDiscountPercent ??
        ((currentUser?.isAdmin == true) ? 100.0 : 5.0);

    String lineDiscType =
        (item.discountType == 'percentage' || item.packDiscount > 0)
            ? 'percentage'
            : 'fixed';
    final initialDisc = lineDiscType == 'percentage'
        ? (item.discountValue > 0 ? item.discountValue : item.packDiscount)
        : (item.discount > 0 ? item.discount : item.discountValue);
    final priceCtrl =
        TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final discCtrl = TextEditingController(
      text: initialDisc > 0
          ? (initialDisc.truncateToDouble() == initialDisc
              ? initialDisc.toInt().toString()
              : initialDisc.toString())
          : '',
    );
    final currency = widget.settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final curUnitPrice =
              double.tryParse(priceCtrl.text.trim()) ?? item.unitPrice;
          final curDiscVal = double.tryParse(discCtrl.text.trim()) ?? 0.0;
          final packVal = curUnitPrice * item.quantity;
          double lineDiscAmt = 0.0;
          if (lineDiscType == 'percentage') {
            lineDiscAmt = (packVal * (curDiscVal / 100.0)).clamp(0.0, packVal);
          } else {
            lineDiscAmt = curDiscVal.clamp(0.0, packVal);
          }
          final lineSubtotal = packVal - lineDiscAmt;

          return AlertDialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Item Pricing: ${item.product.name}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  splashRadius: 16,
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit Price
                  Row(
                    children: [
                      Text('Unit Price ($currency)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textSecondary)),
                      const SizedBox(width: 16),
                      if (!canEditPrice)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded,
                                  size: 10, color: Color(0xFFD97706)),
                              SizedBox(width: 3),
                              Text('Locked by Owner',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706))),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceCtrl,
                    readOnly: !canEditPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                        fontSize: 14,
                        color: !canEditPrice
                            ? const Color(0xFF94A3B8)
                            : textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: !canEditPrice
                          ? (isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9))
                          : inputBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder)),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),

                  if (!canGiveDiscount) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Discounts are restricted for this account by the Business Owner.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Discount Type
                    Row(
                      children: [
                        Text('Discount Type',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textSecondary)),
                        const SizedBox(width: 16),
                        Text('Max Limit: ${maxDiscPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 34,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: inputBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(
                                  () => lineDiscType = 'percentage'),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: lineDiscType == 'percentage'
                                      ? const Color(0xFF4F46E5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Percentage (%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: lineDiscType == 'percentage'
                                        ? Colors.white
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setDlgState(() => lineDiscType = 'fixed'),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: lineDiscType == 'fixed'
                                      ? const Color(0xFF4F46E5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Fixed ($currency)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: lineDiscType == 'fixed'
                                        ? Colors.white
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Discount Value
                    Text(
                      lineDiscType == 'percentage'
                          ? 'Discount Rate (%)'
                          : 'Discount Amount ($currency)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: discCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 14, color: textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorder)),
                        suffixText:
                            lineDiscType == 'percentage' ? '%' : currency,
                        suffixStyle: TextStyle(
                            fontWeight: FontWeight.bold, color: textSecondary),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Preview
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: subtleBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Line Subtotal (${item.quantity.toInt()} ${item.product.unit}):',
                            style:
                                TextStyle(fontSize: 12, color: textSecondary)),
                        Text('$currency ${lineSubtotal.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).updateLineItem(
                        index,
                        unitPrice: item.unitPrice,
                        discount: 0.0,
                        packDiscount: 0.0,
                        discountType: 'fixed',
                        discountValue: 0.0,
                      );
                  Navigator.pop(ctx);
                },
                child: const Text('Clear Discount',
                    style: TextStyle(color: Color(0xFFEF4444))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white),
                onPressed: () {
                  final newPrice =
                      double.tryParse(priceCtrl.text.trim()) ?? item.unitPrice;
                  final newDisc = double.tryParse(discCtrl.text.trim()) ?? 0.0;

                  if (newPrice != item.unitPrice && !canEditPrice) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Permission Denied: Changing unit prices is not authorized for this salesman account.'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (newDisc > 0 && !canGiveDiscount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Permission Denied: Discounts are disabled for this account.'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (lineDiscType == 'percentage' &&
                      newDisc > maxDiscPercent) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Limit Exceeded: Maximum authorized discount is ${maxDiscPercent.toStringAsFixed(0)}%!'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (lineDiscType == 'fixed' && item.unitPrice > 0) {
                    final effective =
                        (newDisc / (item.unitPrice * item.quantity)) * 100.0;
                    if (effective > maxDiscPercent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Fixed discount exceeds maximum allowed rate of ${maxDiscPercent.toStringAsFixed(0)}%!'),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                  }

                  ref.read(cartProvider.notifier).updateLineItem(
                        index,
                        unitPrice: newPrice,
                        discount: lineDiscType == 'percentage' ? 0.0 : newDisc,
                        packDiscount:
                            lineDiscType == 'percentage' ? newDisc : 0.0,
                        discountType: lineDiscType,
                        discountValue: newDisc,
                      );
                  Navigator.pop(ctx);
                },
                child: const Text('Update Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showOrderTaxDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    if (_taxRates.isEmpty || _taxGroups.isEmpty) {
      final db = await _dbFuture;
      final rates = await db.getTaxRates();
      final groups = await db.getTaxGroups();
      if (mounted) {
        setState(() {
          _taxRates = rates;
          _taxGroups = groups;
        });
      }
    }
    if (!mounted) return;

    final cartSnap = ref.read(cartProvider);
    final taxableBase = cartSnap.taxableSubtotal;
    final controller = TextEditingController(
        text: _orderTax > 0 ? _orderTax.toStringAsFixed(2) : '');
    final currency = widget.settings.currencySymbol;
    TaxGroup? chosenGroup = cartSnap.selectedTaxGroup;
    TaxRate? chosenRate = cartSnap.selectedTaxRate;
    Map<String, double> previewBreakdown =
        Map<String, double>.from(cartSnap.taxBreakdown);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Order Tax & Compound Tax Groups',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_taxGroups.isNotEmpty) ...[
                    Text(
                        'Compound / Group Taxes (Taxable: $currency${taxableBase.toStringAsFixed(2)}):',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _taxGroups.map((g) {
                        final selected = chosenGroup?.id == g.id;
                        final eff = g.computeEffectiveRate(_taxRates);
                        return ChoiceChip(
                          label: Text(
                            '${g.name} (${g.isCompound ? "Compound" : "Additive"} ${eff.toStringAsFixed(2)}%)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: selected,
                          onSelected: (_) {
                            final bd =
                                g.calculateBreakdown(taxableBase, _taxRates);
                            final tot =
                                g.calculateTotalTax(taxableBase, _taxRates);
                            setDlgState(() {
                              chosenGroup = g;
                              chosenRate = null;
                              previewBreakdown = bd;
                              controller.text = tot.toStringAsFixed(2);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_taxRates.isNotEmpty) ...[
                    Text('Single Tax Rates:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _taxRates.map((r) {
                        final selected =
                            chosenRate?.id == r.id && chosenGroup == null;
                        return ChoiceChip(
                          label: Text(
                              '${r.name} (${r.amount.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11)),
                          selected: selected,
                          onSelected: (_) {
                            final amt = double.parse(
                                (taxableBase * (r.amount / 100.0))
                                    .toStringAsFixed(2));
                            setDlgState(() {
                              chosenGroup = null;
                              chosenRate = r;
                              previewBreakdown = {
                                '${r.name} (${r.amount}%)': amt
                              };
                              controller.text = amt.toStringAsFixed(2);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (previewBreakdown.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF312E81)
                                : const Color(0xFFC7D2FE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tax Breakdown:',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary)),
                          const SizedBox(height: 4),
                          ...previewBreakdown.entries.map(
                            (e) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key,
                                    style: TextStyle(
                                        fontSize: 11.5, color: textSecondary)),
                                Text('$currency${e.value.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text('Custom / Manual Tax Override ($currency):',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 14, color: textPrimary),
                    onChanged: (_) {
                      if (chosenGroup != null || chosenRate != null) {
                        setDlgState(() {
                          chosenGroup = null;
                          chosenRate = null;
                          previewBreakdown = {};
                        });
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBg,
                      prefixText: '$currency ',
                      prefixStyle: TextStyle(
                          color: textPrimary, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).setOrderTax(0.0);
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white),
              onPressed: () {
                final notifier = ref.read(cartProvider.notifier);
                if (chosenGroup != null) {
                  notifier.applyTaxGroup(chosenGroup, _taxRates);
                } else if (chosenRate != null) {
                  notifier.applyTaxRate(chosenRate);
                } else {
                  final parsed = double.tryParse(controller.text.trim()) ?? 0.0;
                  notifier.setOrderTax(parsed < 0.0 ? 0.0 : parsed);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Apply Tax'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShippingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final controller = TextEditingController(
        text: _shippingCharge > 0 ? _shippingCharge.toString() : '');
    final currency = widget.settings.currencySymbol;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Shipping & Delivery Charges',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Delivery / Shipping Charge:',
                style: TextStyle(fontSize: 12, color: textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14, color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                prefixText: '$currency ',
                prefixStyle:
                    TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: inputBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: inputBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).setShippingCharge(0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white),
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim()) ?? 0.0;
              ref
                  .read(cartProvider.notifier)
                  .setShippingCharge(parsed < 0.0 ? 0.0 : parsed);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  int? _getDaysUntilExpiry(String? expiryDate) =>
      calculateDaysUntilExpiry(expiryDate);

  Future<ProductVariation?> _showVariationSelectorDialog(
    Product product,
    List<ProductVariation> variations,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    return showDialog<ProductVariation>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            ProductThumbnail(
              imagePath: product.resolvedImagePath,
              imageColor: product.imageColor,
              size: 44,
              borderRadius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Select Variation • SKU: ${product.sku}',
                    style: TextStyle(
                      fontSize: 12,
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
        content: SizedBox(
          width: 440,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: variations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final v = variations[idx];
                final outOfStock = v.stockQuantity <= 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (outOfStock) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${product.name} (${v.name}) is OUT OF STOCK!'),
                          backgroundColor: const Color(0xFFEF4444),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx, v);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: outOfStock
                          ? (isDark
                              ? const Color(0xFF450A0A).withValues(alpha: 0.35)
                              : const Color(0xFFFEF2F2))
                          : (isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: outOfStock
                            ? const Color(0xFFFCA5A5)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'SKU: ${v.subSku} • Stock: ${v.stockQuantity % 1 == 0 ? v.stockQuantity.toInt() : v.stockQuantity.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: outOfStock
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$currency ${v.sellingPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(
    Product product, {
    ProductVariation? preselectedVariation,
  }) async {
    ProductVariation? chosen = preselectedVariation;
    if (product.isVariable && chosen == null && product.id != null) {
      final db = await _dbFuture;
      final variations = await db.getProductVariations(product.id!);
      if (!mounted) return;
      if (variations.isNotEmpty) {
        chosen = await _showVariationSelectorDialog(product, variations);
        if (chosen == null || !mounted) return;
      }
    }

    final effectiveStock = chosen?.stockQuantity ?? product.stockQuantity;
    final labelName =
        chosen != null ? '${product.name} (${chosen.name})' : product.name;
    final alreadyInCart = _cartBaseQtyFor(product, chosen);
    if (!widget.settings.allowOverselling &&
        (effectiveStock <= 0 || alreadyInCart + 1.0 > effectiveStock)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            effectiveStock <= 0
                ? '$labelName is OUT OF STOCK!'
                : 'Insufficient stock for $labelName (Available: ${effectiveStock.toStringAsFixed(effectiveStock % 1 == 0 ? 0 : 2)}).',
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final expDays = _getDaysUntilExpiry(product.expiryDate);
    if (expDays != null && expDays <= 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expDays < 0
                ? 'WARNING: ${product.name} is EXPIRED (${product.expiryDate})!'
                : 'NOTICE: ${product.name} nearing expiry ($expDays days left • ${product.expiryDate}).',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              expDays < 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    ref.read(cartProvider.notifier).addProduct(product, variation: chosen);
    _applyProductTaxIfConfigured(product);
    _refocusBarcodeIfEnabled();
  }

  void _refocusBarcodeIfEnabled() {
    if (widget.settings.autoFocusBarcodeSearch && mounted) {
      _searchFocusNode.requestFocus();
    }
  }

  void _toggleProductPanelVisibility() {
    setState(() {
      _showProductPanel = !_showProductPanel;
    });
    _refocusBarcodeIfEnabled();
  }

  double _cartBaseQtyFor(Product product, ProductVariation? variation) {
    return _cart
        .where((item) =>
            item.product.id != null &&
            item.product.id == product.id &&
            item.variationId == variation?.id)
        .fold<double>(
            0.0, (sum, item) => sum + (item.quantity * item.unitMultiplier));
  }

  void _tryIncrementCartItem(int index) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    if (!widget.settings.allowOverselling) {
      final step = (item.quantity < 1 && item.quantity >= 0.25) ? 0.25 : 1.0;
      final addBase = step * item.unitMultiplier;
      final maxStock = item.product.stockQuantity;
      final existingBase = _cartBaseQtyFor(item.product, null);
      if (existingBase + addBase > maxStock && item.variationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock limit reached for ${item.product.name} (${maxStock.toStringAsFixed(maxStock % 1 == 0 ? 0 : 2)} available).',
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    ref.read(cartProvider.notifier).incrementQuantity(index);
  }

  void _applyProductTaxIfConfigured(Product product) {
    final snap = ref.read(cartProvider);
    if (snap.selectedTaxGroup != null ||
        snap.selectedTaxRate != null ||
        snap.orderTax > 0) {
      return;
    }
    if (product.taxGroupId != null) {
      final grp = _taxGroups
          .where((g) => g.id == product.taxGroupId)
          .cast<TaxGroup?>()
          .firstOrNull;
      if (grp != null) {
        ref.read(cartProvider.notifier).applyTaxGroup(grp, _taxRates);
        return;
      }
    }
    if (product.taxRateId != null) {
      final rate = _taxRates
          .where((r) => r.id == product.taxRateId)
          .cast<TaxRate?>()
          .firstOrNull;
      if (rate != null) {
        ref.read(cartProvider.notifier).applyTaxRate(rate);
      }
    }
  }

  void _addToCartWithQuantity(
    Product product,
    double qty, {
    ProductVariation? preselectedVariation,
  }) {
    final effectiveStock =
        preselectedVariation?.stockQuantity ?? product.stockQuantity;
    final alreadyInCart = _cartBaseQtyFor(product, preselectedVariation);
    if (!widget.settings.allowOverselling &&
        (effectiveStock <= 0 || alreadyInCart + qty > effectiveStock)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            effectiveStock <= 0
                ? '${product.name} is OUT OF STOCK!'
                : 'Insufficient stock for ${product.name} (Available: ${effectiveStock.toStringAsFixed(effectiveStock % 1 == 0 ? 0 : 2)}).',
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final expDays = _getDaysUntilExpiry(product.expiryDate);
    if (expDays != null && expDays <= 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expDays < 0
                ? 'WARNING: ${product.name} is EXPIRED (${product.expiryDate})!'
                : 'NOTICE: ${product.name} nearing expiry ($expDays days left • ${product.expiryDate}).',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              expDays < 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    ref.read(cartProvider.notifier).addProduct(
          product,
          quantity: qty,
          variation: preselectedVariation,
          mergeByUnitPrice: true,
        );
    _applyProductTaxIfConfigured(product);
  }

  void _onBarcodeSubmitted(String code) async {
    final raw = code.trim();
    if (raw.isEmpty) return;

    final parsedPrefix = PosTerminalScreen.parseBarcodeQuantityPrefix(raw);
    final qtyMultiplier = parsedPrefix.quantity;
    final cleanCode = parsedPrefix.code;

    // 0. Electronic Weight/Price-Scale Barcode Parsing (EAN-13 20/02 weight or 21..29 price)
    final scale = PosTerminalScreen.parseScaleBarcode(cleanCode);
    if (scale != null) {
      final db = await _dbFuture;
      Product? scaleItem = _products.cast<Product?>().firstWhere(
            (p) =>
                p!.sku.toLowerCase().contains(scale.itemCode.toLowerCase()) ||
                p.barcode.toLowerCase().contains(scale.itemCode.toLowerCase()),
            orElse: () => null,
          );
      if (scaleItem == null) {
        final fallback = await db.getProductsPaged(
          search: scale.itemCode,
          pageSize: 5,
          includeTotalCount: false,
        );
        scaleItem = fallback.items.isNotEmpty ? fallback.items.first : null;
      }

      if (scaleItem != null) {
        final computedQty = scale.isPriceEmbedded
            ? (scaleItem.sellingPrice > 0
                ? double.parse(
                    (scale.value / scaleItem.sellingPrice).toStringAsFixed(3),
                  )
                : 1.0)
            : scale.value;
        _addToCartWithQuantity(scaleItem, computedQty * qtyMultiplier);
        _searchController.clear();
        _applyProductFilter(immediate: true);
        _searchFocusNode.requestFocus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              scale.isPriceEmbedded
                  ? 'Scale Price parsed: ${scaleItem.name} — ${computedQty.toStringAsFixed(3)} ${scaleItem.unit}'
                  : 'Weight-Scale parsed: ${scaleItem.name} — ${computedQty.toStringAsFixed(3)} kg',
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        return;
      }
    }

    // 1. Live Primary Server check first for Secondary LAN Terminals, then local DB lookup
    final db = await _dbFuture;
    (Product, ProductVariation?)? dbMatch;
    if (widget.settings.isLanSecondaryTerminal &&
        widget.settings.serverHost.trim().isNotEmpty &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      final remote =
          await LanRealtimeService.instance.fetchLiveProductByCode(cleanCode);
      if (remote.reachable && remote.product != null) {
        dbMatch = (remote.product!, remote.variation);
      }
    }
    dbMatch ??= await db.getProductWithMatchedVariationByCode(cleanCode);
    if (dbMatch != null) {
      if (qtyMultiplier != 1.0) {
        _addToCartWithQuantity(
          dbMatch.$1,
          qtyMultiplier,
          preselectedVariation: dbMatch.$2,
        );
      } else {
        await _addToCart(dbMatch.$1, preselectedVariation: dbMatch.$2);
      }
      _searchController.clear();
      _applyProductFilter(immediate: true);
      _refocusBarcodeIfEnabled();
    } else {
      _applyProductFilter(immediate: true);
    }
  }

  // Industry POS Extensions
  void _openKotDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cart is empty! Add food items first.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => KotTicketDialog(
        table: _selectedTable,
        waiter: _assignedWaiter,
        diningMode: _diningMode,
        items: List.from(_cart),
        settings: widget.settings,
      ),
    );
  }

  Future<void> _openSolarBundleDialog() async {
    final db = await _dbFuture;
    final prods = (await db.getProductsPaged(
      page: 1,
      pageSize: 300,
      includeTotalCount: false,
    ))
        .items;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => SolarBundleDialog(
        settings: widget.settings,
        products: prods,
        onBundleSelected: (bundleItems) {
          ref.read(cartProvider.notifier).addBundleItems(bundleItems);
        },
      ),
    );
  }

  void _openImeiModal() {
    showDialog(
      context: context,
      builder: (_) => ImeiPickerDialog(
        product: _cart.isNotEmpty
            ? _cart.last.product
            : Product(
                name: 'Mobile Phone Device',
                sku: 'MOB-GEN',
                barcode: 'MOB-GEN',
                purchasePrice: 40000.0,
                sellingPrice: 50000.0,
                stockQuantity: 10.0,
              ),
        serials: const [],
        onSerialSelected: (imei) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Attached IMEI/Serial: $imei to sale invoice!'),
                backgroundColor: const Color(0xFF4F46E5)),
          );
        },
      ),
    );
  }

  // Calculations delegated cleanly to immutable CartState
  double get _calculatedDiscount => ref.read(cartProvider).calculatedDiscount;
  double get _subtotal => ref.read(cartProvider).subtotal;
  double get _grandTotal => ref.read(cartProvider).grandTotal;
  double get _totalQuantity => ref.read(cartProvider).totalQuantity;

  void _applyPromoDiscountIfApplicable(List<CartItem> items) {
    if (_manualOrderDiscountOverride || _discountRules.isEmpty) return;
    final eval = DiscountRule.evaluateCart(rules: _discountRules, items: items);
    final notifier = ref.read(cartProvider.notifier);
    if (eval.hasDiscount) {
      final current = ref.read(cartProvider);
      if (current.discountType != 'fixed' ||
          (current.discountValue - eval.discountAmount).abs() > 0.01) {
        notifier.setOrderDiscount('fixed', eval.discountAmount);
      }
      if (_appliedPromoRuleName != eval.appliedRuleNames.join(', ')) {
        setState(
            () => _appliedPromoRuleName = eval.appliedRuleNames.join(', '));
      }
    } else if (_appliedPromoRuleName.isNotEmpty) {
      notifier.setOrderDiscount('fixed', 0.0);
      setState(() => _appliedPromoRuleName = '');
    }
  }

  // Checkout Actions
  Future<void> _processCheckout({
    required String paymentMethod,
    required double paidAmount,
    required double tendered,
    required double changeReturn,
    required String paymentStatus,
    String saleStatus = 'final',
    String note = '',
    List<Map<String, dynamic>>? splitTenders,
    double loyaltyDiscount = 0.0,
    double redeemedPoints = 0.0,
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) async {
    final requiredPerm =
        saleStatus == 'quotation' ? 'quotation.manage' : 'sale.create';
    final currentUser = AuthService.currentUser;
    if (currentUser != null && !currentUser.hasPermission(requiredPerm)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saleStatus == 'quotation'
                ? 'Permission Denied: Missing quotation.manage authorization.'
                : 'Permission Denied: Missing sale.create authorization.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add items to cart before checkout!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final db = await _dbFuture;

    // Ensure Cash Register is open before finalizing sale
    if (saleStatus == 'final' &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      final activeReg = await db.getActiveRegister();
      if (activeReg == null) {
        if (!mounted) return;
        final opened = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => OpenRegisterDialog(
            settings: widget.settings,
            isDismissible: true,
            onOpened: () => Navigator.of(ctx).pop(true),
          ),
        );
        if (opened != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'A cash register shift must be open before finalizing sales!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }
    }

    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final invoiceNo = _resumedInvoiceNo ?? await db.generateNextInvoiceNo();

    // Loyalty points rewards calculation (1 point per 100 Rs spent)
    final earnedPoints =
        (!_isCurrentCustomerWalkIn && _selectedCustomer?.id != null)
            ? (paidAmount / 100).floorToDouble()
            : 0.0;
    if (_resumedSaleId != null &&
        saleStatus == 'final' &&
        _selectedCustomer?.id != null &&
        !_isCurrentCustomerWalkIn) {
      if (redeemedPoints > 0) {
        await db.updateContactLoyaltyPoints(
            _selectedCustomer!.id!, -redeemedPoints);
      }
      if (earnedPoints > 0) {
        await db.updateContactLoyaltyPoints(
            _selectedCustomer!.id!, earnedPoints);
      }
    }

    if (redeemedPoints > 0 || earnedPoints > 0) {
      final loyaltySummary =
          'Loyalty Rewards: ${redeemedPoints > 0 ? "Redeemed ${redeemedPoints.toInt()} pts (-${widget.settings.currencySymbol}${loyaltyDiscount.toStringAsFixed(2)}). " : ""}Earned +${earnedPoints.toInt()} pts';
      note = note.isEmpty ? loyaltySummary : '$note • $loyaltySummary';
    }

    final totalDiscount = _calculatedDiscount + loyaltyDiscount;
    final finalBillTotal =
        (_grandTotal - loyaltyDiscount).clamp(0.0, double.infinity);
    final cartSnapshot = ref.read(cartProvider);
    final commAgent = _selectedCommissionAgent;
    final commPct = commAgent?.commissionPercent ?? 0.0;
    final commAmt = (commAgent != null && commPct > 0 && saleStatus == 'final')
        ? double.parse(((finalBillTotal * commPct) / 100.0).toStringAsFixed(2))
        : 0.0;

    final sale = Sale(
      invoiceNo: invoiceNo,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      locationId: _selectedLocationId,
      subtotal: _subtotal,
      discount: totalDiscount,
      taxAmount: _orderTax,
      taxRate: cartSnapshot.selectedTaxGroup != null
          ? cartSnapshot.selectedTaxGroup!.computeEffectiveRate(_taxRates)
          : (cartSnapshot.selectedTaxRate?.amount ??
              widget.settings.defaultTaxRate),
      shipping: _shippingCharge,
      totalAmount: finalBillTotal,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      saleStatus: saleStatus,
      note: note,
      createdAt: now,
      commissionAgentId: commAgent?.id,
      commissionAgentName: commAgent?.name ?? '',
      commissionPercent: commPct,
      commissionAmount: commAmt,
      taxGroupId: cartSnapshot.selectedTaxGroup?.id,
      taxBreakdownJson: cartSnapshot.taxBreakdown.isNotEmpty
          ? jsonEncode(cartSnapshot.taxBreakdown)
          : '',
    );

    final Sale completedSale;
    if (_resumedSaleId != null) {
      completedSale = await db.updateSale(
        saleId: _resumedSaleId!,
        sale: sale,
        items: List.from(_cart),
        splitTenders: splitTenders,
      );
    } else if (widget.settings.isLanSecondaryTerminal &&
        widget.settings.serverHost.trim().isNotEmpty &&
        saleStatus == 'final' &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      final remoteRes = await LanRealtimeService.instance.pushOrderToPrimary(
        sale: sale,
        items: List.from(_cart),
        splitTenders: splitTenders,
      );
      if (remoteRes.success && remoteRes.invoiceNo != null) {
        final primarySale = Sale(
          invoiceNo: remoteRes.invoiceNo!,
          customerId: sale.customerId,
          customerName: sale.customerName,
          locationId: sale.locationId,
          subtotal: sale.subtotal,
          discount: sale.discount,
          taxAmount: sale.taxAmount,
          taxRate: sale.taxRate,
          shipping: sale.shipping,
          totalAmount: sale.totalAmount,
          paidAmount: sale.paidAmount,
          paymentMethod: sale.paymentMethod,
          paymentStatus: sale.paymentStatus,
          saleStatus: sale.saleStatus,
          note: sale.note,
          createdAt: sale.createdAt,
        );
        completedSale = await db.createSale(
          sale: primarySale,
          items: List.from(_cart),
          splitTenders: splitTenders,
          chequeNumber: chequeNumber,
          bankName: bankName,
          chequeDueDate: chequeDueDate,
          pointsRedeemed: redeemedPoints.round(),
          pointsEarned: earnedPoints.round(),
          enforceStock: false,
        );
      } else if ((remoteRes.error ?? '')
          .toLowerCase()
          .contains('insufficient stock')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(remoteRes.error!),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        return;
      } else {
        completedSale = await db.createSale(
          sale: sale,
          items: List.from(_cart),
          splitTenders: splitTenders,
          chequeNumber: chequeNumber,
          bankName: bankName,
          chequeDueDate: chequeDueDate,
          pointsRedeemed: redeemedPoints.round(),
          pointsEarned: earnedPoints.round(),
          enforceStock: !widget.settings.allowOverselling,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'LAN Main Server offline: bill saved to local counter queue.'),
              backgroundColor: Color(0xFFD97706),
            ),
          );
        }
      }
    } else {
      completedSale = await db.createSale(
        sale: sale,
        items: List.from(_cart),
        splitTenders: splitTenders,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDueDate: chequeDueDate,
        pointsRedeemed: redeemedPoints.round(),
        pointsEarned: earnedPoints.round(),
        enforceStock: !widget.settings.allowOverselling,
      );
    }

    if (mounted) {
      ref.read(cartProvider.notifier).clear(resetHistory: true);
      setState(() {
        _resumedSaleId = null;
        _resumedInvoiceNo = null;
        _appliedPromoRuleName = '';
        _manualOrderDiscountOverride = false;
      });
      _loadInitialData();
      _refocusBarcodeIfEnabled();

      if (saleStatus == 'draft') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                    'Draft #${completedSale.invoiceNo} saved! You can resume it anytime from Sales > Drafts.'),
              ],
            ),
            backgroundColor: const Color(0xFF0284C7),
          ),
        );
      } else {
        final prevBalance = _selectedCustomer?.balance ?? 0.0;
        if (saleStatus == 'final' && widget.settings.autoPrintReceipt) {
          // Dispatch background ESC/POS receipt print when configured.
          ThermalPrinterService.printSaleReceipt(
            sale: completedSale,
            settings: widget.settings,
            tenderedAmount: tendered,
            changeReturn: changeReturn,
            customerPreviousBalance: prevBalance,
          ).catchError((Object err, StackTrace st) {
            AppLogger.warning(
              'PosTerminalScreen',
              'Auto-print ESC/POS failed for ${completedSale.invoiceNo}',
              err,
              st,
            );
            return false;
          });
        }
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ReceiptDialog(
            sale: completedSale,
            settings: widget.settings,
            tenderedAmount: (saleStatus == 'quotation') ? 0.0 : tendered,
            changeReturn: (saleStatus == 'quotation') ? 0.0 : changeReturn,
            customerPreviousBalance: prevBalance,
          ),
        );
      }
    }
  }

  bool get _isCurrentCustomerWalkIn {
    if (_selectedCustomer == null || _selectedCustomer!.id == null) return true;
    if (_selectedCustomer!.isDefaultWalkIn) return true;
    final name = _selectedCustomer!.name.toLowerCase().trim();
    return name.contains('walk-in') ||
        name.contains('walk in') ||
        name == 'cash customer' ||
        name.contains('walkin');
  }

  void _quickCashCheckout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PosLocalization.tr(
              'Cart is empty! Add products first',
              settings: widget.settings,
            ),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _processCheckout(
      paymentMethod: 'cash',
      paidAmount: _grandTotal,
      tendered: _grandTotal,
      changeReturn: 0.0,
      paymentStatus: 'paid',
    );
  }

  void _quickCardCheckout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PosLocalization.tr(
                'Cart is empty! Add products first',
                settings: widget.settings)),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final isOffline = widget.settings.isOfflineOnly;
    final cardRefCtrl = TextEditingController();
    String selectedCardType = 'Visa / Mastercard';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.credit_card_rounded,
                  color: Color(0xFF4338CA), size: 24),
              const SizedBox(width: 8),
              Text(
                PosLocalization.tr('Card Payment (Debit / Credit Card)',
                    settings: widget.settings),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOffline)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            color: Color(0xFFB45309), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            PosLocalization.tr(
                              'System is running offline. Swipe card on external bank EDC terminal and enter authorization code below.',
                              settings: widget.settings,
                            ),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF78350F),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  '${PosLocalization.tr('TOTAL PAYABLE', settings: widget.settings)}: ${widget.settings.currencySymbol} ${_grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                Text(
                  PosLocalization.tr('Bank Machine Slip # / Auth Code:*',
                      settings: widget.settings),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: cardRefCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. HBL-98124, MCB-4321, Alfalah Slip #',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  PosLocalization.tr('Card Network:',
                      settings: widget.settings),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedCardType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Visa / Mastercard',
                        child: Text('Visa / Mastercard')),
                    DropdownMenuItem(
                        value: 'PayPak / 1Link', child: Text('PayPak / 1Link')),
                    DropdownMenuItem(
                        value: 'UnionPay', child: Text('UnionPay')),
                    DropdownMenuItem(
                        value: 'Other Bank EDC',
                        child: Text('Other Bank EDC Terminal')),
                  ],
                  onChanged: (val) {
                    if (val != null)
                      setModalState(() => selectedCardType = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(PosLocalization.tr('Cancel', settings: widget.settings)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final ref = cardRefCtrl.text.trim();
                if (isOffline && ref.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Slip # or Auth Code is required for card checkout.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _processCheckout(
                  paymentMethod: 'card',
                  paidAmount: _grandTotal,
                  tendered: _grandTotal,
                  changeReturn: 0.0,
                  paymentStatus: 'paid',
                  note: ref.isNotEmpty
                      ? 'Card Payment ($selectedCardType) - Auth/Slip #$ref'
                      : 'Card Payment ($selectedCardType)',
                );
              },
              child: Text(PosLocalization.tr('Complete Card Payment',
                  settings: widget.settings)),
            ),
          ],
        ),
      ),
    );
  }

  void _quickCreditCheckout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PosLocalization.tr(
                'Cart is empty! Add products first',
                settings: widget.settings)),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isCurrentCustomerWalkIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text(
                PosLocalization.tr(
                    'Credit Sale Not Allowed for Walk-in Customer',
                    settings: widget.settings),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            PosLocalization.tr(
              'Walk-in cash customers do not have a credit ledger account. Credit sales require a registered customer.',
              settings: widget.settings,
            ),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(PosLocalization.tr('Cancel', settings: widget.settings)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0038B8),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.person_search, size: 16),
              label: Text(PosLocalization.tr('Select Customer (F3)',
                  settings: widget.settings)),
              onPressed: () {
                Navigator.pop(ctx);
                _openCustomerSearchModal();
              },
            ),
          ],
        ),
      );
      return;
    }

    final creditLimit = _selectedCustomer?.creditLimit ?? 0.0;
    final currentBalance = _selectedCustomer?.balance ?? 0.0;
    final projectedBalance = currentBalance + _grandTotal;
    if (creditLimit > 0 && projectedBalance > creditLimit + 0.01) {
      final currency = widget.settings.currencySymbol;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.credit_score_rounded,
                  color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Text('Credit Limit Exceeded',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '${_selectedCustomer!.name} has a credit limit of $currency${creditLimit.toStringAsFixed(2)}.\n'
            'Current balance: $currency${currentBalance.toStringAsFixed(2)}\n'
            'Projected balance after this sale: $currency${projectedBalance.toStringAsFixed(2)}\n\n'
            'Please receive partial payment via Multiple Pay or increase the customer credit limit.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _openPaymentModal();
              },
              child: const Text('Open Payment Modal'),
            ),
          ],
        ),
      );
      return;
    }

    _processCheckout(
      paymentMethod: 'credit',
      paidAmount: 0.0,
      tendered: 0.0,
      changeReturn: 0.0,
      paymentStatus: 'due',
      note: 'Credit sale (balance due on account)',
    );
  }

  void _handleMultiplePayClick() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cart is empty! Add products first.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    _openPaymentModal();
  }

  void _openPaymentModal() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cart is empty! Add products first.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final isWalkIn = _isCurrentCustomerWalkIn;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PaymentModal(
        grandTotal: _grandTotal,
        currencySymbol: widget.settings.currencySymbol,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
        isWalkIn: isWalkIn,
        customerCreditLimit: _selectedCustomer?.creditLimit ?? 0.0,
        customerCurrentBalance: _selectedCustomer?.balance ?? 0.0,
        customerLoyaltyPoints: _selectedCustomer?.loyaltyPoints ?? 0.0,
        currencyCode: widget.settings.currencyCode,
        multiCurrencyEnabled: widget.settings.multiCurrencyEnabled,
        availableRates: CurrencyRateService.parseRatesJson(
          widget.settings.exchangeRatesJson,
          widget.settings.currencyCode,
        ),
      ),
    );

    if (result != null) {
      final splitTenders = (result['splitTenders'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final loyaltyDiscount =
          (result['loyaltyDiscount'] as num?)?.toDouble() ?? 0.0;
      final redeemedPoints =
          (result['redeemedLoyaltyPoints'] as num?)?.toDouble() ?? 0.0;

      _processCheckout(
        paymentMethod: result['method'] as String,
        paidAmount: result['paidAmount'] as double,
        tendered: result['tendered'] as double,
        changeReturn: result['change'] as double,
        paymentStatus: result['paymentStatus'] as String,
        splitTenders: splitTenders.isNotEmpty ? splitTenders : null,
        note: result['note'] as String,
        loyaltyDiscount: loyaltyDiscount,
        redeemedPoints: redeemedPoints,
        chequeNumber: (result['chequeNumber'] as String?) ?? '',
        bankName: (result['bankName'] as String?) ?? '',
        chequeDueDate: (result['chequeDueDate'] as String?) ?? '',
      );
    }
  }

  Future<void> _refreshParkedCounterQueue() async {
    try {
      final List<ParkedSale> list;
      if (widget.settings.isLanSecondaryTerminal &&
          widget.settings.serverHost.trim().isNotEmpty &&
          !Platform.environment.containsKey('FLUTTER_TEST')) {
        list = await LanRealtimeService.instance.fetchCounterDrafts();
      } else {
        final db = await _dbFuture;
        list = await db.getParkedSales();
      }
      if (mounted) {
        setState(() => _parkedCount = list.length);
      }
    } catch (_) {}
  }

  Future<void> _sendToCashCounterToken() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty! Add items before sending token.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final tokenNum =
        'TKN-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final counterTag = widget.settings.branchName.trim().isNotEmpty
        ? widget.settings.branchName.trim()
        : 'Counter';
    final cartSnapshot = ref.read(cartProvider);
    final itemsMap = _cart.map((e) => e.toSavedStateMap()).toList();
    final parked = ParkedSale(
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      note: '$tokenNum • $counterTag',
      total: _grandTotal,
      createdAt: now,
      itemsJson: jsonEncode(itemsMap),
      discountType: cartSnapshot.discountType,
      discountValue: cartSnapshot.discountValue,
      orderTax: cartSnapshot.orderTax,
      shippingCharge: cartSnapshot.shippingCharge,
      isWholesale: cartSnapshot.isWholesaleMode,
      commissionAgentId: _selectedCommissionAgent?.id,
      commissionAgentName: _selectedCommissionAgent?.name ?? '',
    );

    if (widget.settings.isLanSecondaryTerminal &&
        widget.settings.serverHost.trim().isNotEmpty &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      final res = await LanRealtimeService.instance.pushCounterDraft(
        parked,
        counterName: counterTag,
      );
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Main Payment Counter unreachable (${res.error ?? "network error"}). Bill kept in cart.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    } else {
      final db = await _dbFuture;
      await db.parkSale(parked);
    }

    ref.read(cartProvider.notifier).clear();
    await _refreshParkedCounterQueue();
    _refocusBarcodeIfEnabled();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sent to Cash Counter ($tokenNum) — Customer can pay at Main Counter!',
        ),
        backgroundColor: const Color(0xFF0D9488),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _suspendSale() async {
    if (_cart.isEmpty) return;
    final db = await _dbFuture;
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final cartSnapshot = ref.read(cartProvider);

    final itemsMap = _cart.map((e) => e.toSavedStateMap()).toList();
    final parked = ParkedSale(
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      note: 'Held at ${DateFormat('hh:mm a').format(DateTime.now())}',
      total: _grandTotal,
      createdAt: now,
      itemsJson: jsonEncode(itemsMap),
      discountType: cartSnapshot.discountType,
      discountValue: cartSnapshot.discountValue,
      orderTax: cartSnapshot.orderTax,
      shippingCharge: cartSnapshot.shippingCharge,
      isWholesale: cartSnapshot.isWholesaleMode,
      commissionAgentId: _selectedCommissionAgent?.id,
      commissionAgentName: _selectedCommissionAgent?.name ?? '',
    );

    if (widget.settings.isLanSecondaryTerminal &&
        widget.settings.serverHost.trim().isNotEmpty &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      final res = await LanRealtimeService.instance.pushCounterDraft(parked);
      if (!res.success) {
        await db.parkSale(parked);
      }
    } else {
      await db.parkSale(parked);
    }
    await _refreshParkedCounterQueue();

    ref.read(cartProvider.notifier).clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sale suspended ($_parkedCount held). Next customer can be served.'),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
    }
    _refocusBarcodeIfEnabled();
  }

  void _openParkedSales() {
    showDialog(
      context: context,
      builder: (_) => ParkedSalesDialog(
        currencySymbol: widget.settings.currencySymbol,
        settings: widget.settings,
        onResumeSale: (parked) async {
          ref.read(cartProvider.notifier).loadFromSaved(
                items: parked.getItems(),
                discountType: parked.discountType,
                discountValue: parked.discountValue,
                orderTax: parked.orderTax,
                shippingCharge: parked.shippingCharge,
                isWholesaleMode: parked.isWholesale,
              );
          final foundCust = parked.customerId != null
              ? _customers.where((c) => c.id == parked.customerId)
              : _customers.where((c) => c.name == parked.customerName);
          if (foundCust.isNotEmpty) {
            await _selectCustomer(foundCust.first);
          }
          if (parked.commissionAgentId != null &&
              _commissionAgents.isNotEmpty) {
            final agent = _commissionAgents
                .where((a) => a.id == parked.commissionAgentId)
                .cast<CommissionAgent?>()
                .firstOrNull;
            if (agent != null && mounted) {
              setState(() => _selectedCommissionAgent = agent);
            }
          }
          await _refreshParkedCounterQueue();
        },
      ),
    );
  }

  void _loadResumedSale(Sale sale) {
    final loadedItems = <CartItem>[];
    if (sale.items != null && sale.items!.isNotEmpty) {
      for (final item in sale.items!) {
        final prod = _products.cast<Product?>().firstWhere(
              (p) => p!.id == item.productId,
              orElse: () => null,
            );
        loadedItems.add(CartItem.fromSaleItem(item, prod));
      }
    }

    final loadedTaxGroup = sale.taxGroupId != null
        ? _taxGroups
            .where((g) => g.id == sale.taxGroupId)
            .cast<TaxGroup?>()
            .firstOrNull
        : null;
    Contact? matchedCustomer;
    if (_customers.isNotEmpty && sale.customerId != null) {
      matchedCustomer = _customers.cast<Contact?>().firstWhere(
            (c) => c!.id == sale.customerId,
            orElse: () => null,
          );
    }
    final matchedGroup = matchedCustomer?.customerGroupId != null
        ? _customerGroups
            .where((g) => g.id == matchedCustomer!.customerGroupId)
            .cast<CustomerGroup?>()
            .firstOrNull
        : null;

    ref.read(cartProvider.notifier).loadFromSaved(
          items: loadedItems,
          discountValue: sale.discount,
          orderTax: sale.taxAmount,
          shippingCharge: sale.shipping,
          activeCustomerGroup: matchedGroup,
          selectedTaxGroup: loadedTaxGroup,
          taxBreakdown: sale.taxBreakdownMap,
        );

    setState(() {
      _resumedSaleId = sale.id;
      _resumedInvoiceNo = sale.invoiceNo;
      _isQuotationMode = (sale.saleStatus == 'quotation');

      if (matchedCustomer != null) {
        _selectedCustomer = matchedCustomer;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
                'Loaded ${sale.saleStatus.toUpperCase()} #${sale.invoiceNo} into Cart!'),
          ],
        ),
        backgroundColor: const Color(0xFF4F46E5),
      ),
    );
  }

  void _saveDraft() {
    _processCheckout(
      paymentMethod: 'none',
      paidAmount: 0.0,
      tendered: 0.0,
      changeReturn: 0.0,
      paymentStatus: 'due',
      saleStatus: 'draft',
      note: 'Temporary draft bill',
    );
  }

  void _saveQuotation() {
    _processCheckout(
      paymentMethod: 'none',
      paidAmount: 0.0,
      tendered: 0.0,
      changeReturn: 0.0,
      paymentStatus: 'due',
      saleStatus: 'quotation',
      note: 'Quotation estimate only',
    );
  }

  void _clearCart() {
    if (_cart.isEmpty) return;

    final currentUser = AuthService.currentUser;
    final canDeleteSale = currentUser?.hasPermission('sale.delete') ?? true;

    if (!canDeleteSale) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Permission Denied: Discarding active carts requires Manager or Owner authorization.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!widget.settings.confirmBeforeCancelSale) {
      ref.read(cartProvider.notifier).clear();
      setState(() {
        _resumedSaleId = null;
        _resumedInvoiceNo = null;
      });
      _refocusBarcodeIfEnabled();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Cancel & Clear Cart?',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to discard all items in the current order?',
            style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('No, Keep', style: TextStyle(color: textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clear();
              setState(() {
                _resumedSaleId = null;
                _resumedInvoiceNo = null;
              });
            },
            child: const Text('Yes, Clear Cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomer(Contact cust, {bool showBanner = false}) async {
    if (_customerGroups.isEmpty && cust.customerGroupId != null) {
      final db = await _dbFuture;
      final groups = await db.getCustomerGroups();
      if (mounted) {
        setState(() => _customerGroups = groups);
      }
    }
    if (!mounted) return;
    final CustomerGroup? group = cust.customerGroupId != null
        ? _customerGroups
            .where((g) => g.id == cust.customerGroupId)
            .cast<CustomerGroup?>()
            .firstOrNull
        : null;
    setState(() => _selectedCustomer = cust);
    ref.read(cartProvider.notifier).applyCustomerGroup(group);
    if (cust.creditLimit > 0 && cust.balance >= cust.creditLimit && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Warning: ${cust.name} has reached credit limit (${widget.settings.currencySymbol}${cust.balance.toStringAsFixed(0)} / ${widget.settings.currencySymbol}${cust.creditLimit.toStringAsFixed(0)})',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    } else if (showBanner && group != null && mounted) {
      final signLabel = group.amount >= 0
          ? '+${group.amount.toStringAsFixed(1)}%'
          : '${group.amount.toStringAsFixed(1)}%';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Applied ${group.name} ($signLabel) tiered pricing to cart'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF4F46E5),
        ),
      );
    }
  }

  void _openQuickCustomerModal() {
    showDialog(
      context: context,
      builder: (_) => QuickCustomerDialog(
        onCustomerAdded: (newCustomer) {
          setState(() {
            _customers.add(newCustomer);
          });
          _selectCustomer(newCustomer, showBanner: true);
        },
      ),
    );
  }

  void _openRecentTransactionsModal() async {
    final saleToResume = await showDialog<Sale>(
      context: context,
      builder: (_) => RecentTransactionsDialog(settings: widget.settings),
    );
    if (saleToResume != null && mounted) {
      _loadResumedSale(saleToResume);
    }
  }

  void _openCustomerSearchModal() {
    showDialog(
      context: context,
      builder: (_) => CustomerSearchDialog(
        customers: _customers,
        selectedCustomer: _selectedCustomer,
        currencySymbol: widget.settings.currencySymbol,
        onCustomerSelected: (c) => _selectCustomer(c, showBanner: true),
      ),
    );
  }

  void _resetToWalkInCustomer() {
    final Contact? walkIn = _customers.cast<Contact?>().firstWhere(
          (c) =>
              c!.name.toLowerCase().contains('walk-in') ||
              c.name.toLowerCase().contains('walk in'),
          orElse: () => _customers.isNotEmpty ? _customers.first : null,
        );
    if (walkIn != null) {
      _selectCustomer(walkIn);
    }
  }

  VoidCallback _callbackForShortcutAction(String actionId) {
    switch (actionId) {
      case 'help':
        return _showShortcutsDialog;
      case 'quickCash':
        return _quickCashCheckout;
      case 'customerSearch':
        return _openCustomerSearchModal;
      case 'suspendSale':
        return _suspendSale;
      case 'toggleView':
        return _toggleProductLayout;
      case 'quickCustomer':
        return _openQuickCustomerModal;
      case 'multiPay':
        return _handleMultiplePayClick;
      case 'clearCart':
        return _clearCart;
      case 'recentSales':
        return _openRecentTransactionsModal;
      case 'registerDetails':
        return () => showDialog(
              context: context,
              builder: (_) => RegisterDetailsDialog(settings: widget.settings),
            );
      default:
        return () {};
    }
  }

  bool get _isEditingText =>
      FocusManager.instance.primaryFocus?.context?.widget is EditableText;

  Map<ShortcutActivator, VoidCallback> _buildDynamicShortcuts() {
    final map = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.f11): _openCustomProductDialog,
      const SingleActivator(LogicalKeyboardKey.f12): _toggleWholesaleMode,
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
          ref.read(cartProvider.notifier).undo(),
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
          ref.read(cartProvider.notifier).redo(),
      const SingleActivator(LogicalKeyboardKey.numpadAdd): () {
        if (_cart.isNotEmpty && !_isEditingText) {
          _tryIncrementCartItem(_cart.length - 1);
        }
      },
      const SingleActivator(LogicalKeyboardKey.equal): () {
        if (_cart.isNotEmpty && !_isEditingText) {
          _tryIncrementCartItem(_cart.length - 1);
        }
      },
      const SingleActivator(LogicalKeyboardKey.numpadSubtract): () {
        if (_cart.isNotEmpty && !_isEditingText) {
          ref.read(cartProvider.notifier).decrementQuantity(_cart.length - 1);
        }
      },
      const SingleActivator(LogicalKeyboardKey.minus): () {
        if (_cart.isNotEmpty && !_isEditingText) {
          ref.read(cartProvider.notifier).decrementQuantity(_cart.length - 1);
        }
      },
      const SingleActivator(LogicalKeyboardKey.delete): () {
        if (_cart.isNotEmpty && !_isEditingText) {
          ref.read(cartProvider.notifier).removeAt(_cart.length - 1);
        }
      },
      const SingleActivator(LogicalKeyboardKey.escape): () {
        _searchFocusNode.requestFocus();
      },
      const SingleActivator(LogicalKeyboardKey.slash, shift: true):
          _showShortcutsDialog,
    };

    for (final spec in KeyboardShortcutsService.actions) {
      if (spec.isGlobalOrForm) continue;
      final assignedKey = _shortcutBindings[spec.id] ?? spec.defaultKeyLabel;
      final logicalKey = KeyboardShortcutsService.parseFunctionKey(assignedKey);
      if (logicalKey != null) {
        map[SingleActivator(logicalKey)] = _callbackForShortcutAction(spec.id);
      }
    }
    return map;
  }

  void _openCustomerFacingDisplay() {
    final currency = widget.settings.currencySymbol;
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, watchRef, _) {
          final liveCart = watchRef.watch(cartProvider);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: 560,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.desktop_windows_rounded,
                                color: Color(0xFF4F46E5), size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.settings.businessName,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900)),
                                Text(
                                    'Customer Facing Display • ${_selectedCustomer?.name ?? 'Walk-in Customer'}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: liveCart.items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                    'Welcome! Ready for your next item...',
                                    style: TextStyle(
                                        fontSize: 15, color: Colors.grey)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: liveCart.items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final item = liveCart.items[idx];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} x ${item.product.name}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Text(
                                        '$currency ${item.subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(
                            '$currency ${liveCart.subtotal.toStringAsFixed(2)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (liveCart.calculatedDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF059669))),
                          Text(
                              '-$currency ${liveCart.calculatedDiscount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'TOTAL (${liveCart.totalQuantity % 1 == 0 ? liveCart.totalQuantity.toInt() : liveCart.totalQuantity.toStringAsFixed(2)} items)',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                          Text(
                              '$currency ${liveCart.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4F46E5))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPriceCheckerDialog() {
    final codeCtrl = TextEditingController();
    final currency = widget.settings.currencySymbol;
    Product? found;
    ProductVariation? foundVar;
    String status = 'Scan barcode or enter SKU to check live price & stock.';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> lookup(String query) async {
            final clean = query.trim();
            if (clean.isEmpty) return;
            final db = await _dbFuture;
            final match = await db.getProductWithMatchedVariationByCode(clean);
            if (!ctx.mounted) return;
            if (match != null) {
              setModalState(() {
                found = match.$1;
                foundVar = match.$2;
                status = '';
              });
            } else {
              final paged = await db.getProductsPaged(
                  search: clean, pageSize: 1, includeTotalCount: false);
              if (!ctx.mounted) return;
              setModalState(() {
                found = paged.items.isNotEmpty ? paged.items.first : null;
                foundVar = null;
                status = found == null ? 'No product found for "$clean".' : '';
              });
            }
          }

          final effectivePrice =
              foundVar?.sellingPrice ?? found?.sellingPrice ?? 0.0;
          final effectiveStock =
              foundVar?.stockQuantity ?? found?.stockQuantity ?? 0.0;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: Color(0xFF0D9488)),
                SizedBox(width: 8),
                Text('Fast Price & Stock Checker',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: codeCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Barcode / SKU / Name',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => lookup(codeCtrl.text),
                      ),
                    ),
                    onSubmitted: lookup,
                  ),
                  const SizedBox(height: 16),
                  if (found != null) ...[
                    Builder(
                      builder: (_) {
                        final prod = found!;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0D9488).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF0D9488)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                foundVar != null
                                    ? '${prod.name} (${foundVar!.name})'
                                    : prod.name,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  'SKU: ${foundVar?.subSku ?? prod.sku} • Unit: ${prod.unit}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              if ((prod.rackLocation ?? '').isNotEmpty)
                                Text('Aisle / Rack: ${prod.rackLocation}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4F46E5))),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$currency ${effectivePrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF059669)),
                                  ),
                                  Text(
                                    'Stock: ${effectiveStock % 1 == 0 ? effectiveStock.toInt() : effectiveStock.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: effectiveStock > 0
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else
                    Text(status,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
              if (found != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Add to Cart'),
                  onPressed: () {
                    final item = found!;
                    final itemVar = foundVar;
                    Navigator.pop(ctx);
                    _addToCart(item, preselectedVariation: itemVar);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  void _showShortcutsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    bool isCustomizing = false;
    final draftBindings = Map<String, String>.from(_shortcutBindings);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          backgroundColor: cardBg,
          child: Container(
            width: 560,
            constraints: const BoxConstraints(maxHeight: 620),
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
                            color: isDark
                                ? const Color(0xFF312E81)
                                : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.keyboard_rounded,
                              color: isDark
                                  ? const Color(0xFFA5B4FC)
                                  : const Color(0xFF4F46E5),
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'POS Terminal Shortcuts [F1 / ?]',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: textPrimary),
                            ),
                            Text(
                              isCustomizing
                                  ? 'Reassign F-keys for cashier operations and save'
                                  : 'Quick keyboard hotkeys for rapid cashier operation',
                              style:
                                  TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              setDlgState(() => isCustomizing = !isCustomizing),
                          icon: Icon(
                              isCustomizing
                                  ? Icons.visibility_outlined
                                  : Icons.tune_rounded,
                              size: 16),
                          label: Text(
                              isCustomizing ? 'Preview' : 'Customize F-Keys',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.close, size: 20, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(height: 20, color: borderColor),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...KeyboardShortcutsService.actions.map((spec) {
                          final currentKey =
                              draftBindings[spec.id] ?? spec.defaultKeyLabel;
                          if (!isCustomizing || spec.isGlobalOrForm) {
                            return _shortcutRow(currentKey, spec.label, isDark);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: KeyboardShortcutsService
                                            .customizableFKeys
                                            .contains(currentKey)
                                        ? currentKey
                                        : spec.defaultKeyLabel,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                    ),
                                    items: KeyboardShortcutsService
                                        .customizableFKeys
                                        .map((k) => DropdownMenuItem(
                                            value: k,
                                            child: Text(k,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12))))
                                        .toList(),
                                    onChanged: (newKey) {
                                      if (newKey != null) {
                                        setDlgState(() =>
                                            draftBindings[spec.id] = newKey);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    spec.label,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        _shortcutRow(
                            'F11', 'Custom Product / Ad-hoc Item', isDark),
                        _shortcutRow(
                            'F12', 'Toggle Wholesale Pricing Mode', isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isCustomizing)
                      TextButton(
                        onPressed: () {
                          setDlgState(() {
                            for (final a in KeyboardShortcutsService.actions) {
                              draftBindings[a.id] = a.defaultKeyLabel;
                            }
                          });
                        },
                        child: const Text('Reset Defaults'),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCustomizing) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 11),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: const Text('Save Bindings',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              final encoded =
                                  KeyboardShortcutsService.encodeBindings(
                                      draftBindings);
                              final db = await _dbFuture;
                              final updated = widget.settings
                                  .copyWith(keyboardShortcutsJson: encoded);
                              await db.updateBusinessSettings(updated);
                              if (mounted) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setSettings(updated);
                                setState(() {
                                  _shortcutsJson = encoded;
                                  _shortcutBindings =
                                      KeyboardShortcutsService.resolveBindings(
                                          encoded);
                                });
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                          const SizedBox(width: 10),
                        ],
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortcutRow(String key, String description, [bool isDark = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF4338CA)
                      : const Color(0xFFC7D2FE)),
            ),
            alignment: Alignment.center,
            child: Text(key,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? const Color(0xFFA5B4FC)
                        : const Color(0xFF4F46E5),
                    fontSize: 12)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(description,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _topIconBtn(
      {required IconData icon,
      required VoidCallback onTap,
      Color? color,
      String? tooltip,
      bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon,
                size: 16,
                color: color ??
                    (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    ref.listen<CartState>(cartProvider, (prev, next) {
      if (prev == null || prev.items != next.items) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyPromoDiscountIfApplicable(next.items);
        });
      }
    });

    final currency = widget.settings.currencySymbol;
    final nowTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;
    final isTabletCompact = screenWidth < 1050;
    final isTouchFriendly = ThemeService.touchFriendlyNotifier.value;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final screenBg = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9);
    final subtleBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return CallbackShortcuts(
      bindings: _buildDynamicShortcuts(),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: screenBg,
          body: Column(
            children: [
              // ================= TOP POS BAR =================
              Container(
                height: _isFullscreen ? 42 : 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    if (!_isFullscreen) ...[
                      // Location / Active Branch Switcher
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Location: ',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary)),
                          if (_locations.length > 1)
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _locations
                                        .any((l) => l.id == _selectedLocationId)
                                    ? _selectedLocationId
                                    : _locations.first.id,
                                isDense: true,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                                dropdownColor: cardBg,
                                items: _locations
                                    .where((l) => l.id != null)
                                    .map((loc) => DropdownMenuItem<int>(
                                          value: loc.id!,
                                          child: Text(loc.name,
                                              overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedLocationId = val);
                                  }
                                },
                              ),
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                _locations.isNotEmpty
                                    ? _locations.first.name
                                    : widget.settings.businessName,
                                style: TextStyle(
                                    fontSize: 12.5, color: textSecondary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Date & Time Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B6DF0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(nowTime,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            const Icon(Icons.schedule_outlined,
                                color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],

                    // Industry Presets Quick Action Bar
                    if (widget.settings.isRestaurantEnabled) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          foregroundColor: const Color(0xFFEA580C),
                        ),
                        icon:
                            const Icon(Icons.restaurant_menu_rounded, size: 14),
                        label: Text('$_diningMode: $_selectedTable',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setState(() {
                            if (_diningMode == 'Dine-In') {
                              _diningMode = 'Takeaway';
                            } else if (_diningMode == 'Takeaway') {
                              _diningMode = 'Delivery';
                            } else {
                              _diningMode = 'Dine-In';
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 14),
                        label: const Text('KOT',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _openKotDialog,
                      ),
                    ],

                    if (widget.settings.isSolarHardwareEnabled) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.wb_sunny_rounded, size: 14),
                        label: const Text('Solar BOM',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _openSolarBundleDialog,
                      ),
                    ],

                    if (widget.settings.isMobileElectronicsEnabled) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                          foregroundColor: const Color(0xFF4F46E5),
                        ),
                        icon:
                            const Icon(Icons.qr_code_scanner_rounded, size: 14),
                        label: const Text('IMEI',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _openImeiModal,
                      ),
                    ],

                    const SizedBox(width: 16),

                    // Header Action icons:
                    // Header Action icons:
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // [ < ] Back
                            _topIconBtn(
                              icon: Icons.chevron_left,
                              onTap: () {
                                if (widget.onBackToDashboard != null) {
                                  widget.onBackToDashboard!();
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                              },
                              color: const Color(0xFF4F46E5),
                              tooltip: 'Back to Dashboard',
                              isDark: isDark,
                            ),

                            // [ ↶ ] Undo / Clear
                            _topIconBtn(
                              icon: Icons.undo,
                              onTap: _clearCart,
                              tooltip: 'Reset Order',
                              isDark: isDark,
                            ),

                            // [ || ] Pause / Suspend bills drawer with badge
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Tooltip(
                                message: 'Suspended Bills ($_parkedCount held)',
                                child: InkWell(
                                  onTap: _openParkedSales,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    height: 32,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: _parkedCount > 0 ? 8 : 6),
                                    decoration: BoxDecoration(
                                      color: _parkedCount > 0
                                          ? (isDark
                                              ? const Color(0xFF451A03)
                                              : const Color(0xFFFEF3C7))
                                          : (isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _parkedCount > 0
                                            ? const Color(0xFFD97706)
                                            : (isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.pause,
                                          size: 16,
                                          color: _parkedCount > 0
                                              ? const Color(0xFFD97706)
                                              : (isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF475569)),
                                        ),
                                        if (_parkedCount > 0) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD97706),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$_parkedCount',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // [ ] Register Details (Green icon)
                            _topIconBtn(
                              icon: Icons.work_outline,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => RegisterDetailsDialog(
                                      settings: widget.settings),
                                );
                              },
                              color: const Color(0xFF10B981),
                              tooltip: 'Cash Register Details',
                              isDark: isDark,
                            ),

                            // [ ⌧ ] Close
                            _topIconBtn(
                              icon: Icons.highlight_off,
                              onTap: _clearCart,
                              color: const Color(0xFFEF4444),
                              tooltip: 'Cancel Order',
                              isDark: isDark,
                            ),

                            // [ ] Calculator
                            _topIconBtn(
                              icon: Icons.calculate_outlined,
                              onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => const CalculatorDialog()),
                              color: const Color(0xFF4F46E5),
                              tooltip: 'Calculator',
                              isDark: isDark,
                            ),

                            // [ ] Sales Return / Refund
                            _topIconBtn(
                              icon: Icons.assignment_return_outlined,
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => SalesReturnDialog(
                                  settings: widget.settings,
                                  locationId: _selectedLocationId,
                                  onReturnSuccess: _loadInitialData,
                                ),
                              ),
                              color: const Color(0xFFEF4444),
                              tooltip: 'Sales Return / Refund',
                              isDark: isDark,
                            ),

                            // [ ] Fullscreen
                            _topIconBtn(
                              icon: _isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              onTap: () => setState(
                                  () => _isFullscreen = !_isFullscreen),
                              tooltip: _isFullscreen
                                  ? 'Exit Compact Fullscreen'
                                  : 'Fullscreen Toggle',
                              color: _isFullscreen
                                  ? const Color(0xFF4F46E5)
                                  : null,
                              isDark: isDark,
                            ),

                            // [ ️ ] Screen
                            _topIconBtn(
                              icon: Icons.desktop_windows_outlined,
                              onTap: _openCustomerFacingDisplay,
                              color: const Color(0xFF0D9488),
                              tooltip: 'Customer Facing Display',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),

                            // [ ⊞ / ] Toggle Grid / List Layout
                            if (_showProductPanel) ...[
                              _topIconBtn(
                                icon: _isGridView
                                    ? Icons.view_list_rounded
                                    : Icons.grid_view_rounded,
                                onTap: _toggleProductLayout,
                                tooltip: _isGridView
                                    ? 'Switch to List View [F5]'
                                    : 'Switch to Grid View [F5]',
                                color: const Color(0xFF4F46E5),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 4),
                            ],

                            // Show / Hide Product Catalog Panel (Barcode Superstore Mode)
                            _topIconBtn(
                              icon: _showProductPanel
                                  ? Icons.view_sidebar_rounded
                                  : Icons.view_sidebar_outlined,
                              onTap: _toggleProductPanelVisibility,
                              tooltip: _showProductPanel
                                  ? 'Hide Product Panel (Full-Width Cart + Barcode)'
                                  : 'Show Product Grid / List Panel',
                              color: _showProductPanel
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF4F46E5),
                              isDark: isDark,
                            ),
                            if (widget.settings.isLanSecondaryTerminal ||
                                LocalApiService.instance.isRunning) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: widget.settings.isLanSecondaryTerminal
                                    ? (_lanWsConnected
                                        ? 'LAN Live Sync Connected (${widget.settings.serverHost}:${widget.settings.serverPort})'
                                        : 'LAN Offline / Reconnecting to ${widget.settings.serverHost}')
                                    : 'LAN Multi-Counter Hub Active (${LocalApiService.instance.connectedClientCount} counters live)',
                                child: Container(
                                  height: 30,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        (widget.settings.isLanSecondaryTerminal
                                                ? _lanWsConnected
                                                : true)
                                            ? const Color(0xFF10B981)
                                                .withValues(alpha: 0.14)
                                            : const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (widget.settings
                                                  .isLanSecondaryTerminal
                                              ? _lanWsConnected
                                              : true)
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hub_rounded,
                                        size: 13,
                                        color: (widget.settings
                                                    .isLanSecondaryTerminal
                                                ? _lanWsConnected
                                                : true)
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.settings.isLanSecondaryTerminal
                                            ? (_lanWsConnected
                                                ? 'LAN LIVE'
                                                : 'LAN SYNC')
                                            : 'HUB',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: (widget.settings
                                                      .isLanSecondaryTerminal
                                                  ? _lanWsConnected
                                                  : true)
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),

                            // [ + Add Expense ]
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                foregroundColor: textPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Expense',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddExpenseDialog(
                                    settings: widget.settings,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),

                            // [ Recent Sales F9 ]
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                foregroundColor: textPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.history_rounded,
                                  size: 15, color: Color(0xFF4F46E5)),
                              label: const Text('Recent Sales [F9]',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              onPressed: _openRecentTransactionsModal,
                            ),
                            const SizedBox(width: 6),

                            // [ Till Session F10 ]
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                foregroundColor: textPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 15,
                                  color: Color(0xFF10B981)),
                              label: const Text('Till [F10]',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => RegisterDetailsDialog(
                                      settings: widget.settings),
                                );
                              },
                            ),
                            const SizedBox(width: 6),

                            // [ ⌨ Shortcuts F1 ]
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              icon:
                                  const Icon(Icons.keyboard_outlined, size: 14),
                              label: const Text('Shortcuts [F1]',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              onPressed: _showShortcutsDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (isTabletCompact)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          selected: _mobileTabIndex == 1,
                          onSelected: (_) =>
                              setState(() => _mobileTabIndex = 1),
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              'Catalog (${_products.length})',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          selected: _mobileTabIndex == 0,
                          onSelected: (_) =>
                              setState(() => _mobileTabIndex = 0),
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              'Cart (${cartState.items.length}) • $currency${_grandTotal.toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ================= MAIN TERMINAL SPLIT LAYOUT =================
              Expanded(
                child: Row(
                  children: [
                    // ================= LEFT: ORDER CART & CHECKOUT =================
                    if (!isTabletCompact || _mobileTabIndex == 0)
                      Expanded(
                        flex: isTabletCompact ? 1 : (_showProductPanel ? 7 : 1),
                        child: Container(
                          color: cardBg,
                          child: Column(
                            children: [
                              // Row 1: Dedicated Full-Width Customer Selector & Live Search (F3)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(color: borderColor)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_commissionAgents.isNotEmpty ||
                                        _appliedPromoRuleName.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            if (_commissionAgents
                                                .isNotEmpty) ...[
                                              const Icon(Icons.badge_outlined,
                                                  size: 15,
                                                  color: Color(0xFF4F46E5)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child:
                                                    DropdownButtonHideUnderline(
                                                  child: DropdownButton<
                                                      CommissionAgent?>(
                                                    isDense: true,
                                                    isExpanded: true,
                                                    value:
                                                        _selectedCommissionAgent,
                                                    hint: const Text(
                                                        'Assign Commission Agent (optional)',
                                                        style: TextStyle(
                                                            fontSize: 11.5)),
                                                    items: [
                                                      const DropdownMenuItem<
                                                          CommissionAgent?>(
                                                        value: null,
                                                        child: Text(
                                                            'No Commission Agent',
                                                            style: TextStyle(
                                                                fontSize:
                                                                    11.5)),
                                                      ),
                                                      ..._commissionAgents.map(
                                                        (a) => DropdownMenuItem<
                                                            CommissionAgent?>(
                                                          value: a,
                                                          child: Text(
                                                            'Agent: ${a.name} (${a.commissionPercent.toStringAsFixed(1)}%)',
                                                            style: const TextStyle(
                                                                fontSize: 11.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: (val) =>
                                                        setState(() =>
                                                            _selectedCommissionAgent =
                                                                val),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (_appliedPromoRuleName
                                                .isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFF10B981)),
                                                ),
                                                child: Text(
                                                  'Promo Applied: $_appliedPromoRuleName',
                                                  style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF10B981)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        // Customer Selector with Live Search (F3) - Expanded
                                        Expanded(
                                          child: Container(
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: inputBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: inputBorder),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap:
                                                        _openCustomerSearchModal,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .person_outline_rounded,
                                                              size: 18,
                                                              color: Color(
                                                                  0xFF4F46E5)),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              _selectedCustomer
                                                                      ?.name ??
                                                                  'Walk-in Customer',
                                                              style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      textPrimary),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          if (ref
                                                                  .watch(
                                                                      cartProvider)
                                                                  .activeCustomerGroup !=
                                                              null) ...[
                                                            const SizedBox(
                                                                width: 6),
                                                            Builder(
                                                              builder: (_) {
                                                                final grp = ref
                                                                    .watch(
                                                                        cartProvider)
                                                                    .activeCustomerGroup!;
                                                                final pctTag = grp
                                                                            .amount ==
                                                                        0
                                                                    ? ''
                                                                    : (grp.amount <
                                                                            0
                                                                        ? ' ${grp.amount.toStringAsFixed(0)}%'
                                                                        : ' +${grp.amount.toStringAsFixed(0)}%');
                                                                return Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: const Color(
                                                                        0xFF4F46E5),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    '${grp.name}$pctTag',
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: Colors
                                                                            .white),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                          const SizedBox(
                                                              width: 6),
                                                          // Dedicated "Search (F3)" badge button
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        3),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: isDark
                                                                  ? const Color(
                                                                      0xFF312E81)
                                                                  : const Color(
                                                                      0xFFEEF2FF),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              border: Border.all(
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFF4338CA)
                                                                      : const Color(
                                                                          0xFFC7D2FE)),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .search,
                                                                    size: 12,
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFFA5B4FC)
                                                                        : const Color(
                                                                            0xFF4F46E5)),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  'Search (F3)',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10.5,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: isDark
                                                                          ? const Color(
                                                                              0xFFA5B4FC)
                                                                          : const Color(
                                                                              0xFF4F46E5)),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Icon(
                                                              Icons
                                                                  .arrow_drop_down,
                                                              size: 18,
                                                              color:
                                                                  textSecondary),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (_selectedCustomer != null &&
                                                    !_selectedCustomer!.name
                                                        .toLowerCase()
                                                        .contains('walk-in'))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    child: Tooltip(
                                                      message:
                                                          'Reset to Walk-in Customer',
                                                      child: InkWell(
                                                        onTap:
                                                            _resetToWalkInCustomer,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF450A0A)
                                                                : const Color(
                                                                    0xFFFEE2E2),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                              Icons.close,
                                                              size: 13,
                                                              color: Color(
                                                                  0xFFDC2626)),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // [ + ] Quick Add Customer blue button
                                        Tooltip(
                                          message: 'Add New Customer (F6)',
                                          child: InkWell(
                                            onTap: _openQuickCustomerModal,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4F46E5),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                  Icons.person_add_rounded,
                                                  color: Colors.white,
                                                  size: 18),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Customer Balance Due & Loyalty Badges
                                        if (_selectedCustomer != null &&
                                            !_selectedCustomer!.name
                                                .toLowerCase()
                                                .contains('walk-in')) ...[
                                          if (_selectedCustomer!.balance != 0)
                                            Container(
                                              height: 38,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              decoration: BoxDecoration(
                                                color:
                                                    _selectedCustomer!.balance >
                                                            0
                                                        ? (isDark
                                                            ? const Color(
                                                                0xFF451A03)
                                                            : const Color(
                                                                0xFFFEF3C7))
                                                        : (isDark
                                                            ? const Color(
                                                                0xFF052E16)
                                                            : const Color(
                                                                0xFFDCFCE7)),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: _selectedCustomer!
                                                              .balance >
                                                          0
                                                      ? (isDark
                                                          ? const Color(
                                                              0xFF78350F)
                                                          : const Color(
                                                              0xFFFDE68A))
                                                      : (isDark
                                                          ? const Color(
                                                              0xFF065F46)
                                                          : const Color(
                                                              0xFFA7F3D0)),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Due: ${widget.settings.currencySymbol}${_selectedCustomer!.balance.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _selectedCustomer!
                                                              .balance >
                                                          0
                                                      ? (isDark
                                                          ? const Color(
                                                              0xFFFCD34D)
                                                          : const Color(
                                                              0xFFD97706))
                                                      : (isDark
                                                          ? const Color(
                                                              0xFF6EE7B7)
                                                          : const Color(
                                                              0xFF16A34A)),
                                                ),
                                              ),
                                            ),
                                          if (_selectedCustomer!.loyaltyPoints >
                                              0)
                                            Container(
                                              height: 38,
                                              margin: const EdgeInsets.only(
                                                  left: 6),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF451A03)
                                                    : const Color(0xFFFFFBEB),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF78350F)
                                                        : const Color(
                                                            0xFFFDE68A)),
                                              ),
                                              alignment: Alignment.center,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                      Icons.stars_rounded,
                                                      color: Color(0xFFD97706),
                                                      size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${_selectedCustomer!.loyaltyPoints.toInt()} pts',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFFDE68A)
                                                          : const Color(
                                                              0xFF92400E),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ] else ...[
                                          Tooltip(
                                            message:
                                                'Customer Outstanding Due & Ledger',
                                            child: InkWell(
                                              onTap: () {
                                                if (_selectedCustomer != null) {
                                                  final due = _selectedCustomer!
                                                      .balance;
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Customer: ${_selectedCustomer!.name} | Outstanding Due: ${widget.settings.currencySymbol} ${due.toStringAsFixed(2)}',
                                                      ),
                                                      backgroundColor: due > 0
                                                          ? const Color(
                                                              0xFFD97706)
                                                          : const Color(
                                                              0xFF16A34A),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF312E81)
                                                      : const Color(0xFFEEF2FF),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF4338CA)
                                                          : const Color(
                                                              0xFFC7D2FE)),
                                                ),
                                                child: Icon(
                                                    Icons.payments_outlined,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFA5B4FC)
                                                        : const Color(
                                                            0xFF4F46E5),
                                                    size: 18),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Inline Barcode Search Bar when right Product Panel is hidden (Superstore Mode)
                              if (!_showProductPanel && !isTabletCompact)
                                Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                  decoration: BoxDecoration(
                                    color: subtleBg,
                                    border: Border(
                                      bottom: BorderSide(color: borderColor),
                                    ),
                                  ),
                                  child: _buildBarcodeSearchRow(
                                    isDark: isDark,
                                    inputBg: inputBg,
                                    inputBorder: inputBorder,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                ),

                              // Universal POS Bar: Wholesale/Retail Mode Toggle + Open Item Quick Button
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  border: Border(
                                    top: BorderSide(
                                        color: borderColor, width: 0.8),
                                    bottom: BorderSide(
                                        color: borderColor, width: 0.8),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Retail / Wholesale Pill Toggle
                                      InkWell(
                                        onTap: _toggleWholesaleMode,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _isWholesaleMode
                                                ? const Color(0xFF0891B2)
                                                : (isDark
                                                    ? const Color(0xFF334155)
                                                    : Colors.white),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _isWholesaleMode
                                                  ? const Color(0xFF0891B2)
                                                  : (isDark
                                                      ? const Color(0xFF475569)
                                                      : const Color(
                                                          0xFFCBD5E1)),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _isWholesaleMode
                                                    ? Icons.inventory_2_rounded
                                                    : Icons.storefront_rounded,
                                                size: 14,
                                                color: _isWholesaleMode
                                                    ? Colors.white
                                                    : (isDark
                                                        ? const Color(
                                                            0xFFA5B4FC)
                                                        : const Color(
                                                            0xFF4F46E5)),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _isWholesaleMode
                                                    ? 'Wholesale Tier (Active)'
                                                    : 'Retail Mode (F12)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _isWholesaleMode
                                                      ? Colors.white
                                                      : textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // "+ Custom / Open Item" Pill
                                      InkWell(
                                        onTap: _openCustomProductDialog,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF312E81)
                                                : const Color(0xFFEEF2FF),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF4338CA)
                                                    : const Color(0xFFC7D2FE)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                  Icons
                                                      .add_circle_outline_rounded,
                                                  size: 14,
                                                  color: Color(0xFF4F46E5)),
                                              const SizedBox(width: 5),
                                              Text(
                                                '+ Custom Item',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? const Color(0xFFA5B4FC)
                                                      : const Color(0xFF4F46E5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // Undo / Redo Cart History Buttons
                                      Tooltip(
                                        message: 'Undo Cart Change (Ctrl+Z)',
                                        child: InkWell(
                                          onTap: cartState.canUndo
                                              ? () => ref
                                                  .read(cartProvider.notifier)
                                                  .undo()
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: cartState.canUndo
                                                    ? const Color(0xFF6366F1)
                                                    : borderColor,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.undo_rounded,
                                                  size: 14,
                                                  color: cartState.canUndo
                                                      ? const Color(0xFF4F46E5)
                                                      : textSecondary
                                                          .withValues(
                                                              alpha: 0.45),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Undo',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: cartState.canUndo
                                                        ? textPrimary
                                                        : textSecondary
                                                            .withValues(
                                                                alpha: 0.45),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: 'Redo Cart Change (Ctrl+Y)',
                                        child: InkWell(
                                          onTap: cartState.canRedo
                                              ? () => ref
                                                  .read(cartProvider.notifier)
                                                  .redo()
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: cartState.canRedo
                                                    ? const Color(0xFF6366F1)
                                                    : borderColor,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.redo_rounded,
                                                  size: 14,
                                                  color: cartState.canRedo
                                                      ? const Color(0xFF4F46E5)
                                                      : textSecondary
                                                          .withValues(
                                                              alpha: 0.45),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Redo',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: cartState.canRedo
                                                        ? textPrimary
                                                        : textSecondary
                                                            .withValues(
                                                                alpha: 0.45),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 14),

                                      // Universal Tag / Flexible Units Hint
                                      Text(
                                        'Multi-Unit & Decimal Scale Enabled',
                                        style: TextStyle(
                                            fontSize: 10, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Cart Table Header
                              Container(
                                color: subtleBg,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    SizedBox(
                                        width: 20,
                                        child: Text('#',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: textSecondary))),
                                    Expanded(
                                        flex: 5,
                                        child: Text(
                                            PosLocalization.tr('PRODUCT',
                                                settings: widget.settings),
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? const Color(0xFFA5B4FC)
                                                    : const Color(
                                                        0xFF4F46E5)))),
                                    Expanded(
                                        flex: 3,
                                        child: Text(
                                            PosLocalization.tr('QUANTITY',
                                                settings: widget.settings),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: textSecondary))),
                                    Expanded(
                                        flex: 3,
                                        child: Text(
                                            PosLocalization.tr('PRICE INC. TAX',
                                                settings: widget.settings),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: textSecondary))),
                                    Expanded(
                                        flex: 2,
                                        child: Text(
                                            PosLocalization.tr('SUBTOTAL',
                                                settings: widget.settings),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: textSecondary))),
                                    const SizedBox(width: 36),
                                  ],
                                ),
                              ),

                              // Cart Rows List
                              Expanded(
                                child: _cart.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shopping_cart_outlined,
                                                size: 54,
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFCBD5E1)),
                                            const SizedBox(height: 10),
                                            Text(
                                                PosLocalization.tr(
                                                    'No products in cart',
                                                    settings: widget.settings),
                                                style: TextStyle(
                                                    color: textSecondary,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(
                                                PosLocalization.tr(
                                                    'Scan barcode or select products on the right',
                                                    settings: widget.settings),
                                                style: TextStyle(
                                                    color: textSecondary,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: _cart.length,
                                        separatorBuilder: (_, __) => Divider(
                                            height: 1, color: borderColor),
                                        itemBuilder: (context, index) {
                                          final item = _cart[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            child: Row(
                                              children: [
                                                // Index #
                                                SizedBox(
                                                    width: 20,
                                                    child: Text('${index + 1}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                textSecondary))),

                                                // Thumbnail image
                                                ProductThumbnail(
                                                  imagePath: item.product
                                                      .resolvedImagePath,
                                                  imageColor:
                                                      item.product.imageColor,
                                                  size: 36,
                                                  borderRadius: 6,
                                                ),
                                                const SizedBox(width: 10),

                                                // Product Name (Dark) + SKU & Stock + Batch & Expiry
                                                Expanded(
                                                  flex: 5,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item.displayName,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: textPrimary),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Wrap(
                                                        spacing: 6,
                                                        runSpacing: 2,
                                                        children: [
                                                          Text(
                                                            '${item.product.sku} • ${item.product.stockQuantity.toInt()} left',
                                                            style: TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    textSecondary),
                                                          ),
                                                          if (item.batchNumber !=
                                                                  null &&
                                                              item.batchNumber!
                                                                  .isNotEmpty)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5,
                                                                      vertical:
                                                                          1),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFF312E81)
                                                                    : const Color(
                                                                        0xFFEEF2FF),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            3),
                                                                border: Border.all(
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF4338CA)
                                                                        : const Color(
                                                                            0xFFC7D2FE)),
                                                              ),
                                                              child: Text(
                                                                'Batch: ${item.batchNumber}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFFA5B4FC)
                                                                        : const Color(
                                                                            0xFF4F46E5)),
                                                              ),
                                                            ),
                                                          if (item.expiryDate !=
                                                                  null &&
                                                              item.expiryDate!
                                                                  .isNotEmpty)
                                                            Builder(
                                                              builder: (_) {
                                                                final expDays =
                                                                    _getDaysUntilExpiry(
                                                                        item.expiryDate);
                                                                final isExp =
                                                                    expDays !=
                                                                            null &&
                                                                        expDays <
                                                                            0;
                                                                final isNear =
                                                                    expDays !=
                                                                            null &&
                                                                        expDays >=
                                                                            0 &&
                                                                        expDays <=
                                                                            60;
                                                                final bg = isExp
                                                                    ? (isDark
                                                                        ? const Color(
                                                                            0xFF450A0A)
                                                                        : const Color(
                                                                            0xFFFEE2E2))
                                                                    : (isNear
                                                                        ? (isDark
                                                                            ? const Color(
                                                                                0xFF451A03)
                                                                            : const Color(
                                                                                0xFFFEF3C7))
                                                                        : (isDark
                                                                            ? const Color(0xFF1E293B)
                                                                            : const Color(0xFFF1F5F9)));
                                                                final border = isExp
                                                                    ? (isDark
                                                                        ? const Color(
                                                                            0xFF7F1D1D)
                                                                        : const Color(
                                                                            0xFFFECACA))
                                                                    : (isNear
                                                                        ? (isDark
                                                                            ? const Color(
                                                                                0xFF78350F)
                                                                            : const Color(
                                                                                0xFFFDE68A))
                                                                        : (isDark
                                                                            ? const Color(0xFF334155)
                                                                            : const Color(0xFFCBD5E1)));
                                                                final textCol = isExp
                                                                    ? (isDark
                                                                        ? const Color(
                                                                            0xFFF87171)
                                                                        : const Color(
                                                                            0xFFDC2626))
                                                                    : (isNear
                                                                        ? (isDark
                                                                            ? const Color(0xFFFCD34D)
                                                                            : const Color(0xFFD97706))
                                                                        : textSecondary);
                                                                final label = isExp
                                                                    ? 'EXPIRED: ${item.expiryDate}'
                                                                    : (isNear
                                                                        ? 'Nearing Expiry: ${item.expiryDate} (${expDays}d left)'
                                                                        : 'Exp: ${item.expiryDate}');
                                                                return Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5,
                                                                      vertical:
                                                                          1),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: bg,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(3),
                                                                    border: Border.all(
                                                                        color:
                                                                            border),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      if (isExp ||
                                                                          isNear) ...[
                                                                        Icon(
                                                                          isExp
                                                                              ? Icons.cancel_outlined
                                                                              : Icons.warning_amber_rounded,
                                                                          size:
                                                                              11,
                                                                          color:
                                                                              textCol,
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                3),
                                                                      ],
                                                                      Text(
                                                                        label,
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                10,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: textCol),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          if (item.bonusQuantity >
                                                              0)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5,
                                                                      vertical:
                                                                          1),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFF052E16)
                                                                    : const Color(
                                                                        0xFFECFDF5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            3),
                                                                border: Border.all(
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF065F46)
                                                                        : const Color(
                                                                            0xFFA7F3D0)),
                                                              ),
                                                              child: Text(
                                                                '+Bonus: ${item.bonusQuantity.toInt()}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF6EE7B7)
                                                                        : const Color(
                                                                            0xFF059669)),
                                                              ),
                                                            ),
                                                          if (item.calculatedDiscount >
                                                              0)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5,
                                                                      vertical:
                                                                          1),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFF450A0A)
                                                                    : const Color(
                                                                        0xFFFEE2E2),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            3),
                                                                border: Border.all(
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF7F1D1D)
                                                                        : const Color(
                                                                            0xFFFECACA)),
                                                              ),
                                                              child: Text(
                                                                item.packDiscount >
                                                                        0
                                                                    ? 'Disc: ${item.packDiscount.toStringAsFixed(0)}% (-$currency ${item.calculatedDiscount.toStringAsFixed(2)})'
                                                                    : 'Disc: -$currency ${item.calculatedDiscount.toStringAsFixed(2)}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFFF87171)
                                                                        : const Color(
                                                                            0xFFDC2626)),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Quantity Stepper: [-] 1.00 [+] Pieces
                                                Expanded(
                                                  flex: 3,
                                                  child: Column(
                                                    children: [
                                                      FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            // [-] Red button
                                                            InkWell(
                                                              onTap: () => ref
                                                                  .read(cartProvider
                                                                      .notifier)
                                                                  .decrementQuantity(
                                                                      index),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              child: Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        3),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFF450A0A)
                                                                      : const Color(
                                                                          0xFFFEE2E2),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: const Text(
                                                                    '-',
                                                                    style: TextStyle(
                                                                        color: Color(
                                                                            0xFFEF4444),
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize:
                                                                            16)),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6),
                                                              child: InkWell(
                                                                onTap: () =>
                                                                    _openQuantityDialog(
                                                                        item,
                                                                        index),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                                child:
                                                                    Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF334155)
                                                                        : const Color(
                                                                            0xFFF1F5F9),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(4),
                                                                    border: Border.all(
                                                                        color: isDark
                                                                            ? const Color(
                                                                                0xFF475569)
                                                                            : const Color(
                                                                                0xFFCBD5E1),
                                                                        width:
                                                                            0.8),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        item.quantity == item.quantity.toInt()
                                                                            ? item.quantity
                                                                                .toInt()
                                                                                .toString()
                                                                            : item.quantity.toStringAsFixed(widget.settings.quantityPrecision > 0
                                                                                ? widget.settings.quantityPrecision
                                                                                : 2),
                                                                        style: TextStyle(
                                                                            fontWeight: FontWeight
                                                                                .bold,
                                                                            fontSize:
                                                                                13,
                                                                            color:
                                                                                textPrimary),
                                                                      ),
                                                                      const SizedBox(
                                                                          width:
                                                                              3),
                                                                      Icon(
                                                                          Icons
                                                                              .edit_note_rounded,
                                                                          size:
                                                                              13,
                                                                          color:
                                                                              textSecondary),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            // [+] Green button
                                                            InkWell(
                                                              onTap: () =>
                                                                  _tryIncrementCartItem(
                                                                      index),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              child: Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        3),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFF052E16)
                                                                      : const Color(
                                                                          0xFFDCFCE7),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: const Text(
                                                                    '+',
                                                                    style: TextStyle(
                                                                        color: Color(
                                                                            0xFF16A34A),
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize:
                                                                            16)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      InkWell(
                                                        onTap: () =>
                                                            _openUnitSelectorForCartItem(
                                                                item, index),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF334155)
                                                                : const Color(
                                                                    0xFFEFF6FF),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                            border: Border.all(
                                                                color: const Color(
                                                                        0xFF3B82F6)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.4),
                                                                width: 0.8),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                item.selectedUnitName ??
                                                                    item.product
                                                                        .unit,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Color(
                                                                        0xFF2563EB)),
                                                              ),
                                                              const SizedBox(
                                                                  width: 2),
                                                              const Icon(
                                                                  Icons
                                                                      .keyboard_arrow_down_rounded,
                                                                  size: 12,
                                                                  color: Color(
                                                                      0xFF2563EB)),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Price Inc. Tax input field (Click to edit price / item discount)
                                                Expanded(
                                                  flex: 3,
                                                  child: Center(
                                                    child: Tooltip(
                                                      message:
                                                          'Click to edit item price or discount',
                                                      child: InkWell(
                                                        onTap: () =>
                                                            _showItemDiscountDialog(
                                                                item, index),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        child: Container(
                                                          width: 86,
                                                          height: 32,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: inputBg,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                            border: Border.all(
                                                                color: item.calculatedDiscount >
                                                                        0
                                                                    ? const Color(
                                                                        0xFFEF4444)
                                                                    : inputBorder),
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      item.unitPrice
                                                                          .toStringAsFixed(
                                                                              2),
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        fontSize:
                                                                            12,
                                                                        color: item.calculatedDiscount >
                                                                                0
                                                                            ? const Color(0xFFEF4444)
                                                                            : textPrimary,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            3),
                                                                    Icon(
                                                                        Icons
                                                                            .edit,
                                                                        size:
                                                                            10,
                                                                        color:
                                                                            textSecondary),
                                                                  ],
                                                                ),
                                                                if (item.calculatedDiscount >
                                                                    0)
                                                                  Text(
                                                                    item.discountType ==
                                                                                'percentage' &&
                                                                            item.discountValue >
                                                                                0
                                                                        ? '-${item.discountValue.toStringAsFixed(item.discountValue == item.discountValue.roundToDouble() ? 0 : 1)}%'
                                                                        : '-$currency${item.calculatedDiscount.toStringAsFixed(0)}',
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            9,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: Color(
                                                                            0xFFEF4444)),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // Subtotal
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '$currency ${item.subtotal.toStringAsFixed(2)}',
                                                    textAlign: TextAlign.right,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color: textPrimary),
                                                  ),
                                                ),

                                                // Trash Red button
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 18,
                                                      color: Color(0xFFEF4444)),
                                                  onPressed: () => ref
                                                      .read(
                                                          cartProvider.notifier)
                                                      .removeAt(index),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              // ================= CART BOTTOM SUMMARY BAR =================
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 10 : 16,
                                    vertical: isSmallScreen ? 6 : 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF0FDF4),
                                  border: Border(
                                      top: BorderSide(
                                          color: isDark
                                              ? const Color(0xFF1E3A2F)
                                              : const Color(0xFFBBF7D0))),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _summaryBlock(
                                                PosLocalization.tr('ITEMS',
                                                    settings: widget.settings),
                                                _totalQuantity
                                                    .toStringAsFixed(2),
                                                isDark: isDark,
                                                isSmall: isSmallScreen),
                                            SizedBox(
                                                width: isSmallScreen ? 8 : 14),
                                            _summaryBlock(
                                                PosLocalization.tr('SUBTOTAL',
                                                    settings: widget.settings),
                                                '$currency ${_subtotal.toStringAsFixed(2)}',
                                                isDark: isDark,
                                                isSmall: isSmallScreen),
                                            SizedBox(
                                                width: isSmallScreen ? 8 : 14),
                                            _summaryBlock(
                                              PosLocalization.tr('DISCOUNT(-)',
                                                  settings: widget.settings),
                                              _discountValue <= 0
                                                  ? '$currency 0.00'
                                                  : (_discountType ==
                                                          'percentage'
                                                      ? '${_discountValue.toStringAsFixed(_discountValue.truncateToDouble() == _discountValue ? 0 : 2)}% ($currency ${_calculatedDiscount.toStringAsFixed(2)})'
                                                      : '$currency ${_calculatedDiscount.toStringAsFixed(2)}'),
                                              isEditable: true,
                                              onEdit: _showOrderDiscountDialog,
                                              isDark: isDark,
                                              isSmall: isSmallScreen,
                                            ),
                                            SizedBox(
                                                width: isSmallScreen ? 8 : 14),
                                            _summaryBlock(
                                                PosLocalization.tr(
                                                    'ORDER TAX(+)',
                                                    settings: widget.settings),
                                                '$currency ${_orderTax.toStringAsFixed(2)}',
                                                isEditable: true,
                                                onEdit: _showOrderTaxDialog,
                                                isDark: isDark,
                                                isSmall: isSmallScreen),
                                            SizedBox(
                                                width: isSmallScreen ? 8 : 14),
                                            _summaryBlock(
                                                PosLocalization.tr(
                                                    'SHIPPING(+)',
                                                    settings: widget.settings),
                                                '$currency ${_shippingCharge.toStringAsFixed(2)}',
                                                isEditable: true,
                                                onEdit: _showShippingDialog,
                                                isDark: isDark,
                                                isSmall: isSmallScreen),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 16),

                                    // Big Green TOTAL PAYABLE Box with Words (Urdu & Multi-language)
                                    InkWell(
                                      onTap: _showWordsLanguageDialog,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Tooltip(
                                        message: widget.settings
                                                .enableSecondaryLanguage
                                            ? 'Click to change words language (${_wordsLanguage.toUpperCase()}) / زبان تبدیل کریں'
                                            : 'Click to change words language (${_wordsLanguage.toUpperCase()})',
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  isSmallScreen ? 10 : 16,
                                              vertical: isSmallScreen ? 4 : 6),
                                          constraints: BoxConstraints(
                                              minWidth:
                                                  isSmallScreen ? 130 : 160),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF064E3B)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF86EFAC)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.translate,
                                                    size:
                                                        isSmallScreen ? 10 : 11,
                                                    color: isDark
                                                        ? const Color(
                                                                0xFF6EE7B7)
                                                            .withValues(
                                                                alpha: 0.8)
                                                        : const Color(
                                                                0xFF16A34A)
                                                            .withValues(
                                                                alpha: 0.8),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    PosLocalization.tr(
                                                        'TOTAL PAYABLE',
                                                        settings:
                                                            widget.settings),
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen
                                                          ? 10
                                                          : 11,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF6EE7B7)
                                                          : const Color(
                                                              0xFF16A34A),
                                                      letterSpacing:
                                                          isSmallScreen
                                                              ? 0.4
                                                              : 0.8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                _grandTotal.toStringAsFixed(2),
                                                style: TextStyle(
                                                  fontSize:
                                                      isSmallScreen ? 20 : 26,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF15803D),
                                                  height: 1.1,
                                                ),
                                              ),
                                              if (_grandTotal > 0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 2),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                        maxWidth: isSmallScreen
                                                            ? 180
                                                            : 240),
                                                    child: Text(
                                                      NumberToWordsService
                                                          .convert(
                                                        _grandTotal,
                                                        language:
                                                            _wordsLanguage,
                                                        currencySymbol: widget
                                                            .settings
                                                            .currencySymbol,
                                                        currencyCode: widget
                                                            .settings
                                                            .currencyCode,
                                                      ),
                                                      textDirection:
                                                          NumberToWordsService
                                                                  .isRtl(
                                                                      _wordsLanguage)
                                                              ? ui.TextDirection
                                                                  .rtl
                                                              : ui.TextDirection
                                                                  .ltr,
                                                      textAlign:
                                                          TextAlign.right,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen
                                                            ? 9.5
                                                            : 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        height: 1.2,
                                                        color: isDark
                                                            ? const Color(
                                                                0xFFA7F3D0)
                                                            : const Color(
                                                                0xFF166534),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ================= BOTTOM ACTIONS ROW =================
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: isSmallScreen ? 4 : 8),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  border: Border(
                                      top: BorderSide(color: borderColor)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Secondary Quick Action Tools
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          // [ Cancel ]
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                  color: Color(0xFFEF4444)),
                                              foregroundColor:
                                                  const Color(0xFFEF4444),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isSmallScreen ? 6 : 10,
                                                  vertical:
                                                      isSmallScreen ? 4 : 8),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6)),
                                            ),
                                            icon: const Icon(Icons.close,
                                                size: 14),
                                            label: Text(
                                                PosLocalization.tr('Cancel',
                                                    settings: widget.settings),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: isSmallScreen
                                                        ? 10
                                                        : 11)),
                                            onPressed: _clearCart,
                                          ),
                                          SizedBox(
                                              width: isSmallScreen ? 4 : 6),

                                          // [ Draft ]
                                          _bottomOutlineBtn(
                                              icon: Icons.edit_note,
                                              label: PosLocalization.tr('Draft',
                                                  settings: widget.settings),
                                              onTap: _saveDraft,
                                              isDark: isDark,
                                              isSmall: isSmallScreen),

                                          // [ Quotation ]
                                          _bottomOutlineBtn(
                                              icon: Icons.assignment_outlined,
                                              label: PosLocalization.tr(
                                                  'Quotation',
                                                  settings: widget.settings),
                                              onTap: _saveQuotation,
                                              isDark: isDark,
                                              isSmall: isSmallScreen),

                                          // [ Suspend ]
                                          Tooltip(
                                            message: 'Suspend / Hold Sale [F4]',
                                            child: _bottomOutlineBtn(
                                                icon: Icons.pause,
                                                label: PosLocalization.tr(
                                                    'Suspend',
                                                    settings: widget.settings),
                                                color: const Color(0xFFD97706),
                                                onTap: _suspendSale,
                                                isDark: isDark,
                                                isSmall: isSmallScreen),
                                          ),

                                          if (widget
                                              .settings.enableCounterTokenQueue)
                                            Tooltip(
                                              message:
                                                  'Send bill token to Main Payment Counter queue',
                                              child: _bottomOutlineBtn(
                                                  icon: Icons
                                                      .confirmation_number_outlined,
                                                  label: PosLocalization.tr(
                                                      'Send Token',
                                                      settings:
                                                          widget.settings),
                                                  color:
                                                      const Color(0xFF0D9488),
                                                  onTap:
                                                      _sendToCashCounterToken,
                                                  isDark: isDark,
                                                  isSmall: isSmallScreen),
                                            ),

                                          // [ Credit Sale ]
                                          _bottomOutlineBtn(
                                              icon: Icons.check,
                                              label: PosLocalization.tr(
                                                  'Credit Sale',
                                                  settings: widget.settings),
                                              onTap: _quickCreditCheckout,
                                              isDark: isDark,
                                              isSmall: isSmallScreen),

                                          // [ Recent Sales F9 ]
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: isDark
                                                      ? const Color(0xFF4338CA)
                                                      : const Color(
                                                          0xFFC7D2FE)),
                                              backgroundColor: isDark
                                                  ? const Color(0xFF312E81)
                                                      .withValues(alpha: 0.3)
                                                  : const Color(0xFFEEF2FF),
                                              foregroundColor: isDark
                                                  ? const Color(0xFFA5B4FC)
                                                  : const Color(0xFF4F46E5),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isSmallScreen ? 6 : 10,
                                                  vertical:
                                                      isSmallScreen ? 4 : 8),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6)),
                                            ),
                                            icon: const Icon(
                                                Icons.access_time_rounded,
                                                size: 14),
                                            label: Text(
                                                PosLocalization.tr(
                                                    'Recent Sales [F9]',
                                                    settings: widget.settings),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: isSmallScreen
                                                        ? 10
                                                        : 11)),
                                            onPressed:
                                                _openRecentTransactionsModal,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 4 : 8),

                                    // 2. Primary Checkout Buttons (Card, Multiple Pay [F7], Cash [F2])
                                    // Always fully visible across the entire bottom without any horizontal scroll
                                    Row(
                                      children: [
                                        // [ Card ]
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Color(0xFFEC4899)),
                                            foregroundColor:
                                                const Color(0xFFEC4899),
                                            padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    isSmallScreen ? 8 : 14,
                                                vertical:
                                                    isSmallScreen ? 7 : 11),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.credit_card,
                                              size: 16),
                                          label: Text(
                                              PosLocalization.tr('Card',
                                                  settings: widget.settings),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      isSmallScreen ? 11 : 12)),
                                          onPressed: _quickCardCheckout,
                                        ),
                                        SizedBox(width: isSmallScreen ? 6 : 8),

                                        // [ Multiple Pay ]
                                        Expanded(
                                          flex: 1,
                                          child: Tooltip(
                                            message:
                                                'Multiple / Split Payment [F7]',
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFF1E293B),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        isSmallScreen ? 6 : 10,
                                                    vertical:
                                                        isSmallScreen ? 7 : 12),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                              ),
                                              icon: const Icon(
                                                  Icons.payments_outlined,
                                                  size: 16),
                                              label: Text(
                                                PosLocalization.tr(
                                                    'Multiple Pay',
                                                    settings: widget.settings),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: isSmallScreen
                                                        ? 11
                                                        : 12.5),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              onPressed:
                                                  _handleMultiplePayClick,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: isSmallScreen ? 6 : 8),

                                        // [ Cash ]
                                        Expanded(
                                          flex: 1,
                                          child: Tooltip(
                                            message: 'Quick Cash Checkout [F2]',
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        isSmallScreen ? 8 : 12,
                                                    vertical:
                                                        isSmallScreen ? 7 : 12),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                              ),
                                              icon: const Icon(Icons.money,
                                                  size: 16),
                                              label: Text(
                                                PosLocalization.tr('Cash',
                                                    settings: widget.settings),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: isSmallScreen
                                                        ? 11.5
                                                        : 13.5),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              onPressed: _quickCashCheckout,
                                            ),
                                          ),
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

                    // ================= RIGHT: COMPACT PRODUCT CATALOG =================
                    if ((!isTabletCompact && _showProductPanel) ||
                        (isTabletCompact && _mobileTabIndex == 1))
                      Expanded(
                        flex: isTabletCompact ? 1 : 3,
                        child: Container(
                          color: subtleBg,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Dedicated Product Search & Barcode Scanner
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(color: borderColor)),
                                ),
                                child: _buildBarcodeSearchRow(
                                  isDark: isDark,
                                  inputBg: inputBg,
                                  inputBorder: inputBorder,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),

                              // Row 2: Filter Pills & View Layout Switcher (Directly above products)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  border: Border(
                                    bottom: BorderSide(
                                        color: borderColor, width: 0.8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _filterBtn(
                                              icon: Icons.grid_view_outlined,
                                              label: _selectedCategoryId != null
                                                  ? 'Category: ${_categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => Category(name: 'Category', code: '')).name}'
                                                  : 'Category',
                                              count: _selectedCategoryId != null
                                                  ? null
                                                  : _categories.length,
                                              isSelected:
                                                  _selectedCategoryId != null,
                                              onTap: _showCategoryFilterDialog,
                                              onClear:
                                                  _selectedCategoryId != null
                                                      ? () {
                                                          setState(() =>
                                                              _selectedCategoryId =
                                                                  null);
                                                          _applyProductFilter();
                                                        }
                                                      : null,
                                              isDark: isDark,
                                            ),
                                            const SizedBox(width: 8),
                                            _filterBtn(
                                              icon: Icons
                                                  .branding_watermark_outlined,
                                              label: _selectedBrandId != null
                                                  ? 'Brand: ${_brands.firstWhere((b) => b.id == _selectedBrandId, orElse: () => Brand(name: 'Brand')).name}'
                                                  : 'Brands',
                                              count: _selectedBrandId != null
                                                  ? null
                                                  : _brands.length,
                                              isSelected:
                                                  _selectedBrandId != null,
                                              onTap: _showBrandFilterDialog,
                                              onClear: _selectedBrandId != null
                                                  ? () {
                                                      setState(() =>
                                                          _selectedBrandId =
                                                              null);
                                                      _applyProductFilter();
                                                    }
                                                  : null,
                                              isDark: isDark,
                                            ),
                                            const SizedBox(width: 8),
                                            _filterBtn(
                                              icon: Icons.star_border,
                                              label: 'Featured Products',
                                              count: null,
                                              isSelected: _filterFeatured,
                                              onTap: () {
                                                setState(() => _filterFeatured =
                                                    !_filterFeatured);
                                                _applyProductFilter();
                                              },
                                              isDark: isDark,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Segmented Layout Switcher: [ ⊞ Grid ] [ List ]
                                    Container(
                                      height: 30,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: inputBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Grid View Button
                                          Tooltip(
                                            message: 'Grid View [F5]',
                                            child: InkWell(
                                              onTap: () {
                                                if (!_isGridView) {
                                                  _toggleProductLayout();
                                                }
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: _isGridView
                                                      ? const Color(0xFF4F46E5)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.grid_view_rounded,
                                                      size: 13,
                                                      color: _isGridView
                                                          ? Colors.white
                                                          : textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Grid',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: _isGridView
                                                            ? Colors.white
                                                            : textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),

                                          // List View Button
                                          Tooltip(
                                            message: 'List View [F5]',
                                            child: InkWell(
                                              onTap: () {
                                                if (_isGridView) {
                                                  _toggleProductLayout();
                                                }
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: !_isGridView
                                                      ? const Color(0xFF4F46E5)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .format_list_bulleted_rounded,
                                                      size: 14,
                                                      color: !_isGridView
                                                          ? Colors.white
                                                          : textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'List',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: !_isGridView
                                                            ? Colors.white
                                                            : textSecondary,
                                                      ),
                                                    ),
                                                  ],
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

                              // Switchable Product Layout: Grid OR List View
                              Expanded(
                                child: _loadingCatalog
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : _products.isEmpty
                                        ? Center(
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 450),
                                              padding: const EdgeInsets.all(28),
                                              decoration: BoxDecoration(
                                                color: cardBg,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: borderColor),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF4F46E5)
                                                          .withValues(
                                                              alpha: 0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons
                                                            .point_of_sale_rounded,
                                                        color:
                                                            Color(0xFF4F46E5),
                                                        size: 30),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  Text(
                                                    PosLocalization.tr(
                                                        'No Products in Catalog Yet',
                                                        settings:
                                                            widget.settings),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    PosLocalization.tr(
                                                        'Add products with selling price and initial stock to start billing immediately!',
                                                        settings:
                                                            widget.settings),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: textSecondary,
                                                        height: 1.4),
                                                  ),
                                                  const SizedBox(height: 18),
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF4F46E5),
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 20,
                                                          vertical: 12),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                    ),
                                                    icon: const Icon(
                                                        Icons.add_rounded,
                                                        size: 18),
                                                    label: Text(
                                                      PosLocalization.tr(
                                                          '+ Add First Product',
                                                          settings:
                                                              widget.settings),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13),
                                                    ),
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (_) =>
                                                            AddProductDialog(
                                                          onProductSaved:
                                                              () async {
                                                            await _reloadCatalogFromScratch();
                                                          },
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : _isGridView
                                            ? LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  final width =
                                                      constraints.maxWidth;
                                                  // High-density responsive column count:
                                                  final int crossAxisCount =
                                                      width >= 1100
                                                          ? 6
                                                          : (width >= 880
                                                              ? 5
                                                              : (width >= 660
                                                                  ? 4
                                                                  : (width >=
                                                                          440
                                                                      ? 3
                                                                      : 2)));
                                                  // Fixed compact height so cards never stretch into giant blocks
                                                  const double cardHeight =
                                                      122.0;

                                                  return GridView.builder(
                                                    controller:
                                                        _catalogScrollController,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    gridDelegate:
                                                        SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount:
                                                          crossAxisCount,
                                                      mainAxisExtent:
                                                          cardHeight,
                                                      crossAxisSpacing: 6,
                                                      mainAxisSpacing: 6,
                                                    ),
                                                    itemCount:
                                                        _products.length +
                                                            (_loadingMoreCatalog
                                                                ? 1
                                                                : 0),
                                                    itemBuilder:
                                                        (context, index) {
                                                      if (index >=
                                                          _products.length) {
                                                        return const Center(
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    12),
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2),
                                                          ),
                                                        );
                                                      }
                                                      final p =
                                                          _products[index];
                                                      final currency = widget
                                                          .settings
                                                          .currencySymbol;
                                                      final isOutOfStock =
                                                          p.isOutOfStock;
                                                      final isLowStock =
                                                          !isOutOfStock &&
                                                              p.stockQuantity <=
                                                                  5;

                                                      return Material(
                                                        color: cardBg,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        elevation: 0,
                                                        clipBehavior:
                                                            Clip.antiAlias,
                                                        child: InkWell(
                                                          onTap: () =>
                                                              _addToCart(p),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          hoverColor:
                                                              const Color(
                                                                      0xFF4F46E5)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.04),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        7,
                                                                    vertical:
                                                                        6),
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                              border: Border.all(
                                                                  color:
                                                                      borderColor),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                // Top Row: Stock Badge & Unit
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Container(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              4,
                                                                          vertical:
                                                                              1.5),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: isOutOfStock
                                                                            ? (isDark
                                                                                ? const Color(0xFF450A0A)
                                                                                : const Color(0xFFFEE2E2))
                                                                            : (isLowStock ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)) : (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7))),
                                                                        borderRadius:
                                                                            BorderRadius.circular(3),
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        isOutOfStock
                                                                            ? 'Out of stock'
                                                                            : '${p.stockQuantity % 1 == 0 ? p.stockQuantity.toInt() : p.stockQuantity.toStringAsFixed(1)} in stock',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              8.5,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color: isOutOfStock
                                                                              ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                                                              : (isLowStock ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706)) : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A))),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    if (p.unit
                                                                        .isNotEmpty)
                                                                      Flexible(
                                                                        child:
                                                                            Text(
                                                                          p.unit,
                                                                          style: TextStyle(
                                                                              fontSize: 8.5,
                                                                              fontWeight: FontWeight.w600,
                                                                              color: textSecondary),
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),

                                                                // Product Thumbnail, Title & Details
                                                                Expanded(
                                                                  child:
                                                                      Padding(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        vertical:
                                                                            2),
                                                                    child: Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        ProductThumbnail(
                                                                          imagePath:
                                                                              p.resolvedImagePath,
                                                                          imageColor:
                                                                              p.imageColor,
                                                                          size:
                                                                              36,
                                                                          borderRadius:
                                                                              6,
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                7),
                                                                        Expanded(
                                                                          child:
                                                                              Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            children: [
                                                                              Text(
                                                                                p.name,
                                                                                style: TextStyle(
                                                                                  fontWeight: FontWeight.bold,
                                                                                  fontSize: 11,
                                                                                  color: textPrimary,
                                                                                  height: 1.15,
                                                                                ),
                                                                                maxLines: 2,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                              const SizedBox(height: 1),
                                                                              Row(
                                                                                children: [
                                                                                  if (p.isVariable) ...[
                                                                                    Container(
                                                                                      margin: const EdgeInsets.only(right: 4),
                                                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                                                                      decoration: BoxDecoration(
                                                                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.14),
                                                                                        borderRadius: BorderRadius.circular(3),
                                                                                      ),
                                                                                      child: const Text(
                                                                                        'VAR',
                                                                                        style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                  Expanded(
                                                                                    child: Text(
                                                                                      p.sku,
                                                                                      style: TextStyle(fontSize: 9, color: textSecondary),
                                                                                      maxLines: 1,
                                                                                      overflow: TextOverflow.ellipsis,
                                                                                    ),
                                                                                  ),
                                                                                  if (p.expiryDate != null && p.expiryDate!.isNotEmpty) ...[
                                                                                    Builder(
                                                                                      builder: (_) {
                                                                                        final pExp = _getDaysUntilExpiry(p.expiryDate);
                                                                                        if (pExp == null || pExp > 60) return const SizedBox.shrink();
                                                                                        final isExp = pExp < 0;
                                                                                        return Container(
                                                                                          margin: const EdgeInsets.only(left: 3),
                                                                                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                                                          decoration: BoxDecoration(
                                                                                            color: isExp ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2)) : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
                                                                                            borderRadius: BorderRadius.circular(3),
                                                                                            border: Border.all(
                                                                                              color: isExp ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                                                                              width: 0.5,
                                                                                            ),
                                                                                          ),
                                                                                          child: Row(
                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                            children: [
                                                                                              Icon(
                                                                                                isExp ? Icons.cancel_outlined : Icons.warning_amber_rounded,
                                                                                                size: 8,
                                                                                                color: isExp ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)) : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706)),
                                                                                              ),
                                                                                              const SizedBox(width: 1.5),
                                                                                              Text(
                                                                                                isExp ? 'Expired' : '${pExp}d',
                                                                                                style: TextStyle(
                                                                                                  fontSize: 7.5,
                                                                                                  fontWeight: FontWeight.bold,
                                                                                                  color: isExp ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)) : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706)),
                                                                                                ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    ),
                                                                                  ],
                                                                                ],
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),

                                                                // Price & Add Button Row
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              11.5,
                                                                          fontWeight:
                                                                              FontWeight.w900,
                                                                          color: isDark
                                                                              ? const Color(0xFFA5B4FC)
                                                                              : const Color(0xFF4F46E5),
                                                                        ),
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      width: 20,
                                                                      height:
                                                                          20,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: const Color(
                                                                            0xFF4F46E5),
                                                                        borderRadius:
                                                                            BorderRadius.circular(4),
                                                                      ),
                                                                      child: const Icon(
                                                                          Icons
                                                                              .add,
                                                                          color: Colors
                                                                              .white,
                                                                          size:
                                                                              13),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              )
                                            : ListView.separated(
                                                controller:
                                                    _catalogScrollController,
                                                padding: EdgeInsets.all(
                                                    isSmallScreen ? 6 : 10),
                                                itemCount: _products.length +
                                                    (_loadingMoreCatalog
                                                        ? 1
                                                        : 0),
                                                separatorBuilder: (_, __) =>
                                                    SizedBox(
                                                        height: isSmallScreen
                                                            ? 4
                                                            : 6),
                                                itemBuilder: (context, index) {
                                                  if (index >=
                                                      _products.length) {
                                                    return const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 12),
                                                      child: Center(
                                                        child: SizedBox(
                                                          width: 22,
                                                          height: 22,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  final p = _products[index];
                                                  final currency = widget
                                                      .settings.currencySymbol;
                                                  final isOutOfStock =
                                                      p.isOutOfStock;
                                                  final isLowStock =
                                                      !isOutOfStock &&
                                                          p.stockQuantity <= 5;
                                                  final isDenseCatalog =
                                                      isSmallScreen ||
                                                          widget.settings
                                                              .compactPosProductList;

                                                  return Material(
                                                    color: cardBg,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            isDenseCatalog
                                                                ? 6
                                                                : 8),
                                                    child: InkWell(
                                                      onTap: () =>
                                                          _addToCart(p),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              isDenseCatalog
                                                                  ? 6
                                                                  : 8),
                                                      child: Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          horizontal:
                                                              isDenseCatalog
                                                                  ? 8
                                                                  : 14,
                                                          vertical:
                                                              isDenseCatalog
                                                                  ? 5
                                                                  : 10,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  isDenseCatalog
                                                                      ? 6
                                                                      : 8),
                                                          border: Border.all(
                                                              color:
                                                                  borderColor),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            ProductThumbnail(
                                                              imagePath: p
                                                                  .resolvedImagePath,
                                                              imageColor:
                                                                  p.imageColor,
                                                              size:
                                                                  isDenseCatalog
                                                                      ? 28
                                                                      : 38,
                                                              borderRadius:
                                                                  isDenseCatalog
                                                                      ? 6
                                                                      : 8,
                                                              fallbackIcon: Icons
                                                                  .inventory_2_outlined,
                                                            ),
                                                            SizedBox(
                                                                width:
                                                                    isDenseCatalog
                                                                        ? 7
                                                                        : 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      if (p
                                                                          .isVariable) ...[
                                                                        Container(
                                                                          margin: const EdgeInsets
                                                                              .only(
                                                                              right: 6),
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal: 5,
                                                                              vertical: 1),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                const Color(0xFF4F46E5).withValues(alpha: 0.14),
                                                                            borderRadius:
                                                                                BorderRadius.circular(4),
                                                                          ),
                                                                          child:
                                                                              const Text(
                                                                            'VAR',
                                                                            style: TextStyle(
                                                                                fontSize: 8.5,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: Color(0xFF4F46E5)),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          p.name,
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize: isSmallScreen
                                                                                ? 12
                                                                                : 13,
                                                                            color:
                                                                                textPrimary,
                                                                          ),
                                                                          maxLines:
                                                                              1,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          2),
                                                                  Wrap(
                                                                    spacing:
                                                                        isSmallScreen
                                                                            ? 6
                                                                            : 8,
                                                                    runSpacing:
                                                                        2,
                                                                    children: [
                                                                      Text(
                                                                          'SKU: ${p.sku}',
                                                                          style: TextStyle(
                                                                              fontSize: isSmallScreen ? 10 : 11,
                                                                              color: textSecondary)),
                                                                      if (p.unit
                                                                          .isNotEmpty)
                                                                        Text(
                                                                            '• Unit: ${p.unit}',
                                                                            style:
                                                                                TextStyle(fontSize: isSmallScreen ? 10 : 11, color: textSecondary)),
                                                                      if (p.batchNumber !=
                                                                              null &&
                                                                          p.batchNumber!
                                                                              .isNotEmpty)
                                                                        Text(
                                                                            '• Batch: ${p.batchNumber}',
                                                                            style:
                                                                                TextStyle(fontSize: isSmallScreen ? 10 : 11, color: textSecondary)),
                                                                      if (p.expiryDate !=
                                                                              null &&
                                                                          p.expiryDate!
                                                                              .isNotEmpty)
                                                                        Builder(
                                                                          builder:
                                                                              (_) {
                                                                            final pExp =
                                                                                _getDaysUntilExpiry(p.expiryDate);
                                                                            if (pExp == null ||
                                                                                pExp > 60)
                                                                              return const SizedBox.shrink();
                                                                            final isExp =
                                                                                pExp < 0;
                                                                            return Text(
                                                                              isExp ? '• EXPIRED (${p.expiryDate})' : '• Exp: ${pExp}d (${p.expiryDate})',
                                                                              style: TextStyle(
                                                                                fontSize: isSmallScreen ? 10 : 11,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: isExp ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                                                              ),
                                                                            );
                                                                          },
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            // Stock Status Pill
                                                            Container(
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                horizontal:
                                                                    isSmallScreen
                                                                        ? 6
                                                                        : 8,
                                                                vertical:
                                                                    isSmallScreen
                                                                        ? 2
                                                                        : 3,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isOutOfStock
                                                                    ? (isDark
                                                                        ? const Color(
                                                                            0xFF450A0A)
                                                                        : const Color(
                                                                            0xFFFEE2E2))
                                                                    : (isLowStock
                                                                        ? (isDark
                                                                            ? const Color(
                                                                                0xFF451A03)
                                                                            : const Color(
                                                                                0xFFFEF3C7))
                                                                        : (isDark
                                                                            ? const Color(0xFF052E16)
                                                                            : const Color(0xFFDCFCE7))),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                              child: Text(
                                                                isOutOfStock
                                                                    ? 'Out'
                                                                    : '${p.stockQuantity.toInt()} stk',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      isDenseCatalog
                                                                          ? 9
                                                                          : 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isOutOfStock
                                                                      ? (isDark
                                                                          ? const Color(
                                                                              0xFFF87171)
                                                                          : const Color(
                                                                              0xFFDC2626))
                                                                      : (isLowStock
                                                                          ? (isDark
                                                                              ? const Color(
                                                                                  0xFFFCD34D)
                                                                              : const Color(
                                                                                  0xFFD97706))
                                                                          : (isDark
                                                                              ? const Color(0xFF6EE7B7)
                                                                              : const Color(0xFF16A34A))),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                                width:
                                                                    isDenseCatalog
                                                                        ? 6
                                                                        : 14),
                                                            // Price
                                                            Text(
                                                              '$currency ${p.sellingPrice.toStringAsFixed(0)}',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    isDenseCatalog
                                                                        ? 11.5
                                                                        : 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color:
                                                                    textPrimary,
                                                              ),
                                                            ),
                                                            SizedBox(
                                                                width:
                                                                    isDenseCatalog
                                                                        ? 6
                                                                        : 12),
                                                            // Add Button
                                                            Container(
                                                              width:
                                                                  isDenseCatalog
                                                                      ? 22
                                                                      : 28,
                                                              height:
                                                                  isDenseCatalog
                                                                      ? 22
                                                                      : 28,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                    0xFF4F46E5),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                        isDenseCatalog
                                                                            ? 4
                                                                            : 6),
                                                              ),
                                                              child: Icon(
                                                                  Icons.add,
                                                                  color: Colors
                                                                      .white,
                                                                  size:
                                                                      isDenseCatalog
                                                                          ? 14
                                                                          : 16),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ================= SPEED SHORTCUTS FOOTER BAR =================
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _shortcutPill(_shortcutBindings['help'] ?? 'F1',
                          'Shortcuts Help (?)', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill(_shortcutBindings['quickCash'] ?? 'F2',
                          'Cash Checkout', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill(_shortcutBindings['customerSearch'] ?? 'F3',
                          'Customer', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill(_shortcutBindings['suspendSale'] ?? 'F4',
                          'Hold Bill', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill(_shortcutBindings['multiPay'] ?? 'F7',
                          'Partial / Split Pay', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill(_shortcutBindings['clearCart'] ?? 'F8',
                          'Reset Order', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill(
                          _shortcutBindings['registerDetails'] ?? 'F10',
                          'Shift Reconciliation',
                          isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('Ctrl+Z', 'Undo Cart', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('Esc', 'Search Focus', isDark),
                      const SizedBox(width: 24),
                      Text(
                        isTouchFriendly
                            ? 'Smart POS • Touch Mode Active'
                            : 'Smart POS Engine • Multi-Industry',
                        style: TextStyle(
                            fontSize: 10,
                            color: textSecondary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutPill(String keyLabel, String actionLabel, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          actionLabel,
          style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _summaryBlock(String label, String value,
      {bool isEditable = false,
      VoidCallback? onEdit,
      bool isDark = false,
      bool isSmall = false}) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: isSmall ? 8.5 : 10,
                    fontWeight: FontWeight.bold,
                    color: textSecondary)),
            if (isEditable) ...[
              const SizedBox(width: 3),
              Icon(Icons.edit,
                  size: isSmall ? 8.5 : 10, color: const Color(0xFF4F46E5)),
            ],
          ],
        ),
        SizedBox(height: isSmall ? 1 : 2),
        Text(value,
            style: TextStyle(
                fontSize: isSmall ? 11 : 13,
                fontWeight: FontWeight.bold,
                color: textPrimary)),
      ],
    );

    if (isEditable && onEdit != null) {
      return InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 2 : 4, vertical: isSmall ? 1 : 2),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _bottomOutlineBtn({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
    bool isDark = false,
    bool isSmall = false,
    EdgeInsetsGeometry? padding,
  }) {
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: EdgeInsets.only(right: isSmall ? 4 : 6),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          foregroundColor: color ?? textPrimary,
          padding: padding ??
              EdgeInsets.symmetric(
                  horizontal: isSmall ? 6 : 10, vertical: isSmall ? 4 : 8),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: isSmall ? 12 : 14, color: color ?? iconColor),
        label: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: isSmall ? 10 : 11)),
        onPressed: onTap,
      ),
    );
  }

  Widget _filterBtn({
    required IconData icon,
    required String label,
    int? count,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onClear,
    bool isDark = false,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
              : cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected
                    ? (isDark
                        ? const Color(0xFFA5B4FC)
                        : const Color(0xFF4F46E5))
                    : textSecondary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFF4F46E5))
                      : textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                ),
              ),
            ],
            if (isSelected && onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close,
                      size: 12,
                      color: isDark
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFF4F46E5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeSearchRow({
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: inputBorder),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSubmitted: _onBarcodeSubmitted,
              onChanged: (val) => _applyProductFilter(),
              style: TextStyle(fontSize: 12.5, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Scan barcode / search item / 2*SKU [Esc]',
                hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
                prefixIcon: Icon(Icons.qr_code_scanner_rounded,
                    size: 17, color: textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 15),
                        onPressed: () {
                          _searchController.clear();
                          _applyProductFilter();
                        },
                        tooltip: 'Clear',
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Fast Price & Stock Checker',
          child: InkWell(
            onTap: _openPriceCheckerDialog,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.qr_code_2_rounded,
                  color: Colors.white, size: 19),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Add Custom Item [F11]',
          child: InkWell(
            onTap: _openCustomProductDialog,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 19),
            ),
          ),
        ),
      ],
    );
  }
}
