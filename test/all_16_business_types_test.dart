import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';

void main() {
  group('Comprehensive 16 Business Models Architecture Tests', () {
    test('All 16 business types have verified flags and display names', () {
      final types = [
        {'type': 'general_store', 'expected': 'General Store'},
        {'type': 'supermarket', 'expected': 'Supermarket'},
        {'type': 'clothing', 'expected': 'Garments'},
        {'type': 'mobile', 'expected': 'Mobile'},
        {'type': 'wholesale', 'expected': 'Wholesale'},
        {'type': 'pharmacy', 'expected': 'Pharmacy'},
        {'type': 'restaurant', 'expected': 'Restaurant'},
        {'type': 'repair', 'expected': 'Repairing Shop'},
        {'type': 'hotel', 'expected': 'Hotel Management'},
        {'type': 'gym', 'expected': 'Gym'},
        {'type': 'manufacturing', 'expected': 'Manufacturing'},
        {'type': 'woocommerce', 'expected': 'WooCommerce'},
        {'type': 'hrm', 'expected': 'HR & Employee'},
        {'type': 'accounting_crm', 'expected': 'Accounting & CRM'},
        {'type': 'fruit_wholesale', 'expected': 'Fruit'},
        {'type': 'poultry', 'expected': 'Poultry'},
      ];

      for (final item in types) {
        final settings = BusinessSettings(businessType: item['type']!);
        expect(
          settings.businessTypeDisplayName,
          contains(item['expected']!),
          reason: 'Failed for type ${item['type']}',
        );
      }
    });

    test('All individual boolean getters respond accurately', () {
      expect(BusinessSettings(businessType: 'general_store').isGeneral, isTrue);
      expect(BusinessSettings(businessType: 'supermarket').isSupermarket, isTrue);
      expect(BusinessSettings(businessType: 'clothing').isClothing, isTrue);
      expect(BusinessSettings(businessType: 'electronics').isSolarOrElectronics, isTrue);
      expect(BusinessSettings(businessType: 'wholesale').isWholesale, isTrue);
      expect(BusinessSettings(businessType: 'pharmacy').isPharmacy, isTrue);
      expect(BusinessSettings(businessType: 'restaurant').isRestaurant, isTrue);
      expect(BusinessSettings(businessType: 'repair').isRepair, isTrue);
      expect(BusinessSettings(businessType: 'hotel').isHotel, isTrue);
      expect(BusinessSettings(businessType: 'gym').isGym, isTrue);
      expect(BusinessSettings(businessType: 'manufacturing').isManufacturing, isTrue);
      expect(BusinessSettings(businessType: 'woocommerce').isWooCommerce, isTrue);
      expect(BusinessSettings(businessType: 'hrm').isHrm, isTrue);
      expect(BusinessSettings(businessType: 'accounting_crm').isAccountingCrm, isTrue);
      expect(BusinessSettings(businessType: 'fruit_wholesale').isFruitWholesale, isTrue);
      expect(BusinessSettings(businessType: 'poultry').isPoultry, isTrue);
    });
  });
}
