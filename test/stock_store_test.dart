import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/core/money.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() async {
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_stock_test_');
    db = await DatabaseService.initialize(
      customPath: p.join(tempDir.path, 'test.db'),
    );
  });

  tearDown(() async {
    await db.db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Money utility', () {
    test('parses, formats, and adds currency values cleanly', () {
      expect(Money.parse('0'), 0);
      expect(Money.parse('125.50'), 12550);
      expect(Money.decimal(12550), '125.50');
      expect(Money.format(-505), 'Rs -5.05');
      expect(Money.lineTotal(2500, 4), 10000);
      expect(Money.add(10000, 2550), 12550);
    });

    test('rejects invalid formats and overflow', () {
      expect(() => Money.parse('12.345'), throwsFormatException);
      expect(() => Money.lineTotal(-1, 2), throwsArgumentError);
      expect(() => Money.add(Money.maxTotal, 1), throwsArgumentError);
    });
  });

  group('DatabaseService product catalog & barcode uniqueness', () {
    test('creates, reads, updates, and deletes products', () async {
      final id = await db.addProduct(
        Product(
          name: 'Panadol Extra',
          sku: 'PAN-EX-01',
          barcode: '896400099111',
          purchasePrice: 35.0,
          sellingPrice: 50.0,
          stockQuantity: 100.0,
        ),
      );

      final loaded = await db.getProductById(id);
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Panadol Extra');
      expect(loaded.barcode, '896400099111');
      expect(loaded.stockQuantity, 100.0);

      await db.updateProduct(
        loaded.copyWith(sellingPrice: 55.0, stockQuantity: 85.0),
      );
      final updated = await db.getProductById(id);
      expect(updated!.sellingPrice, 55.0);
      expect(updated.stockQuantity, 85.0);

      await db.deleteProduct(id);
      expect(await db.getProductById(id), isNull);
    });

    test('disambiguates duplicate SKU and barcode collisions automatically', () async {
      final firstId = await db.addProduct(
        Product(
          name: 'Original Soap',
          sku: 'DUP-SKU',
          barcode: '896111222333',
          purchasePrice: 80.0,
          sellingPrice: 120.0,
          stockQuantity: 10.0,
        ),
      );
      final secondId = await db.addProduct(
        Product(
          name: 'Second Soap',
          sku: 'DUP-SKU',
          barcode: '896111222333',
          purchasePrice: 90.0,
          sellingPrice: 130.0,
          stockQuantity: 20.0,
        ),
      );

      final first = await db.getProductById(firstId);
      final second = await db.getProductById(secondId);
      expect(first!.sku, 'DUP-SKU');
      expect(second!.sku, isNot('DUP-SKU'));
      expect(second.barcode, isNot('896111222333'));
    });
  });
}
