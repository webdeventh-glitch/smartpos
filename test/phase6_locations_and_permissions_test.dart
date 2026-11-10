import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Ultimate POS Phase 6: Multi-Branch Business Locations & Custom Role Matrix', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('phase6_locations_permissions_test_');
      dbPath = path.join(tempDir.path, 'pos_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Business Locations Full CRUD: Create, read, update, deactivate, and delete', () async {
      // 1. Verify default seeded locations
      final initialLocations = await dbService.getBusinessLocations();
      expect(initialLocations, isNotEmpty);
      expect(initialLocations.any((l) => l.name.contains('Main Branch')), isTrue);

      // 2. Create new business branch
      final newLoc = BusinessLocation(
        name: 'Gulberg Model Town Branch',
        locationId: 'BL-LHR-02',
        landmark: 'Main Boulevard near Pace',
        city: 'Lahore',
        state: 'Punjab',
        country: 'Pakistan',
        zipCode: '54000',
        mobile: '+92 300 9876543',
        email: 'gulberg@smartpos.pk',
        invoiceScheme: 'GLB-',
        isActive: true,
      );

      final locId = await dbService.addBusinessLocation(newLoc);
      expect(locId, greaterThan(0));

      // 3. Verify location is saved with all fields intact
      final allLocations = await dbService.getBusinessLocations();
      final savedLoc = allLocations.firstWhere((l) => l.id == locId);
      expect(savedLoc.name, 'Gulberg Model Town Branch');
      expect(savedLoc.locationId, 'BL-LHR-02');
      expect(savedLoc.landmark, 'Main Boulevard near Pace');
      expect(savedLoc.city, 'Lahore');
      expect(savedLoc.state, 'Punjab');
      expect(savedLoc.country, 'Pakistan');
      expect(savedLoc.invoiceScheme, 'GLB-');
      expect(savedLoc.isActive, isTrue);

      // 4. Update location details & toggle status
      final updatedLoc = savedLoc.copyWith(
        landmark: 'Suite 404, Pace Tower',
        mobile: '+92 321 1122334',
        isActive: false,
      );
      await dbService.updateBusinessLocation(updatedLoc);

      final refetched = (await dbService.getBusinessLocations()).firstWhere((l) => l.id == locId);
      expect(refetched.landmark, 'Suite 404, Pace Tower');
      expect(refetched.mobile, '+92 321 1122334');
      expect(refetched.isActive, isFalse);

      // 5. Delete location and verify removal
      await dbService.deleteBusinessLocation(locId);
      final finalLocations = await dbService.getBusinessLocations();
      expect(finalLocations.any((l) => l.id == locId), isFalse);
    });

    test('2. User Branch Assignment & Multi-Location Binding', () async {
      // 1. Create a warehouse location
      final warehouse = BusinessLocation(
        name: 'Islamabad Central Hub',
        locationId: 'BL-ISB-01',
        city: 'Islamabad',
        invoiceScheme: 'ISB-',
      );
      final whId = await dbService.addBusinessLocation(warehouse);

      // 2. Create staff member assigned to Islamabad Central Hub
      final staffUser = User(
        name: 'Hamza Tariq',
        username: 'hamza_isb',
        password: 'hashed_password_123',
        email: 'hamza@smartpos.pk',
        role: 'manager',
        branchId: whId,
        branchName: 'Islamabad Central Hub',
        canAccessInventory: true,
      );

      final userId = await dbService.addUser(staffUser);
      expect(userId, greaterThan(0));

      // 3. Retrieve user and verify branch binding
      final users = await dbService.getUsers();
      final retrieved = users.firstWhere((u) => u.username == 'hamza_isb');
      expect(retrieved.branchId, whId);
      expect(retrieved.branchName, 'Islamabad Central Hub');

      // 4. Reassign user to Main Branch
      final reassigned = retrieved.copyWith(
        branchId: 1,
        branchName: 'Main Branch HQ',
      );
      await dbService.updateUser(reassigned);

      final afterUpdate = (await dbService.getUsers()).firstWhere((u) => u.username == 'hamza_isb');
      expect(afterUpdate.branchId, 1);
      expect(afterUpdate.branchName, 'Main Branch HQ');
    });

    test('3. Granular Authorization Matrix: Restricted salesman vs customized privileges', () async {
      // 1. Create a restricted cashier user
      final restrictedCashier = User(
        name: 'Bilal Cashier',
        username: 'bilal_counter',
        password: 'password_test',
        role: 'cashier',
        canEditPrice: false,
        canGiveDiscount: false,
        maxDiscountPercent: 0.0,
        canViewCostPrice: false,
        canDeleteSale: false,
        canProcessReturn: false,
        canAccessKhata: false,
        canAccessInventory: false,
        canAccessReports: false,
        canAccessSettings: false,
        canManageUsers: false,
      );

      final cashierId = await dbService.addUser(restrictedCashier);
      expect(cashierId, greaterThan(0));

      final fetchedCashier = (await dbService.getUsers()).firstWhere((u) => u.username == 'bilal_counter');

      // Verify all restriction checks evaluate to false
      expect(fetchedCashier.canEditPrice, isFalse);
      expect(fetchedCashier.canGiveDiscount, isFalse);
      expect(fetchedCashier.canViewCostPrice, isFalse);
      expect(fetchedCashier.canDeleteSale, isFalse);
      expect(fetchedCashier.canProcessReturn, isFalse);
      expect(fetchedCashier.canAccessInventory, isFalse);
      expect(fetchedCashier.canAccessReports, isFalse);
      expect(fetchedCashier.canAccessSettings, isFalse);

      expect(fetchedCashier.hasPermission('sales.delete'), isFalse);
      expect(fetchedCashier.hasPermission('products.view_cost'), isFalse);
      expect(fetchedCashier.hasPermission('inventory.manage'), isFalse);
      expect(fetchedCashier.hasPermission('reports.view'), isFalse);

      // 2. Grant selective permissions (e.g. Khata recovery + Reports viewing)
      final elevatedCashier = fetchedCashier.copyWith(
        canAccessKhata: true,
        canAccessReports: true,
        canDeleteSale: true,
      );
      await dbService.updateUser(elevatedCashier);

      final updatedCashier = (await dbService.getUsers()).firstWhere((u) => u.username == 'bilal_counter');
      expect(updatedCashier.canAccessKhata, isTrue);
      expect(updatedCashier.canAccessReports, isTrue);
      expect(updatedCashier.canDeleteSale, isTrue);
      expect(updatedCashier.hasPermission('sales.delete'), isTrue);
      expect(updatedCashier.hasPermission('reports.view'), isTrue);
      expect(updatedCashier.hasPermission('inventory.manage'), isFalse); // still restricted
    });

    test('4. Admin & Super Admin Global Authorization Bypass', () {
      // 1. Create a Super Admin user
      final superAdmin = User(
        name: 'Store Owner',
        username: 'owner_root',
        password: 'secure_password',
        role: 'superadmin',
        canEditPrice: false, // Even if flag is nominally false, superadmin bypasses
        canDeleteSale: false,
        canViewCostPrice: false,
      );

      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.isAdmin, isTrue);

      // Bypass verification
      expect(superAdmin.canViewCostPriceEffective, isTrue);
      expect(superAdmin.hasPermission('sales.delete'), isTrue);
      expect(superAdmin.hasPermission('products.view_cost'), isTrue);
      expect(superAdmin.hasPermission('inventory.manage'), isTrue);
      expect(superAdmin.hasPermission('reports.view'), isTrue);
      expect(superAdmin.hasPermission('settings.manage'), isTrue);

      // 2. Regular Admin user
      final regularAdmin = User(
        name: 'Operational Admin',
        username: 'admin_ops',
        password: 'ops_password',
        role: 'admin',
      );

      expect(regularAdmin.isAdmin, isTrue);
      expect(regularAdmin.hasPermission('sales.delete'), isTrue);
      expect(regularAdmin.hasPermission('reports.view'), isTrue);
      expect(regularAdmin.hasPermission('inventory.manage'), isTrue);
    });
  });
}

