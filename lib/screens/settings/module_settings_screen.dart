import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../services/qulop_service.dart';

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
    if (widget.settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PosLocalization.trParams(
              'Business Locked: Only {business} (selected during installation) can be used.',
              {'business': widget.settings.businessTypeDisplayName},
              settings: widget.settings,
            ),
          ),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }
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

  void _applyTierPreset(SaasTierPreset tier) {
    if (widget.settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PosLocalization.trParams(
              'Locked to {business}: Another business tier cannot be applied after installation.',
              {'business': widget.settings.businessTypeDisplayName},
              settings: widget.settings,
            ),
          ),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }
    setState(() {
      _activePresets = {tier.industryPreset.toLowerCase()};
      _activeModules =
          Set<String>.from(tier.modules.map((m) => m.toLowerCase()));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          PosLocalization.trParams(
            'Applied SaaS Tier: {name} ({price})',
            {'name': tier.name, 'price': tier.pricePerMonth},
            settings: widget.settings,
          ),
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isLicensedFeature(String key) {
    final lic = QulopService.qulopNotifier.value;
    if (lic == null) return true;
    return lic.isFeatureLicensed(key);
  }

  void _toggleModule(String key, bool enabled) {
    final lower = key.toLowerCase();
    if (widget.settings.isConfigured &&
        !widget.settings.isModuleAllowedForInstalledBusiness(lower)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PosLocalization.trParams(
              'Locked: This module belongs to a different business type than {business}.',
              {'business': widget.settings.businessTypeDisplayName},
              settings: widget.settings,
            ),
          ),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }
    if (enabled && !_isLicensedFeature(lower)) {
      _showUpgradeLicenseDialog(featureName: lower);
      return;
    }
    setState(() {
      if (enabled) {
        _activeModules.add(lower);
      } else {
        _activeModules.remove(lower);
      }
    });
  }

  Future<void> _showUpgradeLicenseDialog({String? featureName}) async {
    final keyCtrl = TextEditingController();
    String? errText;
    bool isBusy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                    PosLocalization.tr('Upgrade License Tier',
                        settings: widget.settings),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featureName != null
                      ? PosLocalization.trParams(
                          'The "{feature}" module is not included in your current license package. Paste an upgraded license key (e.g. Pro or Enterprise Full Featured) to unlock it immediately without losing any data.',
                          {
                            'feature': PosLocalization.tr(featureName,
                                settings: widget.settings)
                          },
                          settings: widget.settings,
                        )
                      : PosLocalization.tr(
                          'Paste an upgraded Smart POS license key to unlock additional commercial modules immediately.',
                          settings: widget.settings,
                        ),
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: PosLocalization.tr('Upgraded License Key',
                        settings: widget.settings),
                    hintText: 'QULOP-YRL-...',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (errText != null) ...[
                  const SizedBox(height: 10),
                  Text(errText!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(PosLocalization.tr('Cancel', settings: widget.settings)),
            ),
            ElevatedButton.icon(
              onPressed: isBusy
                  ? null
                  : () async {
                      final key = QulopService.sanitizeKeyInput(keyCtrl.text);
                      if (key.isEmpty) {
                        setDialogState(() => errText = PosLocalization.tr(
                            'Please paste a license key.',
                            settings: widget.settings));
                        return;
                      }
                      setDialogState(() {
                        isBusy = true;
                        errText = null;
                      });
                      final verified = await QulopService.verifyQulopKey(key);
                      if (!verified.isValid) {
                        setDialogState(() {
                          isBusy = false;
                          errText = verified.message;
                        });
                        return;
                      }

                      final nextMods = Set<String>.from(_activeModules);
                      if (verified.isFullFeatured) {
                        nextMods.addAll(BusinessSettings.commercialFeatureKeys);
                      } else {
                        nextMods.addAll(verified.licensedFeatures);
                      }
                      final updated = widget.settings.copyWith(
                        purchaseKey: key,
                        enabledModules: widget.settings
                            .enforceSingleBusinessModules(nextMods.join(',')),
                      );
                      QulopService.syncLicenseFeatureGate();
                      QulopService.qulopNotifier.value = verified;
                      final db = await DatabaseService.initialize();
                      await db.updateBusinessSettings(updated);
                      widget.onSettingsUpdated?.call();

                      if (mounted) {
                        setState(() {
                          _activeModules =
                              Set<String>.from(updated.activeModules);
                        });
                      }
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              PosLocalization.trParams(
                                'Upgraded to {tier}! Modules unlocked live.',
                                {'tier': verified.packageTierLabel},
                                settings: widget.settings,
                              ),
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.verified_rounded, size: 16),
              label: Text(PosLocalization.tr(
                  isBusy ? 'Verifying...' : 'Activate Upgrade',
                  settings: widget.settings)),
            ),
          ],
        ),
      ),
    );
    keyCtrl.dispose();
  }

  void _resetToDefaults() {
    final defaults = BusinessSettings.defaultModulesForBusinessType(
        widget.settings.businessType);
    setState(() {
      _activeModules = defaults.map((k) => k.toLowerCase()).toSet();
      _activePresets = {widget.settings.lockedIndustryPreset};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          PosLocalization.trParams(
            'Reset to standard defaults for: {business}',
            {'business': widget.settings.businessTypeDisplayName},
            settings: widget.settings,
          ),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _enableAll() {
    setState(() {
      final allCandidates = {
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
        ...BusinessSettings.commercialFeatureKeys,
      };
      _activeModules = allCandidates
          .where((k) =>
              (!widget.settings.isConfigured ||
                  widget.settings.isModuleAllowedForInstalledBusiness(k)) &&
              _isLicensedFeature(k))
          .toSet();
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
      SnackBar(
        content: Text(PosLocalization.tr('Switched to Minimalist Core POS mode',
            settings: widget.settings)),
        backgroundColor: const Color(0xFF0D9488),
        duration: const Duration(seconds: 2),
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
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(PosLocalization.tr(
                      'Module configuration saved! Sidebar and navigation updated.',
                      settings: widget.settings)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PosLocalization.trParams(
                'Failed to save module settings: {error}', {'error': '$e'},
                settings: widget.settings)),
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
    required IconData icon,
    required Color iconColor,
    required bool isIndustryModule,
  }) {
    final localizedTitle =
        PosLocalization.trPrimary(title, settings: widget.settings);
    final localizedSubtitle =
        PosLocalization.trPrimary(subtitle, settings: widget.settings);
    final secondarySubtitle =
        PosLocalization.trSecondary(subtitle, settings: widget.settings);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final match = title.toLowerCase().contains(query) ||
          localizedTitle.toLowerCase().contains(query) ||
          subtitle.toLowerCase().contains(query) ||
          localizedSubtitle.toLowerCase().contains(query) ||
          (secondarySubtitle != null &&
              secondarySubtitle.toLowerCase().contains(query)) ||
          key.toLowerCase().contains(query);
      if (!match) return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLockedByBusiness = widget.settings.isConfigured &&
        !widget.settings.isModuleAllowedForInstalledBusiness(key);
    if (isLockedByBusiness) return const SizedBox.shrink();
    final isLockedByLicense = !_isLicensedFeature(key);
    final isLockedOther = isLockedByBusiness || isLockedByLicense;
    final isEnabled =
        !isLockedOther && _activeModules.contains(key.toLowerCase());

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
                  : (isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9)),
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
                        PosLocalization.tr(title, settings: widget.settings),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isLockedByBusiness
                            ? PosLocalization.tr('BUSINESS LOCKED',
                                settings: widget.settings)
                            : (isLockedByLicense
                                ? PosLocalization.tr('UPGRADE LICENSE',
                                    settings: widget.settings)
                                : (isEnabled
                                    ? PosLocalization.tr('ACTIVE',
                                        settings: widget.settings)
                                    : PosLocalization.tr('DISABLED',
                                        settings: widget.settings))),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLockedOther
                              ? const Color(0xFFD97706)
                              : (isEnabled
                                  ? const Color(0xFF10B981)
                                  : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  localizedSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                if (secondarySubtitle != null &&
                    secondarySubtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondarySubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isLockedByLicense && !isLockedByBusiness)
            TextButton.icon(
              onPressed: () => _showUpgradeLicenseDialog(featureName: title),
              icon: const Icon(Icons.lock_open_rounded,
                  size: 14, color: Color(0xFFD97706)),
              label: Text(
                  PosLocalization.tr('Upgrade', settings: widget.settings),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706))),
            )
          else
            Switch(
              value: isEnabled,
              activeThumbColor: const Color(0xFF4F46E5),
              onChanged:
                  isLockedOther ? null : (val) => _toggleModule(key, val),
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
    final isSelected = _activePresets.contains(presetKey.toLowerCase()) ||
        (widget.settings.isConfigured &&
            widget.settings.lockedIndustryPreset.toLowerCase() ==
                presetKey.toLowerCase());
    final isLocked = widget.settings.isConfigured;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                      PosLocalization.tr(title, settings: widget.settings),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isSelected
                            ? PosLocalization.tr('PRESET ACTIVE',
                                settings: widget.settings)
                            : PosLocalization.tr('INACTIVE',
                                settings: widget.settings),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? color
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  PosLocalization.tr(subtitle, settings: widget.settings),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  PosLocalization.tr(features, settings: widget.settings),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isSelected,
            activeThumbColor: color,
            onChanged: isLocked ? null : (val) => _togglePreset(presetKey, val),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
                  child: const Icon(Icons.dashboard_customize_rounded,
                      color: Color(0xFF6366F1), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            PosLocalization.tr(
                                'Modular Engine & Feature Toggles',
                                settings: widget.settings),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF312E81),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              PosLocalization.tr(
                                  widget.settings.businessTypeDisplayName,
                                  settings: widget.settings),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA5B4FC)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PosLocalization.tr(
                            'Customize active modules. Inactive features are hidden from the sidebar & POS to keep your workspace clean.',
                            settings: widget.settings),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(PosLocalization.tr('Save Modules',
                      settings: widget.settings)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.settings.isConfigured) ...[
                    // SaaS Subscription Tier Presets
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          PosLocalization.tr('Commercial SaaS Tier Presets',
                              settings: widget.settings),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                              PosLocalization.tr('1-Tap Apply',
                                  settings: widget.settings),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ModuleRegistry.tierPresets.map((tier) {
                            final isApplied = tier.modules.every((m) =>
                                _activeModules.contains(m.toLowerCase()));
                            return InkWell(
                              onTap: () => _applyTierPreset(tier),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: (constraints.maxWidth > 800)
                                    ? (constraints.maxWidth - 40) / 5
                                    : (constraints.maxWidth > 500)
                                        ? (constraints.maxWidth - 20) / 2
                                        : constraints.maxWidth,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isApplied
                                      ? const Color(0xFF4F46E5)
                                          .withValues(alpha: 0.12)
                                      : (isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isApplied
                                        ? const Color(0xFF4F46E5)
                                        : (isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0)),
                                    width: isApplied ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tier.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isApplied)
                                          const Icon(Icons.check_circle_rounded,
                                              size: 14,
                                              color: Color(0xFF10B981)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tier.pricePerMonth,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tier.subtitle,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded,
                          color: Color(0xFF4F46E5), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        PosLocalization.tr('Quick Presets',
                            settings: widget.settings),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        PosLocalization.trParams(
                          '{count} Modules Active',
                          {'count': '${_activeModules.length}'},
                          settings: widget.settings,
                        ),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981)),
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
                        label: Text(PosLocalization.trParams(
                          'Reset to {business} Defaults',
                          {'business': widget.settings.businessTypeDisplayName},
                          settings: widget.settings,
                        )),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                        ),
                        onPressed: _resetToDefaults,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.speed_rounded, size: 16),
                        label: Text(PosLocalization.tr('Minimalist Core Only',
                            settings: widget.settings)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                        ),
                        onPressed: _minimalCoreOnly,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.domain_add_rounded, size: 16),
                        label: Text(PosLocalization.tr('Enable All Licensed',
                            settings: widget.settings)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                        ),
                        onPressed: _enableAll,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.workspace_premium_rounded,
                            size: 16),
                        label: Text(PosLocalization.tr('Upgrade License Key',
                            settings: widget.settings)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showUpgradeLicenseDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search Box
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A)),
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: PosLocalization.tr(
                            'Search modules by name or keywords...',
                            settings: widget.settings),
                        hintStyle: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (!widget.settings.isConfigured) ...[
              // Section 0: Smart POS Industry Presets
              Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFF4F46E5), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    PosLocalization.tr('Smart POS Industry Presets',
                        settings: widget.settings),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    PosLocalization.tr('Auto-enables domain workflows',
                        settings: widget.settings),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildPresetCard(
                presetKey: BusinessSettings.presetPharmacy,
                title: 'A. Pharmacy / Medical Store & Agency Preset',
                subtitle:
                    'Drug License, Formulas, Batch & Expiry FIFO Management',
                features:
                    'Enables Drug License & DL Warrantor, Batch & Expiry Date tracking (FIFO), Medicine Formula search, Strip/Box units, and Pharmacy POS Dispensing.',
                icon: Icons.local_pharmacy_rounded,
                color: const Color(0xFF059669),
                isDark: isDark,
              ),
              _buildPresetCard(
                presetKey: BusinessSettings.presetRetailSuperStore,
                title: 'B. Super Store / Mart / General Retail Preset',
                subtitle:
                    'High-Volume Barcode Retail & Departmental Store Management',
                features:
                    'Enables fast barcode scanning, Weight-Scale barcode parsing, Multi-Unit pricing (Piece, Box, Carton), and Product Variations.',
                icon: Icons.shopping_cart_rounded,
                color: const Color(0xFF0D9488),
                isDark: isDark,
              ),
              _buildPresetCard(
                presetKey: BusinessSettings.presetMobileElectronics,
                title: 'C. Mobile & Electronics Agency Preset',
                subtitle: 'IMEI / Serialized Inventory & Warranty Management',
                features:
                    'Enables mandatory IMEI / Serial Number (1 & 2) selection on Purchase & Sale, Warranty tracking, and Trade-in / Exchange support.',
                icon: Icons.phone_android_rounded,
                color: const Color(0xFF2563EB),
                isDark: isDark,
              ),
              _buildPresetCard(
                presetKey: BusinessSettings.presetSolarHardware,
                title: 'D. Solar & Hardware Agency Preset',
                subtitle:
                    'Quotation Estimates & Solar Composite Packages / BOM',
                features:
                    'Enables Quotation / Estimate Builder, Composite / Bundle Products (Panels + Inverter + Batteries + Structure + Labor), Site address tracking, and Warranty claims.',
                icon: Icons.solar_power_rounded,
                color: const Color(0xFFD97706),
                isDark: isDark,
              ),
              _buildPresetCard(
                presetKey: BusinessSettings.presetRestaurantCafe,
                title: 'E. Restaurant / Cafe Preset',
                subtitle:
                    'Food Service, Dine-In Tables & Kitchen Tickets (KOT)',
                features:
                    'Enables Dine-In, Takeaway, Delivery modes, Table Floor Selection, Waiter assignment, and KOT (Kitchen Order Ticket) printing.',
                icon: Icons.restaurant_rounded,
                color: const Color(0xFFE11D48),
                isDark: isDark,
              ),
              const SizedBox(height: 24),
            ],

            // Section 1: Business Add-On Modules
            Row(
              children: [
                const Icon(Icons.hub_rounded,
                    color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.settings.isConfigured
                      ? PosLocalization.trParams(
                          '{business} & Add-On Modules',
                          {
                            'business': PosLocalization.tr(
                                widget.settings.businessTypeDisplayName,
                                settings: widget.settings)
                          },
                          settings: widget.settings,
                        )
                      : PosLocalization.tr('Specialized Industry Modules',
                          settings: widget.settings),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.settings.isConfigured
                      ? PosLocalization.tr(
                          'Modules for your installed business',
                          settings: widget.settings)
                      : PosLocalization.tr('Turn off if not in this industry',
                          settings: widget.settings),
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              key: BusinessSettings.moduleRestaurant,
              title: 'Restaurant & Cafe',
              subtitle:
                  'Table floor plan, guest seating status, and live Kitchen Order Ticket (KOT) queue.',
              icon: Icons.restaurant_rounded,
              iconColor: const Color(0xFFF59E0B),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleRepair,
              title: 'Repair Shop & Service Center',
              subtitle:
                  'Device Job Sheets with IMEI/Serial, defect diagnostics, technician assignment & estimate billing.',
              icon: Icons.build_circle_rounded,
              iconColor: const Color(0xFF3B82F6),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleHotel,
              title: 'Hotel Management',
              subtitle:
                  'Rooms & suites grid, guest check-in/out with CNIC, room service bills and stay billing.',
              icon: Icons.hotel_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleGym,
              title: 'Gym & Fitness Center',
              subtitle:
                  'Member registry, subscription packages (Monthly/Annual), daily attendance & expiry renewal.',
              icon: Icons.fitness_center_rounded,
              iconColor: const Color(0xFFEC4899),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleManufacturing,
              title: 'Manufacturing & BOM',
              subtitle:
                  'Bill of Materials (BOM) recipes, raw material consumption, work orders and batch costing.',
              icon: Icons.precision_manufacturing_rounded,
              iconColor: const Color(0xFF10B981),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleWooCommerce,
              title: 'Online Store / WooCommerce',
              subtitle:
                  'WooCommerce REST API sync, automatic product catalog push and online order fetch.',
              icon: Icons.shopping_bag_rounded,
              iconColor: const Color(0xFF6366F1),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleHrm,
              title: 'HR & Employee Management',
              subtitle:
                  'Staff directory, daily punch attendance register, salary calculations and pay-slips.',
              icon: Icons.badge_rounded,
              iconColor: const Color(0xFF0EA5E9),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleAccountingCrm,
              title: 'Accounting & General Ledger',
              subtitle:
                  'Double-entry Chart of Accounts, Journal Vouchers (Debit/Credit), trial balance and ledgers.',
              icon: Icons.account_balance_rounded,
              iconColor: const Color(0xFF14B8A6),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleFruitMandi,
              title: 'Fruit & Vegetable Mandi',
              subtitle:
                  'Mandi Arhat auction register, Mun/Kg weight conversion, commission % & net Zamindar payables.',
              icon: Icons.agriculture_rounded,
              iconColor: const Color(0xFFEF4444),
              isIndustryModule: true,
            ),
            _buildModuleCard(
              key: BusinessSettings.modulePoultry,
              title: 'Poultry Farm & Trading',
              subtitle:
                  'Flock batches, daily mortality & feed consumption, live bird crate dispatches and egg trays.',
              icon: Icons.egg_rounded,
              iconColor: const Color(0xFFF97316),
              isIndustryModule: true,
            ),

            const SizedBox(height: 24),

            // Section 2: Standard Operations & Feature Toggles
            Row(
              children: [
                const Icon(Icons.settings_suggest_rounded,
                    color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 8),
                Text(
                  PosLocalization.tr('Operational & Inventory Features',
                      settings: widget.settings),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  PosLocalization.tr('Toggle core modules on/off',
                      settings: widget.settings),
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              key: BusinessSettings.moduleVariations,
              title: 'Variations & Sizes',
              subtitle:
                  'Product color/size matrices and multi-variant pricing for Garments, Shoes, and Boutiques.',
              icon: Icons.style_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleBatchExpiry,
              title: 'Batch Numbers & Expiry Tracking',
              subtitle:
                  'Batch number tracking, expiry date alerts, and pack size bonus calculations.',
              icon: Icons.medical_services_rounded,
              iconColor: const Color(0xFFEC4899),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleStockTransfers,
              title: 'Stock Transfers',
              subtitle:
                  'Transfer inventory between main warehouse and retail branch stores.',
              icon: Icons.sync_alt_rounded,
              iconColor: const Color(0xFF0EA5E9),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleStockAudit,
              title: 'Stock & Expiry Audit',
              subtitle:
                  'Physical stock counting, shelf auditing, and inventory variance adjustments.',
              icon: Icons.fact_check_rounded,
              iconColor: const Color(0xFFF59E0B),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleReturns,
              title: 'Returns Management',
              subtitle:
                  'Credit Notes for customer returns and Debit Notes for supplier returns.',
              icon: Icons.assignment_return_rounded,
              iconColor: const Color(0xFF6366F1),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleExpenses,
              title: 'Expenses Tracker',
              subtitle:
                  'Track daily shop expenses, utility bills, maintenance costs, and petty cash.',
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF10B981),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleFiscalClosing,
              title: 'Annual Fiscal Closing',
              subtitle:
                  'End of financial year audit, net profit distribution, and opening balance rollover.',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF14B8A6),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleMessaging,
              title: 'SMS & WhatsApp Notifications',
              subtitle:
                  'Send automatic WhatsApp invoices, SMS payment reminders & templates.',
              icon: Icons.mark_email_read_rounded,
              iconColor: const Color(0xFF059669),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleWholesaleTools,
              title: 'Orders, Price Groups & Discounts',
              subtitle:
                  'Sales orders, purchase orders, selling price tiers, discount rules & commission agents.',
              icon: Icons.layers_rounded,
              iconColor: const Color(0xFF6366F1),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.modulePrintLabels,
              title: 'Barcode Labels & Bulk Import',
              subtitle:
                  'Print barcode sticker labels and import bulk catalogs via CSV/Excel.',
              icon: Icons.qr_code_2_rounded,
              iconColor: const Color(0xFF0284C7),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleReporting,
              title: 'Financial & Profit Reports',
              subtitle:
                  'Detailed Profit & Loss, Tax reports, Cash Register Z-Reports & Contact Dues.',
              icon: Icons.analytics_rounded,
              iconColor: const Color(0xFFEC4899),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleFiscalTax,
              title: 'FBR / ZATCA Tax Compliance',
              subtitle:
                  'Pakistan FBR POS invoicing QR & Saudi ZATCA TLV compliant tax invoices.',
              icon: Icons.verified_user_rounded,
              iconColor: const Color(0xFF0D9488),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleMultiCurrency,
              title: 'Multi-Currency & Exchange Rates',
              subtitle:
                  'Support multiple currencies with configurable FX rates on invoices.',
              icon: Icons.currency_exchange_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleLanMultiPc,
              title: 'LAN Multi-Counter Network',
              subtitle:
                  'Connect secondary counters and mobile billing terminals over local Wi-Fi/LAN.',
              icon: Icons.lan_rounded,
              iconColor: const Color(0xFF3B82F6),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleCloudSync,
              title: 'Cloud Hybrid Sync & Android App',
              subtitle:
                  'Bidirectional sync with webpixels.net cloud backend and Owner Mobile App.',
              icon: Icons.cloud_sync_rounded,
              iconColor: const Color(0xFF0EA5E9),
              isIndustryModule: false,
            ),
            _buildModuleCard(
              key: BusinessSettings.moduleCloudBackup,
              title: 'Automated Encrypted Cloud Backup',
              subtitle:
                  'Scheduled AES-encrypted offsite backups for disaster recovery.',
              icon: Icons.backup_rounded,
              iconColor: const Color(0xFF10B981),
              isIndustryModule: false,
            ),

            const SizedBox(height: 30),

            // Bottom Save Button
            Center(
              child: SizedBox(
                width: 320,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                      PosLocalization.tr('Save Module Settings',
                          settings: widget.settings),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
