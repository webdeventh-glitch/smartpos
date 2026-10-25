import 'package:flutter/material.dart';
import '../../models/models.dart';
import 'restaurant_cafe_screen.dart';
import 'repair_service_screen.dart';
import 'hotel_management_screen.dart';
import 'gym_fitness_screen.dart';
import 'manufacturing_screen.dart';
import 'woocommerce_sync_screen.dart';
import 'hrm_employee_screen.dart';
import 'accounting_crm_screen.dart';
import 'fruit_mandi_screen.dart';
import 'poultry_business_screen.dart';

class BusinessModulesHubScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Function(int) onNavigateToTab;

  const BusinessModulesHubScreen({
    super.key,
    required this.settings,
    required this.onNavigateToTab,
  });

  @override
  State<BusinessModulesHubScreen> createState() => _BusinessModulesHubScreenState();
}

class _BusinessModulesHubScreenState extends State<BusinessModulesHubScreen> {
  String _searchFilter = '';

  final List<Map<String, dynamic>> _modules = [
    {
      'id': 'general_store',
      'title': 'General Store / Kiryana',
      'subtitle': 'Fast billing, loose item weight (Kg/Grams), barcode scanner & customer khata',
      'icon': Icons.storefront_rounded,
      'color': const Color(0xFF10B981),
      'badge': 'Core Retail',
      'actionType': 'nav_tab',
      'tabIndex': 1, // POS Terminal
    },
    {
      'id': 'supermarket',
      'title': 'Supermarket / Departmental Store',
      'subtitle': 'Multi-counter cashiers, scale integration, aisle departments & loyalty points',
      'icon': Icons.local_grocery_store_rounded,
      'color': const Color(0xFF0EA5E9),
      'badge': 'Superstore',
      'actionType': 'nav_tab',
      'tabIndex': 1,
    },
    {
      'id': 'garments',
      'title': 'Garments / Shoes / Boutique',
      'subtitle': 'Size & Color variations matrix, sticker label barcode tags & seasonal collections',
      'icon': Icons.checkroom_rounded,
      'color': const Color(0xFFEC4899),
      'badge': 'Fashion',
      'actionType': 'nav_tab',
      'tabIndex': 18, // Variations
    },
    {
      'id': 'electronics',
      'title': 'Mobile & Electronics Shop',
      'subtitle': 'IMEI & Serial Number tracking per unit, warranty cards & specs ledger',
      'icon': Icons.phone_android_rounded,
      'color': const Color(0xFF6366F1),
      'badge': 'Tech / Serial',
      'actionType': 'nav_tab',
      'tabIndex': 21, // Warranties
    },
    {
      'id': 'wholesale',
      'title': 'Wholesale & Distribution',
      'subtitle': 'Tiered selling price groups, cartons/packs multipliers & customer credit limits',
      'icon': Icons.local_shipping_rounded,
      'color': const Color(0xFF8B5CF6),
      'badge': 'B2B Trade',
      'actionType': 'nav_tab',
      'tabIndex': 22, // Selling Price Groups
    },
    {
      'id': 'pharmacy',
      'title': 'Pharmacy / Medical Store',
      'subtitle': 'Batch & Expiry date tracking, Drug Act 1976 compliance, formula salt & strip pricing',
      'icon': Icons.medication_rounded,
      'color': const Color(0xFF059669),
      'badge': 'Medical',
      'actionType': 'nav_tab',
      'tabIndex': 24, // Audit & Expiry
    },
    {
      'id': 'restaurant',
      'title': 'Restaurant / Cafe',
      'subtitle': 'Dining table layout, Kitchen Order Tickets (KOT), Dine-in, Takeaway & Delivery',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFFF97316),
      'badge': 'Food & Dine',
      'actionType': 'screen',
      'screenBuilder': (settings) => RestaurantCafeScreen(settings: settings),
    },
    {
      'id': 'repair',
      'title': 'Repairing Shop / Service Center',
      'subtitle': 'Device job sheets, technician assignment, defect diagnostics & repair status tracker',
      'icon': Icons.build_circle_rounded,
      'color': const Color(0xFFEAB308),
      'badge': 'Job Sheets',
      'actionType': 'screen',
      'screenBuilder': (settings) => RepairServiceScreen(settings: settings),
    },
    {
      'id': 'hotel',
      'title': 'Hotel Management',
      'subtitle': 'Rooms & suites grid, Guest Check-In / Check-Out, CNIC verification & room service bills',
      'icon': Icons.hotel_rounded,
      'color': const Color(0xFF3B82F6),
      'badge': 'Hospitality',
      'actionType': 'screen',
      'screenBuilder': (settings) => HotelManagementScreen(settings: settings),
    },
    {
      'id': 'gym',
      'title': 'Gym / Fitness Center',
      'subtitle': 'Member registry, monthly/annual packages, membership expiry alerts & attendance',
      'icon': Icons.fitness_center_rounded,
      'color': const Color(0xFFEF4444),
      'badge': 'Fitness',
      'actionType': 'screen',
      'screenBuilder': (settings) => GymFitnessScreen(settings: settings),
    },
    {
      'id': 'manufacturing',
      'title': 'Manufacturing / Production',
      'subtitle': 'Bill of Materials (BOM), Recipe management, production work orders & batch costing',
      'icon': Icons.precision_manufacturing_rounded,
      'color': const Color(0xFF14B8A6),
      'badge': 'Industrial',
      'actionType': 'screen',
      'screenBuilder': (settings) => ManufacturingScreen(settings: settings),
    },
    {
      'id': 'woocommerce',
      'title': 'Online Store / WooCommerce Integration',
      'subtitle': 'Store API credentials, 1-click product catalog sync & fetch online orders to POS',
      'icon': Icons.shopping_bag_rounded,
      'color': const Color(0xFF9333EA),
      'badge': 'E-Commerce',
      'actionType': 'screen',
      'screenBuilder': (settings) => WooCommerceSyncScreen(settings: settings),
    },
    {
      'id': 'hrm',
      'title': 'HR & Employee Management',
      'subtitle': 'Staff directory, daily attendance check-in, payroll & salary slip generator',
      'icon': Icons.badge_rounded,
      'color': const Color(0xFF2563EB),
      'badge': 'Human Resource',
      'actionType': 'screen',
      'screenBuilder': (settings) => HrmEmployeeScreen(settings: settings),
    },
    {
      'id': 'accounting_crm',
      'title': 'Accounting & CRM',
      'subtitle': 'Chart of Accounts, journal vouchers, double-entry ledger & customer CRM history',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF4338CA),
      'badge': 'Finance & CRM',
      'actionType': 'screen',
      'screenBuilder': (settings) => AccountingCrmScreen(settings: settings),
    },
    {
      'id': 'fruit_wholesale',
      'title': 'Fruit Wholesale / Mandi Arhat',
      'subtitle': 'Zamindar (Grower) vs Beopari, Boli auction, Mun/Kg weight, commission & bardana deductions',
      'icon': Icons.agriculture_rounded,
      'color': const Color(0xFF84CC16),
      'badge': 'Mandi Arhat',
      'actionType': 'screen',
      'screenBuilder': (settings) => FruitMandiScreen(settings: settings),
    },
    {
      'id': 'poultry',
      'title': 'Poultry Farm & Business',
      'subtitle': 'Flock batches, daily feed bags & mortality, live bird crates weight & egg trays ledger',
      'icon': Icons.egg_rounded,
      'color': const Color(0xFFF59E0B),
      'badge': 'Livestock',
      'actionType': 'screen',
      'screenBuilder': (settings) => PoultryBusinessScreen(settings: settings),
    },
  ];

  void _openModule(Map<String, dynamic> mod) {
    if (mod['actionType'] == 'nav_tab') {
      widget.onNavigateToTab(mod['tabIndex'] as int);
    } else if (mod['actionType'] == 'screen') {
      final builder = mod['screenBuilder'] as Widget Function(BusinessSettings);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => builder(widget.settings)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _modules.where((m) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      final title = (m['title'] as String).toLowerCase();
      final sub = (m['subtitle'] as String).toLowerCase();
      final badge = (m['badge'] as String).toLowerCase();
      return title.contains(q) || sub.contains(q) || badge.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                      : [const Color(0xFF4338CA), const Color(0xFF312E81)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Multi-Industry Business Hub',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Smart POS supports 16 customized business workflows & enterprise modules',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_center_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Current: ${widget.settings.businessTypeDisplayName}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.dashboard_customize_rounded, size: 16),
                            label: const Text('Configure Modules (ماڈیول سیٹنگز)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF4F46E5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () => widget.onNavigateToTab(39),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Search Bar & Filter
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 20, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                            onChanged: (val) => setState(() => _searchFilter = val.trim()),
                            decoration: InputDecoration(
                              hintText: 'Search business models (e.g. Restaurant, Kiryana, Mandi, Gym, HR, Poultry)...',
                              hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchFilter.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchFilter = ''),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${filtered.length} of 16 Models Available',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Responsive Grid of Business Modules
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 4;
                if (constraints.maxWidth < 750) {
                  crossAxisCount = 1;
                } else if (constraints.maxWidth < 1100) {
                  crossAxisCount = 2;
                } else if (constraints.maxWidth < 1450) {
                  crossAxisCount = 3;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final mod = filtered[index];
                    final color = mod['color'] as Color;
                    final isCurrent = widget.settings.businessType.toLowerCase() == mod['id'];

                    return InkWell(
                      onTap: () => _openModule(mod),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isCurrent ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(mod['icon'] as IconData, color: color, size: 24),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    mod['badge'] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        mod['title'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        final isEnabled = widget.settings.isModuleEnabled(mod['id'] as String);
                                        return Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isEnabled
                                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isEnabled ? 'ACTIVE' : 'OFF',
                                            style: TextStyle(
                                              color: isEnabled
                                                  ? const Color(0xFF10B981)
                                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mod['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  mod['actionType'] == 'screen' ? 'Open Dedicated Module' : 'Launch POS Feature',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
