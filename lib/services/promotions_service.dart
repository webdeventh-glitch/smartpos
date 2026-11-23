import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Models a Tiered Volume Pricing bracket.
class VolumePricingTier {
  final int minQty;
  final int? maxQty; // null means unbounded (e.g. 11+)
  final double discountPercent;

  const VolumePricingTier({
    required this.minQty,
    this.maxQty,
    required this.discountPercent,
  });

  Map<String, dynamic> toMap() => {
        'minQty': minQty,
        'maxQty': maxQty,
        'discountPercent': discountPercent,
      };

  factory VolumePricingTier.fromMap(Map<String, dynamic> map) =>
      VolumePricingTier(
        minQty: (map['minQty'] as num?)?.toInt() ?? 1,
        maxQty: (map['maxQty'] as num?)?.toInt(),
        discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Advanced Promotional, BOGO & Tiered Volume Pricing Engine for SmartPOS.
class PromotionsService {
  static PromotionsService? _instance;
  static PromotionsService get instance => _instance ??= PromotionsService._();

  PromotionsService._();

  // 1. Happy Hour State
  bool isHappyHourEnabled = true;
  String happyHourName = 'Evening Happy Hour';
  int happyHourStartHour = 16; // 4:00 PM
  int happyHourEndHour = 20; // 8:00 PM
  double happyHourDiscountPercent = 15.0; // 15% discount

  // 2. Buy X Get Y (BOGO) State
  bool isBogoEnabled = true;
  String bogoRuleName = 'Buy 2 Get 1 Free';
  int bogoBuyQty = 2;
  int bogoGetQty = 1;
  double bogoDiscountOnFree = 100.0; // 100% free

  // 3. Tiered Volume Pricing State
  bool isTieredPricingEnabled = true;
  List<VolumePricingTier> volumeTiers = [
    const VolumePricingTier(minQty: 1, maxQty: 5, discountPercent: 0.0),
    const VolumePricingTier(minQty: 6, maxQty: 10, discountPercent: 10.0),
    const VolumePricingTier(minQty: 11, maxQty: null, discountPercent: 20.0),
  ];

  bool _isLoaded = false;

  /// Loads persisted promotion settings from SQLite industry_module_records.
  Future<void> loadSettings() async {
    if (_isLoaded) return;
    try {
      final db = await DatabaseService.initialize();
      final records =
          await db.getModuleRecords('promotions', recordType: 'config');
      if (records.isNotEmpty) {
        final cfg = records.first;
        isHappyHourEnabled = cfg['isHappyHourEnabled'] as bool? ?? true;
        happyHourName = cfg['happyHourName'] as String? ?? 'Evening Happy Hour';
        happyHourStartHour = (cfg['happyHourStartHour'] as num?)?.toInt() ?? 16;
        happyHourEndHour = (cfg['happyHourEndHour'] as num?)?.toInt() ?? 20;
        happyHourDiscountPercent =
            (cfg['happyHourDiscountPercent'] as num?)?.toDouble() ?? 15.0;

        isBogoEnabled = cfg['isBogoEnabled'] as bool? ?? true;
        bogoRuleName = cfg['bogoRuleName'] as String? ?? 'Buy 2 Get 1 Free';
        bogoBuyQty = (cfg['bogoBuyQty'] as num?)?.toInt() ?? 2;
        bogoGetQty = (cfg['bogoGetQty'] as num?)?.toInt() ?? 1;
        bogoDiscountOnFree =
            (cfg['bogoDiscountOnFree'] as num?)?.toDouble() ?? 100.0;

        isTieredPricingEnabled = cfg['isTieredPricingEnabled'] as bool? ?? true;
        if (cfg['volumeTiers'] is List) {
          volumeTiers = (cfg['volumeTiers'] as List)
              .map((e) => VolumePricingTier.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('[PromotionsService] Error loading settings: $e');
    }
  }

  /// Persists current promotional configuration to SQLite.
  Future<void> saveSettings() async {
    try {
      final db = await DatabaseService.initialize();
      final data = <String, dynamic>{
        'isHappyHourEnabled': isHappyHourEnabled,
        'happyHourName': happyHourName,
        'happyHourStartHour': happyHourStartHour,
        'happyHourEndHour': happyHourEndHour,
        'happyHourDiscountPercent': happyHourDiscountPercent,
        'isBogoEnabled': isBogoEnabled,
        'bogoRuleName': bogoRuleName,
        'bogoBuyQty': bogoBuyQty,
        'bogoGetQty': bogoGetQty,
        'bogoDiscountOnFree': bogoDiscountOnFree,
        'isTieredPricingEnabled': isTieredPricingEnabled,
        'volumeTiers': volumeTiers.map((t) => t.toMap()).toList(),
      };

      final existing =
          await db.getModuleRecords('promotions', recordType: 'config');
      await db.saveModuleRecord(
        id: existing.isNotEmpty ? existing.first['_dbId'] as int? : null,
        moduleKey: 'promotions',
        recordType: 'config',
        title: 'SmartPOS Promotional Engine Configuration',
        status: 'active',
        data: data,
      );
    } catch (e) {
      debugPrint('[PromotionsService] Error saving settings: $e');
    }
  }

  /// Checks if Happy Hour is currently active based on system wall-clock time.
  bool isHappyHourActive() {
    if (!isHappyHourEnabled) return false;
    final nowHour = DateTime.now().hour;
    if (happyHourStartHour <= happyHourEndHour) {
      return nowHour >= happyHourStartHour && nowHour < happyHourEndHour;
    } else {
      // Overnight happy hour (e.g. 22:00 to 02:00)
      return nowHour >= happyHourStartHour || nowHour < happyHourEndHour;
    }
  }

  /// Returns active Happy Hour discount percentage (0.0 if not active).
  double getActiveHappyHourDiscount() {
    return isHappyHourActive() ? happyHourDiscountPercent : 0.0;
  }

  /// Calculates Tiered Volume Discount Percentage for a given item quantity.
  double getVolumeDiscountPercent(double quantity) {
    if (!isTieredPricingEnabled || quantity <= 1) return 0.0;
    final intQty = quantity.toInt();
    for (final tier in volumeTiers.reversed) {
      if (intQty >= tier.minQty) {
        if (tier.maxQty == null || intQty <= tier.maxQty!) {
          return tier.discountPercent;
        }
      }
    }
    return 0.0;
  }

  /// Evaluates BOGO eligibility and returns free/discounted units for a given purchased quantity.
  /// E.g. Buy 2 Get 1:
  /// Qty = 2 -> 0 free units
  /// Qty = 3 -> 1 free unit
  /// Qty = 6 -> 2 free units
  int calculateBogoFreeUnits(double quantity) {
    if (!isBogoEnabled || bogoBuyQty <= 0) return 0;
    final intQty = quantity.toInt();
    final bundleSize = bogoBuyQty + bogoGetQty;
    if (intQty < bundleSize) return 0;
    final completeBundles = intQty ~/ bundleSize;
    return completeBundles * bogoGetQty;
  }

  /// Calculates financial savings from BOGO for a line item.
  double calculateBogoSavings(double unitPrice, double quantity) {
    final freeUnits = calculateBogoFreeUnits(quantity);
    if (freeUnits <= 0) return 0.0;
    return freeUnits * unitPrice * (bogoDiscountOnFree / 100.0);
  }
}
