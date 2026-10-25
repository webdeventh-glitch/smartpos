import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/qulop_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Smart POS Phase 1: Database Schema Expansion & Password Security', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartpos_test_');
      dbPath = path.join(tempDir.path, 'test_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Salted SHA-256 password hashing & verification works with fallback', () async {
      const password = 'SecretPassword2026!';
      final hash = AuthService.hashPassword(password);

      expect(hash, startsWith('sha256\$'));
      expect(hash, isNot(equals(password)));

      // Verifies correct password
      expect(AuthService.verifyPassword(password, hash), isTrue);

      // Rejects incorrect password
      expect(AuthService.verifyPassword('WrongPassword', hash), isFalse);

      // Verifies legacy plain text password
      expect(AuthService.verifyPassword('password', 'password'), isTrue);
    });

    test('2. Hardware ID detection and hardware-bound license verification', () async {
      final hwid = await QulopService.getHardwareId();
      expect(hwid, isNotEmpty);
      expect(hwid, startsWith('HWID-'));

      final mac = await QulopService.getDeviceMacAddress();
      expect(mac, isNotEmpty);

      // Generate a key bound to this hardware
      final key = QulopService.generateHardwareBoundKey(
        clientName: 'Alpha Solar Agency',
        hardwareId: hwid,
        tierCode: 'LFT',
      );
      expect(key, startsWith('QULOP-LFT-'));

      // Verify the generated hardware-bound key
      final status = await QulopService.verifyQulopKey(key);
      expect(status.isValid, isTrue);
      expect(status.tier, QulopTier.lifetime);
      expect(status.clientName, 'Alpha Solar Agency');
    });

    test('3. Payment Transactions (Split Tender & Ledger Recoveries) CRUD', () async {
      final now = DateTime.now().toIso8601String();
      final tx = PaymentTransaction(
        transactionType: 'sale',
        parentId: 101,
        contactId: 5,
        contactName: 'Hamza Solar Client',
        paymentMethod: 'card',
        amount: 25000.0,
        accountName: 'Standard Chartered Bank',
        transactionDate: '2026-10-23',
        refNo: 'POS-TX-9001',
        note: 'Advance deposit for 5kW Solar Inverter Package',
        createdBy: 'Cashier Bilal',
        createdAt: now,
      );

      final id = await dbService.addPaymentTransaction(tx);
      expect(id, isPositive);

      final saleTxs = await dbService.getPaymentTransactionsForSale(101);
      expect(saleTxs.length, 1);
      expect(saleTxs.first.amount, 25000.0);
      expect(saleTxs.first.paymentMethod, 'card');
      expect(saleTxs.first.contactName, 'Hamza Solar Client');

      final contactTxs = await dbService.getPaymentTransactionsForContact(5);
      expect(contactTxs.length, 1);
      expect(contactTxs.first.id, id);
    });

    test('4. Product Serials & Batches (IMEI & Expiry FIFO) CRUD', () async {
      final now = DateTime.now().toIso8601String();

      // Mobile with dual IMEI
      final imeiItem = ProductSerialBatch(
        productId: 12,
        productName: 'Samsung Galaxy A54 5G',
        sku: 'MOB-SAM-A54',
        serialNumber1: '352984102938475',
        serialNumber2: '352984102938476',
        warrantyMonths: 12,
        warrantyExpiryDate: '2027-10-23',
        status: 'in_stock',
        purchasePrice: 65000.0,
        sellingPrice: 78000.0,
        createdAt: now,
      );
      final imeiId = await dbService.addProductSerialBatch(imeiItem);
      expect(imeiId, isPositive);

      final fetchedByImei = await dbService.getProductSerialByImei('352984102938475');
      expect(fetchedByImei, isNotNull);
      expect(fetchedByImei!.productName, 'Samsung Galaxy A54 5G');

      // Pharmacy medicine with batch & FIFO expiry
      final batch1 = ProductSerialBatch(
        productId: 45,
        productName: 'Augmentin 625mg Tab',
        batchNumber: 'BATCH-2026-A',
        expiryDate: '2027-04-01',
        status: 'in_stock',
        createdAt: now,
      );
      final batch2 = ProductSerialBatch(
        productId: 45,
        productName: 'Augmentin 625mg Tab',
        batchNumber: 'BATCH-2025-Z',
        expiryDate: '2026-11-01', // earlier expiry
        status: 'in_stock',
        createdAt: now,
      );

      await dbService.addProductSerialBatch(batch1);
      await dbService.addProductSerialBatch(batch2);

      final activeBatches = await dbService.getActiveBatchesForProduct(45);
      expect(activeBatches.length, 2);
      // Verify FIFO ordering: earlier expiry comes first!
      expect(activeBatches.first.batchNumber, 'BATCH-2025-Z');
      expect(activeBatches.last.batchNumber, 'BATCH-2026-A');
    });

    test('5. Product Bundles & System Packages (Solar BOM) CRUD', () async {
      // 10kW Solar Package BOM
      final bundleItems = [
        ProductBundleItem(
          parentProductId: 200,
          subProductId: 10,
          subProductName: 'Longi 580W Tier-1 Solar Panels',
          subSku: 'PANEL-580W',
          quantity: 18.0,
          unitPrice: 17500.0,
        ),
        ProductBundleItem(
          parentProductId: 200,
          subProductId: 20,
          subProductName: 'Inverex Nitrox 10kW Hybrid Inverter',
          subSku: 'INV-10KW',
          quantity: 1.0,
          unitPrice: 420000.0,
        ),
        ProductBundleItem(
          parentProductId: 200,
          subProductId: 30,
          subProductName: 'Narada 48V 100Ah Lithium Battery',
          subSku: 'BAT-NAR-48V',
          quantity: 2.0,
          unitPrice: 280000.0,
        ),
        ProductBundleItem(
          parentProductId: 200,
          subProductId: 40,
          subProductName: 'Standard Mounting Structure & Cabling',
          subSku: 'SRV-INSTALL',
          quantity: 1.0,
          unitPrice: 85000.0,
        ),
      ];

      await dbService.saveBundleItems(200, bundleItems);

      final fetchedBundle = await dbService.getBundleItems(200);
      expect(fetchedBundle.length, 4);
      expect(fetchedBundle[0].subProductName, contains('Longi'));
      expect(fetchedBundle[1].subProductName, contains('Inverter'));

      final totalEstimatedBOM = fetchedBundle.fold<double>(0.0, (acc, item) => acc + item.subtotal);
      expect(totalEstimatedBOM, greaterThan(1000000.0));
    });

    test('6. Audit Logs record sensitive POS and Admin actions', () async {
      final logId = await dbService.logAuditAction(
        action: 'price_override',
        entityType: 'sale_item',
        entityId: 'INV-2026-0099',
        userId: 1,
        userName: 'Irfan Khan',
        details: 'Discount override from Rs 1,500 to Rs 1,200 approved for VIP customer',
        oldValues: '1500.0',
        newValues: '1200.0',
      );
      expect(logId, isPositive);

      final logs = await dbService.getAuditLogs(limit: 10);
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first.action, 'price_override');
      expect(logs.first.userName, 'Irfan Khan');
    });

    test('7. Super Admin user registration with salted SHA-256 encryption', () async {
      final user = await AuthService.registerSuperAdmin(
        name: 'Master Architect',
        username: 'masterpos',
        password: 'SecureMaster2026!',
        email: 'owner@smartpos.com',
        phone: '+92 300 9998877',
      );

      expect(user.role, 'superadmin');
      expect(user.password, startsWith('sha256\$'));

      // Test login with password
      final loginSuccess = await AuthService.login('masterpos', 'SecureMaster2026!');
      expect(loginSuccess, isTrue);
      expect(AuthService.currentUser?.username, 'masterpos');

      // Test login failure with wrong password
      final wrongLogin = await AuthService.login('masterpos', 'WrongPassword123');
      expect(wrongLogin, isFalse);
    });

    test('8. Walk-in customer detection and balance updates', () async {
      // Walk-in customer without ID is detected
      expect(await dbService.isWalkInCustomer(null), isTrue);

      // Contact balance delta
      final contactId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Tariq Electronics Store',
        phone: '+92 321 0000000',
        balance: 1000.0,
        creditLimit: 50000.0,
      ));

      expect(await dbService.isWalkInCustomer(contactId), isFalse);

      await dbService.updateContactBalance(contactId, 4500.0);
      final updatedContact = await dbService.getContactById(contactId);
      expect(updatedContact?.balance, 5500.0);
    });
  });

  group('Smart POS Phase 2: Presets & Business Settings Integration', () {
    test('BusinessSettings supports multi-industry presets and deployment modes', () {
      final settings = BusinessSettings(
        businessName: 'Smart POS Mega Hub',
        industryPresets: 'retail_supermarket,mobile_electronics,solar_hardware,restaurant_cafe',
        deploymentMode: 'offline_server',
        serverHost: '127.0.0.1',
        serverPort: 8080,
        taxNumber: 'STRN-984210',
      );

      expect(settings.isRetailEnabled, isTrue);
      expect(settings.isMobileElectronicsEnabled, isTrue);
      expect(settings.isSolarHardwareEnabled, isTrue);
      expect(settings.isRestaurantEnabled, isTrue);
      expect(settings.isPrimaryServer, isTrue);
      expect(settings.isLanSecondaryTerminal, isFalse);
      expect(settings.taxNumber, 'STRN-984210');

      // Test map serialization
      final map = settings.toMap();
      expect(map['industry_presets'], contains('solar_hardware'));
      expect(map['deployment_mode'], 'offline_server');
      expect(map['server_port'], 8080);
      expect(map['tax_number'], 'STRN-984210');

      final fromMapSettings = BusinessSettings.fromMap(map);
      expect(fromMapSettings.businessName, 'Smart POS Mega Hub');
      expect(fromMapSettings.industryPresets, contains('restaurant_cafe'));
    });
  });
}
