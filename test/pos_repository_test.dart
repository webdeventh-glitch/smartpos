import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/stock_store.dart';
import 'package:desktop_starter/features/pos/pos_repository.dart';

void main() {
  test('inclusive tax extracts tax after discount with half-up rounding', () {
    final totals = CheckoutTotals.calculate(
        [const OrderLine(1, 1, 12000)], 200, 1800,
        taxInclusive: true);
    expect(totals.total, 11800);
    expect(totals.tax, 1800);
    expect(
        CheckoutTotals.calculate([const OrderLine(1, 1, 1)], 0, 10000,
                taxInclusive: true)
            .tax,
        1);
  });

  test('cash change supports split tender and rejects non-cash overpayment',
      () {
    final result =
        PaymentSettlement.calculate(10000, {'Cash': 10000, 'Card': 4000});
    expect(result.allocations, {'Cash': 6000, 'Card': 4000});
    expect(result.change, 4000);
    expect(() => PaymentSettlement.calculate(10000, {'Cash': 9999}),
        throwsArgumentError);
    expect(() => PaymentSettlement.calculate(10000, {'Card': 10001}),
        throwsArgumentError);
    expect(() => PaymentSettlement.calculate(10000, {'Card': 10000, 'Cash': 1}),
        throwsArgumentError);
    expect(PaymentSettlement.calculate(0, {}).change, 0);
  });

  test('v5 persists tender and tax mode, rejects changed replay, upgrades v4',
      () async {
    final folder = await Directory.systemTemp.createTemp('pos_v5');
    final path = '${folder.path}/test.db';
    var store = await StockStore.open(path: path);
    try {
      await store.save(
          name: 'Tea', sku: 'T', price: 11800, minimum: 0, quantity: 3);
      final id = (await store.products()).single['id'] as int;
      final repo = PosRepository(store);
      final invoice = await repo.checkout(
          token: 'inclusive',
          lines: [OrderLine(id, 1, 11800)],
          taxInclusive: true,
          taxRate: 1800,
          payments: {'Cash': 11800},
          cashReceived: 20000);
      final row = (await store.documents('sale')).single;
      expect(row['tax'], 1800);
      expect(row['total'], 11800);
      expect(row['cash_change'], 8200);
      expect(row['tax_inclusive'], 1);
      expect(
          await repo.checkout(
              token: 'inclusive',
              lines: [OrderLine(id, 1, 11800)],
              taxInclusive: true,
              taxRate: 1800,
              payments: {'Cash': 11800},
              cashReceived: 20000),
          invoice);
      await expectLater(
          repo.checkout(
              token: 'inclusive',
              lines: [OrderLine(id, 1, 11800)],
              taxInclusive: true,
              taxRate: 1800,
              payments: {'Cash': 11800},
              cashReceived: 15000),
          throwsStateError);
      await expectLater(
          repo.checkout(
              token: 'invalid',
              lines: [OrderLine(id, 1, 11800)],
              payments: {'Cash': 11800},
              cashReceived: 10000),
          throwsArgumentError);
      expect((await store.products()).single['quantity'], 2);
      // Reconstruct the previous schema around a real posted invoice.
      for (final column in ['tax_inclusive', 'cash_received', 'cash_change']) {
        await store.db.execute('ALTER TABLE documents DROP COLUMN $column');
      }
      await store.db.execute('DROP TABLE sale_return_lines');
      await store.db.execute('DROP TABLE sale_returns');
      await store.db.setVersion(4);
      await store.db.close();
      store = await StockStore.open(path: path);
      expect(await store.db.getVersion(), 6);
      final legacy = (await store.documents('sale')).single;
      expect(legacy['total'], 11800);
      expect(legacy['cash_received'], isNull);
      expect(legacy['tax_inclusive'], isNull);
      expect((await store.db.query('payments')).single['amount'], 11800);
    } finally {
      await store.db.close();
      await folder.delete(recursive: true);
    }
  });

  test(
      'checkout rounds tax, allocates split payments, retries safely and rolls back overselling',
      () async {
    final folder = await Directory.systemTemp.createTemp('pos_test');
    final store = await StockStore.open(path: '${folder.path}/test.db');
    try {
      await store.save(
          name: 'Tea', sku: 'T', price: 10005, minimum: 1, quantity: 5);
      final id = (await store.products()).single['id'] as int;
      final repo = PosRepository(store);
      final lines = [OrderLine(id, 2, 10005)];
      final total = CheckoutTotals.calculate(lines, 1010, 1750);
      expect(total.total, 22325);
      final invoice = await repo.checkout(
          token: 'a',
          lines: lines,
          discount: 1010,
          taxRate: 1750,
          payments: {'Cash': 10000, 'Card': 12325});
      expect(
          await repo.checkout(
              token: 'a',
              lines: lines,
              discount: 1010,
              taxRate: 1750,
              payments: {'Cash': 10000, 'Card': 12325}),
          invoice);
      expect((await store.products()).single['quantity'], 3);
      expect((await store.db.query('payments')).length, 2);
      await expectLater(
          repo.checkout(token: 'a', lines: lines, payments: {'Cash': 20010}),
          throwsStateError);
      await expectLater(store.db.update('documents', {'total': 1}),
          throwsA(isA<Exception>()));
      await expectLater(
          repo.checkout(
              token: 'b',
              lines: [OrderLine(id, 4, 10005)],
              payments: {'Cash': 40020}),
          throwsStateError);
      expect((await store.documents('sale')).length, 1);
      expect((await store.products()).single['quantity'], 3);
      await expectLater(
          repo.checkout(token: 'c', lines: lines, payments: {'Cash': 1}),
          throwsArgumentError);
      await repo
          .park('held', 'Customer', {'items': [], 'customer': 'Customer'});
      await store.db.close();
      final reopened = await StockStore.open(path: '${folder.path}/test.db');
      expect((await PosRepository(reopened).parked()).single['token'], 'held');
      await reopened.db.close();
    } finally {
      if (store.db.isOpen) await store.db.close();
      await folder.delete(recursive: true);
    }
  });
  test('discount and money boundaries reject invalid invoices', () {
    expect(() => CheckoutTotals.calculate([const OrderLine(1, 1, 100)], 101, 0),
        throwsArgumentError);
    expect(() => CheckoutTotals.calculate([const OrderLine(1, 0, 100)], 0, 0),
        throwsArgumentError);
    expect(CheckoutTotals.calculate([const OrderLine(1, 1, 101)], 0, 5000).tax,
        51);
  });
  test('concurrent cashiers cannot oversell the last item', () async {
    final folder = await Directory.systemTemp.createTemp('pos_concurrent');
    final store = await StockStore.open(path: '${folder.path}/test.db');
    try {
      await store.save(
          name: 'Last item', sku: 'L', price: 100, minimum: 0, quantity: 1);
      final id = (await store.products()).single['id'] as int;
      final repo = PosRepository(store);
      Future<bool> sell(String token) async {
        try {
          await repo.checkout(
              token: token,
              lines: [OrderLine(id, 1, 100)],
              payments: {'Cash': 100});
          return true;
        } on StateError {
          return false;
        }
      }

      final results = await Future.wait([sell('one'), sell('two')]);
      expect(results.where((success) => success).length, 1);
      expect((await store.products()).single['quantity'], 0);
      expect((await store.documents('sale')).length, 1);
    } finally {
      await store.db.close();
      await folder.delete(recursive: true);
    }
  });
}
