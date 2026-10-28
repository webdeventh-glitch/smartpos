import 'package:flutter/material.dart';
import '../models/models.dart';
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
import 'products/import_products_screen.dart';
import 'sales/sales_list_screen.dart';
import 'purchases/purchases_list_screen.dart';
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

class MainShell extends StatefulWidget {
  final BusinessSettings initialSettings;

  const MainShell({super.key, required this.initialSettings});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  late BusinessSettings _settings;
  String _activeLocationName = 'Main Branch HQ';

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _activeLocationName = _settings.branchName;
  }

  Product? _productToEdit;
  Product? _productToPrintLabel;

  void _onOpenPos() {
    if (_settings.isRestaurant) {
      setState(() => _selectedIndex = 29); // Restaurant Tables & KOT
    } else if (_settings.isRepair) {
      setState(() => _selectedIndex = 30); // Repair Job Sheets
    } else if (_settings.isHotel) {
      setState(() => _selectedIndex = 31); // Hotel Room Grid
    } else if (_settings.isGym) {
      setState(() => _selectedIndex = 32); // Gym Subscriptions
    } else {
      setState(() => _selectedIndex = 1); // Standard / Fast POS Terminal
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

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          settings: _settings,
          onNavigateToPos: _onOpenPos,
          onNavigateToTab: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return PosTerminalScreen(settings: _settings);
      case 2:
        return ProductsListScreen(
          settings: _settings,
          onNavigateToAddProduct: () => setState(() {
            _productToEdit = null;
            _selectedIndex = 11;
          }),
          onNavigateToEditProduct: (p) => setState(() {
            _productToEdit = p;
            _selectedIndex = 11;
          }),
          onNavigateToPrintLabels: (p) => setState(() {
            _productToPrintLabel = p;
            _selectedIndex = 17;
          }),
        );
      case 3:
        return CategoriesScreen(settings: _settings);
      case 4:
        return SalesListScreen(settings: _settings, onOpenPos: _onOpenPos);
      case 5:
        return PurchasesListScreen(settings: _settings);
      case 6:
        return CustomersScreen(settings: _settings);
      case 7:
        return SuppliersScreen(settings: _settings);
      case 8:
        return ExpensesScreen(settings: _settings);
      case 9:
        return ReportsScreen(settings: _settings);
      case 10:
        return SettingsScreen(
          settings: _settings,
          onSettingsUpdated: (updated) => setState(() => _settings = updated),
        );
      case 11:
        return AddProductScreen(
          settings: _settings,
          productToEdit: _productToEdit,
          onProductCreated: () => setState(() {
            _productToEdit = null;
            _selectedIndex = 2;
          }),
          onCancel: () => setState(() {
            _productToEdit = null;
            _selectedIndex = 2;
          }),
        );
      case 12:
        return UserManagementScreen(settings: _settings);
      case 13:
        return StockTransfersScreen(settings: _settings, initialTab: 0);
      case 14:
        return StockTransfersScreen(settings: _settings, initialTab: 1);
      case 15:
        return PaymentAccountsScreen(settings: _settings);
      case 16:
        return NotificationTemplatesScreen(settings: _settings);
      case 17:
        return PrintLabelsScreen(
          settings: _settings,
          initialProduct: _productToPrintLabel,
        );
      case 18:
        return VariationTemplatesScreen(settings: _settings);
      case 19:
        return UnitsScreen(settings: _settings);
      case 20:
        return BrandsScreen(settings: _settings);
      case 21:
        return WarrantiesScreen(settings: _settings);
      case 22:
        return SellingPriceGroupsScreen(settings: _settings);
      case 23:
        return ImportProductsScreen(
          settings: _settings,
          onImportSuccess: () => setState(() => _selectedIndex = 2),
        );
      case 24:
        return InventoryAuditScreen(settings: _settings);
      case 25:
        return SalesReturnScreen(settings: _settings);
      case 26:
        return PurchaseReturnScreen(settings: _settings);
      case 27:
        return AnnualClosingScreen(settings: _settings);
      case 28:
        return BusinessModulesHubScreen(
          settings: _settings,
          onNavigateToTab: (index) => setState(() => _selectedIndex = index),
        );
      case 29:
        return RestaurantCafeScreen(settings: _settings);
      case 30:
        return RepairServiceScreen(settings: _settings);
      case 31:
        return HotelManagementScreen(settings: _settings);
      case 32:
        return GymFitnessScreen(settings: _settings);
      case 33:
        return ManufacturingScreen(settings: _settings);
      case 34:
        return WooCommerceSyncScreen(settings: _settings);
      case 35:
        return HrmEmployeeScreen(settings: _settings);
      case 36:
        return AccountingCrmScreen(settings: _settings);
      case 37:
        return FruitMandiScreen(settings: _settings);
      case 38:
        return PoultryBusinessScreen(settings: _settings);
      case 39:
        return ModuleSettingsScreen(
          settings: _settings,
          onSettingsUpdated: _reloadSettings,
        );
      case 40:
        return CloudSyncScreen(
          settings: _settings,
          onSettingsUpdated: (updated) => setState(() => _settings = updated),
        );
      default:
        return DashboardScreen(
          settings: _settings,
          onNavigateToPos: _onOpenPos,
          onNavigateToTab: (index) => setState(() => _selectedIndex = index),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Smart POS Bar
          SmartAppBar(
            onOpenPos: _onOpenPos,
            onOpenRegisterDetails: _onOpenRegister,
            onToggleSidebar: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            settings: _settings,
            activeLocationName: _activeLocationName,
            onLocationChanged: (loc) => setState(() => _activeLocationName = loc),
          ),

          // Impending Qulop License Expiry Warning Banner
          ValueListenableBuilder<QulopStatus?>(
            valueListenable: QulopService.qulopNotifier,
            builder: (context, qulopStatus, _) {
              if (qulopStatus != null && qulopStatus.isNearExpiry && qulopStatus.isValid) {
                return Container(
                  width: double.infinity,
                  color: const Color(0xFFFEF3C7),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Qulop License Warning: Your Smart POS ${qulopStatus.tierLabel} will expire in ${qulopStatus.remainingDays} days. Please contact vendor (+92 300 1234567) to renew.',
                          style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => setState(() => _selectedIndex = 23),
                        child: const Text('Renew / Activate Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
                  selectedIndex: _selectedIndex,
                  onSelect: (idx) => setState(() => _selectedIndex = idx),
                  isCollapsed: _sidebarCollapsed,
                  settings: _settings,
                ),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
