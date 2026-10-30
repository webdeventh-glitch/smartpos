import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Verify schema migration and factory reset on isolated test database', () async {
    final tempDbPath = p.join(Directory.systemTemp.path, 'smartpos_migration_test_${DateTime.now().millisecondsSinceEpoch}.db');
    final tempFile = File(tempDbPath);

    try {
      final dbService = await DatabaseService.initialize(customPath: tempDbPath);

      // Verify schema contains primary_db_type
      final res = await dbService.db.rawQuery("PRAGMA table_info('business_settings')");
      final hasCol = res.any((r) => r['name'] == 'primary_db_type');
      expect(hasCol, isTrue);
      print('SUCCESS: primary_db_type column confirmed in business_settings schema!');

      // Factory reset test
      final freshSettings = await dbService.factoryResetForNewBusiness();
      expect(freshSettings.isConfigured, isFalse);
      print('SUCCESS: Database factory reset executed cleanly on isolated test db.');
    } finally {
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
  });
}
