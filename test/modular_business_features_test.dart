import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';

void main() {
  group('Modular Business Features & Dynamic Engine Tests', () {
    test('1. Default module presets tailor features per business type', () {
      // General Store / Kiryana should not have heavy industry modules enabled by default
      final kiryana = BusinessSettings(businessType: 'kiryana');
      expect(kiryana.isModuleEnabled(BusinessSettings.moduleRestaurant), isFalse);
      expect(kiryana.isModuleEnabled(BusinessSettings.moduleHotel), isFalse);
      expect(kiryana.isModuleEnabled(BusinessSettings.moduleGym), isFalse);
      expect(kiryana.isModuleEnabled(BusinessSettings.modulePoultry), isFalse);
      expect(kiryana.isModuleEnabled(BusinessSettings.moduleFruitMandi), isFalse);
      expect(kiryana.isModuleEnabled(BusinessSettings.moduleExpenses), isTrue);

      // Restaurant should have restaurant and HRM enabled by default
      final restaurant = BusinessSettings(businessType: 'restaurant');
      expect(restaurant.isModuleEnabled(BusinessSettings.moduleRestaurant), isTrue);
      expect(restaurant.isModuleEnabled(BusinessSettings.moduleHrm), isTrue);
      expect(restaurant.isModuleEnabled(BusinessSettings.modulePoultry), isFalse);
      expect(restaurant.isModuleEnabled(BusinessSettings.moduleGym), isFalse);

      // Pharmacy should have batch_expiry enabled by default
      final pharmacy = BusinessSettings(businessType: 'pharmacy');
      expect(pharmacy.isModuleEnabled(BusinessSettings.moduleBatchExpiry), isTrue);
      expect(pharmacy.isModuleEnabled(BusinessSettings.moduleRestaurant), isFalse);

      // Garments should have variations enabled by default
      final garments = BusinessSettings(businessType: 'clothing');
      expect(garments.isModuleEnabled(BusinessSettings.moduleVariations), isTrue);
      expect(garments.isModuleEnabled(BusinessSettings.moduleHotel), isFalse);

      // Poultry should have poultry enabled by default
      final poultry = BusinessSettings(businessType: 'poultry');
      expect(poultry.isModuleEnabled(BusinessSettings.modulePoultry), isTrue);
      expect(poultry.isModuleEnabled(BusinessSettings.moduleRestaurant), isFalse);

      // Fruit Mandi should have fruit_mandi enabled by default
      final fruitMandi = BusinessSettings(businessType: 'fruit_wholesale');
      expect(fruitMandi.isModuleEnabled(BusinessSettings.moduleFruitMandi), isTrue);
      expect(fruitMandi.isModuleEnabled(BusinessSettings.moduleGym), isFalse);
    });

    test('2. Custom enabledModules string overrides defaults seamlessly', () {
      // Merchant activates custom mix of modules
      final custom = BusinessSettings(
        businessType: 'general_store',
        enabledModules: 'restaurant,woocommerce,expenses',
      );

      expect(custom.isModuleEnabled(BusinessSettings.moduleRestaurant), isTrue);
      expect(custom.isModuleEnabled(BusinessSettings.moduleWooCommerce), isTrue);
      expect(custom.isModuleEnabled(BusinessSettings.moduleExpenses), isTrue);
      expect(custom.isModuleEnabled(BusinessSettings.moduleHotel), isFalse);
      expect(custom.isModuleEnabled(BusinessSettings.moduleGym), isFalse);
      expect(custom.isModuleEnabled(BusinessSettings.modulePoultry), isFalse);
    });

    test('3. copyWith and SQLite map serialization preserve enabled_modules', () {
      final initial = BusinessSettings(
        businessType: 'supermarket',
        enabledModules: 'variations,batch_expiry,woocommerce',
      );

      final copied = initial.copyWith(
        enabledModules: 'variations,woocommerce',
      );
      expect(copied.isModuleEnabled(BusinessSettings.moduleVariations), isTrue);
      expect(copied.isModuleEnabled(BusinessSettings.moduleWooCommerce), isTrue);
      expect(copied.isModuleEnabled(BusinessSettings.moduleBatchExpiry), isFalse);

      final map = copied.toMap();
      expect(map['enabled_modules'], equals('variations,woocommerce'));

      final reconstructed = BusinessSettings.fromMap(map);
      expect(reconstructed.enabledModules, equals('variations,woocommerce'));
      expect(reconstructed.isModuleEnabled(BusinessSettings.moduleWooCommerce), isTrue);
    });

    test('4. hasAnyIndustryModuleEnabled detects specialized industry modules', () {
      final noIndustry = BusinessSettings(
        businessType: 'kiryana',
        enabledModules: 'expenses,returns',
      );
      expect(noIndustry.hasAnyIndustryModuleEnabled, isFalse);

      final withIndustry = BusinessSettings(
        businessType: 'kiryana',
        enabledModules: 'expenses,returns,repair',
      );
      expect(withIndustry.hasAnyIndustryModuleEnabled, isTrue);
    });
  });
}
