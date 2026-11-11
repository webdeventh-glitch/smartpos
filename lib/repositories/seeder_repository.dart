import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import '../services/app_logger.dart';
import '../services/auth_service.dart';
import '../services/database_encryption_service.dart';
import '../services/database_schema.dart';
import '../services/database_service.dart';
import 'base_repository.dart';

/// Manages industry-specific catalog seeding, bulk demo fixtures, benchmarking, and factory reset.
class SeederRepository extends BaseRepository {
  const SeederRepository([super.dbService]);

  // ===================== MODULAR INITIAL DATA SEEDER BY BUSINESS TYPE =====================

  /// Modular Initial Catalog Seeder based strictly on chosen business type
  Future<Map<String, int>> seedInitialDataForBusinessType({
    required String businessType,
    int? pharmacyProductTarget,
  }) async {
    final type = businessType.toLowerCase().trim();
    if (type == 'pharmacy') {
      if (pharmacyProductTarget != null && pharmacyProductTarget > 50) {
        return await seedMedicineAgencyData(
          productTarget: pharmacyProductTarget,
          customerTarget: 1500,
          supplierTarget: 100,
          salesmanTarget: 15,
        );
      }

      final stopwatch = Stopwatch()..start();
      int productsCount = 0;
      int categoriesCount = 0;
      int contactsCount = 0;

      await db.transaction((txn) async {
        final pharmaCategories = [
          'Antibiotics & Anti-Infectives',
          'Analgesics & Pain Relief',
          'Antipyretics & Cold Preparations',
          'Cardiovascular & Neuro',
          'Gastrointestinal & Antiulcerants',
          'Vitamins & Nutraceuticals',
        ];

        for (final cat in pharmaCategories) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          categoriesCount++;
        }

        final pharmaProducts = [
          {
            'name': 'Panadol 500mg Tab',
            'sku': 'MED-001',
            'barcode': '890103000001',
            'category_name': 'Antipyretics & Cold Preparations',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Box (200s)',
            'purchase_price': 498.0,
            'selling_price': 597.6,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'image_color': '#10B981',
            'batch_number': 'BAT-2025-101',
            'expiry_date': '02-2026',
            'bonus_qty': 0.0,
            'pack_size': 200.0,
          },
          {
            'name': 'Amoxil 500mg Cap',
            'sku': 'MED-002',
            'barcode': '890103000002',
            'category_name': 'Antibiotics & Anti-Infectives',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Box (100s)',
            'purchase_price': 740.0,
            'selling_price': 890.0,
            'stock_quantity': 40.0,
            'alert_quantity': 10.0,
            'image_color': '#3B82F6',
            'batch_number': 'BAT-2025-102',
            'expiry_date': '04-2026',
            'bonus_qty': 0.0,
            'pack_size': 100.0,
          },
          {
            'name': 'Brufen 400mg Tab',
            'sku': 'MED-003',
            'barcode': '890103000003',
            'category_name': 'Analgesics & Pain Relief',
            'brand_name': 'Abbott Laboratories',
            'unit': 'Box (300s)',
            'purchase_price': 1100.0,
            'selling_price': 1320.0,
            'stock_quantity': 35.0,
            'alert_quantity': 10.0,
            'image_color': '#F59E0B',
            'batch_number': 'BRU-9901',
            'expiry_date': '06-2026',
            'bonus_qty': 0.0,
            'pack_size': 300.0,
          },
          {
            'name': 'Augmentin 625mg Tab',
            'sku': 'MED-004',
            'barcode': '890103000004',
            'category_name': 'Antibiotics & Anti-Infectives',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Pack (14s)',
            'purchase_price': 380.0,
            'selling_price': 460.0,
            'stock_quantity': 60.0,
            'alert_quantity': 15.0,
            'image_color': '#6366F1',
            'batch_number': 'AUG-4421',
            'expiry_date': '12-2027',
            'bonus_qty': 0.0,
            'pack_size': 14.0,
          },
          {
            'name': 'Risek 20mg Cap',
            'sku': 'MED-005',
            'barcode': '890103000005',
            'category_name': 'Gastrointestinal & Antiulcerants',
            'brand_name': 'Getz Pharma',
            'unit': 'Pack (14s)',
            'purchase_price': 320.0,
            'selling_price': 390.0,
            'stock_quantity': 45.0,
            'alert_quantity': 10.0,
            'image_color': '#059669',
            'batch_number': 'RSK-3110',
            'expiry_date': '11-2027',
            'bonus_qty': 0.0,
            'pack_size': 14.0,
          },
          {
            'name': 'Disprin 300mg Soluble Tab',
            'sku': 'MED-006',
            'barcode': '890103000006',
            'category_name': 'Analgesics & Pain Relief',
            'brand_name': 'Reckitt',
            'unit': 'Box (100s)',
            'purchase_price': 180.0,
            'selling_price': 220.0,
            'stock_quantity': 80.0,
            'alert_quantity': 20.0,
            'image_color': '#DC2626',
            'batch_number': 'DSP-1029',
            'expiry_date': '01-2028',
            'bonus_qty': 0.0,
            'pack_size': 100.0,
          },
          {
            'name': 'Arinac Forte Tab',
            'sku': 'MED-007',
            'barcode': '890103000007',
            'category_name': 'Antipyretics & Cold Preparations',
            'brand_name': 'Abbott Laboratories',
            'unit': 'Box (100s)',
            'purchase_price': 720.0,
            'selling_price': 865.0,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'image_color': '#D97706',
            'batch_number': 'ARN-7890',
            'expiry_date': '08-2027',
            'bonus_qty': 0.0,
            'pack_size': 100.0,
          },
          {
            'name': 'Softin 10mg Tab',
            'sku': 'MED-008',
            'barcode': '890103000008',
            'category_name': 'Cardiovascular & Neuro',
            'brand_name': 'Searle Pakistan',
            'unit': 'Pack (10s)',
            'purchase_price': 150.0,
            'selling_price': 190.0,
            'stock_quantity': 55.0,
            'alert_quantity': 10.0,
            'image_color': '#2563EB',
            'batch_number': 'SFT-2291',
            'expiry_date': '03-2028',
            'bonus_qty': 0.0,
            'pack_size': 10.0,
          },
          {
            'name': 'Surbex Z Zinc Multivitamin',
            'sku': 'MED-009',
            'barcode': '890103000009',
            'category_name': 'Vitamins & Nutraceuticals',
            'brand_name': 'Abbott Laboratories',
            'unit': 'Bottle (30s)',
            'purchase_price': 390.0,
            'selling_price': 475.0,
            'stock_quantity': 40.0,
            'alert_quantity': 8.0,
            'image_color': '#7C3AED',
            'batch_number': 'SBX-8812',
            'expiry_date': '05-2028',
            'bonus_qty': 0.0,
            'pack_size': 30.0,
          },
          {
            'name': 'Polyfax Skin Ointment 20g',
            'sku': 'MED-010',
            'barcode': '890103000010',
            'category_name': 'Antibiotics & Anti-Infectives',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Tube',
            'purchase_price': 75.0,
            'selling_price': 95.0,
            'stock_quantity': 65.0,
            'alert_quantity': 12.0,
            'image_color': '#0D9488',
            'batch_number': 'PFX-5543',
            'expiry_date': '09-2027',
            'bonus_qty': 0.0,
            'pack_size': 1.0,
          },
        ];

        for (final p in pharmaProducts) {
          await txn.insert('products', p, conflictAlgorithm: ConflictAlgorithm.replace);
          productsCount++;
        }

        final pharmaContacts = [
          {'name': 'GSK Distribution Hub', 'phone': '+92 300 1110001', 'type': 'supplier'},
          {'name': 'Abbott Wholesale Depot', 'phone': '+92 300 2220002', 'type': 'supplier'},
          {'name': 'Getz Pharma Agency', 'phone': '+92 300 3330003', 'type': 'supplier'},
          {'name': 'Al-Shafa Hospital Pharmacy', 'phone': '+92 300 4440004', 'type': 'customer'},
          {'name': 'Care Chemist & Clinic', 'phone': '+92 300 5550005', 'type': 'customer'},
        ];

        for (final c in pharmaContacts) {
          await txn.insert('contacts', {
            'name': c['name'],
            'phone': c['phone'],
            'type': c['type'],
            'balance': 0.0,
            'credit_limit': 100000.0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          contactsCount++;
        }
      });

      stopwatch.stop();
      return {
        'products': productsCount,
        'categories': categoriesCount,
        'contacts': contactsCount,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      };
    }

    final stopwatch = Stopwatch()..start();
    int productsCount = 0;
    int categoriesCount = 0;
    int contactsCount = 0;

    await db.transaction((txn) async {
      if (type == 'restaurant' || type == 'cafe') {
        final restaurantCategories = [
          'Appetizers & Starters',
          'Fast Food & Burgers',
          'Pizzas & Pastas',
          'Desi Karahi & BBQ',
          'Continental & Steaks',
          'Beverages & Mocktails',
          'Desserts & Sweets',
        ];

        for (final cat in restaurantCategories) {
          final code = cat.length >= 3 ? cat.substring(0, 3).toUpperCase() : cat.toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Menu Section',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final menuItems = [
          {'name': 'Crispy Zinger Burger', 'cat': 'Fast Food & Burgers', 'unit': 'Pc', 'cost': 320.0, 'sale': 550.0, 'sku': 'BUR-001'},
          {'name': 'Beef Gourmet Cheeseburger', 'cat': 'Fast Food & Burgers', 'unit': 'Pc', 'cost': 420.0, 'sale': 690.0, 'sku': 'BUR-002'},
          {'name': 'Chicken Karahi Special Full', 'cat': 'Desi Karahi & BBQ', 'unit': 'Kg', 'cost': 1100.0, 'sale': 1850.0, 'sku': 'KRH-001'},
          {'name': 'Chicken Karahi Special Half', 'cat': 'Desi Karahi & BBQ', 'unit': 'Half', 'cost': 600.0, 'sale': 990.0, 'sku': 'KRH-002'},
          {'name': 'Chicken Malai Boti (8 Pcs)', 'cat': 'Desi Karahi & BBQ', 'unit': 'Plate', 'cost': 300.0, 'sale': 520.0, 'sku': 'BBQ-001'},
          {'name': 'Beef Seekh Kabab (4 Pcs)', 'cat': 'Desi Karahi & BBQ', 'unit': 'Plate', 'cost': 280.0, 'sale': 480.0, 'sku': 'BBQ-002'},
          {'name': 'Chicken Tikka Boti', 'cat': 'Desi Karahi & BBQ', 'unit': 'Plate', 'cost': 240.0, 'sale': 420.0, 'sku': 'BBQ-003'},
          {'name': 'Fajita Passion Pizza Large 13"', 'cat': 'Pizzas & Pastas', 'unit': 'Pc', 'cost': 850.0, 'sale': 1650.0, 'sku': 'PIZ-001'},
          {'name': 'Chicken Alfredo Fettuccine', 'cat': 'Pizzas & Pastas', 'unit': 'Plate', 'cost': 480.0, 'sale': 890.0, 'sku': 'PAS-001'},
          {'name': 'Club Sandwich with Fries', 'cat': 'Fast Food & Burgers', 'unit': 'Pc', 'cost': 340.0, 'sale': 620.0, 'sku': 'SND-001'},
          {'name': 'Grilled Chicken Steak (Mushroom Sauce)', 'cat': 'Continental & Steaks', 'unit': 'Plate', 'cost': 780.0, 'sale': 1450.0, 'sku': 'STK-001'},
          {'name': 'Crispy Chicken Wings (6 Pcs)', 'cat': 'Appetizers & Starters', 'unit': 'Plate', 'cost': 240.0, 'sale': 450.0, 'sku': 'APP-001'},
          {'name': 'Mint Margarita Cooler', 'cat': 'Beverages & Mocktails', 'unit': 'Glass', 'cost': 85.0, 'sale': 280.0, 'sku': 'BEV-001'},
          {'name': 'Fresh Lime Soda', 'cat': 'Beverages & Mocktails', 'unit': 'Glass', 'cost': 50.0, 'sale': 180.0, 'sku': 'BEV-002'},
          {'name': 'Hot Cappuccino', 'cat': 'Beverages & Mocktails', 'unit': 'Cup', 'cost': 110.0, 'sale': 350.0, 'sku': 'BEV-003'},
          {'name': 'Molten Lava Cake with Ice Cream', 'cat': 'Desserts & Sweets', 'unit': 'Plate', 'cost': 220.0, 'sale': 550.0, 'sku': 'DES-001'},
          {'name': 'Roghani Naan', 'cat': 'Desi Karahi & BBQ', 'unit': 'Pc', 'cost': 25.0, 'sale': 60.0, 'sku': 'NAN-001'},
          {'name': 'Mineral Water 1.5L', 'cat': 'Beverages & Mocktails', 'unit': 'Bottle', 'cost': 70.0, 'sale': 120.0, 'sku': 'BEV-004'},
        ];

        for (final m in menuItems) {
          await txn.insert('products', {
            'name': m['name'] as String,
            'sku': m['sku'] as String,
            'barcode': m['sku'] as String,
            'category_name': m['cat'] as String,
            'unit': m['unit'] as String,
            'brand_name': 'In-House Kitchen',
            'purchase_price': m['cost'] as double,
            'selling_price': m['sale'] as double,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        // Seed 8 Restaurant Dining Tables
        final initialTables = [
          {'name': 'Table 1', 'section': 'Main Dining', 'capacity': 4, 'status': 'occupied', 'order_total': 2450.0, 'kot_time': '15 mins ago', 'guests': 3},
          {'name': 'Table 2', 'section': 'Main Dining', 'capacity': 2, 'status': 'vacant', 'order_total': 0.0, 'kot_time': '', 'guests': 0},
          {'name': 'Table 3', 'section': 'Main Dining', 'capacity': 4, 'status': 'billed', 'order_total': 4100.0, 'kot_time': '35 mins ago', 'guests': 4},
          {'name': 'Table 4', 'section': 'Main Dining', 'capacity': 6, 'status': 'occupied', 'order_total': 6850.0, 'kot_time': '8 mins ago', 'guests': 5},
          {'name': 'Lounge VIP 1', 'section': 'VIP Family Hall', 'capacity': 8, 'status': 'occupied', 'order_total': 12400.0, 'kot_time': '22 mins ago', 'guests': 7},
          {'name': 'Lounge VIP 2', 'section': 'VIP Family Hall', 'capacity': 10, 'status': 'vacant', 'order_total': 0.0, 'kot_time': '', 'guests': 0},
          {'name': 'Terrace T-1', 'section': 'Rooftop Terrace', 'capacity': 4, 'status': 'vacant', 'order_total': 0.0, 'kot_time': '', 'guests': 0},
          {'name': 'Terrace T-2', 'section': 'Rooftop Terrace', 'capacity': 4, 'status': 'occupied', 'order_total': 3200.0, 'kot_time': '5 mins ago', 'guests': 2},
        ];
        for (final t in initialTables) {
          await txn.insert('restaurant_tables', t);
        }

        // Seed 4 Restaurant Testing KOT Tickets
        try {
          final initialKot = [
            {'kot_no': 'KOT-1048', 'table_name': 'Table 1', 'order_type': 'Dine-In', 'items': '1x Chicken Karahi, 4x Naan, 2x Mint Margarita', 'status': 'Cooking', 'time': '7:42 PM', 'server_name': 'Captain Ali'},
            {'kot_no': 'KOT-1049', 'table_name': 'Lounge VIP 1', 'order_type': 'Dine-In', 'items': '2x Mutton Handi, 1x Biryani Special, 8x Roti, 1x Salad', 'status': 'Ready to Serve', 'time': '7:48 PM', 'server_name': 'Waiter Bilal'},
            {'kot_no': 'KOT-1050', 'table_name': 'Counter 2', 'order_type': 'Takeaway', 'items': '3x Zinger Burgers, 2x Jumbo Fries, 3x Drinks', 'status': 'Preparing', 'time': '7:55 PM', 'server_name': 'Cashier 1'},
            {'kot_no': 'KOT-1051', 'table_name': 'Online Rider', 'order_type': 'Delivery', 'items': '1x Large Pizza, 10x Wings, 1x Garlic Dip', 'status': 'Dispatched', 'time': '7:30 PM', 'server_name': 'Delivery Dispatcher'},
          ];
          for (final k in initialKot) {
            try {
              await txn.insert('restaurant_kot_orders', k);
            } catch (e, st) {
              AppLogger.warning('DatabaseService', 'Failed inserting restaurant KOT seed', e, st);
            }
          }
        } catch (e, st) {
          AppLogger.warning('DatabaseService', 'Failed seeding restaurant KOT orders', e, st);
        }

        final restaurantSuppliers = [
          {'name': 'Al-Madina Meat & Poultry Supplier', 'phone': '+92 300 1112233', 'type': 'supplier'},
          {'name': 'Fresh Farm Dairy & Cheese Co.', 'phone': '+92 321 4445566', 'type': 'supplier'},
          {'name': 'Metro Cash & Carry (Raw Ingredients)', 'phone': '+92 333 7778899', 'type': 'supplier'},
          {'name': 'Walk-in Table Diner', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final c in restaurantSuppliers) {
          await txn.insert('contacts', {
            'type': c['type'],
            'name': c['name'],
            'phone': c['phone'],
            'balance': 0.0,
            'credit_limit': 100000.0,
          });
          contactsCount++;
        }
      } else if (type == 'supermarket') {
        final supermarketCats = [
          'Beverages & Soft Drinks',
          'Snacks, Confectionery & Biscuits',
          'Dairy, Eggs & Bakery',
          'Grains, Flour & Cooking Essentials',
          'Household Cleaning & Personal Care',
        ];
        for (final cat in supermarketCats) {
          final code = cat.length >= 3 ? cat.substring(0, 3).toUpperCase() : cat.toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat FMCG Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final supermarketItems = [
          {'name': 'Tapal Danedar Tea 400g', 'cat': 'Beverages & Soft Drinks', 'brand': 'Tapal', 'unit': 'Pack', 'cost': 540.0, 'sale': 620.0, 'sku': '8961011001'},
          {'name': 'Dalda Cooking Oil 1 Litre', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'Dalda', 'unit': 'Pouch', 'cost': 480.0, 'sale': 540.0, 'sku': '8961011002'},
          {'name': 'Olpers Milk 1000ml Tetra Pack', 'cat': 'Dairy, Eggs & Bakery', 'brand': 'Engro', 'unit': 'Pack', 'cost': 245.0, 'sale': 280.0, 'sku': '8961011003'},
          {'name': 'Lipton Yellow Label Tea 380g', 'cat': 'Beverages & Soft Drinks', 'brand': 'Unilever', 'unit': 'Pack', 'cost': 510.0, 'sale': 590.0, 'sku': '8961011004'},
          {'name': 'Super Basmati Kernel Rice 5kg', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'Guard', 'unit': 'Bag', 'cost': 1550.0, 'sale': 1850.0, 'sku': '8961011005'},
          {'name': 'National Tomato Ketchup 800g Pouch', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'National', 'unit': 'Pouch', 'cost': 340.0, 'sale': 410.0, 'sku': '8961011006'},
          {'name': 'Shan Bombay Biryani Masala 50g', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'Shan', 'unit': 'Box', 'cost': 90.0, 'sale': 110.0, 'sku': '8961011007'},
          {'name': 'Pepsi 1.5 Litre Bottle', 'cat': 'Beverages & Soft Drinks', 'brand': 'PepsiCo', 'unit': 'Bottle', 'cost': 145.0, 'sale': 180.0, 'sku': '8961011008'},
          {'name': 'Coca-Cola 1.5 Litre Bottle', 'cat': 'Beverages & Soft Drinks', 'brand': 'Coca-Cola', 'unit': 'Bottle', 'cost': 145.0, 'sale': 180.0, 'sku': '8961011009'},
          {'name': 'Lays Masala Chips Large 65g', 'cat': 'Snacks, Confectionery & Biscuits', 'brand': 'Lays', 'unit': 'Pack', 'cost': 55.0, 'sale': 70.0, 'sku': '8961011010'},
          {'name': 'Head & Shoulders Shampoo 360ml', 'cat': 'Household Cleaning & Personal Care', 'brand': 'P&G', 'unit': 'Bottle', 'cost': 560.0, 'sale': 680.0, 'sku': '8961011011'},
          {'name': 'Surf Excel Detergent Powder 1kg', 'cat': 'Household Cleaning & Personal Care', 'brand': 'Unilever', 'unit': 'Pack', 'cost': 430.0, 'sale': 520.0, 'sku': '8961011012'},
          {'name': 'Dettol Original Soap 125g Pack of 3', 'cat': 'Household Cleaning & Personal Care', 'brand': 'Reckitt', 'unit': 'Pack', 'cost': 310.0, 'sale': 380.0, 'sku': '8961011013'},
        ];

        for (final item in supermarketItems) {
          await txn.insert('products', {
            'name': item['name'] as String,
            'sku': item['sku'] as String,
            'barcode': item['sku'] as String,
            'category_name': item['cat'] as String,
            'brand_name': item['brand'] as String,
            'unit': item['unit'] as String,
            'purchase_price': item['cost'] as double,
            'selling_price': item['sale'] as double,
            'stock_quantity': 100.0,
            'alert_quantity': 20.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final supermarketVendors = [
          {'name': 'Unilever Pakistan Distribution Network', 'phone': '+92 21 111 222 333', 'type': 'supplier'},
          {'name': 'Nestle Pakistan Wholesale', 'phone': '+92 42 111 637 853', 'type': 'supplier'},
          {'name': 'PepsiCo Beverages Regional Hub', 'phone': '+92 51 444 5555', 'type': 'supplier'},
          {'name': 'General Walk-in Shopper', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final v in supermarketVendors) {
          await txn.insert('contacts', {
            'type': v['type'],
            'name': v['name'],
            'phone': v['phone'],
            'balance': 0.0,
            'credit_limit': 500000.0,
          });
          contactsCount++;
        }
      } else if (type == 'repair' || type == 'service') {
        final repairCats = [
          'Mobile Diagnostics & Parts',
          'Laptop & Motherboard Chip-Level',
          'Electronics & Gaming Consoles',
          'Software, OS & Data Recovery',
        ];
        for (final cat in repairCats) {
          await txn.insert('categories', {
            'name': cat,
            'code': cat.substring(0, 3).toUpperCase(),
            'description': '$cat Service Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final repairParts = [
          {'name': 'Samsung Super AMOLED Display Panel', 'sku': 'REP-DISP-01', 'cat': 'Mobile Diagnostics & Parts', 'cost': 12000.0, 'sale': 18500.0},
          {'name': '5000mAh Lithium Polymer Battery Pack', 'sku': 'REP-BATT-02', 'cat': 'Mobile Diagnostics & Parts', 'cost': 1800.0, 'sale': 3500.0},
          {'name': 'Laptop Type-C Power IC & Charging MOSFET', 'sku': 'REP-CHG-03', 'cat': 'Laptop & Motherboard Chip-Level', 'cost': 1500.0, 'sale': 4500.0},
          {'name': 'NVMe M.2 512GB High-Speed SSD', 'sku': 'REP-SSD-04', 'cat': 'Laptop & Motherboard Chip-Level', 'cost': 5500.0, 'sale': 8000.0},
          {'name': 'CPU & GPU Arctic Thermal Paste Overhaul Service', 'sku': 'REP-SRV-05', 'cat': 'Laptop & Motherboard Chip-Level', 'cost': 300.0, 'sale': 1500.0},
        ];
        for (final rp in repairParts) {
          await txn.insert('products', {
            'name': rp['name'] as String,
            'sku': rp['sku'] as String,
            'barcode': rp['sku'] as String,
            'category_name': rp['cat'] as String,
            'brand_name': 'Original Replacement',
            'unit': 'Pc',
            'purchase_price': rp['cost'] as double,
            'selling_price': rp['sale'] as double,
            'stock_quantity': 25.0,
            'alert_quantity': 5.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        // Seed 2 Sample Repair Diagnostic Jobs
        final sampleJobs = [
          {
            'job_no': 'JOB-9021',
            'customer': 'Asad Mehmood (+92 301 5551234)',
            'device': 'Samsung Galaxy S22 Ultra',
            'imei': '352948109283741',
            'fault': 'Cracked AMOLED screen replacement & battery overhaul',
            'technician': 'Kashif Ali',
            'est_cost': 24500.0,
            'advance': 5000.0,
            'status': 'Diagnosing',
            'date': '21 Oct 2026',
          },
          {
            'job_no': 'JOB-9022',
            'customer': 'Zeeshan Tariq (+92 333 4448899)',
            'device': 'Dell Latitude 5420 Laptop',
            'imei': 'SN: 8F2K9M2',
            'fault': 'Motherboard charging IC short, no power turning on',
            'technician': 'Farhan Tech',
            'est_cost': 8500.0,
            'advance': 2000.0,
            'status': 'Waiting for Parts',
            'date': '20 Oct 2026',
          },
        ];
        for (final j in sampleJobs) {
          await txn.insert('repair_jobs', j);
        }

        final repairContacts = [
          {'name': 'Metro Mobile Spare Parts Wholesale', 'phone': '+92 300 8881122', 'type': 'supplier'},
          {'name': 'Laptop Chipsets & Component Importers', 'phone': '+92 321 7773344', 'type': 'supplier'},
          {'name': 'Walk-in Repair Client', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final rc in repairContacts) {
          await txn.insert('contacts', {
            'type': rc['type'],
            'name': rc['name'],
            'phone': rc['phone'],
            'balance': 0.0,
            'credit_limit': 100000.0,
          });
          contactsCount++;
        }
      } else if (type == 'hotel') {
        // Hotel Rooms Inventory
        final sampleRooms = [
          {'room': '101', 'type': 'Standard Single', 'floor': '1st Floor', 'rate': 4500.0, 'status': 'occupied', 'guest': 'Hamza Ali (CNIC: 35201-1234567-1)', 'nights': 2, 'check_in': '20 Oct', 'room_service': 1200.0},
          {'room': '102', 'type': 'Standard Double', 'floor': '1st Floor', 'rate': 6500.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '103', 'type': 'Executive Deluxe', 'floor': '1st Floor', 'rate': 9500.0, 'status': 'occupied', 'guest': 'Dr. Sajjad Malik', 'nights': 3, 'check_in': '19 Oct', 'room_service': 3450.0},
          {'room': '104', 'type': 'Executive Deluxe', 'floor': '1st Floor', 'rate': 9500.0, 'status': 'cleaning', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '201', 'type': 'Presidential Suite', 'floor': '2nd Floor', 'rate': 18000.0, 'status': 'occupied', 'guest': 'Mr. & Mrs. Mansoor', 'nights': 1, 'check_in': '21 Oct', 'room_service': 2800.0},
          {'room': '202', 'type': 'Standard Double', 'floor': '2nd Floor', 'rate': 6500.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '203', 'type': 'Family 2-Bedroom', 'floor': '2nd Floor', 'rate': 12000.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '204', 'type': 'Standard Single', 'floor': '2nd Floor', 'rate': 4500.0, 'status': 'occupied', 'guest': 'Tariq Jameel', 'nights': 2, 'check_in': '20 Oct', 'room_service': 450.0},
        ];
        for (final r in sampleRooms) {
          await txn.insert('hotel_rooms', r);
        }

        final hotelServices = [
          {'name': 'Continental Breakfast Platter', 'sku': 'HTL-BKT-01', 'cost': 350.0, 'sale': 850.0},
          {'name': 'Executive Laundry & Dry Clean Service', 'sku': 'HTL-LND-02', 'cost': 150.0, 'sale': 450.0},
          {'name': 'Airport VIP Shuttle Dispatch', 'sku': 'HTL-SHT-03', 'cost': 800.0, 'sale': 2500.0},
        ];
        for (final hs in hotelServices) {
          await txn.insert('products', {
            'name': hs['name'] as String,
            'sku': hs['sku'] as String,
            'barcode': hs['sku'] as String,
            'category_name': 'Room Service & Hospitality',
            'brand_name': 'Hotel In-House',
            'unit': 'Service',
            'purchase_price': hs['cost'] as double,
            'selling_price': hs['sale'] as double,
            'stock_quantity': 100.0,
            'alert_quantity': 5.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }
      } else if (type == 'gym') {
        // Seed Gym Members
        final sampleGymMembers = [
          {
            'member_id': 'GYM-101',
            'name': 'Ali Raza',
            'phone': '+92 300 1234567',
            'plan': 'Gold Membership (Annual)',
            'fee': 35000.0,
            'locker': 'L-14',
            'trainer': 'Coach Bilal (Bodybuilding)',
            'expiry_date': '15 Dec 2026',
            'days_left': 55,
            'status': 'Active',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'member_id': 'GYM-102',
            'name': 'Usman Shahid',
            'phone': '+92 321 8882233',
            'plan': 'Silver Plan (Monthly)',
            'fee': 4000.0,
            'locker': 'L-08',
            'trainer': 'General Floor',
            'expiry_date': '23 Oct 2026',
            'days_left': 2,
            'status': 'Expiring Soon',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'member_id': 'GYM-103',
            'name': 'Faisal Qureshi',
            'phone': '+92 333 5556677',
            'plan': 'Quarterly Plan (3-Months)',
            'fee': 10500.0,
            'locker': 'L-22',
            'trainer': 'Coach Rehan (Crossfit)',
            'expiry_date': '10 Oct 2026',
            'days_left': -11,
            'status': 'Expired',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'member_id': 'GYM-104',
            'name': 'Kamran Akmal',
            'phone': '+92 312 4443322',
            'plan': 'Personal Training Pro',
            'fee': 18000.0,
            'locker': 'L-02',
            'trainer': 'Master Coach Tariq',
            'expiry_date': '05 Nov 2026',
            'days_left': 15,
            'status': 'Active',
            'created_at': DateTime.now().toIso8601String(),
          },
        ];
        for (final gm in sampleGymMembers) {
          await txn.insert('gym_members', gm);
        }

        final gymProducts = [
          {'name': 'Whey Protein Isolate 2kg Chocolate', 'sku': 'GYM-PROT-01', 'cost': 12000.0, 'sale': 16500.0},
          {'name': 'Pre-Workout Energy Booster 30 Servings', 'sku': 'GYM-PRE-02', 'cost': 4500.0, 'sale': 6800.0},
          {'name': 'BCAA Hydration Electrolytes 400g', 'sku': 'GYM-BCAA-03', 'cost': 3200.0, 'sale': 4900.0},
          {'name': 'Stainless Steel Shaker Bottle 700ml', 'sku': 'GYM-SHK-04', 'cost': 850.0, 'sale': 1500.0},
        ];
        for (final gp in gymProducts) {
          await txn.insert('products', {
            'name': gp['name'] as String,
            'sku': gp['sku'] as String,
            'barcode': gp['sku'] as String,
            'category_name': 'Fitness Supplements & Nutrition',
            'brand_name': 'Optimum Performance',
            'unit': 'Tub',
            'purchase_price': gp['cost'] as double,
            'selling_price': gp['sale'] as double,
            'stock_quantity': 20.0,
            'alert_quantity': 4.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }
      } else if (type == 'mobile' || type == 'electronics') {
        final mobileCats = [
          'Smartphones & Flagships',
          'Tablets & iPads',
          'Audio & TWS Earbuds',
          'Fast Chargers & Cables',
          'Protective Glass & Covers',
        ];
        for (final cat in mobileCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final mobileProducts = [
          {'name': 'Apple iPhone 15 Pro Max 256GB', 'cat': 'Smartphones & Flagships', 'brand': 'Apple', 'unit': 'Unit', 'cost': 385000.0, 'sale': 425000.0, 'sku': 'IPH-15PM-256', 'barcode': '195949012345'},
          {'name': 'Samsung Galaxy S24 Ultra 512GB', 'cat': 'Smartphones & Flagships', 'brand': 'Samsung', 'unit': 'Unit', 'cost': 350000.0, 'sale': 389000.0, 'sku': 'SAM-S24U-512', 'barcode': '880609501234'},
          {'name': 'Xiaomi Redmi Note 13 8GB/256GB', 'cat': 'Smartphones & Flagships', 'brand': 'Xiaomi', 'unit': 'Unit', 'cost': 48000.0, 'sale': 54999.0, 'sku': 'RED-N13-256', 'barcode': '694181270123'},
          {'name': 'Apple AirPods Pro (2nd Gen) USB-C', 'cat': 'Audio & TWS Earbuds', 'brand': 'Apple', 'unit': 'Box', 'cost': 62000.0, 'sale': 72000.0, 'sku': 'APP-AIRPOD-P2', 'barcode': '195949567890'},
          {'name': 'Anker 65W GaN III Fast Charger', 'cat': 'Fast Chargers & Cables', 'brand': 'Anker', 'unit': 'Pc', 'cost': 8500.0, 'sale': 11500.0, 'sku': 'ANK-65W-GAN', 'barcode': '084806101234'},
          {'name': 'Baseus 100W PD Type-C Fast Cable', 'cat': 'Fast Chargers & Cables', 'brand': 'Baseus', 'unit': 'Pc', 'cost': 1200.0, 'sale': 2200.0, 'sku': 'BAS-TC-100W', 'barcode': '695315620123'},
        ];

        int iphoneId = 0;
        int samsungId = 0;

        for (final mp in mobileProducts) {
          final pid = await txn.insert('products', {
            'name': mp['name'] as String,
            'sku': mp['sku'] as String,
            'barcode': mp['barcode'] as String,
            'category_name': mp['cat'] as String,
            'brand_name': mp['brand'] as String,
            'unit': mp['unit'] as String,
            'purchase_price': mp['cost'] as double,
            'selling_price': mp['sale'] as double,
            'stock_quantity': 15.0,
            'alert_quantity': 3.0,
            'pack_size': 1.0,
          });
          productsCount++;
          if (mp['sku'] == 'IPH-15PM-256') iphoneId = pid;
          if (mp['sku'] == 'SAM-S24U-512') samsungId = pid;
        }

        // Seed sample IMEI tracking records in product_serials_batches
        if (iphoneId > 0) {
          await txn.insert('product_serials_batches', {
            'product_id': iphoneId,
            'product_name': 'Apple iPhone 15 Pro Max 256GB',
            'sku': 'IPH-15PM-256',
            'serial_number_1': '352948109283741',
            'serial_number_2': '352948109283742',
            'warranty_months': 12,
            'warranty_expiry_date': '2027-10-23',
            'status': 'in_stock',
            'purchase_price': 385000.0,
            'selling_price': 425000.0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        if (samsungId > 0) {
          await txn.insert('product_serials_batches', {
            'product_id': samsungId,
            'product_name': 'Samsung Galaxy S24 Ultra 512GB',
            'sku': 'SAM-S24U-512',
            'serial_number_1': '867302058192019',
            'serial_number_2': '867302058192020',
            'warranty_months': 12,
            'warranty_expiry_date': '2027-10-23',
            'status': 'in_stock',
            'purchase_price': 350000.0,
            'selling_price': 389000.0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        final mobileVendors = [
          {'name': 'Airlink Communication Official Dist.', 'phone': '+92 42 111 247 546', 'type': 'supplier'},
          {'name': 'CoreCell Telecom Importers', 'phone': '+92 21 358 1111', 'type': 'supplier'},
          {'name': 'Walk-in Mobile Customer', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final v in mobileVendors) {
          await txn.insert('contacts', {
            'type': v['type'],
            'name': v['name'],
            'phone': v['phone'],
            'balance': 0.0,
            'credit_limit': 1000000.0,
          });
          contactsCount++;
        }
      } else if (type == 'solar' || type == 'solar_hardware') {
        final solarCats = [
          'Tier-1 Solar Panels',
          'Solar Hybrid Inverters',
          'Deep Cycle Batteries',
          'DC Breakers & Protection',
          'Solar Cables & Connectors',
          'Complete Solar Bundles',
        ];
        for (final cat in solarCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final solarProducts = [
          {'name': 'Longi Hi-MO 6 585W Mono Perc Panel', 'cat': 'Tier-1 Solar Panels', 'brand': 'Longi', 'unit': 'Panel', 'cost': 18500.0, 'sale': 22500.0, 'sku': 'SOL-LONGI-585', 'barcode': 'SOL585001'},
          {'name': 'Canadian Solar 550W TopCon Bifacial', 'cat': 'Tier-1 Solar Panels', 'brand': 'Canadian Solar', 'unit': 'Panel', 'cost': 17200.0, 'sale': 21000.0, 'sku': 'SOL-CAN-550', 'barcode': 'SOL550002'},
          {'name': 'Inverex Nitrox 6kW Hybrid IP65 Inverter', 'cat': 'Solar Hybrid Inverters', 'brand': 'Inverex', 'unit': 'Unit', 'cost': 265000.0, 'sale': 295000.0, 'sku': 'INV-NITROX-6K', 'barcode': 'INV600001'},
          {'name': 'Knox Krypton 3.2kW Solar Inverter', 'cat': 'Solar Hybrid Inverters', 'brand': 'Knox', 'unit': 'Unit', 'cost': 110000.0, 'sale': 125000.0, 'sku': 'INV-KNOX-32K', 'barcode': 'INV320002'},
          {'name': 'Phoenix TX-1800 Tall Tubular Battery', 'cat': 'Deep Cycle Batteries', 'brand': 'Phoenix', 'unit': 'Unit', 'cost': 45000.0, 'sale': 53000.0, 'sku': 'BAT-PHOENIX-1800', 'barcode': 'BAT180001'},
          {'name': 'Narada 48V 100Ah Lithium LiFePO4', 'cat': 'Deep Cycle Batteries', 'brand': 'Narada', 'unit': 'Unit', 'cost': 320000.0, 'sale': 365000.0, 'sku': 'BAT-NARADA-LFP', 'barcode': 'BAT4810002'},
          {'name': 'Pakistan Cables 6mm Pure Copper DC Cable', 'cat': 'Solar Cables & Connectors', 'brand': 'Pakistan Cables', 'unit': 'Meter', 'cost': 280.0, 'sale': 360.0, 'sku': 'CBL-SOLAR-6MM', 'barcode': 'CBL6MM001'},
          {'name': 'MC4 Solar Connectors Male/Female Pair', 'cat': 'Solar Cables & Connectors', 'brand': 'Staubli', 'unit': 'Pair', 'cost': 120.0, 'sale': 250.0, 'sku': 'ACC-MC4-PAIR', 'barcode': 'MC4000001'},
          {'name': '6kW Complete Net-Metering Solar Package', 'cat': 'Complete Solar Bundles', 'brand': 'Smart POS Solar', 'unit': 'Package', 'cost': 650000.0, 'sale': 780000.0, 'sku': 'BND-SOLAR-6KW', 'barcode': 'BND6KW001'},
        ];

        int panelId = 0;
        int inverterId = 0;
        int batteryId = 0;
        int bundleId = 0;

        for (final sp in solarProducts) {
          final pid = await txn.insert('products', {
            'name': sp['name'] as String,
            'sku': sp['sku'] as String,
            'barcode': sp['barcode'] as String,
            'category_name': sp['cat'] as String,
            'brand_name': sp['brand'] as String,
            'unit': sp['unit'] as String,
            'purchase_price': sp['cost'] as double,
            'selling_price': sp['sale'] as double,
            'stock_quantity': 25.0,
            'alert_quantity': 5.0,
            'pack_size': 1.0,
          });
          productsCount++;
          if (sp['sku'] == 'SOL-LONGI-585') panelId = pid;
          if (sp['sku'] == 'INV-NITROX-6K') inverterId = pid;
          if (sp['sku'] == 'BAT-PHOENIX-1800') batteryId = pid;
          if (sp['sku'] == 'BND-SOLAR-6KW') bundleId = pid;
        }

        // Seed bundle bill-of-materials in product_bundles
        if (bundleId > 0 && panelId > 0) {
          await txn.insert('product_bundles', {
            'parent_product_id': bundleId,
            'sub_product_id': panelId,
            'sub_product_name': 'Longi Hi-MO 6 585W Mono Perc Panel',
            'sub_sku': 'SOL-LONGI-585',
            'quantity': 10.0,
            'unit_price': 18500.0,
          });
        }
        if (bundleId > 0 && inverterId > 0) {
          await txn.insert('product_bundles', {
            'parent_product_id': bundleId,
            'sub_product_id': inverterId,
            'sub_product_name': 'Inverex Nitrox 6kW Hybrid IP65 Inverter',
            'sub_sku': 'INV-NITROX-6K',
            'quantity': 1.0,
            'unit_price': 265000.0,
          });
        }
        if (bundleId > 0 && batteryId > 0) {
          await txn.insert('product_bundles', {
            'parent_product_id': bundleId,
            'sub_product_id': batteryId,
            'sub_product_name': 'Phoenix TX-1800 Tall Tubular Battery',
            'sub_sku': 'BAT-PHOENIX-1800',
            'quantity': 4.0,
            'unit_price': 45000.0,
          });
        }

        final solarVendors = [
          {'name': 'Inverex Solar Power Systems HQ', 'phone': '+92 21 111 468 373', 'type': 'supplier'},
          {'name': 'Longi Solar Pakistan Central Warehouse', 'phone': '+92 42 357 8888', 'type': 'supplier'},
          {'name': 'Green Energy Solutions EPC Contractor', 'phone': '+92 300 5558899', 'type': 'customer'},
        ];
        for (final sv in solarVendors) {
          await txn.insert('contacts', {
            'type': sv['type'],
            'name': sv['name'],
            'phone': sv['phone'],
            'balance': 0.0,
            'credit_limit': 2000000.0,
          });
          contactsCount++;
        }
      } else if (type == 'dairy_milk' || type == 'dairy') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Liters', 'Ltr', allowDecimal: 1);
        await seedUnit('Kilograms', 'Kg', allowDecimal: 1);
        await seedUnit('Dozen', 'Dzn', allowDecimal: 0);
        await seedUnit('Half Liter', 'Half Ltr', allowDecimal: 1, multiplier: 0.5);
        await seedUnit('Quarter / Pao (250g)', 'Pao', allowDecimal: 1, multiplier: 0.25);
        await seedUnit('Egg Crate (30 Dozen)', 'Crate', allowDecimal: 0, multiplier: 30.0);

        final dairyCats = [
          'Fresh Buffalo & Cow Milk (تازہ دودھ)',
          'Fresh Yogurt & Raita (دہی و رائتہ)',
          'Pure Butter & Desi Ghee (مکھن و دیسی گھی)',
          'Fresh Farm Eggs (انڈے فارمی و دیسی)',
          'Khoya, Paneer & Sweets (کھویا و مٹھائی)',
        ];
        for (final cat in dairyCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final dairyProducts = [
          {'name': 'Pure Buffalo Milk (تازہ بھینس کا دودھ)', 'cat': 'Fresh Buffalo & Cow Milk (تازہ دودھ)', 'unit': 'Ltr', 'cost': 180.0, 'sale': 210.0, 'sku': 'MLK-BUF-01', 'stock': 200.0},
          {'name': 'Fresh Cow Milk (گائے کا دودھ)', 'cat': 'Fresh Buffalo & Cow Milk (تازہ دودھ)', 'unit': 'Ltr', 'cost': 160.0, 'sale': 190.0, 'sku': 'MLK-COW-02', 'stock': 120.0},
          {'name': 'Fresh Sweet Yogurt (میٹھی دہی)', 'cat': 'Fresh Yogurt & Raita (دہی و رائتہ)', 'unit': 'Kg', 'cost': 210.0, 'sale': 250.0, 'sku': 'DAHI-SWT-01', 'stock': 80.0},
          {'name': 'Farm Fresh White Eggs (فارمی انڈے)', 'cat': 'Fresh Farm Eggs (انڈے فارمی و دیسی)', 'unit': 'Dzn', 'cost': 280.0, 'sale': 320.0, 'sku': 'EGG-FRM-01', 'stock': 50.0},
          {'name': 'Pure Desi Eggs (اصیل دیسی انڈے)', 'cat': 'Fresh Farm Eggs (انڈے فارمی و دیسی)', 'unit': 'Dzn', 'cost': 480.0, 'sale': 550.0, 'sku': 'EGG-DSI-02', 'stock': 30.0},
          {'name': 'Pure Desi Cow Ghee (خالص دیسی گھی)', 'cat': 'Pure Butter & Desi Ghee (مکھن و دیسی گھی)', 'unit': 'Kg', 'cost': 2200.0, 'sale': 2600.0, 'sku': 'GHEE-DSI-01', 'stock': 25.0},
          {'name': 'Fresh Khoya Peda (تازہ کھویا پیڑا)', 'cat': 'Khoya, Paneer & Sweets (کھویا و مٹھائی)', 'unit': 'Kg', 'cost': 900.0, 'sale': 1200.0, 'sku': 'KHY-PEDA-01', 'stock': 20.0},
          {'name': 'Fresh Zeera Raita (زیرہ رائتہ)', 'cat': 'Fresh Yogurt & Raita (دہی و رائتہ)', 'unit': 'Kg', 'cost': 240.0, 'sale': 300.0, 'sku': 'DAHI-RTA-02', 'stock': 15.0},
        ];
        for (final dp in dairyProducts) {
          await txn.insert('products', {
            'name': dp['name'] as String,
            'sku': dp['sku'] as String,
            'barcode': dp['sku'] as String,
            'category_name': dp['cat'] as String,
            'brand_name': 'Fresh Farm Pure',
            'unit': dp['unit'] as String,
            'purchase_price': dp['cost'] as double,
            'selling_price': dp['sale'] as double,
            'stock_quantity': dp['stock'] as double,
            'alert_quantity': 15.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final dairyContacts = [
          {'name': 'Gawala Dairy Farm Colony', 'phone': '+92 300 1234501', 'type': 'supplier'},
          {'name': 'Govt Dairy Supply Milk Depot', 'phone': '+92 300 1234502', 'type': 'supplier'},
          {'name': 'Al-Faisal Broiler & Egg Layer Farm', 'phone': '+92 300 1234503', 'type': 'supplier'},
          {'name': 'Daily Morning Milk Customer (Khata)', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final dc in dairyContacts) {
          await txn.insert('contacts', {
            'type': dc['type'],
            'name': dc['name'],
            'phone': dc['phone'],
            'balance': 0.0,
            'credit_limit': 50000.0,
          });
          contactsCount++;
        }
      } else if (type == 'tyres_battery' || type == 'tyres') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Piece', 'Pc', allowDecimal: 0);
        await seedUnit('Pair (2 Tyres)', 'Pair', allowDecimal: 0, multiplier: 2.0);
        await seedUnit('Set (4 Tyres)', 'Set', allowDecimal: 0, multiplier: 4.0);
        await seedUnit('Service Job', 'Job', allowDecimal: 0);

        final tyreCats = [
          'Passenger Car Tyres (13" to 17")',
          'SUV & Commercial 4x4 Tyres',
          'Motorcycle & Rickshaw Tyres',
          'Alloy Rims & Steel Wheels',
          'Automotive Maintenance-Free Batteries',
          'Wheel Alignment & Balancing Services',
        ];
        for (final cat in tyreCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final tyreProducts = [
          {'name': 'Yokohama BlueEarth 195/65 R15 (Japan)', 'cat': 'Passenger Car Tyres (13" to 17")', 'brand': 'Yokohama', 'unit': 'Pc', 'cost': 18500.0, 'sale': 22000.0, 'sku': 'TYR-YOKO-19565'},
          {'name': 'Bridgestone Ecopia 205/55 R16', 'cat': 'Passenger Car Tyres (13" to 17")', 'brand': 'Bridgestone', 'unit': 'Pc', 'cost': 24000.0, 'sale': 28500.0, 'sku': 'TYR-BRDG-20555'},
          {'name': 'General Euro Star 185/65 R15 (OEM)', 'cat': 'Passenger Car Tyres (13" to 17")', 'brand': 'General Tyre', 'unit': 'Pc', 'cost': 13500.0, 'sale': 16000.0, 'sku': 'TYR-GEN-18565'},
          {'name': 'Panther 100/90-18 Tubeless Bike Tyre', 'cat': 'Motorcycle & Rickshaw Tyres', 'brand': 'Panther', 'unit': 'Pc', 'cost': 5200.0, 'sale': 6500.0, 'sku': 'TYR-PANTH-100'},
          {'name': 'Phoenix TX-1000 Maintenance Free Battery', 'cat': 'Automotive Maintenance-Free Batteries', 'brand': 'Phoenix', 'unit': 'Pc', 'cost': 17500.0, 'sale': 21000.0, 'sku': 'BAT-PHX-1000'},
          {'name': 'Exide Power-100 Dry Battery 12V 85Ah', 'cat': 'Automotive Maintenance-Free Batteries', 'brand': 'Exide', 'unit': 'Pc', 'cost': 19000.0, 'sale': 22500.0, 'sku': 'BAT-EXD-100'},
          {'name': 'Computerized 3D Alignment & Wheel Balancing (Set)', 'cat': 'Wheel Alignment & Balancing Services', 'brand': 'In-House Service', 'unit': 'Job', 'cost': 500.0, 'sale': 2000.0, 'sku': 'SRV-ALIGN-3D'},
          {'name': 'Nitrogen High-Pressure Air Filling (4 Tyres)', 'cat': 'Wheel Alignment & Balancing Services', 'brand': 'In-House Service', 'unit': 'Job', 'cost': 100.0, 'sale': 500.0, 'sku': 'SRV-NITRO-4'},
        ];
        for (final tp in tyreProducts) {
          await txn.insert('products', {
            'name': tp['name'] as String,
            'sku': tp['sku'] as String,
            'barcode': tp['sku'] as String,
            'category_name': tp['cat'] as String,
            'brand_name': tp['brand'] as String,
            'unit': tp['unit'] as String,
            'purchase_price': tp['cost'] as double,
            'selling_price': tp['sale'] as double,
            'stock_quantity': 24.0,
            'alert_quantity': 4.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final tyreContacts = [
          {'name': 'Yokohama Tires Direct Importers', 'phone': '+92 21 3568001', 'type': 'supplier'},
          {'name': 'General Tyre Official Warehouse', 'phone': '+92 42 3578002', 'type': 'supplier'},
          {'name': 'Exide Battery Regional Distributor', 'phone': '+92 51 4458003', 'type': 'supplier'},
          {'name': 'City Rent-A-Car Fleet', 'phone': '+92 300 9998877', 'type': 'customer'},
        ];
        for (final tc in tyreContacts) {
          await txn.insert('contacts', {
            'type': tc['type'],
            'name': tc['name'],
            'phone': tc['phone'],
            'balance': 0.0,
            'credit_limit': 300000.0,
          });
          contactsCount++;
        }
      } else if (type == 'hardware_tools' || type == 'hardware') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Piece', 'Pc', allowDecimal: 0);
        await seedUnit('Packet', 'Pkt', allowDecimal: 0);
        await seedUnit('Bag (50kg)', 'Bag', allowDecimal: 0);
        await seedUnit('Kilograms', 'Kg', allowDecimal: 1);
        await seedUnit('Running Foot', 'Rft', allowDecimal: 1);
        await seedUnit('Meter', 'Mtr', allowDecimal: 1);
        await seedUnit('Bucket (16L)', 'Bucket', allowDecimal: 0);

        final hardwareCats = [
          'Cement & Building Materials',
          'Paints, Distemper & Weathercoat',
          'Power Tools & Hand Machinery',
          'Fasteners, Steel Nails & Screws',
          'Plumbing Pipes & Sanitary Fittings',
          'Electrical Cables & Switchboards',
        ];
        for (final cat in hardwareCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final hardwareProducts = [
          {'name': 'Bestway Cement Ordinary Portland 50kg', 'cat': 'Cement & Building Materials', 'brand': 'Bestway', 'unit': 'Bag', 'cost': 1320.0, 'sale': 1450.0, 'sku': 'CMT-BSTWY-50'},
          {'name': 'Berger Weathercoat White 16L Bucket', 'cat': 'Paints, Distemper & Weathercoat', 'brand': 'Berger', 'unit': 'Bucket', 'cost': 9500.0, 'sale': 12000.0, 'sku': 'PNT-BRG-16L'},
          {'name': 'Diamond 13mm Impact Electric Drill 750W', 'cat': 'Power Tools & Hand Machinery', 'brand': 'Diamond', 'unit': 'Pc', 'cost': 4800.0, 'sale': 6500.0, 'sku': 'TOL-DRL-13M'},
          {'name': 'Steel Concrete Nails 2.5 Inch (1kg Pack)', 'cat': 'Fasteners, Steel Nails & Screws', 'brand': 'Imported', 'unit': 'Kg', 'cost': 240.0, 'sale': 350.0, 'sku': 'FST-NAL-25'},
          {'name': 'Pakistan Cables 3/29 Pure Copper Wire Coil', 'cat': 'Electrical Cables & Switchboards', 'brand': 'Pakistan Cables', 'unit': 'Pc', 'cost': 7200.0, 'sale': 8800.0, 'sku': 'ELE-PKC-329'},
          {'name': 'PVC Water Pipe 3 Inch Class B (10 Ft Length)', 'cat': 'Plumbing Pipes & Sanitary Fittings', 'brand': 'Popular', 'unit': 'Pc', 'cost': 680.0, 'sale': 950.0, 'sku': 'PLM-PVC-3IN'},
          {'name': 'Brass Ball Valve 1/2 Inch Heavy Duty', 'cat': 'Plumbing Pipes & Sanitary Fittings', 'brand': 'Master', 'unit': 'Pc', 'cost': 350.0, 'sale': 550.0, 'sku': 'PLM-VLV-12'},
        ];
        for (final hp in hardwareProducts) {
          await txn.insert('products', {
            'name': hp['name'] as String,
            'sku': hp['sku'] as String,
            'barcode': hp['sku'] as String,
            'category_name': hp['cat'] as String,
            'brand_name': hp['brand'] as String,
            'unit': hp['unit'] as String,
            'purchase_price': hp['cost'] as double,
            'selling_price': hp['sale'] as double,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final hardwareContacts = [
          {'name': 'Bestway Cement Factory Depot', 'phone': '+92 51 2233441', 'type': 'supplier'},
          {'name': 'Berger Paints Pakistan Regional Hub', 'phone': '+92 42 3556677', 'type': 'supplier'},
          {'name': 'Ali Raza Building Contractor', 'phone': '+92 300 8887766', 'type': 'customer'},
          {'name': 'Malik Electric & Hardware Store', 'phone': '+92 321 4443322', 'type': 'customer'},
        ];
        for (final hc in hardwareContacts) {
          await txn.insert('contacts', {
            'type': hc['type'],
            'name': hc['name'],
            'phone': hc['phone'],
            'balance': 0.0,
            'credit_limit': 500000.0,
          });
          contactsCount++;
        }
      } else if (type == 'auto_parts') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Piece', 'Pc', allowDecimal: 0);
        await seedUnit('Set', 'Set', allowDecimal: 0);
        await seedUnit('Pair', 'Pair', allowDecimal: 0, multiplier: 2.0);
        await seedUnit('Kit', 'Kit', allowDecimal: 0);
        await seedUnit('Pack', 'Pack', allowDecimal: 0);

        final autoCats = [
          'Brake System & Brake Pads',
          'Suspension, Shocks & Ball Joints',
          'Engine Parts, Belts & Plugs',
          'Filters & Air Intake Systems',
          'Headlights, Indicators & Body Parts',
          'Clutch & Transmission Components',
        ];
        for (final cat in autoCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final autoProducts = [
          {'name': 'Toyota Genuine Brake Pads Front (Corolla 2014-2022)', 'cat': 'Brake System & Brake Pads', 'brand': 'Toyota Genuine', 'unit': 'Set', 'cost': 6500.0, 'sale': 8500.0, 'sku': '04465-02220'},
          {'name': 'NGK Iridium Spark Plug (Set of 4 Pcs)', 'cat': 'Engine Parts, Belts & Plugs', 'brand': 'NGK', 'unit': 'Set', 'cost': 3800.0, 'sale': 5200.0, 'sku': 'NGK-BKR6E-4'},
          {'name': '555 Japan Lower Ball Joint Pair (Civic Rebirth)', 'cat': 'Suspension, Shocks & Ball Joints', 'brand': '555 Japan', 'unit': 'Pair', 'cost': 4500.0, 'sale': 6200.0, 'sku': '555-SB-6202'},
          {'name': 'Denso Engine Air Filter (Honda City 1.3/1.5)', 'cat': 'Filters & Air Intake Systems', 'brand': 'Denso', 'unit': 'Pc', 'cost': 1100.0, 'sale': 1700.0, 'sku': '17220-RB6-000'},
          {'name': 'Aisin Japan Clutch Plate & Pressure Plate Kit', 'cat': 'Clutch & Transmission Components', 'brand': 'Aisin', 'unit': 'Kit', 'cost': 14500.0, 'sale': 18500.0, 'sku': 'KT-AISIN-01'},
          {'name': 'Bando Japan V-Ribbed Alternator Fan Belt 4PK', 'cat': 'Engine Parts, Belts & Plugs', 'brand': 'Bando', 'unit': 'Pc', 'cost': 1200.0, 'sale': 1800.0, 'sku': '4PK-850-BND'},
          {'name': 'Depo Crystal Headlight Lamp RH (Mehran Euro-II)', 'cat': 'Headlights, Indicators & Body Parts', 'brand': 'Depo', 'unit': 'Pc', 'cost': 2800.0, 'sale': 3900.0, 'sku': 'HL-MHR-DEP'},
        ];
        for (final ap in autoProducts) {
          await txn.insert('products', {
            'name': ap['name'] as String,
            'sku': ap['sku'] as String,
            'barcode': ap['sku'] as String,
            'category_name': ap['cat'] as String,
            'brand_name': ap['brand'] as String,
            'unit': ap['unit'] as String,
            'purchase_price': ap['cost'] as double,
            'selling_price': ap['sale'] as double,
            'stock_quantity': 30.0,
            'alert_quantity': 5.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final autoContacts = [
          {'name': 'Plaza Auto Parts Wholesale Karachi', 'phone': '+92 21 3272001', 'type': 'supplier'},
          {'name': 'Badami Bagh Auto Parts Traders Lahore', 'phone': '+92 42 3765002', 'type': 'supplier'},
          {'name': 'Master Usman Auto Mechanic Workshop', 'phone': '+92 300 5556677', 'type': 'customer'},
          {'name': 'Quick Fix Car AC & Suspension Lab', 'phone': '+92 321 8889900', 'type': 'customer'},
        ];
        for (final ac in autoContacts) {
          await txn.insert('contacts', {
            'type': ac['type'],
            'name': ac['name'],
            'phone': ac['phone'],
            'balance': 0.0,
            'credit_limit': 200000.0,
          });
          contactsCount++;
        }
      } else if (type == 'meat_butchery' || type == 'meat') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Kilograms', 'Kg', allowDecimal: 1);
        await seedUnit('Grams', 'gm', allowDecimal: 1, multiplier: 0.001);
        await seedUnit('Half Kilogram', 'Half Kg', allowDecimal: 1, multiplier: 0.5);
        await seedUnit('Cleaned Bird', 'Bird', allowDecimal: 0);

        final meatCats = [
          'Fresh Mutton (Goat / Chota Gosht)',
          'Fresh Beef / Veal (Bachia / Bara Gosht)',
          'Fresh Broiler Chicken (Safai Shuda)',
          'Fresh Boneless, Chops & Steaks',
          'Hand & Machine Keema (Mince)',
          'Fresh River Fish & Seafood',
        ];
        for (final cat in meatCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final meatProducts = [
          {'name': 'Fresh Mutton Mix Bone-in (چھوٹا گوشت مکس)', 'cat': 'Fresh Mutton (Goat / Chota Gosht)', 'unit': 'Kg', 'cost': 1850.0, 'sale': 2200.0, 'sku': 'MUT-MIX-01'},
          {'name': 'Mutton Boneless Pasanday & Chops (مٹن بون لیس و چانپ)', 'cat': 'Fresh Boneless, Chops & Steaks', 'unit': 'Kg', 'cost': 2400.0, 'sale': 2800.0, 'sku': 'MUT-BNS-02'},
          {'name': 'Fresh Veal / Bachia Beef Bone-in (بچھیا کا گوشت مکس)', 'cat': 'Fresh Beef / Veal (Bachia / Bara Gosht)', 'unit': 'Kg', 'cost': 850.0, 'sale': 1050.0, 'sku': 'BEF-VCL-01'},
          {'name': 'Beef Boneless Rump & Undercut (بیف بون لیس انڈر کٹ)', 'cat': 'Fresh Boneless, Chops & Steaks', 'unit': 'Kg', 'cost': 1100.0, 'sale': 1350.0, 'sku': 'BEF-BNS-02'},
          {'name': 'Fresh Broiler Chicken Cleaned Meat (صافی مرغی گوشت)', 'cat': 'Fresh Broiler Chicken (Safai Shuda)', 'unit': 'Kg', 'cost': 480.0, 'sale': 560.0, 'sku': 'CHK-CLN-01'},
          {'name': 'Chicken Boneless Breast Fillet (چکن بون لیس بریسٹ)', 'cat': 'Fresh Boneless, Chops & Steaks', 'unit': 'Kg', 'cost': 750.0, 'sale': 900.0, 'sku': 'CHK-BNS-02'},
          {'name': 'Special Veal Machine Keema (بچھیا کا قیمہ دوہرا مشین)', 'cat': 'Hand & Machine Keema (Mince)', 'unit': 'Kg', 'cost': 1000.0, 'sale': 1250.0, 'sku': 'KMA-BEF-01'},
          {'name': 'Fresh Kala Rohu Fish Sliced (کالا روہو مچھلی صاف شدہ)', 'cat': 'Fresh River Fish & Seafood', 'unit': 'Kg', 'cost': 700.0, 'sale': 900.0, 'sku': 'FSH-ROH-01'},
        ];
        for (final mp in meatProducts) {
          await txn.insert('products', {
            'name': mp['name'] as String,
            'sku': mp['sku'] as String,
            'barcode': mp['sku'] as String,
            'category_name': mp['cat'] as String,
            'brand_name': 'Fresh Halal Butchery',
            'unit': mp['unit'] as String,
            'purchase_price': mp['cost'] as double,
            'selling_price': mp['sale'] as double,
            'stock_quantity': 100.0,
            'alert_quantity': 15.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final meatContacts = [
          {'name': 'Bakra Mandi Animal Lot Supplier', 'phone': '+92 300 1122334', 'type': 'supplier'},
          {'name': 'Punjab Slaughterhouse Cattle Wholesale', 'phone': '+92 42 3766112', 'type': 'supplier'},
          {'name': 'Royal Palace Wedding Hall & Catering', 'phone': '+92 321 7776655', 'type': 'customer'},
          {'name': 'Walk-in Meat Customer', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final mc in meatContacts) {
          await txn.insert('contacts', {
            'type': mc['type'],
            'name': mc['name'],
            'phone': mc['phone'],
            'balance': 0.0,
            'credit_limit': 150000.0,
          });
          contactsCount++;
        }
      } else if (type == 'fabrics_textile' || type == 'fabrics') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Meter', 'Mtr', allowDecimal: 1);
        await seedUnit('Gazz (Yard)', 'Gazz', allowDecimal: 1, multiplier: 0.9144);
        await seedUnit('Thaan (25 Mtr)', 'Thaan', allowDecimal: 0, multiplier: 25.0);
        await seedUnit('Suit Length (4.5 Gazz)', 'Suit Cut', allowDecimal: 1, multiplier: 4.5);

        final fabricCats = [
          'Men\'s Pure Boski & Silk Fabrics',
          'Men\'s Premium Wash & Wear Suiting',
          'Men\'s Cotton & Handloom Khaddar',
          'Ladies Unstitched Lawn & Cotton Thaan',
          'Lining, Aster & Pocketing Fabrics',
          'Woolen Tweed & Winter Suiting',
        ];
        for (final cat in fabricCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final fabricProducts = [
          {'name': 'Pure Silk Boski 6-Pound Full Suit Length (4.5 Gazz)', 'cat': 'Men\'s Pure Boski & Silk Fabrics', 'brand': 'China Pure Boski', 'unit': 'Suit Cut', 'cost': 8500.0, 'sale': 11500.0, 'sku': 'BSK-6LB-SUIT'},
          {'name': 'Grace Premium Wash & Wear Suiting (Per Meter)', 'cat': 'Men\'s Premium Wash & Wear Suiting', 'brand': 'Grace Fabrics', 'unit': 'Mtr', 'cost': 650.0, 'sale': 950.0, 'sku': 'GRC-WNW-MTR'},
          {'name': 'Gul Ahmed 100% Egyptian Cotton Fabric (Per Meter)', 'cat': 'Men\'s Cotton & Handloom Khaddar', 'brand': 'Gul Ahmed', 'unit': 'Mtr', 'cost': 580.0, 'sale': 850.0, 'sku': 'GUL-CTN-MTR'},
          {'name': 'Kamalia Pure Handloom Khaddar Suit (7 Meter Cut)', 'cat': 'Men\'s Cotton & Handloom Khaddar', 'brand': 'Kamalia Khaddar', 'unit': 'Suit Cut', 'cost': 2200.0, 'sale': 3200.0, 'sku': 'KAM-KHD-SUIT'},
          {'name': 'Ladies Digital Print Premium Lawn Thaan (Per Meter)', 'cat': 'Ladies Unstitched Lawn & Cotton Thaan', 'brand': 'Al-Karam', 'unit': 'Mtr', 'cost': 320.0, 'sale': 480.0, 'sku': 'LWN-DIG-MTR'},
          {'name': 'Imported Suiting Aster / Lining Soft Silk (Per Meter)', 'cat': 'Lining, Aster & Pocketing Fabrics', 'brand': 'Imported', 'unit': 'Mtr', 'cost': 120.0, 'sale': 200.0, 'sku': 'LIN-AST-MTR'},
        ];
        for (final fp in fabricProducts) {
          await txn.insert('products', {
            'name': fp['name'] as String,
            'sku': fp['sku'] as String,
            'barcode': fp['sku'] as String,
            'category_name': fp['cat'] as String,
            'brand_name': fp['brand'] as String,
            'unit': fp['unit'] as String,
            'purchase_price': fp['cost'] as double,
            'selling_price': fp['sale'] as double,
            'stock_quantity': 150.0,
            'alert_quantity': 20.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final fabricContacts = [
          {'name': 'Grace Fabrics Official Wholesale Agency', 'phone': '+92 21 3522110', 'type': 'supplier'},
          {'name': 'Faisalabad Kapra Mandi Thaan Traders', 'phone': '+92 41 2644550', 'type': 'supplier'},
          {'name': 'Master Tailors & Fashion Designers', 'phone': '+92 300 4433221', 'type': 'customer'},
          {'name': 'Walk-in Fabric Shopper', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final fc in fabricContacts) {
          await txn.insert('contacts', {
            'type': fc['type'],
            'name': fc['name'],
            'phone': fc['phone'],
            'balance': 0.0,
            'credit_limit': 250000.0,
          });
          contactsCount++;
        }
      } else if (type == 'lubricants_oil' || type == 'lubricants') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Liter', 'Ltr', allowDecimal: 1);
        await seedUnit('1-Liter Can', '1L Can', allowDecimal: 0);
        await seedUnit('3-Liter Can', '3L Can', allowDecimal: 0);
        await seedUnit('4-Liter Can', '4L Can', allowDecimal: 0);
        await seedUnit('Drum (208L)', 'Drum', allowDecimal: 0, multiplier: 208.0);
        await seedUnit('Piece / Filter', 'Pc', allowDecimal: 0);
        await seedUnit('Service Job', 'Job', allowDecimal: 0);

        final oilCats = [
          'Synthetic Engine Oil (0W-20 & 5W-30)',
          'Semi-Synthetic Engine Oil (10W-40 & 20W-50)',
          'Heavy Duty Diesel Engine Oil (15W-40)',
          'Motorcycle 4T Engine Oil (0.7L / 1L)',
          'Automatic Transmission Fluid (ATF & CVT)',
          'Engine Oil Filters & Air Filters',
          'Quick Oil Change & Inspection Labor',
        ];
        for (final cat in oilCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final oilProducts = [
          {'name': 'Shell Helix HX7 10W-40 Synthetic (4L Can)', 'cat': 'Semi-Synthetic Engine Oil (10W-40 & 20W-50)', 'brand': 'Shell', 'unit': '4L Can', 'cost': 5200.0, 'sale': 6200.0, 'sku': 'OIL-SHL-HX7'},
          {'name': 'ZIC X7 5W-30 Fully Synthetic Engine Oil (4L Can)', 'cat': 'Synthetic Engine Oil (0W-20 & 5W-30)', 'brand': 'ZIC', 'unit': '4L Can', 'cost': 6800.0, 'sale': 8200.0, 'sku': 'OIL-ZIC-X7'},
          {'name': 'Caltex Havoline Super 4T 20W-50 Bike Oil (1L)', 'cat': 'Motorcycle 4T Engine Oil (0.7L / 1L)', 'brand': 'Caltex Havoline', 'unit': '1L Can', 'cost': 1100.0, 'sale': 1350.0, 'sku': 'OIL-HAV-4T1L'},
          {'name': 'Total Quartz 9000 Future 0W-20 Eco (4L Can)', 'cat': 'Synthetic Engine Oil (0W-20 & 5W-30)', 'brand': 'Total', 'unit': '4L Can', 'cost': 8400.0, 'sale': 10200.0, 'sku': 'OIL-TOT-0W20'},
          {'name': 'Guard Genuine Engine Oil Filter (Corolla/Civic)', 'cat': 'Engine Oil Filters & Air Filters', 'brand': 'Guard', 'unit': 'Pc', 'cost': 650.0, 'sale': 950.0, 'sku': 'FLT-GRD-OIL'},
          {'name': 'Aisin Fully Synthetic CVT Fluid (4L Can)', 'cat': 'Automatic Transmission Fluid (ATF & CVT)', 'brand': 'Aisin', 'unit': '4L Can', 'cost': 9500.0, 'sale': 12000.0, 'sku': 'OIL-ASN-CVT'},
          {'name': 'Oil Change Labor, Air Blow & 20-Point Check', 'cat': 'Quick Oil Change & Inspection Labor', 'brand': 'In-House Service', 'unit': 'Job', 'cost': 100.0, 'sale': 600.0, 'sku': 'SRV-OIL-CHG'},
        ];
        for (final op in oilProducts) {
          await txn.insert('products', {
            'name': op['name'] as String,
            'sku': op['sku'] as String,
            'barcode': op['sku'] as String,
            'category_name': op['cat'] as String,
            'brand_name': op['brand'] as String,
            'unit': op['unit'] as String,
            'purchase_price': op['cost'] as double,
            'selling_price': op['sale'] as double,
            'stock_quantity': 40.0,
            'alert_quantity': 8.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final oilContacts = [
          {'name': 'Shell Pakistan Authorized Regional Distributor', 'phone': '+92 21 111 743 555', 'type': 'supplier'},
          {'name': 'Hi-Tech Lubricants (ZIC) Distribution', 'phone': '+92 42 111 645 645', 'type': 'supplier'},
          {'name': 'Al-Rehman Goods Transport Fleet', 'phone': '+92 300 7766554', 'type': 'customer'},
          {'name': 'Walk-in Oil Change Customer', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final oc in oilContacts) {
          await txn.insert('contacts', {
            'type': oc['type'],
            'name': oc['name'],
            'phone': oc['phone'],
            'balance': 0.0,
            'credit_limit': 400000.0,
          });
          contactsCount++;
        }
      } else if (type == 'sanitary_tiles' || type == 'sanitary') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Square Feet', 'Sq Ft', allowDecimal: 1);
        await seedUnit('Tile Box', 'Box', allowDecimal: 0);
        await seedUnit('Piece', 'Pc', allowDecimal: 0);
        await seedUnit('Meter', 'Mtr', allowDecimal: 1);
        await seedUnit('Set', 'Set', allowDecimal: 0);

        final sanitaryCats = [
          'Floor Ceramic & Porcelain Tiles (24x24 / 24x48)',
          'Bathroom & Kitchen Wall Tiles (12x24 / 12x36)',
          'Sanitary Ware (Commode, Basins & Vanity)',
          'Brass Water Taps, Mixers & Showers',
          'PPRC Hot/Cold Water Pipes & Fittings',
          'Tile Bond, Grout & Waterproofing Chemicals',
        ];
        for (final cat in sanitaryCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final sanitaryProducts = [
          {'name': 'Master Porcelain 24x24 Carrara Gloss Tile (Box of 4 Pcs / 16 Sq Ft)', 'cat': 'Floor Ceramic & Porcelain Tiles (24x24 / 24x48)', 'brand': 'Master Tiles', 'unit': 'Box', 'cost': 2800.0, 'sale': 3600.0, 'sku': 'TLE-MST-2424'},
          {'name': 'Stile 12x24 Glazed Bathroom Wall Tile (Box of 8 Pcs / 16 Sq Ft)', 'cat': 'Bathroom & Kitchen Wall Tiles (12x24 / 12x36)', 'brand': 'Stile', 'unit': 'Box', 'cost': 2400.0, 'sale': 3100.0, 'sku': 'TLE-STL-1224'},
          {'name': 'Porta One-Piece Dual-Flush Commode Suite', 'cat': 'Sanitary Ware (Commode, Basins & Vanity)', 'brand': 'Porta', 'unit': 'Set', 'cost': 16500.0, 'sale': 21500.0, 'sku': 'SAN-PRT-COM'},
          {'name': 'Sonex Chrome Wall Shower & Basin Mixer Set Brass', 'cat': 'Brass Water Taps, Mixers & Showers', 'brand': 'Sonex', 'unit': 'Set', 'cost': 12000.0, 'sale': 15500.0, 'sku': 'SAN-SNX-MXR'},
          {'name': 'Fast PPRC 25mm Hot/Cold Water Pipe (13 Ft Length)', 'cat': 'PPRC Hot/Cold Water Pipes & Fittings', 'brand': 'Fast Cables', 'unit': 'Pc', 'cost': 480.0, 'sale': 680.0, 'sku': 'SAN-FST-25M'},
          {'name': 'Diamond Tile Bond Adhesive 20kg Bag', 'cat': 'Tile Bond, Grout & Waterproofing Chemicals', 'brand': 'Diamond', 'unit': 'Pc', 'cost': 650.0, 'sale': 850.0, 'sku': 'CHM-BND-20K'},
        ];
        for (final sp in sanitaryProducts) {
          await txn.insert('products', {
            'name': sp['name'] as String,
            'sku': sp['sku'] as String,
            'barcode': sp['sku'] as String,
            'category_name': sp['cat'] as String,
            'brand_name': sp['brand'] as String,
            'unit': sp['unit'] as String,
            'purchase_price': sp['cost'] as double,
            'selling_price': sp['sale'] as double,
            'stock_quantity': 45.0,
            'alert_quantity': 8.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final sanitaryContacts = [
          {'name': 'Master Tiles & Ceramics Factory Agency', 'phone': '+92 55 111 845 377', 'type': 'supplier'},
          {'name': 'Sonex Sanitary & Brass Fittings Gujranwala', 'phone': '+92 55 4299001', 'type': 'supplier'},
          {'name': 'Al-Haram Builders & Contractors', 'phone': '+92 300 3344556', 'type': 'customer'},
          {'name': 'Chaudhry Plumber & Fitting Services', 'phone': '+92 321 6655443', 'type': 'customer'},
        ];
        for (final sc in sanitaryContacts) {
          await txn.insert('contacts', {
            'type': sc['type'],
            'name': sc['name'],
            'phone': sc['phone'],
            'balance': 0.0,
            'credit_limit': 600000.0,
          });
          contactsCount++;
        }
      } else if (type == 'fruit_wholesale' || type == 'fruit_mandi') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Peti (Wooden Box)', 'Peti', allowDecimal: 0);
        await seedUnit('Bori (Jute Sack)', 'Bori', allowDecimal: 0);
        await seedUnit('Dhari (5 Kg)', 'Dhari', allowDecimal: 1, multiplier: 5.0);
        await seedUnit('Mann (40 Kg)', 'Mann', allowDecimal: 1, multiplier: 40.0);
        await seedUnit('Crate / Tokra', 'Crate', allowDecimal: 0);
        await seedUnit('Kilograms', 'Kg', allowDecimal: 1);

        final mandiCats = [
          'Fresh Fruits (Seasonal & Imported)',
          'Fresh Vegetables (Subziat Mandi)',
          'Potato & Onion Lots (Aaloo & Piaz)',
          'Citrus, Apples & Mango Peti',
          'Mazdoori & Mandi Arhat Services',
        ];
        for (final cat in mandiCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final mandiProducts = [
          {'name': 'Aalo (Potato) Punjab 50kg Bori', 'cat': 'Potato & Onion Lots (Aaloo & Piaz)', 'unit': 'Bori', 'cost': 2400.0, 'sale': 2850.0, 'sku': 'MND-ALO-50K'},
          {'name': 'Piaz (Onion) Sindh 40kg Mann', 'cat': 'Potato & Onion Lots (Aaloo & Piaz)', 'unit': 'Mann', 'cost': 3200.0, 'sale': 3800.0, 'sku': 'MND-PIZ-40K'},
          {'name': 'Tomato Sindhi Red Crate (15kg)', 'cat': 'Fresh Vegetables (Subziat Mandi)', 'unit': 'Crate', 'cost': 1200.0, 'sale': 1550.0, 'sku': 'MND-TOM-CRT'},
          {'name': 'Chaunsa Mango Special Wooden Peti (12kg)', 'cat': 'Citrus, Apples & Mango Peti', 'unit': 'Peti', 'cost': 1800.0, 'sale': 2400.0, 'sku': 'MND-MNG-PETI'},
          {'name': 'Apple Kala Kulu Wooden Box (18kg)', 'cat': 'Citrus, Apples & Mango Peti', 'unit': 'Peti', 'cost': 2600.0, 'sale': 3400.0, 'sku': 'MND-APL-PETI'},
          {'name': 'Palledari / Labour Loading Service (Per Peti)', 'cat': 'Mazdoori & Mandi Arhat Services', 'unit': 'Pc', 'cost': 20.0, 'sale': 40.0, 'sku': 'SRV-PLD-PETI'},
        ];
        for (final mp in mandiProducts) {
          await txn.insert('products', {
            'name': mp['name'] as String,
            'sku': mp['sku'] as String,
            'barcode': mp['sku'] as String,
            'category_name': mp['cat'] as String,
            'brand_name': 'Mandi Commission Agency',
            'unit': mp['unit'] as String,
            'purchase_price': mp['cost'] as double,
            'selling_price': mp['sale'] as double,
            'stock_quantity': 100.0,
            'alert_quantity': 10.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final mandiContacts = [
          {'name': 'Chaudhry Aslam Zamindar (Okara Lot)', 'phone': '+92 300 4455667', 'type': 'supplier'},
          {'name': 'Sardar Tariq Cotton & Vegetable Grower', 'phone': '+92 301 7788990', 'type': 'supplier'},
          {'name': 'Al-Madina Fruit Shop (Mandi Buyer)', 'phone': '+92 322 3344551', 'type': 'customer'},
          {'name': 'Subzi Mandi Boli Commission Client', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final mc in mandiContacts) {
          await txn.insert('contacts', {
            'type': mc['type'],
            'name': mc['name'],
            'phone': mc['phone'],
            'balance': 0.0,
            'credit_limit': 500000.0,
          });
          contactsCount++;
        }
      } else if (type == 'wholesale') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Master Carton', 'Ctn', allowDecimal: 0);
        await seedUnit('Packet / Bundle', 'Pkt', allowDecimal: 0);
        await seedUnit('Dozen', 'Dzn', allowDecimal: 0, multiplier: 12.0);
        await seedUnit('Piece', 'Pc', allowDecimal: 0);
        await seedUnit('Bori / Sack', 'Bori', allowDecimal: 0);

        final wholesaleCats = [
          'Bulk Edible Oils & Banaspati Ghee',
          'Beverages & Tea Master Cartons',
          'Detergents & Soap Master Bundles',
          'Flour, Rice & Sugar Bulk Sacks',
        ];
        for (final cat in wholesaleCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final wholesaleProducts = [
          {'name': 'Tapal Danedar Tea Master Carton (24x400g Packs)', 'cat': 'Beverages & Tea Master Cartons', 'brand': 'Tapal', 'unit': 'Ctn', 'cost': 12200.0, 'sale': 13600.0, 'sku': 'WHL-TPL-CTN'},
          {'name': 'Dalda Banaspati 16kg Master Tin Ghee', 'cat': 'Bulk Edible Oils & Banaspati Ghee', 'brand': 'Dalda', 'unit': 'Ctn', 'cost': 7200.0, 'sale': 7900.0, 'sku': 'WHL-DLD-16K'},
          {'name': 'Surf Excel Detergent Master Box (12x1kg)', 'cat': 'Detergents & Soap Master Bundles', 'brand': 'Unilever', 'unit': 'Ctn', 'cost': 4900.0, 'sale': 5600.0, 'sku': 'WHL-SRF-CTN'},
          {'name': 'Super Basmati Kernel Rice 50kg Bori', 'cat': 'Flour, Rice & Sugar Bulk Sacks', 'brand': 'Guard', 'unit': 'Bori', 'cost': 14500.0, 'sale': 16500.0, 'sku': 'WHL-RIC-50K'},
        ];
        for (final wp in wholesaleProducts) {
          await txn.insert('products', {
            'name': wp['name'] as String,
            'sku': wp['sku'] as String,
            'barcode': wp['sku'] as String,
            'category_name': wp['cat'] as String,
            'brand_name': wp['brand'] as String,
            'unit': wp['unit'] as String,
            'purchase_price': wp['cost'] as double,
            'selling_price': wp['sale'] as double,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final wholesaleContacts = [
          {'name': 'Unilever Pakistan Central Factory', 'phone': '+92 21 111 222 333', 'type': 'supplier'},
          {'name': 'Dalda Foods Manufacturing Hub', 'phone': '+92 21 3567000', 'type': 'supplier'},
          {'name': 'Bismillah Kiryana Super Store (Wholesale Client)', 'phone': '+92 300 5544332', 'type': 'customer'},
          {'name': 'Madina Mini Mart Retail Outlet', 'phone': '+92 321 8877665', 'type': 'customer'},
        ];
        for (final wc in wholesaleContacts) {
          await txn.insert('contacts', {
            'type': wc['type'],
            'name': wc['name'],
            'phone': wc['phone'],
            'balance': 0.0,
            'credit_limit': 1000000.0,
          });
          contactsCount++;
        }
      } else if (type == 'clothing' || type == 'garments') {
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        await seedUnit('Piece', 'Pc', allowDecimal: 0);
        await seedUnit('Pair', 'Pair', allowDecimal: 0, multiplier: 2.0);
        await seedUnit('Suit', 'Suit', allowDecimal: 0);
        await seedUnit('Set', 'Set', allowDecimal: 0);

        final garmentCats = [
          'Men\'s Casual Shirts & Polos',
          'Men\'s Denim Jeans & Trousers',
          'Men\'s Shalwar Kameez Designer Suits',
          'Ladies Ready-to-Wear Pret',
          'Kids Wear & Footwear',
        ];
        for (final cat in garmentCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final garmentProducts = [
          {'name': 'Men\'s Oxford Button-Down Casual Shirt (M, L, XL)', 'cat': 'Men\'s Casual Shirts & Polos', 'brand': 'Outfitters Style', 'unit': 'Pc', 'cost': 1400.0, 'sale': 2400.0, 'sku': 'CLO-SHR-OXF'},
          {'name': 'Men\'s Slim-Fit Stretch Denim Jeans (Sizes 30-36)', 'cat': 'Men\'s Denim Jeans & Trousers', 'brand': 'Levis Premium', 'unit': 'Pc', 'cost': 1800.0, 'sale': 3200.0, 'sku': 'CLO-JNS-SLM'},
          {'name': 'Men\'s Wash-and-Wear Stitched Kurta Shalwar', 'cat': 'Men\'s Shalwar Kameez Designer Suits', 'brand': 'Junaid Jamshed Cut', 'unit': 'Suit', 'cost': 2600.0, 'sale': 4500.0, 'sku': 'CLO-SUIT-JJ'},
          {'name': 'Ladies 2-Piece Embroidered Lawn Pret Kurti', 'cat': 'Ladies Ready-to-Wear Pret', 'brand': 'Khaadi Pret', 'unit': 'Suit', 'cost': 2200.0, 'sale': 3600.0, 'sku': 'CLO-LAD-PRT'},
        ];
        for (final gp in garmentProducts) {
          await txn.insert('products', {
            'name': gp['name'] as String,
            'sku': gp['sku'] as String,
            'barcode': gp['sku'] as String,
            'category_name': gp['cat'] as String,
            'brand_name': gp['brand'] as String,
            'unit': gp['unit'] as String,
            'purchase_price': gp['cost'] as double,
            'selling_price': gp['sale'] as double,
            'stock_quantity': 40.0,
            'alert_quantity': 6.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final garmentContacts = [
          {'name': 'Faisalabad Garments Manufacturing Mill', 'phone': '+92 41 8765432', 'type': 'supplier'},
          {'name': 'Karachi Textile Export Remnants Depot', 'phone': '+92 21 3456789', 'type': 'supplier'},
          {'name': 'Walk-in Boutique Shopper', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final gc in garmentContacts) {
          await txn.insert('contacts', {
            'type': gc['type'],
            'name': gc['name'],
            'phone': gc['phone'],
            'balance': 0.0,
            'credit_limit': 150000.0,
          });
          contactsCount++;
        }
      } else {
        // Universal Business / Other / Custom Business / General Retail & Wholesale
        Future<void> seedUnit(String actual, String short, {int allowDecimal = 0, double multiplier = 1.0}) async {
          final exists = await txn.query('units', where: 'actual_name = ? OR short_name = ?', whereArgs: [actual, short]);
          if (exists.isEmpty) {
            await txn.insert('units', {
              'actual_name': actual,
              'short_name': short,
              'allow_decimal': allowDecimal,
              'base_unit_multiplier': multiplier,
            });
          }
        }

        // 1. Seed complete universal units covering both retail, wholesale & decimal weights/lengths
        await seedUnit('Pieces', 'Pc', allowDecimal: 0);
        await seedUnit('Kilograms', 'Kg', allowDecimal: 1);
        await seedUnit('Liters', 'Ltr', allowDecimal: 1);
        await seedUnit('Meters', 'Mtr', allowDecimal: 1);
        await seedUnit('Master Carton', 'Ctn', allowDecimal: 0);
        await seedUnit('Box', 'Box', allowDecimal: 0);
        await seedUnit('Packet / Bundle', 'Pkt', allowDecimal: 0);
        await seedUnit('Dozen', 'Dzn', allowDecimal: 0, multiplier: 12.0);
        await seedUnit('Bag / Sack', 'Bag', allowDecimal: 0);
        await seedUnit('Feet / Foot', 'Ft', allowDecimal: 1);
        await seedUnit('Square Feet', 'Sq Ft', allowDecimal: 1);
        await seedUnit('Grams', 'Gm', allowDecimal: 1, multiplier: 0.001);
        await seedUnit('Roll / Thaan', 'Roll', allowDecimal: 0);

        // 2. Seed universal categories
        final universalCats = [
          'General Merchandise (عام سامان)',
          'Wholesale Lots & Cartons (ہول سیل لاٹس)',
          'Retail Fast-Moving Goods (ریٹیل اشیاء)',
          'Loose & Weighed Items (وزن والی اشیاء)',
          'Spare Parts & Hardware (پرزہ جات و سامان)',
          'Services & Custom Orders (خدمات و آرڈرز)',
        ];
        for (final cat in universalCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        // 3. Seed versatile products demonstrating retail, wholesale bulk, and decimal fractional weights
        final universalProducts = [
          {'name': 'Standard Retail Merchandise Item', 'sku': 'UNI-RET-01', 'cat': 'Retail Fast-Moving Goods (ریٹیل اشیاء)', 'unit': 'Pc', 'cost': 180.0, 'sale': 250.0, 'stock': 100.0},
          {'name': 'Wholesale Master Carton Bulk Lot (24 Units)', 'sku': 'UNI-WHL-02', 'cat': 'Wholesale Lots & Cartons (ہول سیل لاٹس)', 'unit': 'Ctn', 'cost': 3800.0, 'sale': 4500.0, 'stock': 40.0},
          {'name': 'Loose Weighed Product (Fractional Decimal OK)', 'sku': 'UNI-WGT-03', 'cat': 'Loose & Weighed Items (وزن والی اشیاء)', 'unit': 'Kg', 'cost': 240.0, 'sale': 320.0, 'stock': 250.0},
          {'name': 'Liquid Measured Product (Per Liter)', 'sku': 'UNI-LIQ-04', 'cat': 'Loose & Weighed Items (وزن والی اشیاء)', 'unit': 'Ltr', 'cost': 190.0, 'sale': 260.0, 'stock': 120.0},
          {'name': 'Length Fabric / Wire (Per Meter)', 'sku': 'UNI-MTR-05', 'cat': 'Spare Parts & Hardware (پرزہ جات و سامان)', 'unit': 'Mtr', 'cost': 90.0, 'sale': 150.0, 'stock': 500.0},
          {'name': 'Heavy Duty 50kg Sack / Bag', 'sku': 'UNI-BAG-06', 'cat': 'Wholesale Lots & Cartons (ہول سیل لاٹس)', 'unit': 'Bag', 'cost': 3100.0, 'sale': 3650.0, 'stock': 60.0},
        ];
        for (final up in universalProducts) {
          await txn.insert('products', {
            'name': up['name'] as String,
            'sku': up['sku'] as String,
            'barcode': up['sku'] as String,
            'category_name': up['cat'] as String,
            'brand_name': 'Universal Standard',
            'unit': up['unit'] as String,
            'purchase_price': up['cost'] as double,
            'selling_price': up['sale'] as double,
            'stock_quantity': up['stock'] as double,
            'alert_quantity': 10.0,
            'pack_size': 1.0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          productsCount++;
        }

        // 4. Seed contacts for Suppliers, Wholesale Khata Clients, and Retail
        final universalContacts = [
          {'name': 'Main Central Wholesale Distributor', 'phone': '+92 300 1122334', 'type': 'supplier', 'limit': 1500000.0},
          {'name': 'Factory Direct Import House', 'phone': '+92 321 4455667', 'type': 'supplier', 'limit': 2000000.0},
          {'name': 'Al-Rehman Traders (Wholesale Khata Client)', 'phone': '+92 333 7788990', 'type': 'customer', 'limit': 500000.0},
          {'name': 'Walk-in Cash Customer (Retail)', 'phone': '+92 300 0000000', 'type': 'customer', 'limit': 50000.0},
        ];
        for (final uc in universalContacts) {
          await txn.insert('contacts', {
            'type': uc['type'],
            'name': uc['name'],
            'phone': uc['phone'],
            'balance': 0.0,
            'credit_limit': uc['limit'] as double,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          contactsCount++;
        }
      }
    });    stopwatch.stop();
    return {
      'products': productsCount,
      'categories': categoriesCount,
      'contacts': contactsCount,
      'elapsedMs': stopwatch.elapsedMilliseconds,
    };
  }

// Dashboard Enhanced Analytics

  // ===================== PURGE & MEDICINE DATA SEEDING =====================
  Future<void> purgeAllBusinessData() async {
    try {
      await db.execute('PRAGMA foreign_keys = OFF;');
    } catch (e, st) {
      AppLogger.warning('DatabaseService', 'Could not disable foreign_keys during purge', e, st);
    }

    await db.transaction((txn) async {
      final tables = [
        'sale_return_items',
        'sale_returns',
        'purchase_return_items',
        'purchase_returns',
        'sale_items',
        'sales',
        'purchase_items',
        'purchases',
        'payment_transactions',
        'product_serials_batches',
        'product_bundles',
        'variations',
        'products',
        'expenses',
        'stock_transfers',
        'stock_adjustments',
        'contact_payments',
        'account_transfers',
        'contacts',
        'categories',
        'brands',
        'units',
        'tax_rates',
        'tax_groups',
        'customer_groups',
        'restaurant_kot_orders',
        'restaurant_tables',
        'gym_members',
        'hotel_rooms',
        'repair_jobs',
        'cash_registers',
        'audit_logs',
        'activity_log',
        'sync_queue',
        'discounts',
        'warranty_claims',
        'printer_configs',
      ];
      for (final table in tables) {
        if (await DatabaseSchema.tableExists(txn, table)) {
          await txn.delete(table);
        }
      }
      if (await DatabaseSchema.tableExists(txn, 'sqlite_sequence')) {
        await txn.delete('sqlite_sequence');
      }
    });

    try {
      await db.execute('PRAGMA foreign_keys = ON;');
    } catch (e, st) {
      AppLogger.warning('DatabaseService', 'Could not re-enable foreign_keys after purge', e, st);
    }

    DatabaseService.onSyncQueueUpdated?.call();
  }

  /// Complete Factory Reset: Wipes all business data, clears user credentials, resets settings
  /// to unconfigured so SetupWizardScreen creates the sole new Super Admin cleanly.
  Future<BusinessSettings> factoryResetForNewBusiness() async {
    await purgeAllBusinessData();
    await db.delete('users');

    final resetSettings = BusinessSettings(
      id: 1,
      businessName: 'Smart POS System',
      branchName: 'Main Branch HQ',
      currencySymbol: 'Rs',
      currencyCode: 'PKR',
      defaultTaxRate: 5.0,
      phone: '',
      email: '',
      address: '',
      invoicePrefix: 'INV-',
      receiptFooter: '',
      purchaseKey: '',
      businessType: 'general',
      isConfigured: false,
      industryPresets: '',
      enabledModules: '',
      primaryDbType: 'mysql',
      dbHost: 'localhost',
      dbPort: 3306,
      dbName: 'smartpos',
      dbUser: 'root',
      dbPassword: '',
      syncMode: 'offline',
    );
    await dbService.settingsRepo.updateBusinessSettings(resetSettings);
    await AuthService.logout();
    if (dbService.dbFilePath != null && dbService.dbFilePath != inMemoryDatabasePath) {
      await dbService.checkpointWal();
      await DatabaseEncryptionService.sealVaultSnapshot(dbService.dbFilePath!);
    }
    AppLogger.info('DatabaseService', 'Factory reset completed; Setup Wizard ready for new Super Admin.');
    return resetSettings;
  }

  /// Bulk Seed 2,500 Medicines, 1,500 Customers, 100 Suppliers, 15 Salesmen
  Future<Map<String, int>> seedMedicineAgencyData({
    int productTarget = 2500,
    int customerTarget = 1500,
    int supplierTarget = 100,
    int salesmanTarget = 15,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Medicine Companies / Brands (Pharma Manufacturers)
    final pharmaBrands = [
      'Getz Pharma', 'Searle Pakistan', 'Abbott Laboratories', 'GSK Pakistan',
      'Ferozsons Laboratories', 'Sami Pharmaceuticals', 'Hilton Pharma',
      'Martin Dow Marker', 'Highnoon Laboratories', 'Bosch Pharmaceuticals',
      'Barrett Hodgson', 'Atco Laboratories', 'Sanofi-Aventis', 'Pfizer',
      'Novartis', 'Bayer HealthCare', 'CCL Pharmaceuticals', 'PharmEvo',
      'Macter International', 'Horizon Pharmaceuticals', 'Platinum Pharmaceuticals',
      'Shaigan Pharmaceuticals', 'Genix Pharma', 'Werrick Pharmaceuticals',
      'Zafa Pharmaceuticals', 'AGP Limited', 'Standpharm Pakistan',
      'Scotmann Pharmaceuticals', 'Brooks Pharma', 'Aspin Pharma'
    ];

    // 2. Medicine Categories & Salt Formulations
    final pharmaCategories = [
      'Antibiotics & Antimicrobials',
      'Analgesics, Pain & NSAIDs',
      'Antipyretics & Cold Preparations',
      'Cardiovascular & Antihypertensives',
      'Gastrointestinal & Antiulcerants',
      'Antidiabetic & Endocrinology',
      'Antihistamines & Anti-allergic',
      'Respiratory, Asthma & Inhalers',
      'Vitamins, Minerals & Supplements',
      'Dermatological & Topical Creams',
      'Ophthalmic & ENT Drops',
      'Neuro-Psychiatric & Sedatives',
      'Injectables & IV Infusions',
      'Pediatric Syrups & Drops',
      'Medical Disposables & Surgical'
    ];

    final medicineBases = [
      {'name': 'Panadol 500mg Tab', 'cat': 'Antipyretics & Cold Preparations', 'unit': 'Box (200s)', 'cost': 600.0, 'sale': 720.0, 'pack': 200.0},
      {'name': 'Panadol Extra Tab', 'cat': 'Analgesics, Pain & NSAIDs', 'unit': 'Box (100s)', 'cost': 450.0, 'sale': 540.0, 'pack': 100.0},
      {'name': 'Augmentin 625mg Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Pack (14s)', 'cost': 380.0, 'sale': 460.0, 'pack': 14.0},
      {'name': 'Augmentin 1g Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Pack (14s)', 'cost': 580.0, 'sale': 695.0, 'pack': 14.0},
      {'name': 'Augmentin 156mg Syrup 60ml', 'cat': 'Pediatric Syrups & Drops', 'unit': 'Bottle', 'cost': 160.0, 'sale': 195.0, 'pack': 1.0},
      {'name': 'Brufen 400mg Tab', 'cat': 'Analgesics, Pain & NSAIDs', 'unit': 'Box (300s)', 'cost': 1100.0, 'sale': 1320.0, 'pack': 300.0},
      {'name': 'Brufen DS Syrup 120ml', 'cat': 'Pediatric Syrups & Drops', 'unit': 'Bottle', 'cost': 95.0, 'sale': 118.0, 'pack': 1.0},
      {'name': 'Flygal 400mg Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Box (200s)', 'cost': 520.0, 'sale': 640.0, 'pack': 200.0},
      {'name': 'Risek 20mg Cap (Omeprazole)', 'cat': 'Gastrointestinal & Antiulcerants', 'unit': 'Pack (14s)', 'cost': 320.0, 'sale': 390.0, 'pack': 14.0},
      {'name': 'Risek 40mg Cap (Omeprazole)', 'cat': 'Gastrointestinal & Antiulcerants', 'unit': 'Pack (14s)', 'cost': 540.0, 'sale': 650.0, 'pack': 14.0},
      {'name': 'Risek 40mg IV Inj', 'cat': 'Injectables & IV Infusions', 'unit': 'Vial', 'cost': 390.0, 'sale': 480.0, 'pack': 1.0},
      {'name': 'Arinac 200/30mg Tab', 'cat': 'Antipyretics & Cold Preparations', 'unit': 'Box (100s)', 'cost': 480.0, 'sale': 580.0, 'pack': 100.0},
      {'name': 'Arinac Forte Tab', 'cat': 'Antipyretics & Cold Preparations', 'unit': 'Box (100s)', 'cost': 720.0, 'sale': 865.0, 'pack': 100.0},
      {'name': 'Cac-1000 Plus Effervescent Tab', 'cat': 'Vitamins, Minerals & Supplements', 'unit': 'Tube (10s)', 'cost': 240.0, 'sale': 295.0, 'pack': 10.0},
      {'name': 'Surbex-Z High Potency Tab', 'cat': 'Vitamins, Minerals & Supplements', 'unit': 'Bottle (30s)', 'cost': 390.0, 'sale': 475.0, 'pack': 30.0},
      {'name': 'Rigix 10mg Tab (Cetirizine)', 'cat': 'Antihistamines & Anti-allergic', 'unit': 'Pack (30s)', 'cost': 180.0, 'sale': 225.0, 'pack': 30.0},
      {'name': 'T-Day 5mg Tab (Levocetirizine)', 'cat': 'Antihistamines & Anti-allergic', 'unit': 'Pack (10s)', 'cost': 140.0, 'sale': 175.0, 'pack': 10.0},
      {'name': 'Gravinate 50mg Tab', 'cat': 'Gastrointestinal & Antiulcerants', 'unit': 'Box (100s)', 'cost': 310.0, 'sale': 380.0, 'pack': 100.0},
      {'name': 'Amoxil 500mg Cap', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Box (100s)', 'cost': 740.0, 'sale': 890.0, 'pack': 100.0},
      {'name': 'Ciproxin 500mg Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Pack (10s)', 'cost': 320.0, 'sale': 395.0, 'pack': 10.0},
      {'name': 'Loprin 75mg Tab (Aspirin)', 'cat': 'Cardiovascular & Antihypertensives', 'unit': 'Box (30s)', 'cost': 95.0, 'sale': 120.0, 'pack': 30.0},
      {'name': 'Norvasc 5mg Tab (Amlodipine)', 'cat': 'Cardiovascular & Antihypertensives', 'unit': 'Pack (30s)', 'cost': 450.0, 'sale': 540.0, 'pack': 30.0},
      {'name': 'Softin 10mg Tab (Loratadine)', 'cat': 'Antihistamines & Anti-allergic', 'unit': 'Pack (10s)', 'cost': 150.0, 'sale': 185.0, 'pack': 10.0},
      {'name': 'Ponstan 500mg Forte Tab', 'cat': 'Analgesics, Pain & NSAIDs', 'unit': 'Box (250s)', 'cost': 850.0, 'sale': 1050.0, 'pack': 250.0},
      {'name': 'Xanax 0.5mg Tab (Alprazolam)', 'cat': 'Neuro-Psychiatric & Sedatives', 'unit': 'Pack (30s)', 'cost': 260.0, 'sale': 320.0, 'pack': 30.0},
      {'name': 'Lexotanil 3mg Tab (Bromazepam)', 'cat': 'Neuro-Psychiatric & Sedatives', 'unit': 'Pack (30s)', 'cost': 310.0, 'sale': 380.0, 'pack': 30.0},
      {'name': 'Betnesol Oral Drops 15ml', 'cat': 'Ophthalmic & ENT Drops', 'unit': 'Bottle', 'cost': 75.0, 'sale': 95.0, 'pack': 1.0},
      {'name': 'Polyfax Eye Ointment 6g', 'cat': 'Ophthalmic & ENT Drops', 'unit': 'Tube', 'cost': 85.0, 'sale': 105.0, 'pack': 1.0},
      {'name': 'Polyfax Plus Skin Ointment 20g', 'cat': 'Dermatological & Topical Creams', 'unit': 'Tube', 'cost': 140.0, 'sale': 175.0, 'pack': 1.0},
      {'name': 'Fucidin Cream 15g', 'cat': 'Dermatological & Topical Creams', 'unit': 'Tube', 'cost': 220.0, 'sale': 270.0, 'pack': 1.0},
      {'name': 'Ventolin Inhaler 100mcg', 'cat': 'Respiratory, Asthma & Inhalers', 'unit': 'Inhaler', 'cost': 380.0, 'sale': 460.0, 'pack': 1.0},
      {'name': 'Seretide Evohaler 25/125mcg', 'cat': 'Respiratory, Asthma & Inhalers', 'unit': 'Inhaler', 'cost': 1350.0, 'sale': 1620.0, 'pack': 1.0},
      {'name': 'Glucophage 500mg Tab', 'cat': 'Antidiabetic & Endocrinology', 'unit': 'Box (50s)', 'cost': 290.0, 'sale': 355.0, 'pack': 50.0},
      {'name': 'Getformin 850mg Tab', 'cat': 'Antidiabetic & Endocrinology', 'unit': 'Box (30s)', 'cost': 210.0, 'sale': 260.0, 'pack': 30.0},
      {'name': 'Gravibinan 1ml Inj', 'cat': 'Injectables & IV Infusions', 'unit': 'Ampoule', 'cost': 340.0, 'sale': 420.0, 'pack': 1.0},
      {'name': 'Neurobion 3ml Inj', 'cat': 'Injectables & IV Infusions', 'unit': 'Ampoule', 'cost': 110.0, 'sale': 138.0, 'pack': 1.0},
      {'name': 'Clexane 40mg Prefilled Syringe', 'cat': 'Injectables & IV Infusions', 'unit': 'Syringe', 'cost': 1150.0, 'sale': 1390.0, 'pack': 1.0},
      {'name': 'IV Cannula 20G / 22G / 24G', 'cat': 'Medical Disposables & Surgical', 'unit': 'Box (50s)', 'cost': 1200.0, 'sale': 1550.0, 'pack': 50.0},
      {'name': 'Disposable Syringes 5ml BD', 'cat': 'Medical Disposables & Surgical', 'unit': 'Box (100s)', 'cost': 850.0, 'sale': 1100.0, 'pack': 100.0},
      {'name': 'Surgical Face Masks 3-Ply', 'cat': 'Medical Disposables & Surgical', 'unit': 'Box (50s)', 'cost': 220.0, 'sale': 300.0, 'pack': 50.0},
    ];

    final colors = ['#004EEB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4', '#EC4899', '#3B82F6'];

    // Execute in transaction
    await db.transaction((txn) async {
      // 0. Seed Categories
      for (final cat in pharmaCategories) {
        await txn.insert('categories', {
          'name': cat,
          'code': cat.length >= 3 ? cat.substring(0, 3).toUpperCase() : cat.toUpperCase(),
          'description': '$cat Category',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // A. Seed 100 Suppliers (Pharma Distributors)
      final supplierCities = ['Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Peshawar', 'Multan', 'Faisalabad', 'Hyderabad'];
      for (int i = 1; i <= supplierTarget; i++) {
        final bName = pharmaBrands[(i - 1) % pharmaBrands.length];
        final city = supplierCities[(i - 1) % supplierCities.length];
        await txn.insert('contacts', {
          'type': 'supplier',
          'name': 'Distributor Rep $i (${bName.split(" ").first})',
          'business_name': '$bName Distribution Network Ltd',
          'phone': '+92 321 000${(1000 + i)}',
          'email': 'supply$i@${bName.toLowerCase().replaceAll(" ", "").replaceAll("-", "")}.com',
          'address': 'Plot ${10 + i}, Medicine Wholesale Market, $city',
          'credit_limit': 500000.0,
          'balance': (i % 3 == 0) ? (15000.0 + (i * 1200.0)) : 0.0,
        });
      }

      // B. Seed 1,500 Customers (Pharmacies, Hospitals, Clinics)
      final pharmacyTypes = ['Medical Store & Pharmacy', 'Community Pharmacy', 'Hospital Pharmacy', 'General Clinic', 'Care Chemist'];
      const batchSize = 300;
      for (int b = 0; b < customerTarget; b += batchSize) {
        final batch = txn.batch();
        final end = (b + batchSize < customerTarget) ? b + batchSize : customerTarget;
        for (int i = b + 1; i <= end; i++) {
          final pType = pharmacyTypes[(i - 1) % pharmacyTypes.length];
          final city = supplierCities[(i - 1) % supplierCities.length];
          final due = (i % 4 == 0) ? (2500.0 + (i * 35.0)) : 0.0;
          batch.insert('contacts', {
            'type': 'customer',
            'name': 'Client Pharmacy #$i',
            'business_name': 'Al-Shafa $pType #$i',
            'phone': '+92 300 999${(1000 + i)}',
            'email': 'pharmacy$i@gmail.com',
            'address': 'Shop ${5 + (i % 80)}, Main Market, $city',
            'credit_limit': 50000.0,
            'balance': due,
          });
        }
        await batch.commit(noResult: true);
      }

      // C. Seed 2,500 Products (Pharmaceutical Catalog with generic variants, dosages & expiries)
      for (int b = 0; b < productTarget; b += batchSize) {
        final batch = txn.batch();
        final end = (b + batchSize < productTarget) ? b + batchSize : productTarget;
        for (int i = b + 1; i <= end; i++) {
          final base = medicineBases[(i - 1) % medicineBases.length];
          final brand = pharmaBrands[(i - 1) % pharmaBrands.length];
          final color = colors[i % colors.length];
          final sku = 'MED-${i.toString().padLeft(5, "0")}';
          final barcode = '8964000${i.toString().padLeft(6, "0")}';
          final batchNo = 'BAT-${2024 + (i % 3)}-${(100 + (i % 900))}';

          // Expiry dates between 2025 and 2028
          final expMonth = ((i % 12) + 1).toString().padLeft(2, '0');
          final expYear = (2025 + (i % 4)).toString();
          final expiryStr = '$expMonth-$expYear';

          final baseCost = (base['cost'] as double) * (0.8 + ((i % 15) * 0.03));
          final baseSale = (base['sale'] as double) * (0.8 + ((i % 15) * 0.03));

          final nameSuffix = (i > medicineBases.length) ? ' [Dosage #$i]' : '';

          batch.insert('products', {
            'name': '${base['name']}$nameSuffix',
            'sku': sku,
            'barcode': barcode,
            'category_name': base['cat'] as String,
            'brand_name': brand,
            'unit': base['unit'] as String,
            'purchase_price': double.parse(baseCost.toStringAsFixed(2)),
            'selling_price': double.parse(baseSale.toStringAsFixed(2)),
            'stock_quantity': 50.0 + (i % 250),
            'alert_quantity': 15.0,
            'image_color': color,
            'batch_number': batchNo,
            'expiry_date': expiryStr,
            'bonus_qty': (i % 10 == 0) ? 1.0 : 0.0,
            'pack_size': base['pack'] as double,
          });
        }
        await batch.commit(noResult: true);
      }

      // D. Seed 15 Salesmen if not already present (hashed with forced password rotation)
      for (int i = 1; i <= salesmanTarget; i++) {
        final existing = await txn.rawQuery(
          'SELECT id FROM users WHERE username = ?',
          ['salesman$i'],
        );
        if (existing.isEmpty) {
          await txn.insert('users', {
            'name': 'Field Salesman #$i',
            'username': 'salesman$i',
            'password': AuthService.hashPassword('Sales#${1000 + i}!Pos'),
            'email': 'salesman$i@smartpos.com',
            'role': 'salesman',
            'status': 'active',
            'branch_id': 1,
            'branch_name': 'Main Branch HQ',
            'phone': '+92 311 00000${i.toString().padLeft(2, '0')}',
            'must_change_password': 1,
          });
        }
      }
    });

    stopwatch.stop();
    return {
      'products': productTarget,
      'customers': customerTarget,
      'suppliers': supplierTarget,
      'salesmen': salesmanTarget,
      'elapsedMs': stopwatch.elapsedMilliseconds,
    };
  }

  /// High Performance Transaction Batch Generator for load testing
  Future<Map<String, dynamic>> benchmarkTransactions({int count = 10000}) async {
    final stopwatch = Stopwatch()..start();
    final f = DateFormat('yyyy-MM-dd HH:mm:ss');
    final now = DateTime.now();

    final customers = await db.query('contacts', where: "type = 'customer'", limit: 50);
    final products = await db.query('products', limit: 50);

    if (products.isEmpty) {
      return {
        'count': 0,
        'transactions_inserted': 0,
        'elapsedMs': 0,
        'elapsed_ms': 0,
        'speedPerSec': 0,
        'transactions_per_sec': 0,
      };
    }

    const batchSize = 1000;
    int insertedSales = 0;

    await db.transaction((txn) async {
      for (int b = 0; b < count; b += batchSize) {
        final saleBatch = txn.batch();
        final currentChunk = (b + batchSize < count) ? batchSize : (count - b);

        for (int i = 0; i < currentChunk; i++) {
          final globalIndex = b + i + 1;
          final cust = customers.isNotEmpty ? customers[globalIndex % customers.length] : null;
          final prod = products[globalIndex % products.length];

          final qty = 1.0 + (globalIndex % 4);
          final price = (prod['selling_price'] as num?)?.toDouble() ?? 100.0;
          final total = qty * price;
          final dateStr = f.format(now.subtract(Duration(minutes: globalIndex * 2)));

          saleBatch.insert('sales', {
            'invoice_no': 'LOAD-${100000 + globalIndex}',
            'customer_id': cust?['id'] ?? 1,
            'customer_name': cust?['name'] ?? 'Walk-in Customer',
            'total_amount': total,
            'tax_amount': 0.0,
            'discount_amount': 0.0,
            'paid_amount': total,
            'due_amount': 0.0,
            'payment_status': 'paid',
            'payment_method': (globalIndex % 2 == 0) ? 'cash' : 'card',
            'sale_status': 'final',
            'created_at': dateStr,
            'cash_register_id': 1,
          });
        }
        await saleBatch.commit(noResult: true);
        insertedSales += currentChunk;
      }
    });

    stopwatch.stop();
    final speed = insertedSales / (stopwatch.elapsedMilliseconds / 1000.0);

    return {
      'count': insertedSales,
      'transactions_inserted': insertedSales,
      'elapsedMs': stopwatch.elapsedMilliseconds,
      'elapsed_ms': stopwatch.elapsedMilliseconds,
      'speedPerSec': speed.round(),
      'transactions_per_sec': speed.round(),
    };
  }


  /// Reset business configuration to trigger first-time installation wizard on next launch
  Future<void> resetToFreshInstallation() async {
    await db.execute("UPDATE business_settings SET is_configured = 0");
  }
}
