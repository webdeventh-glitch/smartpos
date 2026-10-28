import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/auth_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Owner Authorization & Complete System Verification Tests', () {
    late DatabaseService dbService;

    setUpAll(() async {
      // Use in-memory SQLite database for fast, isolated test execution
      dbService = await DatabaseService.initialize(customPath: inMemoryDatabasePath);
      await dbService.seedInitialDataForBusinessType(businessType: 'general');
    });

    test('1. Verify All Parity Tables Exist in Database', () async {
      final db = dbService.db;
      final tablesRes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tablesRes.map((r) => r['name'] as String).toSet();

      final expectedTables = [
        'customer_groups',
        'cash_denominations',
        'product_racks',
        'types_of_services',
        'invoice_layouts',
        'discounts',
        'document_and_notes',
        'users',
        'products',
        'sales',
        'sale_items',
        'sale_returns',
        'business_settings',
      ];

      for (final table in expectedTables) {
        expect(tableNames.contains(table), isTrue, reason: 'Expected table $table to exist');
      }
    });

    test('2. Verify Users Table Schema Contains All 12 Granular Authorization Columns', () async {
      final db = dbService.db;
      final columnsRes = await db.rawQuery("PRAGMA table_info(users)");
      final colNames = columnsRes.map((r) => r['name'] as String).toSet();

      final expectedCols = [
        'can_edit_price',
        'can_give_discount',
        'max_discount_percent',
        'can_view_cost_price',
        'can_delete_sale',
        'can_process_return',
        'can_access_khata',
        'can_access_inventory',
        'can_access_reports',
        'can_access_settings',
        'can_manage_users',
        'permissions',
      ];

      for (final col in expectedCols) {
        expect(colNames.contains(col), isTrue, reason: 'Expected column $col in users table');
      }
    });

    test('3. Verify Pre-Seeded Accounts and Granular Security Settings', () async {
      final users = await dbService.getUsers();
      expect(users.isNotEmpty, isTrue);

      final owner = users.firstWhere((u) => u.username == 'webdeventh');
      final salesman = users.firstWhere((u) => u.username == 'salesman1');
      final manager = users.firstWhere((u) => u.username == 'manager1');

      // A. Owner (webdeventh) - Complete and Unrestricted Power
      expect(owner.isSuperAdmin, isTrue);
      expect(owner.canEditPrice, isTrue);
      expect(owner.canGiveDiscount, isTrue);
      expect(owner.maxDiscountPercent, greaterThanOrEqualTo(100.0));
      expect(owner.canViewCostPrice, isTrue);
      expect(owner.canDeleteSale, isTrue);
      expect(owner.canProcessReturn, isTrue);
      expect(owner.canAccessReports, isTrue);
      expect(owner.canAccessSettings, isTrue);
      expect(owner.canManageUsers, isTrue);

      // B. Salesman (salesman1) - Protected & Restricted Counter Persona
      expect(owner.hasPermission('pos.edit_price'), isTrue);
      expect(salesman.isSalesman, isTrue);
      expect(salesman.canEditPrice, isFalse, reason: 'Salesman must NOT be able to alter selling prices');
      expect(salesman.canGiveDiscount, isTrue);
      expect(salesman.maxDiscountPercent, equals(5.0), reason: 'Salesman discount limit must be capped at 5%');
      expect(salesman.canViewCostPrice, isFalse, reason: 'Salesman must NOT see wholesale purchase costs');
      expect(salesman.canDeleteSale, isFalse, reason: 'Salesman must NOT be able to void/delete sales');
      expect(salesman.canProcessReturn, isFalse, reason: 'Salesman must NOT process cash refunds without manager');
      expect(salesman.canAccessKhata, isTrue, reason: 'Salesman can view customer credit balance');
      expect(salesman.canAccessReports, isFalse);
      expect(salesman.canAccessSettings, isFalse);
      expect(salesman.canManageUsers, isFalse);

      // C. Store Manager (manager1) - Supervisory Powers
      expect(manager.isManager, isTrue);
      expect(manager.canEditPrice, isTrue);
      expect(manager.canGiveDiscount, isTrue);
      expect(manager.maxDiscountPercent, equals(20.0));
      expect(manager.canViewCostPrice, isTrue);
      expect(manager.canDeleteSale, isTrue);
      expect(manager.canProcessReturn, isTrue);
      expect(manager.canAccessReports, isTrue);
      expect(manager.canManageUsers, isFalse);
    });

    test('4. Test Authentication Service with Hashed / Salting Logic', () async {
      // Correct password logins
      final ownerSuccess = await AuthService.login('webdeventh', 'password');
      expect(ownerSuccess, isTrue);
      expect(AuthService.currentUser?.username, equals('webdeventh'));

      final salesmanSuccess = await AuthService.login('salesman1', 'password');
      expect(salesmanSuccess, isTrue);
      expect(AuthService.currentUser?.username, equals('salesman1'));

      final managerSuccess = await AuthService.login('manager1', 'password');
      expect(managerSuccess, isTrue);
      expect(AuthService.currentUser?.username, equals('manager1'));

      // Incorrect password fails
      final badLogin = await AuthService.login('salesman1', 'wrong_pass_123');
      expect(badLogin, isFalse);
    });

    test('5. Owner Dynamically Modifies Salesman Permissions & Persists to Database', () async {
      final users = await dbService.getUsers();
      final salesman = users.firstWhere((u) => u.username == 'salesman1');

      // Verify baseline
      expect(salesman.canEditPrice, isFalse);
      expect(salesman.maxDiscountPercent, equals(5.0));

      // Owner upgrades salesman: grants price editing and raises discount limit to 15%
      final upgradedSalesman = salesman.copyWith(
        canEditPrice: true,
        maxDiscountPercent: 15.0,
        canViewCostPrice: true,
      );

      await dbService.updateUser(upgradedSalesman);

      // Reload from database to ensure SQLite persistence
      final refreshedUsers = await dbService.getUsers();
      final refreshedSalesman = refreshedUsers.firstWhere((u) => u.username == 'salesman1');

      expect(refreshedSalesman.canEditPrice, isTrue, reason: 'Updated price permission should persist');
      expect(refreshedSalesman.maxDiscountPercent, equals(15.0), reason: 'Updated max discount should persist');
      expect(refreshedSalesman.canViewCostPrice, isTrue, reason: 'Updated cost price visibility should persist');

      // Owner restricts salesman again
      final lockedSalesman = refreshedSalesman.copyWith(
        canEditPrice: false,
        canGiveDiscount: false,
        maxDiscountPercent: 0.0,
      );
      await dbService.updateUser(lockedSalesman);

      final reRefreshed = await dbService.getUsers();
      final reSalesman = reRefreshed.firstWhere((u) => u.username == 'salesman1');
      expect(reSalesman.canEditPrice, isFalse);
      expect(reSalesman.canGiveDiscount, isFalse);
      expect(reSalesman.maxDiscountPercent, equals(0.0));
    });

    test('6. POS Terminal Security Logic Simulation', () async {
      final products = await dbService.getProducts();
      expect(products.isNotEmpty, isTrue);
      final sample = products.first;

      final users = await dbService.getUsers();
      final salesmanRaw = users.firstWhere((u) => u.username == 'salesman1');
      // Ensure standard salesman baseline
      final salesman = salesmanRaw.copyWith(
        canEditPrice: false,
        canGiveDiscount: true,
        maxDiscountPercent: 5.0,
        canViewCostPrice: false,
      );
      await dbService.updateUser(salesman);

      // A. Cart item pricing calculation
      final item = CartItem(product: sample, quantity: 3, unitPrice: sample.sellingPrice);
      expect(item.subtotal, equals(sample.sellingPrice * 3));

      // B. Enforce Price alteration rule for salesman
      bool allowPriceEdit(User user) => user.canEditPrice;
      expect(allowPriceEdit(salesman), isFalse);

      // C. Enforce Discount limit rule for salesman
      bool allowDiscount(User user, double rate) => user.canGiveDiscount && rate <= user.maxDiscountPercent;
      expect(allowDiscount(salesman, 4.0), isTrue); // within 5% limit
      expect(allowDiscount(salesman, 5.0), isTrue); // exactly at 5% limit
      expect(allowDiscount(salesman, 5.1), isFalse); // exceeds 5% limit
      expect(allowDiscount(salesman, 20.0), isFalse); // exceeds 5% limit

      // D. Enforce Cost Price Masking for salesman
      String getDisplayCost(User user, Product p) {
        return user.canViewCostPrice ? '${p.purchasePrice}' : '••••••';
      }
      expect(getDisplayCost(salesman, sample), equals('••••••'));

      final owner = users.firstWhere((u) => u.username == 'webdeventh');
      expect(getDisplayCost(owner, sample), isNot(equals('••••••')));
      expect(allowPriceEdit(owner), isTrue);
      expect(allowDiscount(owner, 50.0), isTrue);
    });
  });
}
