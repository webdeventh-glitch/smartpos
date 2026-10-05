import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/stock_store.dart';

void main() {
  test(
      'purchase and sale persist snapshots and roll back an entire oversold order',
      () async {
    final dir = await Directory.systemTemp.createTemp('orders_test_');
    var store = await StockStore.open(path: '${dir.path}/stock.db');
    try {
      await store.save(
          name: 'A', sku: 'A', price: 500, minimum: 1, quantity: 4);
      await store.save(
          name: 'B', sku: 'B', price: 700, minimum: 1, quantity: 1);
      final products = await store.products();
      final a = products[0]['id'] as int, b = products[1]['id'] as int;
      final purchase = await store.postDocument('purchase', 'Supplier',
          'Delivery', [OrderLine(a, 6, 300), OrderLine(b, 2, 400)]);
      expect((await store.documents('purchase')).single['total'], 2600);
      expect((await store.products()).first['quantity'], 10);
      final sale = await store.postDocument(
          'sale', 'Customer', '', [OrderLine(a, 2, 500), OrderLine(b, 1, 700)]);
      expect((await store.documents('sale')).single['total'], 1700);
      final movements = (await store.history()).length;
      await expectLater(
          store.postDocument(
              'sale', '', '', [OrderLine(a, 1, 500), OrderLine(b, 99, 700)]),
          throwsStateError);
      expect((await store.products()).first['quantity'], 8);
      expect((await store.history()).length, movements);
      expect((await store.documents('sale')).length, 1);
      await expectLater(
          store.postDocument(
              'sale', '', '', [OrderLine(a, 1, 500), OrderLine(a, 1, 500)]),
          throwsArgumentError);
      await store.delete(a);
      await store.db.close();
      store = await StockStore.open(path: '${dir.path}/stock.db');
      expect((await store.documentLines(sale)).first['name'], 'A');
      expect((await store.documentLines(purchase)).length, 2);
    } finally {
      await store.db.close();
      await dir.delete(recursive: true);
    }
  });
  test('version 1 database upgrades without losing inventory', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('migration_test_');
    final path = '${dir.path}/stock.db';
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, sku TEXT, price INTEGER, quantity INTEGER, minimum INTEGER)');
              await db.insert('products', {
                'id': 1,
                'name': 'Existing',
                'sku': 'E',
                'price': 100,
                'quantity': 9,
                'minimum': 1
              });
            }));
    await old.close();
    final store = await StockStore.open(path: path);
    try {
      expect(await store.db.getVersion(), 6);
      expect((await store.products()).single['quantity'], 9);
      expect(await store.documents('sale'), isEmpty);
    } finally {
      await store.db.close();
      await dir.delete(recursive: true);
    }
  });
}
