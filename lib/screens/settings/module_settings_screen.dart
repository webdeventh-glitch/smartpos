import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class ModuleSettingsScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onSettingsUpdated;

  const ModuleSettingsScreen({
    super.key,
    required this.settings,
    this.onSettingsUpdated,
  });

  @override
  State<ModuleSettingsScreen> createState() => _ModuleSettingsScreenState();
}

class _ModuleSettingsScreenState extends State<ModuleSettingsScreen> {
  late Set<String> _activeModules;
  late Set<String> _activePresets;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeModules = Set<String>.from(widget.settings.activeModules);
    _activePresets = widget.settings.industryPresets.isNotEmpty
        ? widget.settings.industryPresets
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toSet()
        : {BusinessSettings.presetRetailSuperStore};
  }

  void _togglePreset(String presetKey, bool enabled) {
    setState(() {
      final key = presetKey.toLowerCase();
      if (enabled) {
        // Enforce strictly 1 active business preset at a time
        _activePresets = {key};
        _activeModules.removeWhere((m) => [
          BusinessSettings.presetRetailSuperStore,
          BusinessSettings.presetPharmacy,
          BusinessSettings.presetMobileElectronics,
          BusinessSettings.presetSolarHardware,
          BusinessSettings.presetRestaurantCafe,
          BusinessSettings.moduleRestaurant,
          BusinessSettings.moduleRepair,
        ].contains(m));

        _activeModules.add(key);
        switch (key) {
          case BusinessSettings.presetPharmacy:
            _activeModules.addAll([
              BusinessSettings.moduleBatchExpiry,
            ]);
            break;
          case BusinessSettings.presetRetailSuperStore:
            _activeModules.addAll([
              BusinessSettings.moduleBatchExpiry,
              BusinessSettings.moduleVariations,
            ]);
            break;
          case BusinessSettings.presetMobileElectronics:
            _activeModules.addAll([
              BusinessSettings.moduleRepair,
              BusinessSettings.moduleVariations,
            ]);
            break;
          case BusinessSettings.presetSolarHardware:
            _activeModules.addAll([
              BusinessSettings.moduleRepair,
              BusinessSettings.moduleVariations,
            ]);
            break;
          case BusinessSettings.presetRestaurantCafe:
            _activeModules.addAll([
              BusinessSettings.moduleRestaurant,
              BusinessSettings.moduleHrm,
            ]);
            break;
        }
      }
    });
  }

  void _toggleModule(String key, bool enabled) {
    setState(() {
      if (enabled) {
        _activeModules.add(key.toLowerCase());
      } else {
        _activeModules.remove(key.toLowerCase());
      }
    });
  }

  void _resetToDefaults() {
    final defaults = BusinessSettings.defaultModulesForBusinessType(widget.settings.businessType);
    setState(() {
      _activeModules = defaults.map((k) => k.toLowerCase()).toSet();
      _activePresets = {BusinessSettings.presetRetailSuperStore};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reset to standard defaults for: ${widget.settings.businessTypeDisplayName}'),
        backgroundColor: const Color(0xFF4F46E5),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  void _enableAll() {
    setState(() {
      _activeModules = {
        BusinessSettings.moduleRestaurant,
        BusinessSettings.moduleRepair,
        BusinessSettings.moduleHotel,
        BusinessSettings.moduleGym,
        BusinessSettings.moduleManufacturing,
        BusinessSettings.moduleWooCommerce,
        BusinessSettings.moduleHrm,
        BusinessSettings.moduleAccountingCrm,
        BusinessSettings.moduleFruitMandi,
        BusinessSettings.modulePoultry,
        BusinessSettings.moduleVariations,
        BusinessSettings.moduleBatchExpiry,
        BusinessSettings.moduleStockTransfers,
        BusinessSettings.moduleStockAudit,
        BusinessSettings.moduleExpenses,
        BusinessSettings.moduleReturns,
        BusinessSettings.moduleFiscalClosing,
      };
    });
  }

  void _minimalCoreOnly() {
    setState(() {
      _activeModules = {
        BusinessSettings.moduleExpenses,
        BusinessSettings.moduleReturns,
      };
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Switched to Minimalist Core POS mode'),
        backgroundColor: Color(0xFF0D9488),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);
    try {
      final updatedSettings = widget.settings.copyWith(
        enabledModules: _activeModules.join(','),
        industryPresets: _activePresets.join(','),
      );
      final db = await DatabaseService.initialize();
      await db.updateBusinessSettings(updatedSettings);
      widget.onSettingsUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Module configuration saved! Sidebar and navigation updated.'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save module settings: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildModuleCard({
    required String key,
    required String title,
    required String subtitle,
    required String urduDesc,
    required IconData icon,
    required Color iconColor,
    required bool isIndustryModule,
  }) {
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final match = title.toLowerCase().contains(query) ||
          subtitle.toLowerCase().contains(query) ||
          urduDesc.toLowerCase().contains(query) ||
          key.toLowerCase().contains(query);
      if (!match) return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = _activeModules.contains(key.toLowerCase());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? (isDark ? const Color(0xFF4F46E5) : const Color(0xFF818CF8))
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isEnabled ? 1.5 : 1.0,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled
                  ? iconColor.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isEnabled ? iconColor : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isEnabled ? 'ACTIVE' : 'DISABLED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isEnabled
                              ? const Color(0xFF10B981)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  urduDesc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0EA5E9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isEnabled,
            activeThumbColor: const Color(0xFF4F46E5),
            onChanged: (val) => _toggleModule(key, val),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard({
    required String presetKey,
    required String title,
    required String subtitle,
    required String features,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _activePresets.contains(presetKey.toLowerCase());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isSelected ? 'PRESET ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  features,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isSelected,
            activeThumbColor: color,
            onChanged: (val) => _togglePreset(presetKey, val),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF6366F1), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Modular Engine & Feature Toggles',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF312E81),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.settings.businessTypeDisplayName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA5B4FC)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Customize active modules. Inactive features are hidden from the sidebar & POS to keep your workspace clean. (ماڈیولر کنفیگریشن)',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Modules (محفوظ کریں)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _saveConfiguration,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Explanatory Banner & Quick Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Quick Presets (فوری پری سیٹ)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        '${_activeModules.length} Modules Active',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: Text('Reset to ${widget.settings.businessTypeDisplayName} Defaults'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                        ),
                        onPressed: _resetToDefaults,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.speed_rounded, size: 16),
                        label: const Text('Minimalist Core Only (سادہ بلنگ)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                        ),
                        onPressed: _minimalCoreOnly,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.domain_add_rounded, size: 16),
                        label: const Text('Enable All 16 Modules (تمام فعال)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                        ),
                        onPressed: _enableAll,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search Box
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Search modules by name, keywords, or Urdu (تلاش کریں)...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 0: Smart POS Industry Presets
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Smart POS Industry Presets (بنیادی تجارتی شعبہ جات)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto-enables domain workflows',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildPresetCard(
              presetKey: BusinessSettings.presetPharmacy,
              title: 'A. Pharmacy / Medical Store & Agency Preset',
              subtitle: 'Drug License, Formulas, Batch & Expiry FIFO Management',
              features: 'Enables Drug License & DL Warrantor, Batch & Expiry Date tracking (FIFO), Medicine Formula search, Strip/Box units, and Pharmacy POS Dispensing.',
              icon: Icons.local_pharmacy_rounded,
              color: const Color(0xFF059669),
              isDark: isDark,
            ),
            _buildPresetCard(
              presetKey: BusinessSettings.presetRetailSuperStore,
              title: 'B. Super Store / Mart / General Retail Preset',
              subtitle: 'High-Volume Barcode Retail & Departmental Store Management',
              features: 'Enables fast barcode scanning, Weight-Scale barcode parsing, Multi-Unit pricing (Piece, Box, Carton), and Product Variations.',
              icon: Icons.shopping_cart_rounded,
              color: const Color(0xFF0D9488),
              isDark: isDark,
            ),
            _buildPresetCard(
              presetKey: BusinessSettings.presetMobileElectronics,
              title: 'C. Mobile & Electronics Agency Preset',
              subtitle: 'IMEI / Serialized Inventory & Warranty Management',
              features: 'Enables mandatory IMEI / Serial Number (1 & 2) selection on Purchase & Sale, Warranty tracking, and Trade-in / Exchange support.',
              icon: Icons.phone_android_rounded,
              color: const Color(0xFF2563EB),
              isDark: isDark,
            ),
            _buildPresetCard(
              presetKey: BusinessSettings.presetSolarHardware,
              title: 'D. Solar & Hardware Agency Preset',
              subtitle: 'Quotation Estimates & Solar Composite Packages / BOM',
              features: 'Enables Quotation / Estimate Builder, Composite / Bundle Products (Panels + Inverter + Batteries + Structure + Labor), Site address tracking, and Warranty claims.',
              icon: Icons.solar_power_rounded,
              color: const Color(0xFFD97706),
              isDark: isDark,
            ),
            _buildPresetCard(
              presetKey: BusinessSettings.presetRestaurantCafe,
              title: 'E. Restaurant / Cafe Preset',
              subtitle: 'Food Service, Dine-In Tables & Kitchen Tickets (KOT)',
              features: 'Enables Dine-In, Takeaway, Delivery modes, Table Floor Selection, Waiter assignment, and KOT (Kitchen Order Ticket) printing.',
              icon: Icons.restaurant_rounded,
              color: const Color(0xFFE11D48),
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Section 1: Specialized Industry Modules
            Row(
              children: [
                const Icon(Icons.hub_rounded, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Specialized Industry Modules (شعبہ جاتی ماڈیولز)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  'Turn off if not in this industry',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),


            _buildModuleCard(
              key: BusinessSettings.moduleRestaurant,
              title: '️ Restaurant & Cafe (ٹیبل و کچن آرڈر)',
              subtitle: 'Table floor plan, guest seating status, and live Kitchen Order Ticket (KOT) queue.',
              urduDesc: 'ڈائن اِن ٹیبل مینیجمنٹ اور لائیو کچن آرڈر ٹکٹ (KOT)',
              icon: Icons.restaurant_rounded,
              iconColor: const Color(0xFFF59E0B),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleRepair,
              title: 'Repair Shop & Service Center (مرمت و جاب شیٹ)',
              subtitle: 'Device Job Sheets with IMEI/Serial, defect diagnostics, technician assignment & estimate billing.',
              urduDesc: 'موبائل، لیپ ٹاپ اور الیکٹرانکس کی جاب کارڈ اور ٹیکنیشن ورک فلو',
              icon: Icons.build_circle_rounded,
              iconColor: const Color(0xFF3B82F6),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleHotel,
              title: 'Hotel Management (ہوٹل روم و گیسٹ)',
              subtitle: 'Rooms & suites grid, guest check-in/out with CNIC, room service bills and stay billing.',
              urduDesc: 'کمروں کا کرایہ، گیسٹ چیک اِن / چیک آؤٹ اور روم سروس کھاتہ',
              icon: Icons.hotel_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleGym,
              title: '️ Gym & Fitness Center (جم و فٹنس ممبرشپ)',
              subtitle: 'Member registry, subscription packages (Monthly/Annual), daily attendance & expiry renewal.',
              urduDesc: 'جم ممبرشپ، فیس ایکسپائری الرٹس اور یومیہ حاضری لاگ',
              icon: Icons.fitness_center_rounded,
              iconColor: const Color(0xFFEC4899),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleManufacturing,
              title: 'Manufacturing & BOM (پیداوار و خام مال)',
              subtitle: 'Bill of Materials (BOM) recipes, raw material consumption, work orders and batch costing.',
              urduDesc: 'خام مال کی کھپت سے تیار شدہ پروڈکٹ کا حساب اور پیداواری لاگت',
              icon: Icons.precision_manufacturing_rounded,
              iconColor: const Color(0xFF10B981),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleWooCommerce,
              title: 'Online Store / WooCommerce (آن لائن اسٹور سنک)',
              subtitle: 'WooCommerce REST API sync, automatic product catalog push and online order fetch.',
              urduDesc: 'ورڈپریس / ووکامرس ویب سائٹ سے اسٹاک سنک اور آن لائن آرڈرز',
              icon: Icons.shopping_bag_rounded,
              iconColor: const Color(0xFF6366F1),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleHrm,
              title: 'HR & Employee Management (ملازمین و پی رول)',
              subtitle: 'Staff directory, daily punch attendance register, salary calculations and pay-slips.',
              urduDesc: 'اسٹاف حاضری، ماہانہ تنخواہ سلپ اور ایڈوانس کٹوتی رجسٹر',
              icon: Icons.badge_rounded,
              iconColor: const Color(0xFF0EA5E9),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleAccountingCrm,
              title: 'Accounting & General Ledger (ڈبل انٹری کھاتہ)',
              subtitle: 'Double-entry Chart of Accounts, Journal Vouchers (Debit/Credit), trial balance and ledgers.',
              urduDesc: 'مکمل ڈبل انٹری فنانشل اکاؤنٹس اور جنرل جرنل واؤچرز',
              icon: Icons.account_balance_rounded,
              iconColor: const Color(0xFF14B8A6),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleFruitMandi,
              title: 'Fruit & Vegetable Mandi (فروٹ و سبزی آڑھت)',
              subtitle: 'Mandi Arhat auction register, Mun/Kg weight conversion, commission % & net Zamindar payables.',
              urduDesc: 'منڈی کی روزانہ بولی، من اور کلو کا وزن اور آڑھتی کمیشن کاٹ کر ادائیگی',
              icon: Icons.agriculture_rounded,
              iconColor: const Color(0xFFEF4444),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.modulePoultry,
              title: 'Poultry Farm & Trading (پولٹری فارم و برائلر)',
              subtitle: 'Flock batches, daily mortality & feed consumption, live bird crate dispatches and egg trays.',
              urduDesc: 'برائلر فلاک، یومیہ اموات، فیڈ کی کھپت، اور لائیو مرغی گاڑی کا وزن',
              icon: Icons.egg_rounded,
              iconColor: const Color(0xFFF97316),
              isIndustryModule: true,
            ),

            const SizedBox(height: 24),

            // Section 2: Standard Operations & Feature Toggles
            Row(
              children: [
                const Icon(Icons.settings_suggest_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Operational & Inventory Features (آپریشنل و انوینٹری فیچرز)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  'Toggle core modules on/off',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              key: BusinessSettings.moduleVariations,
              title: '️ Variations & Sizes (سائز و رنگ)',
              subtitle: 'Product color/size matrices and multi-variant pricing for Garments, Shoes, and Boutiques.',
              urduDesc: 'کپڑوں اور جوتوں کے سائز، رنگ اور مختلف ورائٹی کا الگ الگ اسٹاک',
              icon: Icons.style_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleBatchExpiry,
              title: 'Batch Numbers & Expiry Tracking (بیچ و ایکسپائری)',
              subtitle: 'Batch number tracking, expiry date alerts, and pack size bonus calculations.',
              urduDesc: 'دوائیوں اور اشیاء خوردونوش کے بیچ نمبر اور ایکسپائری کی تاریخ کا الرٹ',
              icon: Icons.medical_services_rounded,
              iconColor: const Color(0xFFEC4899),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleStockTransfers,
              title: 'Stock Transfers (اسٹاک ٹرانسفر)',
              subtitle: 'Transfer inventory between main warehouse and retail branch stores.',
              urduDesc: 'گودام اور مختلف برانچوں کے درمیان سامان کی منتقلی کا رجسٹر',
              icon: Icons.sync_alt_rounded,
              iconColor: const Color(0xFF0EA5E9),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleStockAudit,
              title: 'Stock & Expiry Audit (انوینٹری آڈٹ)',
              subtitle: 'Physical stock counting, shelf auditing, and inventory variance adjustments.',
              urduDesc: 'دکان اور گودام کے سامان کی گنتی اور اصل اسٹاک سے موازنہ',
              icon: Icons.fact_check_rounded,
              iconColor: const Color(0xFFF59E0B),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleReturns,
              title: '↩️ Returns Management (سیلز و پرچیز واپسی)',
              subtitle: 'Credit Notes for customer returns and Debit Notes for supplier returns.',
              urduDesc: 'گاہک کی سامان واپسی (Credit Note) اور سپلائر کو سامان واپسی (Debit Note)',
              icon: Icons.assignment_return_rounded,
              iconColor: const Color(0xFF6366F1),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleExpenses,
              title: 'Expenses Tracker (دکان کے اخراجات)',
              subtitle: 'Track daily shop expenses, utility bills, maintenance costs, and petty cash.',
              urduDesc: 'بجلی، کرایہ، چائے، تنخواہ اور روزمرہ کے تمام اخراجات کا اندراج',
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF10B981),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleFiscalClosing,
              title: 'Annual Fiscal Closing (سالانہ کلوزنگ)',
              subtitle: 'End of financial year audit, net profit distribution, and opening balance rollover.',
              urduDesc: 'مالی سال کا اختتام، نفع و نقصان کا حتمی حساب اور نئے سال کا اوپننگ بیلنس',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF14B8A6),
              isIndustryModule: false,
            ),

            const SizedBox(height: 30),

            // Bottom Save Button
            Center(
              child: SizedBox(
                width: 320,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Save Module Settings (محفوظ کریں)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _saveConfiguration,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
