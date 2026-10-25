import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Business Type First Installation Setup & Lock Engine Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = await DatabaseService.initialize(customPath: inMemoryDatabasePath);
    });

    test('1. BusinessSettings helper displays correct labels and copyWith works', () {
      final pharmacy = BusinessSettings(businessType: 'pharmacy');
      expect(pharmacy.businessTypeDisplayName, contains('Pharmacy'));

      final solar = BusinessSettings(businessType: 'solar');
      expect(solar.businessTypeDisplayName, contains('Solar'));

      final mobile = BusinessSettings(businessType: 'mobile');
      expect(mobile.businessTypeDisplayName, contains('Mobile'));

      final clothing = BusinessSettings(businessType: 'clothing');
      expect(clothing.businessTypeDisplayName, contains('Apparel'));

      final general = BusinessSettings(businessType: 'general');
      expect(general.businessTypeDisplayName, contains('General Retail'));

      final copied = pharmacy.copyWith(businessName: 'New Pharmacy Name');
      expect(copied.businessName, equals('New Pharmacy Name'));
      expect(copied.businessType, equals('pharmacy'));
    });

    test('2. First installation wizard sets business type permanently', () async {
      // Step 1: Newly seeded database starts unconfigured
      final initial = await dbService.getBusinessSettings();
      expect(initial.isConfigured, isFalse);

      // Step 2: During Setup Wizard, client chooses Solar Energy business model
      final configured = initial.copyWith(
        businessName: 'Apex Solar Energy Solutions',
        businessType: 'solar',
        isConfigured: true,
      );
      await dbService.updateBusinessSettings(configured);

      final saved = await dbService.getBusinessSettings();
      expect(saved.isConfigured, isTrue);
      expect(saved.businessType, equals('solar'));
      expect(saved.businessName, equals('Apex Solar Energy Solutions'));
    });

    test('3. Post-installation business type cannot be switched or altered', () async {
      // The business was established as 'solar' during initial installation in test 2
      final current = await dbService.getBusinessSettings();
      expect(current.isConfigured, isTrue);
      expect(current.businessType, equals('solar'));

      // Attempt to switch business type to clothing or pharmacy post-installation
      final illicitUpdate = current.copyWith(
        businessName: 'Apex Electronics & Clothing',
        businessType: 'clothing',
      );
      await dbService.updateBusinessSettings(illicitUpdate);

      // Verify that businessName updated, but businessType was strictly LOCKED
      final postAttempt = await dbService.getBusinessSettings();
      expect(postAttempt.businessName, equals('Apex Electronics & Clothing'));
      expect(postAttempt.businessType, equals('solar'),
          reason: 'Business type must remain locked to the first-installation configuration');
    });
  });
}
