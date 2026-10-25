import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Verify schema migration and factory reset on local app database', () async {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final dbFile = File('$localAppData\\SmartPOS\\smart_pos.db');

    if (!dbFile.existsSync()) {
      print('Database file does not exist yet at: ${dbFile.path}');
      return;
    }

    print('Connecting to real local database: ${dbFile.path}');
    final dbService = await DatabaseService.initialize();

    // Verify schema contains primary_db_type
    final res = await dbService.db.rawQuery("PRAGMA table_info('business_settings')");
    final hasCol = res.any((r) => r['name'] == 'primary_db_type');
    expect(hasCol, isTrue);
    print('SUCCESS: primary_db_type column confirmed in business_settings schema!');


    // Factory reset database so user starts with fresh business setup
    final freshSettings = await dbService.factoryResetForNewBusiness();
    expect(freshSettings.isConfigured, isFalse);
    print('SUCCESS: Database factory reset executed cleanly! Ready for new business testing.');
  });
}
