import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/stock_store.dart';

void main() {
  test(
      'SQLite persists products, rejects duplicate SKU and prevents negative stock',
      () async {
    final dir = await Directory.systemTemp.createTemp('stock_test_');
    final path = '${dir.path}/test.db';
    var store = await StockStore.open(path: path);
    try {
      await store.save(
          name: 'Notebook',
          sku: 'NB01',
          price: 12550,
          minimum: 3,
          quantity: 10);
      final id = (await store.products()).single['id'] as int;
      await expectLater(
          store.save(name: 'Duplicate', sku: 'nb01', price: 100, minimum: 1),
          throwsException);
      await store.adjust(id, -4, 'Sale');
      await expectLater(store.adjust(id, -7, 'Oversell'), throwsStateError);
      expect((await store.products()).single['quantity'], 6);
      expect((await store.history()).length, 2);
      await store.adjust(id, 2, 'Delivery');
      await store.save(
          id: id, name: 'Notebook A5', sku: 'NB01', price: 15000, minimum: 5);
      await store.db.close();
      store = await StockStore.open(path: path);
      final product = (await store.products()).single;
      expect(product['quantity'], 8);
      expect(product['name'], 'Notebook A5');
      expect(product['price'], 15000);
      await store.delete(id);
      expect(await store.products(), isEmpty);
      expect((await store.history()).length, 4);
    } finally {
      await store.db.close();
      await dir.delete(recursive: true);
    }
  });
}
