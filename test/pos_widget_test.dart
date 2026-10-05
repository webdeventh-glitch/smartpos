import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/main.dart';
import 'package:desktop_starter/stock_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets('POS workspace adapts and adds a real product to bill',
      (tester) async {
    late StockStore store;
    await tester.runAsync(() async {
      store = await StockStore.open(path: inMemoryDatabasePath);
      await store.save(
          name: 'Coffee', sku: 'C', price: 25000, minimum: 1, quantity: 10);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(DesktopStarterApp(store: store));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsNWidgets(2));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Tax (included)'), findsOneWidget);
    expect(find.text('Charge · F9'), findsOneWidget);
    await tester.tap(find.text('Charge · F9'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Cash received (Rs)'), '300');
    await tester.pumpAndSettle();
    expect(find.text('Change: Rs 50.00'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Complete sale'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Payment complete'), findsOneWidget);
    await tester.runAsync(() async {
      expect((await store.products()).single['quantity'], 9);
      expect((await store.db.query('payments')).single['amount'], 25000);
      expect((await store.documents('sale')).single['cash_change'], 5000);
      expect((await store.documents('sale')).single['tax_inclusive'], 1);
    });
    await tester.tap(find.text('New sale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    for (final size in [
      const Size(1024, 600),
      const Size(390, 844),
      const Size(320, 568)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    }
    await tester.tap(find.text('Current bill (1)'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => store.db.close());
  });
}
