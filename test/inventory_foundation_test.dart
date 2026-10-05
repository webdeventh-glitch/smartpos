import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/core/money.dart';
import 'package:desktop_starter/stock_store.dart';

void main() {
  test(
      'money parses and formats exactly, rejecting overflow and precision loss',
      () {
    expect(Money.parse('0.29'), 29);
    expect(Money.parse('99999999.99'), 9999999999);
    expect(Money.decimal(9000000000000000), '90000000000000.00');
    expect(Money.decimal(-1), '-0.01');
    for (final value in ['1.001', '-1', '1e3', 'NaN', '100000000']) {
      expect(() => Money.parse(value), throwsFormatException);
    }
    expect(() => Money.lineTotal(9999999999, 100000000), throwsArgumentError);
    expect(() => Money.add(Money.maxTotal, 1), throwsArgumentError);
  });

  test(
      'metadata persists, barcode uniqueness and append-only history are enforced',
      () async {
    final store = await StockStore.open(path: inMemoryDatabasePath);
    addTearDown(store.db.close);
    await store.save(
        name: 'Notebook',
        sku: 'N1',
        price: 29,
        minimum: 1,
        quantity: 10,
        barcode: ' AbC123 ',
        category: 'Stationery',
        cost: 20);
    final product = (await store.findBarcode('abc123'))!;
    final id = product['id'] as int;
    expect(product['cost'], 20);
    expect((await store.searchProducts('Note')).single['id'], id);
    expect((await store.searchProducts('abc')).single['id'], id);
    expect(await store.searchProducts('%'), isEmpty);
    await expectLater(
        store.save(
            name: 'Duplicate',
            sku: 'N2',
            price: 10,
            minimum: 0,
            barcode: 'ABC123'),
        throwsException);
    await store.save(
        id: id, name: 'Notebook edited', sku: 'N1', price: 30, minimum: 1);
    expect((await store.findBarcode('abc123'))!['category'], 'Stationery');
    await expectLater(
        store.db.update('movements', {'delta': 999}), throwsException);
    await expectLater(store.db.delete('movements'), throwsException);
    await store.delete(id);
    expect((await store.history()).length, 2);
  });

  test('concurrent sales cannot oversell and oversized totals roll back',
      () async {
    final store = await StockStore.open(path: inMemoryDatabasePath);
    addTearDown(store.db.close);
    await store.save(
        name: 'Last item', sku: 'L', price: 100, minimum: 0, quantity: 1);
    final id = (await store.products()).single['id'] as int;
    final results = await Future.wait(List.generate(2, (_) async {
      try {
        await store.postDocument('sale', '', '', [OrderLine(id, 1, 100)]);
        return true;
      } on StateError {
        return false;
      }
    }));
    expect(results.where((success) => success).length, 1);
    expect((await store.products()).single['quantity'], 0);
    await expectLater(
        store.postDocument(
            'purchase', '', '', [OrderLine(id, 100000000, 9999999999)]),
        throwsArgumentError);
    expect(await store.documents('purchase'), isEmpty);
    expect((await store.history()).length, 2);
  });

  test(
      'populated v2 upgrade preserves products, movements and invoice snapshots',
      () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('inventory_v2_');
    final path = '${dir.path}/stock.db';
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, sku TEXT COLLATE NOCASE UNIQUE, price INTEGER, quantity INTEGER, minimum INTEGER)');
              await db.execute(
                  'CREATE TABLE movements (id INTEGER PRIMARY KEY, product_id INTEGER, product_name TEXT, delta INTEGER, balance INTEGER, note TEXT, created_at TEXT)');
              await db.execute(
                  'CREATE TABLE documents (id INTEGER PRIMARY KEY, kind TEXT, party TEXT, note TEXT, total INTEGER, created_at TEXT)');
              await db.execute(
                  'CREATE TABLE document_lines (id INTEGER PRIMARY KEY, document_id INTEGER, product_id INTEGER, name TEXT, sku TEXT, quantity INTEGER, price INTEGER)');
              await db.rawInsert(
                  "INSERT INTO products VALUES (1, 'Old', 'O', 100, 4, 1)");
              await db.rawInsert(
                  "INSERT INTO movements VALUES (1, 1, 'Old', 4, 4, 'Opening', '2026-01-01')");
              await db.rawInsert(
                  "INSERT INTO documents VALUES (1, 'sale', 'Customer', '', 100, '2026-01-01')");
              await db.rawInsert(
                  "INSERT INTO document_lines VALUES (1, 1, 1, 'Old', 'O', 1, 100)");
            }));
    await old.close();
    final store = await StockStore.open(path: path);
    try {
      expect(await store.db.getVersion(), 6);
      expect((await store.products()).single['quantity'], 4);
      expect((await store.products()).single['cost'], isNull);
      expect((await store.history()).single['delta'], 4);
      expect((await store.documentLines(1)).single['price'], 100);
      expect(
          (await store.db.rawQuery('PRAGMA integrity_check'))
              .single
              .values
              .single,
          'ok');
    } finally {
      await store.db.close();
      await dir.delete(recursive: true);
    }
  });
}
