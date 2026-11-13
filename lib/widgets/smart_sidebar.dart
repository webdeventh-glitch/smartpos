import 'package:flutter/material.dart';
import '../models/models.dart';
import '../navigation/app_routes.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class SmartSidebar extends StatefulWidget {
  final AppRoute selectedRoute;
  final ValueChanged<AppRoute> onSelect;
  final bool isCollapsed;
  final BusinessSettings? settings;

  const SmartSidebar({
    super.key,
    required this.selectedRoute,
    required this.onSelect,
    required this.isCollapsed,
    this.settings,
  });

  @override
  State<SmartSidebar> createState() => _SmartSidebarState();
}

class _SmartSidebarState extends State<SmartSidebar> {
  final TextEditingController _menuSearchCtrl = TextEditingController();
  String _filter = '';

  // Expandable sections matching Smart POS structure
  bool _userMgmtExpanded = false;
  bool _contactsExpanded = false;
  bool _productsExpanded = false;
  bool _purchasesExpanded = false;
  bool _sellExpanded = false;
  bool _transfersExpanded = false;
  bool _adjustmentsExpanded = false;
  bool _expensesExpanded = false;
  bool _reportsExpanded = false;
  bool _settingsExpanded = false;
  bool _industryExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncActiveSection(widget.selectedRoute);
  }

  @override
  void didUpdateWidget(SmartSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoute != widget.selectedRoute) {
      _syncActiveSection(widget.selectedRoute);
    }
  }

  void _syncActiveSection(AppRoute route) {
    if (route == AppRoute.userManagement) {
      _userMgmtExpanded = true;
    } else if (route == AppRoute.customers || route == AppRoute.suppliers) {
      _contactsExpanded = true;
    } else if (const [
      AppRoute.productsList,
      AppRoute.categories,
      AppRoute.addProduct,
      AppRoute.printLabels,
      AppRoute.variationTemplates,
      AppRoute.units,
      AppRoute.brands,
      AppRoute.warranties,
      AppRoute.sellingPriceGroups,
      AppRoute.importProducts,
      AppRoute.discountRules
    ].contains(route)) {
      _productsExpanded = true;
    } else if (const [
      AppRoute.purchasesList,
      AppRoute.purchaseReturn,
      AppRoute.addPurchase,
      AppRoute.purchaseOrders
    ].contains(route)) {
      _purchasesExpanded = true;
    } else if (const [
      AppRoute.posTerminal,
      AppRoute.salesList,
      AppRoute.salesReturn,
      AppRoute.salesOrders,
      AppRoute.commissionAgents
    ].contains(route)) {
      _sellExpanded = true;
    } else if (route == AppRoute.stockTransfers) {
      _transfersExpanded = true;
    } else if (route == AppRoute.stockAdjustments) {
      _adjustmentsExpanded = true;
    } else if (route == AppRoute.expenses) {
      _expensesExpanded = true;
    } else if (const [AppRoute.reports, AppRoute.inventoryAudit]
        .contains(route)) {
      _reportsExpanded = true;
    } else if (const [
      AppRoute.settings,
      AppRoute.paymentAccounts,
      AppRoute.chequeManagement,
      AppRoute.annualClosing,
      AppRoute.moduleSettings,
      AppRoute.cloudSync
    ].contains(route)) {
      _settingsExpanded = true;
    } else if (const [
      AppRoute.businessModulesHub,
      AppRoute.restaurantCafe,
      AppRoute.repairService,
      AppRoute.hotelManagement,
      AppRoute.gymFitness,
      AppRoute.manufacturing,
      AppRoute.wooCommerceSync,
      AppRoute.hrmEmployee,
      AppRoute.accountingCrm,
      AppRoute.fruitMandi,
      AppRoute.poultryBusiness
    ].contains(route)) {
      _industryExpanded = true;
    }
  }

  bool _isModEnabled(String key) {
    if (widget.settings == null) return true;
    return widget.settings!.isModuleEnabled(key);
  }

  @override
  void dispose() {
    _menuSearchCtrl.dispose();
    super.dispose();
  }

  Widget _sectionHeader(String title) {
    if (widget.isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
      );
    }
    if (_filter.isNotEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 12, top: 16, bottom: 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color:
                    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.6)
                  : const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayTitle(String title, String? defaultUrduSubtitle) {
    final settings = widget.settings;
    if (settings == null) return title;
    final primary = settings.activePrimaryLanguage;
    if (primary == 'en') return title;
    if (primary == 'ur' &&
        defaultUrduSubtitle != null &&
        defaultUrduSubtitle.isNotEmpty) {
      return defaultUrduSubtitle;
    }
    return PosLocalization.tr(title, settings: settings);
  }

  String? _getLocalizedSubtitle(String title, String? defaultUrduSubtitle) {
    // Secondary language is ONLY allowed when Primary Language is English
    final settings = widget.settings;
    if (settings == null || !settings.hasEffectiveSecondaryLanguage) {
      return null;
    }

    final sec = settings.secondaryLanguage.toLowerCase().trim();
    if (sec == 'ur' &&
        defaultUrduSubtitle != null &&
        defaultUrduSubtitle.isNotEmpty) {
      return defaultUrduSubtitle;
    }
    if (sec == 'en') return null;

    final translated = PosLocalization.tr(title, primaryOverride: sec);
    if (translated != title && translated.isNotEmpty) {
      return translated;
    }

    if (sec == 'fa') {
      const farsiSubtitles = {
        'Dashboard': 'داشبورد اصلی',
        'POS Terminal': 'ترمینال فروش',
        'Products': 'محصولات و موجودی',
        'Stock Transfers': 'انتقال کالا و انبار',
        'Stock Adjustments': 'تعدیل و کسری موجودی',
        'Sales': 'فروش و صورتحساب',
        'Purchases': 'خرید و ورود کالا',
        'Expenses': 'هزینه‌ها و تنخواه',
        'Contacts': 'مشتریان و تامین‌کنندگان',
        'Contacts & Khata': 'مشتریان، تامین‌کنندگان و حساب‌ها',
        'User Management': 'کاربران و اختیارات',
        'Reports': 'گزارش‌ها و تحلیل مالی',
        'SMS & WhatsApp Alerts': 'اعلان‌ها و پیامک',
        'Settings': 'تنظیمات و پیکربندی',
        'Business Settings': 'اطلاعات کسب و کار',
        'Payment Accounts': 'بانک و نقدینگی',
        'Annual Fiscal Closing': 'بستن حساب سال مالی',
        'Cloud & MySQL Sync': 'همگام‌سازی ابری',
        'Modular Features': 'ماژول‌های انتخابی',
        'Specialized Industry Modules': 'ماژول‌های تخصصی',
        'List Products': 'فهرست محصولات',
        'Add Product': 'افزودن محصول جدید',
        'Print Labels': 'چاپ بارکد',
        'Variations': 'تنوع کالا',
        'Import Products': 'ورود محصولات',
        'Price Groups': 'گروه‌های قیمت',
        'Units': 'واحدهای سنجش',
        'Categories': 'دسته‌بندی‌ها',
        'Brands': 'برندها',
        'Warranties': 'گارانتی‌ها',
        'List Transfers': 'فهرست انتقالات',
        'Add Transfer': 'ثبت انتقال جدید',
        'Stock Adjustment': 'تعدیل موجودی',
        'Adjustments List': 'فهرست تعدیلات',
        'Add Adjustment': 'ثبت تعدیل جدید',
        'All Sales': 'همه فروش‌ها',
        'List POS': 'فاکتورهای صندوق',
        'Sales Return': 'مرجوعی فروش',
        'Purchases List': 'فهرست خریدها',
        'Add Purchase': 'ثبت خرید جدید',
        'Purchase Return': 'مرجوعی خرید',
        'List Expenses': 'فهرست هزینه‌ها',
        'Add Expense': 'ثبت هزینه جدید',
        'Customers': 'مشتریان',
        'Suppliers': 'تامین‌کنندگان',
        'Customer Groups': 'گروه‌های مشتری',
        'Users': 'کاربران',
        'Roles & Permissions': 'نقش‌ها و دسترسی‌ها',
        'Profit / Loss Report': 'گزارش سود و زیان',
        'Purchase & Sale': 'خرید و فروش',
        'Tax Report': 'گزارش مالیات',
        'Contact Dues': 'بدهی اشخاص',
        'Stock & Expiry Audit': 'حسابرسی انبار و انقضا',
        'Trending Products': 'کالاهای پرفروش',
      };
      return farsiSubtitles[title];
    }

    if (sec == 'ps') {
      const pashtoSubtitles = {
        'Dashboard': 'مرکزي ډشبورډ',
        'POS Terminal': 'د خرڅلاو ترمینل',
        'Products': 'توکي او زېرمه',
        'Stock Transfers': 'د توکو لېږد',
        'Stock Adjustments': 'د زېرمې برابرول',
        'Sales': 'پلور او بیلونه',
        'Purchases': 'پېرل او توکي ترلاسه کول',
        'Expenses': 'لګښتونه او پیټي کیش',
        'Contacts': 'پېرودونکي او درمل پلورونکي',
        'Contacts & Khata': 'پېرودونکي، عرضه کوونکي او حسابونه',
        'User Management': 'کاروونکي او واکونه',
        'Reports': 'راپورونه او مالي تحلیل',
        'SMS & WhatsApp Alerts': 'خبرتیاوې او پیغامونه',
        'Settings': 'تنظیمات او سازونه',
        'Business Settings': 'د سوداګرۍ معلومات',
        'Payment Accounts': 'بانکي او نغدي حسابونه',
        'Annual Fiscal Closing': 'کلنی حساب بندول',
        'Cloud & MySQL Sync': 'کلاوډ همغږي',
        'Modular Features': 'فعالې برخې',
        'Specialized Industry Modules': 'ځانګړې برخې',
        'List Products': 'د توکو لست',
        'Add Product': 'نوی توکی اضافه کول',
        'Print Labels': 'د بارکوډ چاپ',
        'Variations': 'ویرینټونه',
        'Import Products': 'د توکو واردول',
        'Price Groups': 'د بیو ګروپونه',
        'Units': 'د اندازه کولو واحدونه',
        'Categories': 'ډلبندۍ',
        'Brands': 'برانډونه',
        'Warranties': 'وارنټۍ',
        'List Transfers': 'د لېږد لست',
        'Add Transfer': 'نوی لېږد',
        'Stock Adjustment': 'د زېرمې برابرول',
        'Adjustments List': 'د برابرولو لست',
        'Add Adjustment': 'نوی برابرول',
        'All Sales': 'ټول پلورونه',
        'List POS': 'د پی او ایس بلونه',
        'Sales Return': 'د پلور بېرته ګرځول',
        'Purchases List': 'د پېرلو لست',
        'Add Purchase': 'نوی پېرل',
        'Purchase Return': 'د پېر بېرته ګرځول',
        'List Expenses': 'د لګښتونو لست',
        'Add Expense': 'نوی لګښت',
        'Customers': 'پېرودونکي',
        'Suppliers': 'عرضه کوونکي',
        'Customer Groups': 'د پېرودونکو ګروپونه',
        'Users': 'کاروونکي',
        'Roles & Permissions': 'واکونه او رولونه',
        'Profit / Loss Report': 'د ګټې او تاوان راپور',
        'Purchase & Sale': 'پېر او پلور',
        'Tax Report': 'د مالیاتو راپور',
        'Contact Dues': 'د پېرودونکو پاتې پیسې',
        'Stock & Expiry Audit': 'د زېرمې او نېټې څارنه',
        'Trending Products': 'ډېر پلورل شوي توکي',
      };
      return pashtoSubtitles[title];
    }

    if (sec == 'ur') {
      return defaultUrduSubtitle;
    }

    if (sec == 'es') {
      const spanishSubtitles = {
        'Dashboard': 'Panel Principal',
        'POS Terminal': 'Terminal POS',
        'Products': 'Productos e Inventario',
        'Stock Transfers': 'Transferencias',
        'Stock Adjustments': 'Ajustes de Stock',
        'Sales': 'Ventas y Facturas',
        'Purchases': 'Compras y Pedidos',
        'Expenses': 'Gastos y Caja Chica',
        'Contacts': 'Clientes y Proveedores',
        'Contacts & Khata': 'Clientes y Proveedores',
        'User Management': 'Usuarios y Permisos',
        'Reports': 'Informes y Finanzas',
        'SMS & WhatsApp Alerts': 'Alertas y Mensajes',
        'Settings': 'Configuración',
        'Business Settings': 'Ajustes del Negocio',
        'Payment Accounts': 'Cuentas de Pago',
        'Annual Fiscal Closing': 'Cierre Fiscal Anual',
        'Cloud & MySQL Sync': 'Sincronización Cloud',
        'Modular Features': 'Módulos',
        'Specialized Industry Modules': 'Módulos Especiales',
        'List Products': 'Lista de Productos',
        'Add Product': 'Nuevo Producto',
        'Print Labels': 'Imprimir Códigos',
        'Variations': 'Variaciones',
        'Import Products': 'Importar Productos',
        'Price Groups': 'Grupos de Precios',
        'Units': 'Unidades',
        'Categories': 'Categorías',
        'Brands': 'Marcas',
        'Warranties': 'Garantías',
        'List Transfers': 'Lista de Transferencias',
        'Add Transfer': 'Nueva Transferencia',
        'Stock Adjustment': 'Ajuste de Stock',
        'Adjustments List': 'Lista de Ajustes',
        'Add Adjustment': 'Nuevo Ajuste',
        'All Sales': 'Todas las Ventas',
        'List POS': 'Ventas POS',
        'Sales Return': 'Devolución de Venta',
        'Purchases List': 'Lista de Compras',
        'Add Purchase': 'Nueva Compra',
        'Purchase Return': 'Devolución de Compra',
        'List Expenses': 'Lista de Gastos',
        'Add Expense': 'Nuevo Gasto',
        'Customers': 'Clientes',
        'Suppliers': 'Proveedores',
        'Customer Groups': 'Grupos de Clientes',
        'Users': 'Usuarios',
        'Roles & Permissions': 'Permisos',
        'Profit / Loss Report': 'Ganancias y Pérdidas',
        'Purchase & Sale': 'Compras y Ventas',
        'Tax Report': 'Reporte de Impuestos',
        'Contact Dues': 'Saldos Pendientes',
        'Stock & Expiry Audit': 'Auditoría de Stock',
        'Trending Products': 'Productos Populares',
      };
      return spanishSubtitles[title];
    }

    if (sec == 'nl') {
      const dutchSubtitles = {
        'Dashboard': 'Hoofddashboard',
        'POS Terminal': 'Kassasysteem POS',
        'Products': 'Producten en Voorraad',
        'Stock Transfers': 'Voorraadoverdracht',
        'Stock Adjustments': 'Voorraadcorrecties',
        'Sales': 'Verkopen en Facturen',
        'Purchases': 'Inkopen en Bestellingen',
        'Expenses': 'Uitgaven en Kasboek',
        'Contacts': 'Klanten en Leveranciers',
        'Contacts & Khata': 'Klanten en Leveranciers',
        'User Management': 'Gebruikersbeheer',
        'Reports': 'Rapporten en Financiën',
        'SMS & WhatsApp Alerts': 'Notificaties',
        'Settings': 'Instellingen',
        'Business Settings': 'Bedrijfsinstellingen',
        'Payment Accounts': 'Betaalrekeningen',
        'Annual Fiscal Closing': 'Fiscaal Jaarafsluiting',
        'Cloud & MySQL Sync': 'Cloud & MySQL Sync',
        'Modular Features': 'Modules',
        'Specialized Industry Modules': 'Branchemodules',
        'List Products': 'Productenlijst',
        'Add Product': 'Nieuw Product',
        'Print Labels': 'Labels Afdrukken',
        'Variations': 'Variaties',
        'Import Products': 'Producten Importeren',
        'Price Groups': 'Prijsgroepen',
        'Units': 'Eenheden',
        'Categories': 'Categorieën',
        'Brands': 'Merken',
        'Warranties': 'Garanties',
        'List Transfers': 'Overdrachten',
        'Add Transfer': 'Nieuwe Overdracht',
        'Stock Adjustment': 'Voorraadcorrectie',
        'Adjustments List': 'Correctielijst',
        'Add Adjustment': 'Nieuwe Correctie',
        'All Sales': 'Alle Verkopen',
        'List POS': 'Kassaoverzicht',
        'Sales Return': 'Verkoopretouren',
        'Purchases List': 'Inkooplijst',
        'Add Purchase': 'Nieuwe Inkoop',
        'Purchase Return': 'Inkoopretouren',
        'List Expenses': 'Uitgavenlijst',
        'Add Expense': 'Nieuwe Uitgave',
        'Customers': 'Klanten',
        'Suppliers': 'Leveranciers',
        'Customer Groups': 'Klantgroepen',
        'Users': 'Gebruikers',
        'Roles & Permissions': 'Rollen & Rechten',
        'Profit / Loss Report': 'Winst- en Verliesrekening',
        'Purchase & Sale': 'Inkoop & Verkoop',
        'Tax Report': 'Belastingrapport',
        'Contact Dues': 'Openstaande Saldi',
        'Stock & Expiry Audit': 'Voorraadaudit',
        'Trending Products': 'Populaire Producten',
      };
      return dutchSubtitles[title];
    }

    if (sec == 'en') {
      return null;
    }

    return null;
  }

  Widget _navItem({
    required IconData icon,
    required String title,
    String? urduSubtitle,
    required AppRoute route,
    bool hasSubmenu = false,
    bool isExpanded = false,
    bool isActiveParent = false,
    String? badgeText,
    Color? badgeColor,
    VoidCallback? onToggleSubmenu,
    VoidCallback? onTapDirect,
  }) {
    final displayTitle = _getDisplayTitle(title, urduSubtitle);
    final activeSubtitle = _getLocalizedSubtitle(title, urduSubtitle);
    final matchesFilter = _filter.isEmpty ||
        title.toLowerCase().contains(_filter) ||
        displayTitle.toLowerCase().contains(_filter) ||
        (activeSubtitle != null &&
            activeSubtitle.toLowerCase().contains(_filter));

    if (!matchesFilter) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.selectedRoute == route || isActiveParent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final activeText =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final activeIcon =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final inactiveText =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final inactiveIcon =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Tooltip(
          message: activeSubtitle != null && activeSubtitle.isNotEmpty
              ? '$title ($activeSubtitle)'
              : title,
          preferBelow: false,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (hasSubmenu && onToggleSubmenu != null) {
                  onToggleSubmenu();
                }
                if (onTapDirect != null) {
                  onTapDirect();
                } else {
                  widget.onSelect(route);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFC7D2FE),
                          width: 1)
                      : null,
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon,
                          size: 21,
                          color: isSelected ? activeIcon : inactiveIcon),
                      if (badgeText != null)
                        Positioned(
                          top: -3,
                          right: -5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: badgeColor ?? const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (hasSubmenu && onToggleSubmenu != null) {
              onToggleSubmenu();
              if (onTapDirect != null) {
                onTapDirect();
              }
            } else {
              widget.onSelect(route);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: isDark
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                          : const Color(0xFFC7D2FE),
                      width: 1)
                  : null,
            ),
            child: Row(
              children: [
                // Active indicator pill on left edge
                if (isSelected)
                  Container(
                    width: 3.5,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: activeIcon,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                else
                  const SizedBox(width: 4),

                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? activeIcon : inactiveIcon,
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? activeText : inactiveText,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (activeSubtitle != null && activeSubtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            activeSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF6366F1))
                                  : (isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8)),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (badgeText != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],

                if (hasSubmenu)
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: isSelected ? activeIcon : const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subItem({
    required String title,
    String? urduSubtitle,
    required AppRoute route,
  }) {
    final displayTitle = _getDisplayTitle(title, urduSubtitle);
    final activeSubtitle = _getLocalizedSubtitle(title, urduSubtitle);
    final matchesFilter = _filter.isEmpty ||
        title.toLowerCase().contains(_filter) ||
        displayTitle.toLowerCase().contains(_filter) ||
        (activeSubtitle != null &&
            activeSubtitle.toLowerCase().contains(_filter));

    if (!matchesFilter) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.selectedRoute == route;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final activeText =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final activeDot =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final inactiveText =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final inactiveDot =
        isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return Padding(
      padding:
          const EdgeInsets.only(left: 28, right: 10, top: 1.5, bottom: 1.5),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: activeSubtitle != null && activeSubtitle.isNotEmpty
              ? '$title ($activeSubtitle)'
              : title,
          waitDuration: const Duration(milliseconds: 350),
          child: InkWell(
            onTap: () => widget.onSelect(route),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
              decoration: BoxDecoration(
                color: isSelected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Connecting Guide Dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? activeDot : inactiveDot,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? activeText : inactiveText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final user = AuthService.currentUser;
    bool can(String perm) => user?.hasPermission(perm) ?? true;
    final canPos = can('pos.access');
    final canProducts = can('product.view');
    final canAddProduct = can('product.create');
    final canPrintLabels = can('product.print_labels');
    final canSales = can('sale.view');
    final canReturns = can('sale.return');
    final canPurchases = can('purchase.view') || can('purchase.create');
    final canAddPurchase = can('purchase.create');
    final canExpenses = can('expense.view') || can('expense.add');
    final canInventory = can('inventory.transfer') ||
        can('inventory.adjust') ||
        can('inventory.audit') ||
        can('inventory.manage');
    final canReports = can('report.view');
    final canKhata = can('customer.view') ||
        can('customer.manage') ||
        can('supplier.manage') ||
        can('contact.khata_payment');
    final canManageUsers = can('user.manage') || can('role.manage');
    final canSettings = can('settings.manage');

    // Check if parent sections are active
    final isProductsActive = const [
      AppRoute.productsList,
      AppRoute.categories,
      AppRoute.addProduct,
      AppRoute.printLabels,
      AppRoute.variationTemplates,
      AppRoute.units,
      AppRoute.brands,
      AppRoute.warranties,
      AppRoute.sellingPriceGroups,
      AppRoute.importProducts,
      AppRoute.discountRules
    ].contains(widget.selectedRoute);
    final isPurchasesActive = const [
      AppRoute.purchasesList,
      AppRoute.purchaseReturn,
      AppRoute.addPurchase,
      AppRoute.purchaseOrders
    ].contains(widget.selectedRoute);
    final isSellActive = const [
      AppRoute.posTerminal,
      AppRoute.salesList,
      AppRoute.salesReturn,
      AppRoute.salesOrders,
      AppRoute.commissionAgents
    ].contains(widget.selectedRoute);
    final isContactsActive = const [AppRoute.customers, AppRoute.suppliers]
        .contains(widget.selectedRoute);
    final isTransfersActive = widget.selectedRoute == AppRoute.stockTransfers;
    final isAdjustmentsActive =
        widget.selectedRoute == AppRoute.stockAdjustments;
    final isExpensesActive = widget.selectedRoute == AppRoute.expenses;
    final isReportsActive = const [AppRoute.reports, AppRoute.inventoryAudit]
        .contains(widget.selectedRoute);
    final isSettingsActive = const [
      AppRoute.settings,
      AppRoute.paymentAccounts,
      AppRoute.chequeManagement,
      AppRoute.annualClosing,
      AppRoute.moduleSettings,
      AppRoute.cloudSync
    ].contains(widget.selectedRoute);
    final isIndustryActive = const [
      AppRoute.businessModulesHub,
      AppRoute.restaurantCafe,
      AppRoute.repairService,
      AppRoute.hotelManagement,
      AppRoute.gymFitness,
      AppRoute.manufacturing,
      AppRoute.wooCommerceSync,
      AppRoute.hrmEmployee,
      AppRoute.accountingCrm,
      AppRoute.fruitMandi,
      AppRoute.poultryBusiness
    ].contains(widget.selectedRoute);

    return [
      // ==========================================
      // SECTION 1: OVERVIEW & COUNTER
      // ==========================================
      _sectionHeader('Dashboard & Counter'),

      // 1. Home (Dashboard)
      _navItem(
        icon: Icons.dashboard_outlined,
        title: 'Home',
        urduSubtitle: 'مرکزی ڈیش بورڈ',
        route: AppRoute.dashboard,
      ),

      // POS Terminal Quick Link
      if (canPos)
        _navItem(
          icon: Icons.point_of_sale_rounded,
          title: 'POS Terminal (F1)',
          urduSubtitle: 'فوری کاؤنٹر سیل',
          badgeText: 'F1',
          badgeColor: const Color(0xFF10B981),
          route: AppRoute.posTerminal,
        ),

      // ==========================================
      // SECTION 2: INVENTORY & CATALOG
      // ==========================================
      if (canProducts || canInventory) ...[
        _sectionHeader('Inventory & Products'),

        // 4. Products
        if (canProducts) ...[
          _navItem(
            icon: Icons.inventory_2_outlined,
            title: 'Products',
            urduSubtitle: 'پروڈکٹس اور سٹاک',
            route: AppRoute.productsList,
            hasSubmenu: true,
            isExpanded: _productsExpanded,
            isActiveParent: isProductsActive,
            onToggleSubmenu: () =>
                setState(() => _productsExpanded = !_productsExpanded),
            onTapDirect: () => widget.onSelect(AppRoute.productsList),
          ),
          if (!widget.isCollapsed && _productsExpanded) ...[
            _subItem(
                title: 'List Products',
                urduSubtitle: 'پروڈکٹس لسٹ',
                route: AppRoute.productsList),
            if (canAddProduct)
              _subItem(
                  title: 'Add Product',
                  urduSubtitle: 'نیا پروڈکٹ',
                  route: AppRoute.addProduct),
            if (canPrintLabels)
              _subItem(
                  title: 'Print Labels',
                  urduSubtitle: 'بارکوڈ لیبلز',
                  route: AppRoute.printLabels),
            if (_isModEnabled(BusinessSettings.moduleVariations))
              _subItem(
                  title: 'Variations',
                  urduSubtitle: 'ویرینٹس',
                  route: AppRoute.variationTemplates),
            if (canAddProduct)
              _subItem(
                  title: 'Import Products',
                  urduSubtitle: 'امپورٹ',
                  route: AppRoute.importProducts),
            if (canSettings)
              _subItem(
                  title: 'Price Groups',
                  urduSubtitle: 'قیمت گروپس',
                  route: AppRoute.sellingPriceGroups),
            if (canSettings || canAddProduct)
              _subItem(
                  title: 'Discount Rules',
                  urduSubtitle: 'رعایت کے اصول',
                  route: AppRoute.discountRules),
            _subItem(
                title: 'Units',
                urduSubtitle: 'پیمائش کے یونٹس',
                route: AppRoute.units),
            _subItem(
                title: 'Categories',
                urduSubtitle: 'کیٹیگریز',
                route: AppRoute.categories),
            _subItem(
                title: 'Brands',
                urduSubtitle: 'برانڈز',
                route: AppRoute.brands),
            _subItem(
                title: 'Warranties',
                urduSubtitle: 'وارنٹیز',
                route: AppRoute.warranties),
          ],
        ],
      ],

      // Stock Transfers
      if (canInventory &&
          _isModEnabled(BusinessSettings.moduleStockTransfers)) ...[
        _navItem(
          icon: Icons.local_shipping_outlined,
          title: 'Stock Transfers',
          urduSubtitle: 'برانچ ٹرانسفر',
          route: AppRoute.stockTransfers,
          hasSubmenu: true,
          isExpanded: _transfersExpanded,
          isActiveParent: isTransfersActive,
          onToggleSubmenu: () =>
              setState(() => _transfersExpanded = !_transfersExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.stockTransfers),
        ),
        if (!widget.isCollapsed && _transfersExpanded) ...[
          _subItem(
              title: 'List Transfers',
              urduSubtitle: 'تمام ٹرانسفرز',
              route: AppRoute.stockTransfers),
          _subItem(
              title: 'Add Transfer',
              urduSubtitle: 'نیا ٹرانسفر بھیجیں',
              route: AppRoute.stockTransfers),
        ],
      ],

      // Stock Adjustment
      if (canInventory) ...[
        _navItem(
          icon: Icons.tune_outlined,
          title: 'Stock Adjustment',
          urduSubtitle: 'سٹاک درستگی / ضیاع',
          route: AppRoute.stockAdjustments,
          hasSubmenu: true,
          isExpanded: _adjustmentsExpanded,
          isActiveParent: isAdjustmentsActive,
          onToggleSubmenu: () =>
              setState(() => _adjustmentsExpanded = !_adjustmentsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.stockAdjustments),
        ),
        if (!widget.isCollapsed && _adjustmentsExpanded) ...[
          _subItem(
              title: 'Adjustments List',
              urduSubtitle: 'لسٹ',
              route: AppRoute.stockAdjustments),
          _subItem(
              title: 'Add Adjustment',
              urduSubtitle: 'نیا اندراج',
              route: AppRoute.stockAdjustments),
        ],
      ],

      // ==========================================
      // SECTION 3: SALES & PURCHASES
      // ==========================================
      if (canSales || canPos || canPurchases || canExpenses)
        _sectionHeader('Sales & Purchases'),

      // Sell
      if (canSales || canPos) ...[
        _navItem(
          icon: Icons.receipt_long_outlined,
          title: 'Sell',
          urduSubtitle: 'فروخت اور بلنگ',
          route: AppRoute.salesList,
          hasSubmenu: true,
          isExpanded: _sellExpanded,
          isActiveParent: isSellActive,
          onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.salesList),
        ),
        if (!widget.isCollapsed && _sellExpanded) ...[
          if (canSales)
            _subItem(
                title: 'All Sales',
                urduSubtitle: 'تمام بلز',
                route: AppRoute.salesList),
          if (canSales)
            _subItem(
                title: 'Sales Orders',
                urduSubtitle: 'سیلز آرڈرز',
                route: AppRoute.salesOrders),
          if (canSales)
            _subItem(
                title: 'Commission Agents',
                urduSubtitle: 'کمیشن ایجنٹس',
                route: AppRoute.commissionAgents),
          if (canPos)
            _subItem(
                title: 'POS Terminal',
                urduSubtitle: 'کاؤنٹر سیل',
                route: AppRoute.posTerminal),
          if (canSales)
            _subItem(
                title: 'List POS',
                urduSubtitle: 'پی او ایس انوائسز',
                route: AppRoute.salesList),
          if (canReturns && _isModEnabled(BusinessSettings.moduleReturns))
            _subItem(
                title: 'Sales Return',
                urduSubtitle: 'سیلز واپسی',
                route: AppRoute.salesReturn),
        ],
      ],

      // Purchases
      if (canPurchases) ...[
        _navItem(
          icon: Icons.shopping_cart_outlined,
          title: 'Purchases',
          urduSubtitle: 'خریداری / مال انورڈ',
          route: AppRoute.purchasesList,
          hasSubmenu: true,
          isExpanded: _purchasesExpanded,
          isActiveParent: isPurchasesActive,
          onToggleSubmenu: () =>
              setState(() => _purchasesExpanded = !_purchasesExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.purchasesList),
        ),
        if (!widget.isCollapsed && _purchasesExpanded) ...[
          _subItem(
              title: 'Purchases List',
              urduSubtitle: 'خریداری لسٹ',
              route: AppRoute.purchasesList),
          _subItem(
              title: 'Purchase Orders',
              urduSubtitle: 'پرچیز آرڈرز',
              route: AppRoute.purchaseOrders),
          if (canAddPurchase)
            _subItem(
                title: 'Add Purchase',
                urduSubtitle: 'نئی خریداری درج کریں',
                route: AppRoute.addPurchase),
          if (canAddPurchase && _isModEnabled(BusinessSettings.moduleReturns))
            _subItem(
                title: 'Purchase Return',
                urduSubtitle: 'خریداری واپسی',
                route: AppRoute.purchaseReturn),
        ],
      ],

      // Expenses
      if (canExpenses && _isModEnabled(BusinessSettings.moduleExpenses)) ...[
        _navItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Expenses',
          urduSubtitle: 'دکان و پیٹی کیش اخراجات',
          route: AppRoute.expenses,
          hasSubmenu: true,
          isExpanded: _expensesExpanded,
          isActiveParent: isExpensesActive,
          onToggleSubmenu: () =>
              setState(() => _expensesExpanded = !_expensesExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.expenses),
        ),
        if (!widget.isCollapsed && _expensesExpanded) ...[
          _subItem(
              title: 'List Expenses',
              urduSubtitle: 'تمام اخراجات',
              route: AppRoute.expenses),
          _subItem(
              title: 'Add Expense',
              urduSubtitle: 'نیا خرچہ شامل کریں',
              route: AppRoute.expenses),
        ],
      ],

      // ==========================================
      // SECTION 4: CONTACTS & ACCOUNTS
      // ==========================================
      _sectionHeader('Contacts & Khata'),

      // Contacts
      if (canKhata)
        _navItem(
          icon: Icons.people_alt_outlined,
          title: 'Contacts & Khata',
          urduSubtitle: 'گاہک، سپلائر اور کھاتہ',
          route: AppRoute.customers,
          hasSubmenu: true,
          isExpanded: _contactsExpanded,
          isActiveParent: isContactsActive,
          onToggleSubmenu: () =>
              setState(() => _contactsExpanded = !_contactsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.customers),
        ),
      if (!widget.isCollapsed && _contactsExpanded && canKhata) ...[
        _subItem(
            title: 'Customers',
            urduSubtitle: 'گاہک / کسٹمرز',
            route: AppRoute.customers),
        _subItem(
            title: 'Suppliers',
            urduSubtitle: 'سپلائرز / وینڈرز',
            route: AppRoute.suppliers),
        _subItem(
            title: 'Customer Groups',
            urduSubtitle: 'کسٹمر گروپس',
            route: AppRoute.customers),
      ],

      if (canSettings) ...[
        _navItem(
          icon: Icons.account_balance_outlined,
          title: 'Cheques & Clearing',
          urduSubtitle: 'چیک مینجمنٹ',
          route: AppRoute.chequeManagement,
        ),
      ],

      // User Management
      if (canManageUsers)
        _navItem(
          icon: Icons.manage_accounts_outlined,
          title: 'User Management',
          urduSubtitle: 'صارفین اور اختیارات',
          route: AppRoute.userManagement,
          hasSubmenu: true,
          isExpanded: _userMgmtExpanded,
          isActiveParent: widget.selectedRoute == AppRoute.userManagement,
          onToggleSubmenu: () =>
              setState(() => _userMgmtExpanded = !_userMgmtExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.userManagement),
        ),
      if (!widget.isCollapsed && _userMgmtExpanded && canManageUsers) ...[
        _subItem(
            title: 'Users',
            urduSubtitle: 'صارفین کی فہرست',
            route: AppRoute.userManagement),
        _subItem(
            title: 'Roles & Permissions',
            urduSubtitle: 'اختیارات',
            route: AppRoute.userManagement),
      ],

      // ==========================================
      // SECTION 5: INTELLIGENCE & AUDIT
      // ==========================================
      _sectionHeader('Reports & Audit'),

      // Reports
      if (canReports) ...[
        _navItem(
          icon: Icons.analytics_outlined,
          title: 'Reports',
          urduSubtitle: 'نفع نقصان اور مالیاتی رپورٹس',
          route: AppRoute.reports,
          hasSubmenu: true,
          isExpanded: _reportsExpanded,
          isActiveParent: isReportsActive,
          onToggleSubmenu: () =>
              setState(() => _reportsExpanded = !_reportsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.reports),
        ),
        if (!widget.isCollapsed && _reportsExpanded) ...[
          _subItem(
              title: 'Profit / Loss Report',
              urduSubtitle: 'نفع نقصان',
              route: AppRoute.reports),
          _subItem(
              title: 'Purchase & Sale',
              urduSubtitle: 'خرید و فروخت',
              route: AppRoute.reports),
          _subItem(
              title: 'Tax Report',
              urduSubtitle: 'ٹیکس رپورٹ',
              route: AppRoute.reports),
          _subItem(
              title: 'Contact Dues',
              urduSubtitle: 'کھاتہ بقایا جات',
              route: AppRoute.reports),
          if (_isModEnabled(BusinessSettings.moduleStockAudit))
            _subItem(
                title: 'Stock & Expiry Audit',
                urduSubtitle: 'سٹاک و ایکسپائری',
                route: AppRoute.inventoryAudit),
          _subItem(
              title: 'Trending Products',
              urduSubtitle: 'زیادہ بکنے والا مال',
              route: AppRoute.reports),
        ],
      ],

      // Notification Templates
      _navItem(
        icon: Icons.mark_email_read_outlined,
        title: 'SMS & WhatsApp Alerts',
        urduSubtitle: 'اطلاعات کے ٹیمپلیٹس',
        route: AppRoute.notificationTemplates,
      ),

      // ==========================================
      // SECTION 6: SYSTEM PREFERENCES
      // ==========================================
      _sectionHeader('System Settings'),

      if (canSettings) ...[
        _navItem(
          icon: Icons.settings_suggest_outlined,
          title: 'Settings',
          urduSubtitle: 'سسٹم، برانچ و کلاؤڈ کنفیگریشن',
          route: AppRoute.settings,
          hasSubmenu: true,
          isExpanded: _settingsExpanded,
          isActiveParent: isSettingsActive,
          onToggleSubmenu: () =>
              setState(() => _settingsExpanded = !_settingsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.settings),
        ),
        if (!widget.isCollapsed && _settingsExpanded) ...[
          _subItem(
              title: 'Business Settings',
              urduSubtitle: 'کاروباری معلومات',
              route: AppRoute.settings),
          _subItem(
              title: 'Payment Accounts',
              urduSubtitle: 'بینک و کیش',
              route: AppRoute.paymentAccounts),
          if (_isModEnabled(BusinessSettings.moduleFiscalClosing))
            _subItem(
                title: 'Annual Fiscal Closing',
                urduSubtitle: 'سالانہ کلوزنگ',
                route: AppRoute.annualClosing),
          _subItem(
              title: 'Cloud & MySQL Sync',
              urduSubtitle: 'کلاؤڈ سنک',
              route: AppRoute.cloudSync),
          _subItem(
              title: 'Modular Features',
              urduSubtitle: 'ماڈیولز آن/آف',
              route: AppRoute.moduleSettings),
        ],
      ],

      // ==========================================
      // SECTION 7: SPECIALIZED INDUSTRY MODULES
      // ==========================================
      if (widget.settings?.hasAnyIndustryModuleEnabled == true) ...[
        _sectionHeader('Specialized Industry Modules'),
        _navItem(
          icon: Icons.widgets_outlined,
          title: 'Industry Modules',
          urduSubtitle: 'خصوصی ورٹیکل ماڈیولز',
          route: AppRoute.businessModulesHub,
          hasSubmenu: true,
          isExpanded: _industryExpanded,
          isActiveParent: isIndustryActive,
          onToggleSubmenu: () =>
              setState(() => _industryExpanded = !_industryExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.businessModulesHub),
        ),
        if (!widget.isCollapsed && _industryExpanded) ...[
          _subItem(
              title: 'All Modules Hub', route: AppRoute.businessModulesHub),
          if (_isModEnabled(BusinessSettings.moduleRestaurant))
            _subItem(
                title: 'Restaurant / Cafe', route: AppRoute.restaurantCafe),
          if (_isModEnabled(BusinessSettings.moduleRepair))
            _subItem(
                title: 'Repair Shop / Service', route: AppRoute.repairService),
          if (_isModEnabled(BusinessSettings.moduleHotel))
            _subItem(
                title: 'Hotel Management', route: AppRoute.hotelManagement),
          if (_isModEnabled(BusinessSettings.moduleGym))
            _subItem(title: 'Gym & Fitness Center', route: AppRoute.gymFitness),
          if (_isModEnabled(BusinessSettings.moduleManufacturing))
            _subItem(
                title: 'Manufacturing / BOM', route: AppRoute.manufacturing),
          if (_isModEnabled(BusinessSettings.moduleWooCommerce))
            _subItem(
                title: 'Online Store (Woo)', route: AppRoute.wooCommerceSync),
          if (_isModEnabled(BusinessSettings.moduleHrm))
            _subItem(
                title: 'HR & Employee (Payroll)', route: AppRoute.hrmEmployee),
          if (_isModEnabled(BusinessSettings.moduleAccountingCrm))
            _subItem(
                title: 'Accounting & Ledgers', route: AppRoute.accountingCrm),
          if (_isModEnabled(BusinessSettings.moduleFruitMandi))
            _subItem(title: 'Fruit Mandi (Arhat)', route: AppRoute.fruitMandi),
          if (_isModEnabled(BusinessSettings.modulePoultry))
            _subItem(
                title: 'Poultry Farm & Trading',
                route: AppRoute.poultryBusiness),
        ],
      ],

      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.currentUser;
    final userName = user?.name ?? 'Admin User';
    final userRole = user?.role ?? 'Superadmin';
    final branchName = widget.settings?.branchName ?? 'Main Branch HQ';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: widget.isCollapsed ? 68 : 252,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Search Box (Only when expanded)
          if (!widget.isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _menuSearchCtrl,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  onChanged: (val) =>
                      setState(() => _filter = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search menu...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14),
                            onPressed: () {
                              _menuSearchCtrl.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),

          // 2. High-Impact Fast Checkout Terminal Action Pill
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 8 : 12,
              vertical: 6,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onSelect(AppRoute.posTerminal),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: widget.isCollapsed
                      ? const Center(
                          child: Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 22),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'POS Terminal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'F1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),

          // 3. Navigation Items Scrollable Tree
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _buildMenuItems(),
            ),
          ),

          // 4. Sleek Profile & Active Branch Footer Card
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 8 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: widget.isCollapsed
                ? Tooltip(
                    message:
                        '$userName ($userRole)\n$branchName\n● Smart POS Live',
                    preferBelow: false,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF4F46E5),
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: -1,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF4F46E5),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    branchName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v1.0',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
