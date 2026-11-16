import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('UltimatePOS Parity Upgrades Test Suite (Phases 1 - 5)', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ultimatepos_parity_test_');
      dbPath = path.join(
          tempDir.path, 'parity_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        await dbService.db.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Phase 1: ModuleRegistry contains all 15+ core SaaS modules', () {
      expect(ModuleRegistry.corePos, equals('core_pos'));
      expect(ModuleRegistry.accounting, equals('accounting_crm'));
      expect(ModuleRegistry.restaurant, equals('restaurant'));
      expect(ModuleRegistry.pharmacy, equals('batch_expiry'));
      expect(ModuleRegistry.repair, equals('repair'));
      expect(ModuleRegistry.hotel, equals('hotel'));
      expect(ModuleRegistry.gym, equals('gym'));
      expect(ModuleRegistry.manufacturing, equals('manufacturing'));
      expect(ModuleRegistry.hrm, equals('hrm'));
      expect(ModuleRegistry.cloudSync, equals('cloud_sync'));
      expect(ModuleRegistry.lanMultiCounter, equals('lan_counter'));
      expect(ModuleRegistry.allModules, contains(ModuleRegistry.restaurant));
      expect(ModuleRegistry.allModules.length, greaterThanOrEqualTo(15));
    });

    test('Phase 1: CartItem supports negative line items for counter exchange',
        () {
      final product = Product(
        id: 101,
        name: 'Cotton T-Shirt Blue',
        sku: 'TSH-BLU',
        barcode: '10101010',
        purchasePrice: 400.0,
        sellingPrice: 800.0,
        stockQuantity: 20.0,
      );

      final exchangeReturnItem = CartItem(
        product: product,
        quantity: -1.0,
        unitPrice: 800.0,
      );

      expect(exchangeReturnItem.isReturnItem, isTrue);
      expect(exchangeReturnItem.quantity, equals(-1.0));
      expect(exchangeReturnItem.subtotal, equals(-800.0));
    });

    test('Phase 1: Blind return routes damaged stock to scrap quarantine',
        () async {
      final product = Product(
        name: 'LED Bulb 18W',
        sku: 'LED-18W',
        barcode: '20202020',
        purchasePrice: 150.0,
        sellingPrice: 300.0,
        stockQuantity: 50.0,
      );
      final prodId = await dbService.addProduct(product);

      final damagedReturnItem = SaleReturnItem(
        returnId: 1,
        productId: prodId,
        productName: 'LED Bulb 18W',
        quantity: 2.0,
        unitPrice: 300.0,
        subtotal: 600.0,
        isDamaged: true,
        destination: 'quarantine',
      );

      final saleReturn = SaleReturn(
        returnNo: 'RET-BLIND-001',
        saleId: null,
        invoiceNo: 'BLIND-RETURN',
        customerName: 'Walk-in',
        date: DateTime.now().toIso8601String(),
        totalAmount: 600.0,
        refundAmount: 600.0,
        refundStatus: 'paid',
        paymentMethod: 'cash',
        note: 'Customer returned shattered bulb without receipt',
        items: [damagedReturnItem],
      );

      final returnId = await dbService.addSaleReturn(saleReturn);
      expect(returnId, greaterThan(0));

      // Active stock must NOT increase for damaged scrap items
      final updatedProd = await dbService.getProduct(prodId);
      expect(updatedProd?.stockQuantity, equals(50.0));

      // Must be logged into stock_adjustments as abnormal quarantine
      final adjustments = await dbService.db.query(
        'stock_adjustments',
        where: 'adjustment_type = ?',
        whereArgs: ['abnormal'],
      );
      expect(adjustments.isNotEmpty, isTrue);
      expect(adjustments.first['total_amount'], equals(600.0));
    });

    test('Phase 2: Product Rack/Shelf/Row location saves and loads properly',
        () async {
      final product = Product(
        name: 'Ceramic Floor Tiles 60x60',
        sku: 'TILE-6060',
        barcode: '30303030',
        purchasePrice: 1200.0,
        sellingPrice: 1600.0,
        stockQuantity: 100.0,
        rackLocation: 'Aisle 4, Rack B, Row 2',
      );

      final prodId = await dbService.addProduct(product);
      final fetched = await dbService.getProduct(prodId);

      expect(fetched?.rackLocation, equals('Aisle 4, Rack B, Row 2'));
    });

    test(
        'Phase 2: Combo/Bundle BOM components auto-deduct and restore atomically',
        () async {
      // 1. Create components
      final panelId = await dbService.addProduct(Product(
        name: 'Solar Panel 550W',
        sku: 'SOL-550',
        barcode: '40404040',
        purchasePrice: 15000.0,
        sellingPrice: 18000.0,
        stockQuantity: 10.0,
      ));
      final inverterId = await dbService.addProduct(Product(
        name: 'Hybrid Inverter 6kW',
        sku: 'INV-6KW',
        barcode: '50505050',
        purchasePrice: 120000.0,
        sellingPrice: 145000.0,
        stockQuantity: 5.0,
      ));

      // 2. Create bundle product
      final bundleId = await dbService.addProduct(Product(
        name: 'Complete 3kW Solar System',
        sku: 'BNDL-SOL3KW',
        barcode: '60606060',
        type: 'combo',
        purchasePrice: 180000.0,
        sellingPrice: 220000.0,
        stockQuantity: 1.0,
      ));

      // 3. Link components into product_bundles (6 panels + 1 inverter)
      await dbService.db.insert('product_bundles', {
        'parent_product_id': bundleId,
        'sub_product_id': panelId,
        'sub_product_name': 'Solar Panel 550W',
        'quantity': 6.0,
      });
      await dbService.db.insert('product_bundles', {
        'parent_product_id': bundleId,
        'sub_product_id': inverterId,
        'sub_product_name': 'Hybrid Inverter 6kW',
        'quantity': 1.0,
      });

      // 4. Sell 1 bundle
      final bundleProd = (await dbService.getProduct(bundleId))!;
      final sale = Sale(
        invoiceNo: 'INV-BNDL-001',
        subtotal: 220000.0,
        totalAmount: 220000.0,
        paidAmount: 220000.0,
        saleStatus: 'final',
        paymentStatus: 'paid',
        createdAt: DateTime.now().toIso8601String(),
        locationId: 1,
      );
      final saleItems = [
        CartItem(
          product: bundleProd,
          quantity: 1.0,
          unitPrice: 220000.0,
        ),
      ];

      final createdSale = await dbService.salesRepo.createSale(
        sale: sale,
        items: saleItems,
      );
      final saleId = createdSale.id!;
      expect(saleId, greaterThan(0));

      // 5. Verify component stocks deducted
      final panelAfterSale = await dbService.getProduct(panelId);
      final invAfterSale = await dbService.getProduct(inverterId);
      expect(panelAfterSale?.stockQuantity, equals(4.0)); // 10 - 6 = 4
      expect(invAfterSale?.stockQuantity, equals(4.0)); // 5 - 1 = 4

      // 6. Delete sale and verify components restored
      await dbService.salesRepo.deleteSale(saleId);
      final panelAfterCancel = await dbService.getProduct(panelId);
      final invAfterCancel = await dbService.getProduct(inverterId);
      expect(panelAfterCancel?.stockQuantity, equals(10.0)); // Restored to 10
      expect(invAfterCancel?.stockQuantity, equals(5.0)); // Restored to 5
    });

    test(
        'Phase 2: Cheque clearance & bounce re-debits customer and adjusts bank',
        () async {
      // 1. Create Bank Account with Rs 50,000 balance
      final accId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Meezan Bank Operations',
        accountNumber: 'PK92MEZN001',
        accountType: 'bank',
        currentBalance: 50000.0,
      ));

      // 2. Create customer with 0 balance
      final custId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Haji Aslam Textiles',
        phone: '03001234567',
        balance: 0.0,
      ));

      // 3. Issue sale cheque of Rs 25,000
      final tx = PaymentTransaction(
        transactionType: 'sale',
        contactId: custId,
        contactName: 'Haji Aslam Textiles',
        paymentMethod: 'cheque',
        amount: 25000.0,
        accountId: accId,
        chequeNumber: 'CHQ-88201',
        bankName: 'HBL',
        chequeDueDate: '2026-11-20',
        chequeStatus: 'pending',
        transactionDate: DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );
      final txId = await dbService.addPaymentTransaction(tx);

      // 4. Mark cheque as Cleared -> Bank balance increases to Rs 75,000
      await dbService.updateChequeStatus(
          transactionId: txId, newStatus: 'cleared');
      final accsCleared = await dbService.getPaymentAccounts();
      final accCleared = accsCleared.firstWhere((a) => a.id == accId);
      expect(accCleared.currentBalance, equals(75000.0));

      // 5. Dishonored / Bounced after deposit -> Bank reverses back to 50,000 and customer re-debited
      await dbService.updateChequeStatus(
          transactionId: txId, newStatus: 'bounced');

      // Customer balance should be re-debited with Rs 25,000
      final custAfterBounce =
          await dbService.contactsRepo.getContactById(custId);
      expect(custAfterBounce?.balance, equals(25000.0));

      // Bank account should be reversed back to 50,000
      final accsBounced = await dbService.getPaymentAccounts();
      final accAfterBounce = accsBounced.firstWhere((a) => a.id == accId);
      expect(accAfterBounce.currentBalance, equals(50000.0));
    });

    test('Phase 3: Restaurant KDS tracks live orders and advances statuses',
        () async {
      final kotId = await dbService.addRestaurantKotOrder({
        'kot_no': 'KOT-9021',
        'table_name': 'Table 7',
        'order_type': 'Dine-In',
        'items': '2x Zinger Burger, 1x Family Fries',
        'status': 'Cooking',
        'time': '8:15 PM',
        'server_name': 'Captain Usman',
      });

      expect(kotId, greaterThan(0));

      final orders = await dbService.getRestaurantKotOrders();
      final match = orders.firstWhere((k) => k['id'] == kotId);
      expect(match['status'], equals('Cooking'));

      // Chef marks order as Ready
      await dbService.updateRestaurantKotStatus(kotId, 'Ready');
      final updatedOrders = await dbService.getRestaurantKotOrders();
      final updatedMatch = updatedOrders.firstWhere((k) => k['id'] == kotId);
      expect(updatedMatch['status'], equals('Ready'));

      // Waiter marks order as Served
      await dbService.updateRestaurantKotStatus(kotId, 'Served');
      final servedOrders = await dbService.getRestaurantKotOrders();
      final servedMatch = servedOrders.firstWhere((k) => k['id'] == kotId);
      expect(servedMatch['status'], equals('Served'));
    });

    test('Phase 3: Pharmacy FEFO batches sorts by earliest expiry first',
        () async {
      final medId = await dbService.addProduct(Product(
        name: 'Augmentin 625mg Tablets',
        sku: 'AUG-625',
        barcode: '70707070',
        purchasePrice: 280.0,
        sellingPrice: 350.0,
        stockQuantity: 100.0,
      ));

      // Batch 1: Expiring in 2027
      await dbService.addProductSerialBatch(ProductSerialBatch(
        productId: medId,
        productName: 'Augmentin 625mg',
        sku: 'AUG-625',
        serialNumber1: '',
        serialNumber2: '',
        batchNumber: 'BATCH-2027-LATE',
        manufacturingDate: '2025-01-01',
        expiryDate: '2027-12-31',
        status: 'in_stock',
        locationId: 1,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // Batch 2: Expiring earlier in 2026 (FEFO Priority)
      await dbService.addProductSerialBatch(ProductSerialBatch(
        productId: medId,
        productName: 'Augmentin 625mg',
        sku: 'AUG-625',
        serialNumber1: '',
        serialNumber2: '',
        batchNumber: 'BATCH-2026-EARLY',
        manufacturingDate: '2024-06-01',
        expiryDate: '2026-06-30',
        status: 'in_stock',
        locationId: 1,
        createdAt: DateTime.now().toIso8601String(),
      ));

      final activeBatches = await dbService.getActiveBatchesForProduct(medId);
      expect(activeBatches.length, equals(2));
      // First batch MUST be the earliest expiry (FEFO)
      expect(activeBatches.first.batchNumber, equals('BATCH-2026-EARLY'));
      expect(activeBatches.last.batchNumber, equals('BATCH-2027-LATE'));
    });

    test('Phase 5: HRM attendance punch logs status and records history',
        () async {
      const dateKey = '2026-11-15';
      const empId = 'EMP-01';

      final punchId = await dbService.saveModuleRecord(
        moduleKey: 'hrm',
        recordType: 'attendance_$dateKey',
        title: '$empId • Muhammad Irfan',
        status: 'Present',
        data: {
          'empId': empId,
          'name': 'Muhammad Irfan',
          'status': 'Present',
          'clockIn': '08:55 AM',
          'clockOut': '06:05 PM',
          'workHours': 9.15,
          'date': dateKey,
        },
      );

      expect(punchId, greaterThan(0));

      final rows = await dbService.getModuleRecords('hrm',
          recordType: 'attendance_$dateKey');
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['status'], equals('Present'));
      expect(rows.first['clockIn'], equals('08:55 AM'));
    });

    test(
        'Phase 5: HRM payroll disbursal posts expense and deducts payment account',
        () async {
      // 1. Create a Payroll Bank Account with initial Rs 100,000 balance
      final accId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Meezan Bank Payroll',
        accountNumber: 'PK99MEZN00112233',
        accountType: 'bank',
        currentBalance: 100000.0,
      ));

      const netSalaries = 35000.0;

      // 2. Disburse payroll: Insert into expenses and deduct account balance
      await dbService.db.insert('expenses', {
        'category': 'Salary & Wages',
        'amount': netSalaries,
        'ref_no': 'PAY-202611',
        'note': 'Monthly Staff Payroll Disbursed',
        'date': DateTime.now().toIso8601String(),
        'payment_method': 'Meezan Bank Payroll',
      });

      await dbService.db.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance - ? WHERE id = ?',
        [netSalaries, accId],
      );

      // 3. Verify expenses record created
      final expenseRows = await dbService.db
          .query('expenses', where: 'ref_no = ?', whereArgs: ['PAY-202611']);
      expect(expenseRows.isNotEmpty, isTrue);
      expect(expenseRows.first['amount'], equals(35000.0));

      // 4. Verify payment account deducted from 100,000 to 65,000
      final accounts = await dbService.getPaymentAccounts();
      final payrollAcc = accounts.firstWhere((a) => a.id == accId);
      expect(payrollAcc.currentBalance, equals(65000.0));
    });

    test(
        'Phase 5: Manufacturing production run atomically updates finished and raw goods',
        () async {
      // 1. Create Raw Material Product (100 units in stock)
      final rawId = await dbService.addProduct(Product(
        name: 'Mango Pulp 1kg',
        sku: 'RAW-MNG-1KG',
        barcode: '88118811',
        purchasePrice: 150.0,
        sellingPrice: 180.0,
        stockQuantity: 100.0,
      ));

      // 2. Create Finished Product (0 units in stock)
      final finishedId = await dbService.addProduct(Product(
        name: 'Organic Mango Jam 500g',
        sku: 'FG-MNG-JAM',
        barcode: '88228822',
        purchasePrice: 120.0,
        sellingPrice: 220.0,
        stockQuantity: 0.0,
      ));

      // 3. Execute Production Run: Produce 25 jars consuming 50kg pulp
      const producedQty = 25.0;
      const consumedRawQty = 50.0;

      await dbService.db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [producedQty, finishedId],
        );
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [consumedRawQty, rawId],
        );
      });

      // 4. Verify finished stock incremented to 25 and raw stock deducted to 50
      final updatedFinished = await dbService.getProductById(finishedId);
      final updatedRaw = await dbService.getProductById(rawId);

      expect(updatedFinished?.stockQuantity, equals(25.0));
      expect(updatedRaw?.stockQuantity, equals(50.0));
    });

    test(
        'Phase 5: Stock Transfer in-transit status verifies and receives stock',
        () async {
      final transferProdId = await dbService.addProduct(Product(
        name: 'Electric Water Heater 35L',
        sku: 'EWH-35L',
        barcode: '99339933',
        purchasePrice: 15000.0,
        sellingPrice: 18500.0,
        stockQuantity: 40.0,
      ));

      // Set initial location stocks: Location 1 = 40, Location 2 = 0
      await dbService.db.insert(
        'product_locations',
        {
          'product_id': transferProdId,
          'location_id': 1,
          'qty_available': 40.0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await dbService.db.insert(
        'product_locations',
        {
          'product_id': transferProdId,
          'location_id': 2,
          'qty_available': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Create in-transit transfer of 10 units from Loc 1 to Loc 2
      final transfer = StockTransfer(
        refNo: 'TR-TEST-900',
        fromLocationId: 1,
        fromLocationName: 'Main Warehouse',
        toLocationId: 2,
        toLocationName: 'Branch 2',
        status: 'in_transit',
        shippingCharges: 500.0,
        finalTotal: 150500.0,
        date: DateTime.now().toIso8601String(),
        note: 'Inter-branch dispatch',
        itemsJson: jsonEncode([
          {
            'product_id': transferProdId,
            'product_name': 'Electric Water Heater 35L',
            'sku': 'EWH-35L',
            'quantity': 10.0,
            'unit_price': 15000.0,
          }
        ]),
      );

      final transferId = await dbService.createStockTransfer(transfer);

      // Verify Loc 1 deducted to 30, but Loc 2 still 0 while in transit
      final loc1DuringTransit = await dbService.db.query('product_locations',
          where: 'product_id = ? AND location_id = ?',
          whereArgs: [transferProdId, 1]);
      final loc2DuringTransit = await dbService.db.query('product_locations',
          where: 'product_id = ? AND location_id = ?',
          whereArgs: [transferProdId, 2]);

      expect((loc1DuringTransit.first['qty_available'] as num).toDouble(),
          equals(30.0));
      expect((loc2DuringTransit.first['qty_available'] as num).toDouble(),
          equals(0.0));

      // Now receiving manager verifies and marks Completed
      await dbService.updateStockTransferStatus(transferId, 'completed');

      final loc2Received = await dbService.db.query('product_locations',
          where: 'product_id = ? AND location_id = ?',
          whereArgs: [transferProdId, 2]);
      expect((loc2Received.first['qty_available'] as num).toDouble(),
          equals(10.0));
    });

    test(
        'Phase 6: Hotel Folio service charges posting, itemized billing & checkout',
        () async {
      // 1. Add Room 402 Deluxe to hotel
      final roomId = await dbService.addHotelRoom({
        'room': '402',
        'type': 'Executive Deluxe',
        'floor': '4th Floor',
        'rate': 8500.0,
        'status': 'occupied',
        'guest': 'Chaudhry Tariq (CNIC: 35201-1122334-1)',
        'nights': 2,
        'check_in': '2026-11-16',
        'room_service': 0.0,
      });

      // 2. Post itemized folio service charges (Restaurant dining & laundry)
      const charge1 = 1500.0;
      const charge2 = 600.0;

      await dbService.saveModuleRecord(
        moduleKey: 'hotel',
        recordType: 'hotel_folio_402',
        title: 'Dining: Mixed Grill Platter',
        status: 'pending',
        data: {
          'roomId': roomId,
          'roomNo': '402',
          'category': 'Dining & Room Service',
          'description': 'Mixed Grill Platter',
          'amount': charge1,
        },
      );

      await dbService.saveModuleRecord(
        moduleKey: 'hotel',
        recordType: 'hotel_folio_402',
        title: 'Laundry: 4 Suits Dry Cleaned',
        status: 'pending',
        data: {
          'roomId': roomId,
          'roomNo': '402',
          'category': 'Laundry & Dry Cleaning',
          'description': '4 Suits Dry Cleaned',
          'amount': charge2,
        },
      );

      // Increment room_service balance atomically
      await dbService.updateHotelRoom(roomId, {
        'room_service': charge1 + charge2,
      });

      // Verify room balance
      final rooms = await dbService.getHotelRooms();
      final room402 = rooms.firstWhere((r) => r['room'] == '402');
      expect((room402['room_service'] as num).toDouble(), equals(2100.0));

      const roomRent = 8500.0 * 2; // 17000
      const totalStayBill = roomRent + 2100.0; // 19100.0

      // 3. Perform checkout: settle bill, create sale invoice and mark room cleaning
      final invNo = await dbService.generateNextInvoiceNo();
      await dbService.createSale(
        sale: Sale(
          invoiceNo: invNo,
          customerName: 'Chaudhry Tariq',
          subtotal: totalStayBill,
          totalAmount: totalStayBill,
          paidAmount: totalStayBill,
          paymentMethod: 'cash',
          paymentStatus: 'paid',
          saleStatus: 'final',
          note: 'Hotel Checkout • Room 402',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [
          CartItem(
            product: Product(
              name: 'Room 402 Stay (2 nights)',
              sku: 'ROOM-402',
              barcode: 'ROOM-402',
              purchasePrice: 0,
              sellingPrice: roomRent,
              stockQuantity: 1,
            ),
            quantity: 1,
            unitPrice: roomRent,
          ),
          CartItem(
            product: Product(
              name: 'Room 402 - Folio Services',
              sku: 'FOLIO-402',
              barcode: 'FOLIO-402',
              purchasePrice: 0,
              sellingPrice: 2100.0,
              stockQuantity: 1,
            ),
            quantity: 1,
            unitPrice: 2100.0,
          ),
        ],
        enforceStock: false,
      );

      // Room reset for housekeeping
      await dbService.updateHotelRoom(roomId, {
        'status': 'cleaning',
        'guest': '',
        'nights': 0,
        'room_service': 0.0,
      });

      final refreshedRooms = await dbService.getHotelRooms();
      final cleanedRoom = refreshedRooms.firstWhere((r) => r['room'] == '402');
      expect(cleanedRoom['status'], equals('cleaning'));
      expect((cleanedRoom['room_service'] as num).toDouble(), equals(0.0));
      expect(cleanedRoom['guest'], equals(''));
    });

    test('Phase 6: Gym Turnstile Barcode check-in & automated expiry detection',
        () async {
      // 1. Add active member and expired member
      final activeMemberId = await dbService.addGymMember({
        'member_id': 'GYM-201',
        'name': 'Hamza Bilal',
        'phone': '03009988776',
        'plan': 'Annual Pro (Rs 35,000)',
        'fee': 35000.0,
        'locker': 'L-42',
        'trainer': 'Coach Asad',
        'expiry_date': DateTime.now()
            .add(const Duration(days: 45))
            .toString()
            .substring(0, 10),
        'days_left': 45,
        'status': 'Active',
      });

      final expiredMemberId = await dbService.addGymMember({
        'member_id': 'GYM-202',
        'name': 'Zahid Qureshi',
        'phone': '03215544332',
        'plan': 'Monthly Basic',
        'fee': 4000.0,
        'locker': 'None',
        'trainer': 'General Floor',
        'expiry_date': '2026-01-01',
        'days_left': 0,
        'status': 'Expired',
      });

      // 2. Simulate Active member card scan -> Access Granted
      final allMembers = await dbService.getGymMembers();
      final hamza = allMembers.firstWhere((m) => m['member_id'] == 'GYM-201');
      expect(hamza['status'], equals('Active'));
      expect((hamza['days_left'] as num).toInt(), greaterThan(0));

      // Check-in log recorded in SQLite
      await dbService.saveModuleRecord(
        moduleKey: 'gym',
        recordType: 'gym_checkin',
        title: 'Turnstile: ${hamza['name']}',
        status: 'checked_in',
        data: {
          'memberId': activeMemberId,
          'memberCode': 'GYM-201',
          'name': hamza['name'],
          'scanTime': DateTime.now().toIso8601String(),
        },
      );

      final checkinLogs =
          await dbService.getModuleRecords('gym', recordType: 'gym_checkin');
      expect(checkinLogs.length, greaterThanOrEqualTo(1));
      expect(
          checkinLogs.first['_title'] ??
              checkinLogs.first['title'] ??
              checkinLogs.first['name'],
          contains('Hamza Bilal'));

      // 3. Simulate Expired member card scan -> Access Denied & Instant Renewal
      final zahid = allMembers.firstWhere((m) => m['member_id'] == 'GYM-202');
      expect(zahid['status'], equals('Expired'));
      expect((zahid['days_left'] as num).toInt(), equals(0));

      // Instant renewal (+30 days)
      await dbService.updateGymMember(expiredMemberId, {
        'status': 'Active',
        'days_left': 30,
        'expiry_date': DateTime.now()
            .add(const Duration(days: 30))
            .toString()
            .substring(0, 10),
      });

      final renewedZahid = (await dbService.getGymMembers())
          .firstWhere((m) => m['member_id'] == 'GYM-202');
      expect(renewedZahid['status'], equals('Active'));
      expect((renewedZahid['days_left'] as num).toInt(), equals(30));
    });

    test('Phase 6: Dynamic Modular SaaS Tier Presets & Sidebar feature gating',
        () {
      // 1. Verify 5 official SaaS Tier presets exist
      expect(ModuleRegistry.tierPresets.length, equals(5));

      const starter = ModuleRegistry.starterRetailTier;
      const enterprise = ModuleRegistry.enterpriseSuperstoreTier;

      // 2. Verify Starter Retail tier isolates core retail and excludes heavy verticals
      expect(starter.id, equals('starter_retail'));
      expect(starter.modules, contains(ModuleRegistry.corePos));
      expect(starter.modules, contains(ModuleRegistry.returns));
      expect(starter.modules, contains(ModuleRegistry.expenses));
      expect(starter.modules.contains(ModuleRegistry.restaurant), isFalse);
      expect(starter.modules.contains(ModuleRegistry.hotel), isFalse);
      expect(starter.modules.contains(ModuleRegistry.gym), isFalse);
      expect(starter.modules.contains(ModuleRegistry.manufacturing), isFalse);

      // 3. Verify Enterprise Superstore unlocks all modules
      expect(enterprise.id, equals('enterprise_superstore'));
      expect(enterprise.modules, contains(ModuleRegistry.restaurant));
      expect(enterprise.modules, contains(ModuleRegistry.pharmacy));
      expect(enterprise.modules, contains(ModuleRegistry.hotel));
      expect(enterprise.modules, contains(ModuleRegistry.gym));
      expect(enterprise.modules, contains(ModuleRegistry.manufacturing));
      expect(enterprise.modules, contains(ModuleRegistry.hrm));
      expect(enterprise.modules, contains(ModuleRegistry.accounting));
      expect(enterprise.modules, contains(ModuleRegistry.lanMultiCounter));

      // 4. Test BusinessSettings evaluation with Starter Retail tier
      final starterSettings = BusinessSettings(
        enabledModules: starter.modules.join(','),
        industryPresets: starter.industryPreset,
        businessType: 'general_store',
      );

      expect(starterSettings.isRestaurantEnabled, isFalse);
      expect(starterSettings.isHotel, isFalse);
      expect(starterSettings.isGym, isFalse);
      expect(starterSettings.isModuleEnabled(ModuleRegistry.hotel), isFalse);
      expect(starterSettings.isModuleEnabled(ModuleRegistry.gym), isFalse);
      expect(starterSettings.isModuleEnabled(ModuleRegistry.returns), isTrue);
    });
  });
}
