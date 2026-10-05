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

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

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
          onNavigateToAddProduct: () => setState(() => _selectedIndex = 11),
        );
      case 3:
        return const CategoriesBrandsScreen();
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
          onProductCreated: () => setState(() => _selectedIndex = 2),
          onCancel: () => setState(() => _selectedIndex = 2),
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
