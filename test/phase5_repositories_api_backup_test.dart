import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/backup_update_service.dart';
import 'package:desktop_starter/services/local_api_service.dart';
import 'package:desktop_starter/repositories/sales_repository.dart';
import 'package:desktop_starter/repositories/purchase_repository.dart';
import 'package:desktop_starter/repositories/inventory_repository.dart';
import 'package:desktop_starter/repositories/contacts_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Smart POS Phase 5: Repositories, Local API & Backup Center', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartpos_phase5_test_');
      dbPath = path.join(tempDir.path, 'phase5_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      if (LocalApiService.instance.isRunning) {
        await LocalApiService.instance.stopServer();
      }
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. BackupUpdateService creates instant snapshot and lists backups', () async {
      final backupService = BackupUpdateService.instance;
      final backupDir = await backupService.getBackupDirectory();
      expect(backupDir.existsSync(), isTrue);

      final backupFile = await backupService.createBackup(customNote: 'Automated test snapshot');
      expect(backupFile.existsSync(), isTrue);
      expect(backupFile.path.endsWith('.db'), isTrue);

      final backups = await backupService.listBackups();
      expect(backups.any((f) => f.path == backupFile.path), isTrue);

      // Clean up backup file
      try {
        if (backupFile.existsSync()) backupFile.deleteSync();
      } catch (_) {}
    });

    test('2. BackupUpdateService online check and offline package migration', () async {
      final backupService = BackupUpdateService.instance;

      // Online check simulation
      final onlineInfo = await backupService.checkOnlineUpdate();
      expect(onlineInfo['has_update'], isTrue);
      expect(onlineInfo['latest_version'], equals('2.6.2'));
      expect(onlineInfo['release_notes'], isNotEmpty);

      // Offline package migration
      final fakePkg = File(path.join(tempDir.path, 'smartpos_v2.6_update.pkg'));
      fakePkg.writeAsStringSync('Smart POS Offline Upgrade Archive Package');

      final result = await backupService.applyOfflineUpdatePackage(fakePkg.path);
      expect(result['success'], isTrue);
      expect(result['migrated_tables'], contains('payment_transactions'));
      expect(result['migrated_tables'], contains('sync_queue'));
    });

    test('3. Embedded LocalApiService start, health check & query over HTTP', () async {
      final api = LocalApiService.instance;
      final started = await api.startServer(port: 9091);
      expect(started, isTrue);
      expect(api.isRunning, isTrue);
      expect(api.port, equals(9091));

      final client = HttpClient();
      try {
        // Test GET /health
        final healthReq = await client.getUrl(Uri.parse('http://127.0.0.1:9091/health'));
        final healthRes = await healthReq.close();
        expect(healthRes.statusCode, equals(200));
        final healthBody = await healthRes.transform(utf8.decoder).join();
        final healthJson = jsonDecode(healthBody) as Map<String, dynamic>;
        expect(healthJson['status'], equals('ok'));
        expect(healthJson['app'], equals('Smart POS'));

        // Test GET /products
        final prodReq = await client.getUrl(Uri.parse('http://127.0.0.1:9091/products'));
        final prodRes = await prodReq.close();
        expect(prodRes.statusCode, equals(200));

        // Test GET /reports/summary
        final repReq = await client.getUrl(Uri.parse('http://127.0.0.1:9091/reports/summary'));
        final repRes = await repReq.close();
        expect(repRes.statusCode, equals(200));
      } finally {
        client.close();
        await api.stopServer();
        expect(api.isRunning, isFalse);
      }
    });

    test('4. Domain Repositories: Sales, Purchases, Inventory, Contacts', () async {
      final salesRepo = SalesRepository(dbService);
      final purchaseRepo = PurchaseRepository(dbService);
      final invRepo = InventoryRepository(dbService);
      final contactsRepo = ContactsRepository(dbService);

      // 1. Add customer via ContactsRepository
      final custId = await contactsRepo.addContact(Contact(
        type: 'customer',
        name: 'Enterprise Client Corp',
        phone: '03001234567',
      ));
      expect(custId, isPositive);

      final customer = await contactsRepo.getContactById(custId);
      expect(customer, isNotNull);
      expect(customer!.name, equals('Enterprise Client Corp'));
      expect(await contactsRepo.isWalkInCustomer(custId), isFalse);

      // 2. Add product via InventoryRepository
      final prodId = await invRepo.addProduct(Product(
        name: 'Solar Hybrid Inverter 5kW',
        sku: 'INV-5KW-001',
        barcode: 'INV-5KW-001',
        purchasePrice: 120000.0,
        sellingPrice: 145000.0,
        stockQuantity: 20.0,
      ));
      expect(prodId, isPositive);

      final product = await invRepo.getProductById(prodId);
      expect(product, isNotNull);
      expect(product!.sku, equals('INV-5KW-001'));

      // Filter products by search
      final searchResults = await invRepo.getProducts(search: 'Inverter');
      expect(searchResults.any((p) => p.id == prodId), isTrue);

      // 3. Create Sale via SalesRepository
      final sale = Sale(
        invoiceNo: 'INV-REPO-001',
        customerId: custId,
        customerName: 'Enterprise Client Corp',
        subtotal: 145000.0,
        totalAmount: 145000.0,
        paidAmount: 50000.0,
        paymentStatus: 'partial',
        paymentMethod: 'cash',
        createdAt: DateTime.now().toIso8601String(),
      );

      final cartItem = CartItem(
        product: product,
        quantity: 1.0,
        unitPrice: 145000.0,
      );

      final createdSale = await salesRepo.createSale(
        sale: sale,
        items: [cartItem],
      );
      expect(createdSale.id, isNotNull);

      // Verify contact balance increased by due balance (145000 - 50000 = 95000)
      final updatedCust = await contactsRepo.getContactById(custId);
      expect(updatedCust!.balance, closeTo(95000.0, 0.01));

      // 4. Create Purchase via PurchaseRepository
      final suppId = await contactsRepo.addContact(Contact(
        type: 'supplier',
        name: 'Solar Tech Principal',
        phone: '03119876543',
      ));
      expect(suppId, isPositive);

      final purchase = Purchase(
        refNo: 'PO-REPO-001',
        supplierId: suppId,
        supplierName: 'Solar Tech Principal',
        totalAmount: 240000.0,
        paidAmount: 100000.0,
        paymentStatus: 'partial',
        status: 'received',
        createdAt: DateTime.now().toIso8601String(),
      );

      final purchaseId = await purchaseRepo.createPurchase(
        purchase: purchase,
        items: [
          {
            'product_id': prodId,
            'product_name': product.name,
            'quantity': 2.0,
            'unit_cost': 120000.0,
            'subtotal': 240000.0,
          }
        ],
      );
      expect(purchaseId, isPositive);

      // Verify supplier outstanding balance updated (240000 - 100000 = 140000)
      final updatedSupp = await contactsRepo.getContactById(suppId);
      expect(updatedSupp!.balance, closeTo(140000.0, 0.01));
    });
  });
}
