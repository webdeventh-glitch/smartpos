import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/app_routes.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/backup_update_service.dart';
import '../services/database_service.dart';
import '../services/qulop_service.dart';
import '../widgets/smart_app_bar.dart';
import '../widgets/smart_sidebar.dart';
import 'pos/register_details_dialog.dart';
import 'dashboard/dashboard_screen.dart';
import 'pos/pos_terminal_screen.dart';
import 'products/products_list_screen.dart';
import 'products/add_product_screen.dart';
import 'products/categories_screen.dart';
import 'products/brands_screen.dart';
import 'products/units_screen.dart';
import 'products/variation_templates_screen.dart';
import 'products/print_labels_screen.dart';
import 'products/warranties_screen.dart';
import 'products/selling_price_groups_screen.dart';
import 'products/discount_rules_screen.dart';
import 'products/import_products_screen.dart';
import 'sales/sales_list_screen.dart';
import 'sales/sales_orders_screen.dart';
import 'sales/commission_agents_screen.dart';
import 'purchases/purchases_list_screen.dart';
import 'purchases/add_purchase_screen.dart';
import 'purchases/purchase_orders_screen.dart';
import 'finance/cheque_management_screen.dart';
import 'contacts/customers_screen.dart';
import 'contacts/suppliers_screen.dart';
import 'expenses/expenses_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import 'users/user_management_screen.dart';
import 'inventory/stock_transfers_screen.dart';
import 'inventory/inventory_audit_screen.dart';
import 'accounts/payment_accounts_screen.dart';
import 'notifications/notification_templates_screen.dart';
import 'returns/sales_return_screen.dart';
import 'returns/purchase_return_screen.dart';
import 'financial/annual_closing_screen.dart';
import 'business_modules/business_modules_hub_screen.dart';
import 'business_modules/restaurant_cafe_screen.dart';
import 'business_modules/repair_service_screen.dart';
import 'business_modules/hotel_management_screen.dart';
import 'business_modules/gym_fitness_screen.dart';
import 'business_modules/manufacturing_screen.dart';
import 'business_modules/woocommerce_sync_screen.dart';
import 'business_modules/hrm_employee_screen.dart';
import 'business_modules/accounting_crm_screen.dart';
import 'business_modules/fruit_mandi_screen.dart';
import 'business_modules/poultry_business_screen.dart';
import 'settings/module_settings_screen.dart';
import 'settings/cloud_sync_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  final BusinessSettings initialSettings;

  const MainShell({super.key, required this.initialSettings});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _sidebarCollapsed = false;
  bool _initializedLayout = false;
  late BusinessSettings _settings;
  String _activeLocationName = 'Main Branch HQ';
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(settingsProvider.notifier).setSettings(_settings);
    });
    _activeLocationName = _settings.branchName;
    AuthService.configureSessionTimeout(_settings.sessionTimeoutMinutes);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => AuthService.checkSessionValidity(),
    );
    BackupUpdateService.instance.startAutoBackupScheduler();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    AuthService.recordActivity();
    return false;
  }

  @override
  void dispose() {
    BackupUpdateService.instance.stopAutoBackupScheduler();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedLayout) {
      _initializedLayout = true;
      if (MediaQuery.of(context).size.width < 1300) {
        _sidebarCollapsed = true;
      }
    }
  }

  Product? _productToEdit;
  Product? _productToPrintLabel;
  Sale? _saleToResumeInPos;

  void _onOpenPos({Sale? saleToResume}) {
    final isCompact = MediaQuery.of(context).size.width < 1400;
    _saleToResumeInPos = saleToResume;
    if (saleToResume != null) {
      setState(() {
        ref.read(navigationProvider.notifier).goTo(AppRoute.posTerminal);
        if (isCompact) _sidebarCollapsed = true;
      });
      return;
    }
    if (_settings.isRestaurant) {
      setState(() {
        ref.read(navigationProvider.notifier).goTo(AppRoute.restaurantCafe);
        if (isCompact) _sidebarCollapsed = true;
      });
    } else if (_settings.isRepair) {
      setState(() {
        ref.read(navigationProvider.notifier).goTo(AppRoute.repairService);
        if (isCompact) _sidebarCollapsed = true;
      });
    } else if (_settings.isHotel) {
      setState(() {
        ref.read(navigationProvider.notifier).goTo(AppRoute.hotelManagement);
        if (isCompact) _sidebarCollapsed = true;
      });
    } else if (_settings.isGym) {
      setState(() {
        ref.read(navigationProvider.notifier).goTo(AppRoute.gymFitness);
        if (isCompact) _sidebarCollapsed = true;
      });
    } else {
      setState(() {
        ref.read(navigationProvider.notifier).goTo(AppRoute.posTerminal);
        if (isCompact) _sidebarCollapsed = true;
      });
    }
  }

  void _onOpenRegister() {
    showDialog(
      context: context,
      builder: (_) => RegisterDetailsDialog(settings: _settings),
    );
  }

  Future<void> _reloadSettings() async {
    final db = await DatabaseService.initialize();
    final fresh = await db.getBusinessSettings();
    if (mounted) {
      setState(() => _settings = fresh);
    }
  }

  void _navigateTo(AppRoute route, {bool collapseOnCompact = false}) {
    ref.read(navigationProvider.notifier).goTo(route);
    if (collapseOnCompact && MediaQuery.of(context).size.width < 1400) {
      setState(() => _sidebarCollapsed = true);
    }
  }

  bool _canAccessRoute(AppRoute route) {
    final user = ref.read(authProvider) ?? AuthService.currentUser;
    if (user == null || user.isAdmin) return true;
    switch (route) {
      case AppRoute.dashboard:
        return true;
      case AppRoute.posTerminal:
      case AppRoute.restaurantCafe:
      case AppRoute.repairService:
      case AppRoute.hotelManagement:
      case AppRoute.gymFitness:
      case AppRoute.fruitMandi:
      case AppRoute.poultryBusiness:
      case AppRoute.businessModulesHub:
      case AppRoute.manufacturing:
      case AppRoute.hrmEmployee:
      case AppRoute.accountingCrm:
      case AppRoute.wooCommerceSync:
        return user.hasPermission('pos.access');
      case AppRoute.productsList:
      case AppRoute.categories:
      case AppRoute.units:
      case AppRoute.brands:
      case AppRoute.warranties:
        return user.hasPermission('product.view');
      case AppRoute.addProduct:
        return _productToEdit != null
            ? user.hasPermission('product.edit')
            : user.hasPermission('product.create');
      case AppRoute.printLabels:
        return user.hasPermission('product.print_labels');
      case AppRoute.importProducts:
        return user.hasPermission('product.import');
      case AppRoute.salesList:
      case AppRoute.salesOrders:
      case AppRoute.commissionAgents:
        return user.hasPermission('sale.view');
      case AppRoute.salesReturn:
        return user.hasPermission('sale.return');
      case AppRoute.purchasesList:
      case AppRoute.purchaseOrders:
        return user.hasPermission('purchase.view');
      case AppRoute.addPurchase:
        return user.hasPermission('purchase.create');
      case AppRoute.purchaseReturn:
        return user.hasPermission('purchase.return');
      case AppRoute.customers:
        return user.hasPermission('customer.view');
      case AppRoute.suppliers:
        return user.hasPermission('supplier.view');
      case AppRoute.expenses:
        return user.hasPermission('expense.view');
      case AppRoute.paymentAccounts:
      case AppRoute.chequeManagement:
        return user.hasPermission('account.manage');
      case AppRoute.reports:
        return user.hasPermission('report.view');
      case AppRoute.stockTransfers:
        return user.hasPermission('inventory.transfer');
      case AppRoute.stockAdjustments:
      case AppRoute.variationTemplates:
      case AppRoute.sellingPriceGroups:
      case AppRoute.discountRules:
        return user.hasPermission('inventory.adjust');
      case AppRoute.inventoryAudit:
        return user.hasPermission('inventory.audit');
      case AppRoute.annualClosing:
        return user.hasPermission('fiscal.close');
      case AppRoute.userManagement:
        return user.hasPermission('user.manage') || user.hasPermission('role.manage');
      case AppRoute.settings:
      case AppRoute.moduleSettings:
      case AppRoute.cloudSync:
      case AppRoute.notificationTemplates:
        return user.hasPermission('settings.manage');
    }
  }

  Widget _buildAccessDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person_rounded, size: 56, color: Color(0xFFDC2626)),
            const SizedBox(height: 14),
            const Text(
              'Access Restricted',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your account role does not have permission to open this module.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _navigateTo(AppRoute.dashboard),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppRoute selectedRoute) {
    if (!_canAccessRoute(selectedRoute)) {
      return _buildAccessDeniedView();
    }
    switch (selectedRoute) {
      case AppRoute.dashboard:
        return DashboardScreen(
          settings: _settings,
          onNavigateToPos: _onOpenPos,
          onNavigateToRoute: _navigateTo,
        );
      case AppRoute.posTerminal:
        return PosTerminalScreen(
          settings: _settings,
          initialSaleToResume: _saleToResumeInPos,
          onBackToDashboard: () => setState(() {
            _saleToResumeInPos = null;
            ref.read(navigationProvider.notifier).goTo(AppRoute.dashboard);
          }),
        );
      case AppRoute.productsList:
        return ProductsListScreen(
          settings: _settings,
          onNavigateToAddProduct: () => setState(() {
            _productToEdit = null;
            ref.read(navigationProvider.notifier).goTo(AppRoute.addProduct);
          }),
          onNavigateToEditProduct: (p) => setState(() {
            _productToEdit = p;
            ref.read(navigationProvider.notifier).goTo(AppRoute.addProduct);
          }),
          onNavigateToPrintLabels: (p) => setState(() {
            _productToPrintLabel = p;
            ref.read(navigationProvider.notifier).goTo(AppRoute.printLabels);
          }),
        );
      case AppRoute.categories:
        return CategoriesScreen(settings: _settings);
      case AppRoute.salesList:
        return SalesListScreen(
          settings: _settings,
          onOpenPos: _onOpenPos,
          onResumeInPos: (sale) => _onOpenPos(saleToResume: sale),
        );
      case AppRoute.purchasesList:
        return PurchasesListScreen(
          settings: _settings,
          onNavigateToAddPurchase: () => _navigateTo(AppRoute.addPurchase),
        );
      case AppRoute.customers:
        return CustomersScreen(settings: _settings);
      case AppRoute.suppliers:
        return SuppliersScreen(settings: _settings);
      case AppRoute.expenses:
        return ExpensesScreen(settings: _settings);
      case AppRoute.reports:
        return ReportsScreen(settings: _settings);
      case AppRoute.settings:
        return SettingsScreen(
          settings: _settings,
          onSettingsUpdated: (updated) => setState(() {
            _settings = updated;
              ref.read(settingsProvider.notifier).setSettings(updated);
            if (updated.branchName.isNotEmpty) {
              _activeLocationName = updated.branchName;
            }
          }),
        );
      case AppRoute.addProduct:
        return AddProductScreen(
          settings: _settings,
          productToEdit: _productToEdit,
          onProductCreated: () => setState(() {
            _productToEdit = null;
            ref.read(navigationProvider.notifier).goTo(AppRoute.productsList);
          }),
          onCancel: () => setState(() {
            _productToEdit = null;
            ref.read(navigationProvider.notifier).goTo(AppRoute.productsList);
          }),
        );
      case AppRoute.userManagement:
        return UserManagementScreen(settings: _settings);
      case AppRoute.stockTransfers:
        return StockTransfersScreen(settings: _settings, initialTab: 0);
      case AppRoute.stockAdjustments:
        return StockTransfersScreen(settings: _settings, initialTab: 1);
      case AppRoute.paymentAccounts:
        return PaymentAccountsScreen(settings: _settings);
      case AppRoute.notificationTemplates:
        return NotificationTemplatesScreen(settings: _settings);
      case AppRoute.printLabels:
        return PrintLabelsScreen(
          settings: _settings,
          initialProduct: _productToPrintLabel,
        );
      case AppRoute.variationTemplates:
        return VariationTemplatesScreen(settings: _settings);
      case AppRoute.units:
        return UnitsScreen(settings: _settings);
      case AppRoute.brands:
        return BrandsScreen(settings: _settings);
      case AppRoute.warranties:
        return WarrantiesScreen(settings: _settings);
      case AppRoute.sellingPriceGroups:
        return SellingPriceGroupsScreen(settings: _settings);
      case AppRoute.importProducts:
        return ImportProductsScreen(
          settings: _settings,
          onImportSuccess: () => _navigateTo(AppRoute.productsList),
        );
      case AppRoute.inventoryAudit:
        return InventoryAuditScreen(settings: _settings);
      case AppRoute.salesReturn:
        return SalesReturnScreen(settings: _settings);
      case AppRoute.purchaseReturn:
        return PurchaseReturnScreen(settings: _settings);
      case AppRoute.annualClosing:
        return AnnualClosingScreen(settings: _settings);
      case AppRoute.businessModulesHub:
        return BusinessModulesHubScreen(
          settings: _settings,
          onNavigateToRoute: _navigateTo,
        );
      case AppRoute.restaurantCafe:
        return RestaurantCafeScreen(settings: _settings);
      case AppRoute.repairService:
        return RepairServiceScreen(settings: _settings);
      case AppRoute.hotelManagement:
        return HotelManagementScreen(settings: _settings);
      case AppRoute.gymFitness:
        return GymFitnessScreen(settings: _settings);
      case AppRoute.manufacturing:
        return ManufacturingScreen(settings: _settings);
      case AppRoute.wooCommerceSync:
        return WooCommerceSyncScreen(settings: _settings);
      case AppRoute.hrmEmployee:
        return HrmEmployeeScreen(settings: _settings);
      case AppRoute.accountingCrm:
        return AccountingCrmScreen(settings: _settings);
      case AppRoute.fruitMandi:
        return FruitMandiScreen(settings: _settings);
      case AppRoute.poultryBusiness:
        return PoultryBusinessScreen(settings: _settings);
      case AppRoute.moduleSettings:
        return ModuleSettingsScreen(
          settings: _settings,
          onSettingsUpdated: _reloadSettings,
        );
      case AppRoute.cloudSync:
        return CloudSyncScreen(
          settings: _settings,
          onSettingsUpdated: (updated) => setState(() {
            _settings = updated;
              ref.read(settingsProvider.notifier).setSettings(updated);
            if (updated.branchName.isNotEmpty) {
              _activeLocationName = updated.branchName;
            }
          }),
        );
      case AppRoute.addPurchase:
        return AddPurchaseScreen(
          settings: _settings,
          onPurchaseSaved: () => _navigateTo(AppRoute.purchasesList),
          onBackToList: () => _navigateTo(AppRoute.purchasesList),
        );
      case AppRoute.salesOrders:
        return SalesOrdersScreen(settings: _settings);
      case AppRoute.purchaseOrders:
        return PurchaseOrdersScreen(settings: _settings);
      case AppRoute.chequeManagement:
        return ChequeManagementScreen(settings: _settings);
      case AppRoute.commissionAgents:
        return CommissionAgentsScreen(settings: _settings);
      case AppRoute.discountRules:
        return DiscountRulesScreen(settings: _settings);
      default:
        return DashboardScreen(
          settings: _settings,
          onNavigateToPos: _onOpenPos,
          onNavigateToRoute: _navigateTo,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(navigationProvider);
    ref.watch(authProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AuthService.recordActivity(),
      onPointerSignal: (_) => AuthService.recordActivity(),
      child: Focus(
        onKeyEvent: (_, __) {
          AuthService.recordActivity();
          return KeyEventResult.ignored;
        },
        child: Scaffold(
      body: Column(
        children: [
          // Top Smart POS Bar
          SmartAppBar(
            onOpenPos: _onOpenPos,
            onOpenRegisterDetails: _onOpenRegister,
            onToggleSidebar: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            settings: _settings,
            activeLocationName: _activeLocationName,
            onLocationChanged: (loc) {
              setState(() {
                _activeLocationName = loc;
                _settings = _settings.copyWith(branchName: loc);
              });
            },
            onOpenSettings: () => _navigateTo(AppRoute.settings),
          ),

          // Impending Qulop License Expiry Warning Banner
          ValueListenableBuilder<QulopStatus?>(
            valueListenable: QulopService.qulopNotifier,
            builder: (context, qulopStatus, _) {
              if (qulopStatus != null &&
                  qulopStatus.isNearExpiry &&
                  qulopStatus.isValid) {
                return Container(
                  width: double.infinity,
                  color: const Color(0xFFFEF3C7),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Qulop License Warning: Your Smart POS ${qulopStatus.tierLabel} will expire in ${qulopStatus.remainingDays} days. Please contact vendor (+92 300 1234567) to renew.',
                          style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _navigateTo(AppRoute.importProducts),
                        child: const Text('Renew / Activate Key',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Main Workspace: Sidebar + Dynamic Body
          Expanded(
            child: Row(
              children: [
                SmartSidebar(
                  selectedRoute: selectedRoute,
                  onSelect: (route) => _navigateTo(
                    route,
                    collapseOnCompact: route == AppRoute.posTerminal,
                  ),
                  isCollapsed: _sidebarCollapsed,
                  settings: _settings,
                ),
                Expanded(
                  child: _buildBody(selectedRoute),
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
}
