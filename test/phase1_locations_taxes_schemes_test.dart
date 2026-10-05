import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Phase 1: Multi-Location, Tax Rates and Invoice Schemes operations', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_phase1_test_');
    final dbPath = '${tempDir.path}/test_phase1.db';

    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // 1. Business Locations test
    final locs = await dbService.getBusinessLocations();
    expect(locs.isNotEmpty, isTrue);
    expect(locs.any((l) => l.name.contains('Main Branch')), isTrue);

    final newLocId = await dbService.addBusinessLocation(
      BusinessLocation(
        name: 'Airport Outlet #4',
        locationId: 'BL0003',
        city: 'Queens',
        mobile: '+1 (800) 555-9988',
      ),
    );
    expect(newLocId, greaterThan(0));

    final updatedLocs = await dbService.getBusinessLocations();
    expect(updatedLocs.length, locs.length + 1);
    expect(updatedLocs.any((l) => l.name == 'Airport Outlet #4'), isTrue);

    // 2. Tax Rates test
    final taxes = await dbService.getTaxRates();
    expect(taxes.isNotEmpty, isTrue);
    expect(taxes.any((t) => t.name.contains('VAT') || t.amount == 5.0), isTrue);

    final newTaxId = await dbService.addTaxRate(
      TaxRate(name: 'Import Duty 8%', amount: 8.0),
    );
    expect(newTaxId, greaterThan(0));
    final updatedTaxes = await dbService.getTaxRates();
    expect(updatedTaxes.any((t) => t.name == 'Import Duty 8%'), isTrue);

    // 3. Invoice Schemes test
    final schemes = await dbService.getInvoiceSchemes();
    expect(schemes.isNotEmpty, isTrue);

    final inv1 = await dbService.generateNextInvoiceNumber();
    expect(inv1, startsWith('INV-'));

    final inv2 = await dbService.generateNextInvoiceNumber();
    expect(inv2, isNot(equals(inv1)));

    // Clean up
    await dbService.db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
