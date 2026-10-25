import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('High-Volume Seeding & Benchmark Stress Test', () async {
    final db = await DatabaseService.initialize(customPath: inMemoryDatabasePath);

    // 1. Purge data
    await db.purgeAllBusinessData();
    var pCount = (await db.getProducts()).length;
    expect(pCount, equals(0));

    // 2. High-volume medicine agency seed
    final seedSw = Stopwatch()..start();
    final seedSummary = await db.seedMedicineAgencyData(
      productTarget: 2500,
      customerTarget: 1500,
      supplierTarget: 100,
      salesmanTarget: 15,
    );
    seedSw.stop();

    print('Seeding completed in ${seedSw.elapsedMilliseconds}ms: $seedSummary');
    expect(seedSummary['products'], equals(2500));
    expect(seedSummary['customers'], equals(1500));
    expect(seedSummary['suppliers'], equals(100));
    expect(seedSummary['salesmen'], equals(15));

    final products = await db.getProducts();
    expect(products.length, equals(2500));

    final customers = await db.getCustomers();
    expect(customers.length, equals(1500));

    final suppliers = await db.getSuppliers();
    expect(suppliers.length, equals(100));

    final users = await db.getUsers();
    expect(users.length, greaterThanOrEqualTo(15));

    // 3. Benchmark 10,000 sales transactions
    final benchResult = await db.benchmarkTransactions(count: 10000);
    print('Benchmark Results: $benchResult');
    expect(benchResult['transactions_inserted'], equals(10000));
    expect(benchResult['elapsed_ms'], greaterThan(0));
    print('Speed: ${(benchResult['transactions_per_sec'] as num).toStringAsFixed(0)} tx/sec!');
  });
}
