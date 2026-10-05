import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/stock_store.dart';
import 'package:desktop_starter/features/pos/pos_repository.dart';
import 'package:desktop_starter/features/returns/returns_repository.dart';

void main() {
  late StockStore store;
  late ReturnsRepository repo;
  late int product, sale;
  setUp(() async {
    store = await StockStore.open(path: inMemoryDatabasePath);
    repo = ReturnsRepository(store);
    await store.save(
        name: 'Tea', sku: 'T', price: 100, minimum: 0, quantity: 10);
    product = (await store.products()).single['id'] as int;
    sale = await PosRepository(store).checkout(
        token: 'sale',
        lines: [OrderLine(product, 3, 100)],
        discount: 1,
        payments: {'Cash': 299});
  });
  tearDown(() => store.db.close());

  test('partial refunds accumulate exactly, retry safely and restore stock',
      () async {
    final item = (await repo.items(sale)).single;
    expect(item.refund(1), 99);
    final id = await repo.post(
        saleId: sale,
        token: 'r1',
        quantities: {item.lineId: 1},
        reason: 'Unwanted',
        method: 'Cash',
        expectedRefund: 99);
    expect(
        await repo.post(
            saleId: sale,
            token: 'r1',
            quantities: {item.lineId: 1},
            reason: 'Unwanted',
            method: 'Cash',
            expectedRefund: 99),
        id);
    await expectLater(
        repo.post(
            saleId: sale,
            token: 'r1',
            quantities: {item.lineId: 1},
            reason: 'Changed',
            method: 'Cash',
            expectedRefund: 99),
        throwsStateError);
    final rest = (await repo.items(sale)).single;
    expect(rest.remaining, 2);
    expect(rest.refund(2), 200);
    await repo.post(
        saleId: sale,
        token: 'r2',
        quantities: {item.lineId: 2},
        reason: 'Remaining',
        method: 'Card',
        expectedRefund: 200);
    expect((await store.products()).single['quantity'], 10);
    expect(
        (await repo.history(sale))
            .fold<int>(0, (sum, r) => sum + (r['total'] as int)),
        299);
    expect((await store.documents('sale')).single['total'], 299);
    await expectLater(
        repo.post(
            saleId: sale,
            token: 'r3',
            quantities: {item.lineId: 1},
            reason: 'Too many',
            method: 'Cash',
            expectedRefund: 100),
        throwsArgumentError);
    await expectLater(store.db.update('sale_returns', {'total': 1}),
        throwsA(isA<Exception>()));
    await expectLater(
        store.db.delete('sale_return_lines'), throwsA(isA<Exception>()));
  });

  test('invalid and stale requests have no stock or refund side effects',
      () async {
    final item = (await repo.items(sale)).single;
    for (final quantities in [
      {item.lineId: 4},
      {item.lineId: 0},
      {999: 1}
    ]) {
      await expectLater(
          repo.post(
              saleId: sale,
              token: 'bad',
              quantities: quantities,
              reason: 'Bad',
              method: 'Cash',
              expectedRefund: 0),
          throwsArgumentError);
    }
    await expectLater(
        repo.post(
            saleId: sale,
            token: 'stale',
            quantities: {item.lineId: 1},
            reason: 'Bad quote',
            method: 'Cash',
            expectedRefund: 100),
        throwsStateError);
    await store.delete(product);
    await expectLater(
        repo.post(
            saleId: sale,
            token: 'deleted',
            quantities: {item.lineId: 1},
            reason: 'Deleted',
            method: 'Cash',
            expectedRefund: 99),
        throwsStateError);
    expect(await repo.history(sale), isEmpty);
    expect(await store.db.query('sale_return_lines'), isEmpty);
  });

  test('concurrent returns cannot exceed quantities sold', () async {
    final item = (await repo.items(sale)).single;
    Future<bool> attempt(String token) async {
      try {
        await repo.post(
            saleId: sale,
            token: token,
            quantities: {item.lineId: 3},
            reason: 'Full',
            method: 'Cash',
            expectedRefund: 299);
        return true;
      } on ArgumentError {
        return false;
      }
    }

    expect(
        (await Future.wait([attempt('a'), attempt('b')]))
            .where((v) => v)
            .length,
        1);
    expect((await store.products()).single['quantity'], 10);
  });

  test(
      'multi-line tax/discount allocation refunds exactly, independent of order',
      () async {
    await store.save(
        name: 'Coffee', sku: 'C', price: 201, minimum: 0, quantity: 2);
    final other = (await store.products())
        .firstWhere((p) => p['sku'] == 'C')['id'] as int;
    final invoice = await PosRepository(store).checkout(
        token: 'tax-sale',
        lines: [OrderLine(product, 2, 100), OrderLine(other, 1, 201)],
        discount: 10,
        taxRate: 1750,
        payments: {'Cash': 459});
    final items = await repo.items(invoice);
    var sum = 0;
    for (final item in items.reversed) {
      final value = item.refund(item.remaining);
      sum += value;
      await repo.post(
          saleId: invoice,
          token: 'line-${item.lineId}',
          quantities: {item.lineId: item.remaining},
          reason: 'Full',
          method: 'Cash',
          expectedRefund: value);
    }
    expect(sum, 459);
  });

  test('legacy sales reject refunds and free sales can be restocked', () async {
    final legacy =
        await store.postDocument('sale', '', '', [OrderLine(product, 1, 100)]);
    await expectLater(repo.items(legacy), throwsStateError);
    final free = await PosRepository(store).checkout(
        token: 'free',
        lines: [OrderLine(product, 1, 100)],
        discount: 100,
        payments: {});
    final item = (await repo.items(free)).single;
    await repo.post(
        saleId: free,
        token: 'free-return',
        quantities: {item.lineId: 1},
        reason: 'Free item',
        method: 'Cash',
        expectedRefund: 0);
    expect((await repo.history(free)).single['total'], 0);
  });

  test('failure on a later line rolls back earlier restocking', () async {
    await store.save(
        name: 'Second', sku: 'S', price: 100, minimum: 0, quantity: 1);
    final second = (await store.products())
        .firstWhere((p) => p['sku'] == 'S')['id'] as int;
    final invoice = await PosRepository(store).checkout(
        token: 'two',
        lines: [OrderLine(product, 1, 100), OrderLine(second, 1, 100)],
        payments: {'Cash': 200});
    final items = await repo.items(invoice);
    await store.delete(second);
    final before = (await store.products()).single['quantity'];
    final movements = (await store.history()).length;
    await expectLater(
        repo.post(
            saleId: invoice,
            token: 'rollback',
            quantities: {for (final item in items) item.lineId: 1},
            reason: 'Both',
            method: 'Cash',
            expectedRefund: 200),
        throwsStateError);
    expect((await store.products()).single['quantity'], before);
    expect((await store.history()).length, movements);
    expect(await repo.history(invoice), isEmpty);
  });

  test('v5 upgrade preserves sales and returns survive restart', () async {
    final dir = await Directory.systemTemp.createTemp('returns_migration');
    var disk = await StockStore.open(path: '${dir.path}/test.db');
    try {
      await disk.save(
          name: 'Item', sku: 'I', price: 100, minimum: 0, quantity: 1);
      final product = (await disk.products()).single['id'] as int;
      final sale = await PosRepository(disk).checkout(
          token: 'disk-sale',
          lines: [OrderLine(product, 1, 100)],
          payments: {'Cash': 100});
      await disk.db.execute('DROP TABLE sale_return_lines');
      await disk.db.execute('DROP TABLE sale_returns');
      await disk.db.setVersion(5);
      await disk.db.close();
      disk = await StockStore.open(path: '${dir.path}/test.db');
      expect(await disk.db.getVersion(), 6);
      final item = (await ReturnsRepository(disk).items(sale)).single;
      await ReturnsRepository(disk).post(
          saleId: sale,
          token: 'disk-return',
          quantities: {item.lineId: 1},
          reason: 'Full',
          method: 'Cash',
          expectedRefund: 100);
      await disk.db.close();
      disk = await StockStore.open(path: '${dir.path}/test.db');
      expect(
          (await ReturnsRepository(disk).history(sale)).single['total'], 100);
      expect((await ReturnsRepository(disk).items(sale)).single.remaining, 0);
    } finally {
      await disk.db.close();
      await dir.delete(recursive: true);
    }
  });
}
