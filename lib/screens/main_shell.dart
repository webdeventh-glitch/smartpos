import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/ultimate_app_bar.dart';
import '../widgets/ultimate_sidebar.dart';
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
import 'accounts/payment_accounts_screen.dart';
import 'notifications/notification_templates_screen.dart';

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
    setState(() => _selectedIndex = 1); // Index 1 is POS Terminal
  }

  void _onOpenRegister() {
    showDialog(
      context: context,
      builder: (_) => RegisterDetailsDialog(settings: _settings),
    );
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
          // Top Ultimate POS Bar
          UltimateAppBar(
            onOpenPos: _onOpenPos,
            onOpenRegisterDetails: _onOpenRegister,
            onToggleSidebar: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            settings: _settings,
            activeLocationName: _activeLocationName,
            onLocationChanged: (loc) => setState(() => _activeLocationName = loc),
          ),

          // Main Workspace: Sidebar + Dynamic Body
          Expanded(
            child: Row(
              children: [
                UltimateSidebar(
                  selectedIndex: _selectedIndex,
                  onSelect: (idx) => setState(() => _selectedIndex = idx),
                  isCollapsed: _sidebarCollapsed,
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
