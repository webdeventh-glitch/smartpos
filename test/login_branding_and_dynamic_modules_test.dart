import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Login Screen Branding & Custom Presets Tests', () {
    test('Default Pharmacy effectiveLoginBanner points to medicine agency banner', () {
      final settings = BusinessSettings(
        businessType: 'pharmacy',
      );
      expect(settings.effectiveLoginBanner, 'assets/images/medicine_agency_banner.jpg');
    });

    test('Custom loginBannerPath overrides default', () {
      final settings = BusinessSettings(
        businessType: 'supermarket',
        loginBannerPath: 'assets/images/supermarket_banner.jpg',
        loginSideTitle: 'Supermarket Wholesale Engine',
        loginSideSubtitle: 'Barcode billing with rapid checkout.',
      );
      expect(settings.effectiveLoginBanner, 'assets/images/supermarket_banner.jpg');
      expect(settings.loginSideTitle, 'Supermarket Wholesale Engine');
      expect(settings.loginSideSubtitle, 'Barcode billing with rapid checkout.');
    });

    test('Serialization toMap and fromMap preserves login banner fields', () {
      final settings = BusinessSettings(
        businessName: 'Irfan Medicen Agency',
        loginBannerPath: 'assets/images/medicine_agency_banner.jpg',
        loginSideTitle: 'Next-Generation Pharmacy Engine',
        loginSideSubtitle: 'Form 2A & 236H Tax Compliant',
      );

      final map = settings.toMap();
      expect(map['login_banner_path'], 'assets/images/medicine_agency_banner.jpg');
      expect(map['login_side_title'], 'Next-Generation Pharmacy Engine');
      expect(map['login_side_subtitle'], 'Form 2A & 236H Tax Compliant');

      final deserialized = BusinessSettings.fromMap(map);
      expect(deserialized.businessName, 'Irfan Medicen Agency');
      expect(deserialized.effectiveLoginBanner, 'assets/images/medicine_agency_banner.jpg');
      expect(deserialized.loginSideTitle, 'Next-Generation Pharmacy Engine');
      expect(deserialized.loginSideSubtitle, 'Form 2A & 236H Tax Compliant');
    });
  });

  group('Dynamic Industry Modules Database Persistence Tests', () {
    late DatabaseService dbService;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pos_dynamic_test_');
      final dbPath = p.join(tempDir.path, 'dynamic_test.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('Gym Members SQLite CRUD is 100% dynamic', () async {
      final initialMembers = await dbService.getGymMembers();
      expect(initialMembers.isNotEmpty, true, reason: 'Should have initial seed rows');

      // Add a dynamic member
      final newMemberId = await dbService.addGymMember({
        'member_id': 'GYM-999',
        'name': 'Babar Azam',
        'phone': '+92 300 9998877',
        'plan': 'Pro Athlete Annual',
        'fee': 45000.0,
        'locker': 'L-99',
        'trainer': 'Olympic Coach',
        'expiry_date': '2027-10-22',
        'days_left': 365,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(newMemberId, isNonZero);

      // Verify member is stored in SQLite
      final updatedList = await dbService.getGymMembers();
      final added = updatedList.firstWhere((m) => m['name'] == 'Babar Azam');
      expect(added['member_id'], 'GYM-999');
      expect(added['plan'], 'Pro Athlete Annual');

      // Update member status
      await dbService.updateGymMember(newMemberId, {'status': 'Expiring Soon', 'days_left': 3});
      final refreshed = await dbService.getGymMembers();
      final updatedMember = refreshed.firstWhere((m) => m['name'] == 'Babar Azam');
      expect(updatedMember['status'], 'Expiring Soon');
      expect(updatedMember['days_left'], 3);

      // Delete member
      await dbService.deleteGymMember(newMemberId);
      final afterDelete = await dbService.getGymMembers();
      expect(afterDelete.any((m) => m['name'] == 'Babar Azam'), false);
    });

    test('Hotel Rooms SQLite CRUD is 100% dynamic', () async {
      final initialRooms = await dbService.getHotelRooms();
      expect(initialRooms.isNotEmpty, true);

      // Check-in guest to Room 102
      final room102 = initialRooms.firstWhere((r) => r['room'] == '102');
      final roomId = room102['id'] as int;

      await dbService.updateHotelRoom(roomId, {
        'status': 'occupied',
        'guest': 'Imran Khan (Guest VIP)',
        'nights': 3,
        'check_in': '22 Oct',
        'room_service': 2500.0,
      });

      final occupiedRooms = await dbService.getHotelRooms(status: 'occupied');
      expect(occupiedRooms.any((r) => r['room'] == '102'), true);

      // Check-out
      await dbService.updateHotelRoom(roomId, {
        'status': 'cleaning',
        'guest': '',
        'nights': 0,
        'room_service': 0.0,
      });

      final cleaningRooms = await dbService.getHotelRooms(status: 'cleaning');
      expect(cleaningRooms.any((r) => r['room'] == '102'), true);
    });

    test('Repair Jobs SQLite CRUD is 100% dynamic', () async {
      final initialJobs = await dbService.getRepairJobs();
      expect(initialJobs.isNotEmpty, true);

      // Create new repair ticket
      final jobId = await dbService.addRepairJob({
        'job_no': 'JOB-9999',
        'customer': 'Shahid Afridi (+92 300 1112233)',
        'device': 'MacBook Pro M3 Max 16-inch',
        'imei': 'SN: C02DF99XX',
        'fault': 'Liquid spill on trackpad & keyboard backlight failure',
        'technician': 'Senior Hardware Specialist',
        'est_cost': 45000.0,
        'advance': 15000.0,
        'status': 'Diagnosing',
        'date': '2026-10-22',
      });
      expect(jobId, isNonZero);

      // Mark Delivered
      await dbService.updateRepairJob(jobId, {'status': 'Delivered'});
      final deliveredJobs = await dbService.getRepairJobs(status: 'Delivered');
      expect(deliveredJobs.any((j) => j['job_no'] == 'JOB-9999'), true);
    });

    test('Sync Queue handles outbox push queueing', () async {
      final initialPending = await dbService.getPendingSyncCount();

      final queueId = await dbService.queueSyncItem(
        entityType: 'product',
        entityId: '501',
        action: 'create',
        payload: {'name': 'Panadol 500mg', 'sku': 'MED-501', 'price': 35.0},
      );
      expect(queueId, isNonZero);

      final countAfter = await dbService.getPendingSyncCount();
      expect(countAfter, initialPending + 1);

      final items = await dbService.getPendingSyncItems();
      expect(items.any((i) => i['id'] == queueId), true);

      // Mark done
      await dbService.markSyncItemsDone([queueId]);
      final countFinal = await dbService.getPendingSyncCount();
      expect(countFinal, initialPending);
    });

    test('Restaurant Tables & KOT SQLite CRUD is 100% dynamic', () async {
      final initialTables = await dbService.getRestaurantTables();
      expect(initialTables.isNotEmpty, true, reason: 'Initial dining tables seeded');

      // Add a dynamic dining table
      final newTableId = await dbService.addRestaurantTable({
        'name': 'Rooftop VIP Gazebo',
        'section': 'Sky Lounge',
        'capacity': 8,
        'status': 'vacant',
        'order_total': 0.0,
        'kot_time': '',
        'guests': 0,
      });
      expect(newTableId, isNonZero);

      // Verify table is saved
      final tablesAfter = await dbService.getRestaurantTables();
      final addedTable = tablesAfter.firstWhere((t) => t['name'] == 'Rooftop VIP Gazebo');
      expect(addedTable['capacity'], 8);
      expect(addedTable['section'], 'Sky Lounge');

      // Update table to occupied
      await dbService.updateRestaurantTable(newTableId, {
        'status': 'occupied',
        'order_total': 5400.0,
        'guests': 6,
        'kot_time': 'Just now',
      });
      final tablesOccupied = await dbService.getRestaurantTables();
      final updated = tablesOccupied.firstWhere((t) => t['name'] == 'Rooftop VIP Gazebo');
      expect(updated['status'], 'occupied');
      expect(updated['order_total'], 5400.0);

      // KOT order CRUD
      final kotId = await dbService.addRestaurantKotOrder({
        'kot_no': 'KOT-999',
        'table_name': 'Rooftop VIP Gazebo',
        'order_type': 'Dine-In',
        'items': '2x Chicken Karahi, 6x Roghani Naan, 2x Mint Margarita',
        'status': 'Cooking',
        'time': '8:30 PM',
      });
      expect(kotId, isNonZero);

      await dbService.updateRestaurantKotStatus(kotId, 'Ready to Serve');
      final kotOrders = await dbService.getRestaurantKotOrders();
      final updatedKot = kotOrders.firstWhere((k) => k['kot_no'] == 'KOT-999');
      expect(updatedKot['status'], 'Ready to Serve');
    });

    test('Modular Initial Seeder strictly seeds Restaurant data for Restaurant business', () async {
      final resSummary = await dbService.seedInitialDataForBusinessType(businessType: 'restaurant');
      expect(resSummary['products']! > 0, true, reason: 'Menu dishes must be seeded');
      expect(resSummary['categories']! > 0, true, reason: 'Restaurant food categories must be seeded');

      final products = await dbService.getProducts();
      expect(products.any((p) => p.name.contains('Zinger') || p.name.contains('Karahi')), true);
    });

    test('Modular Initial Seeder strictly seeds Supermarket data for Supermarket business', () async {
      final smSummary = await dbService.seedInitialDataForBusinessType(businessType: 'supermarket');
      expect(smSummary['products']! > 0, true, reason: 'FMCG items must be seeded');

      final products = await dbService.getProducts();
      expect(products.any((p) => p.name.contains('Tea') || p.name.contains('Cooking Oil')), true);
    });
  });
}
