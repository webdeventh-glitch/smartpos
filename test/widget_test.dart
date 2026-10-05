import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/stock_page.dart';
import 'package:desktop_starter/stock_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('sidebar, drawer and profile adapt to window sizes',
      (tester) async {
    late StockStore store;
    await tester.runAsync(() async {
      store = await StockStore.open(path: inMemoryDatabasePath);
      await store.save(
          name: 'Test product',
          sku: 'T01',
          price: 100,
          minimum: 5,
          quantity: 2);
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(MaterialApp(home: StockPage(store: store)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('WORKSPACE'), findsOneWidget);
    for (final size in [
      const Size(1024, 600),
      const Size(800, 600),
      const Size(390, 844),
      const Size(320, 568)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Layout at $size');
    }
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock history'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Latest 200 movements - newest first'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Latest 200 movements - newest first'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('User menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.text('Local User'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => store.db.close());
  });
  testWidgets('empty inventory and add product form render', (tester) async {
    late StockStore store;
    await tester.runAsync(() async {
      store = await StockStore.open(path: inMemoryDatabasePath);
    });
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StockPage(store: store)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Your inventory is empty'), findsOneWidget);
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a product name'), findsOneWidget);
    expect(find.text('Enter a unique SKU'), findsOneWidget);
    await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextFormField))
            .at(0),
        'Notebook');
    await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextFormField))
            .at(1),
        'NB01');
    await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextFormField))
            .at(2),
        '125.50');
    await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextFormField))
            .at(3),
        '10');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Barcode (optional)'), 'NB-123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Category (optional)'),
        'Stationery');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Purchase cost (Rs, optional)'),
        '80.29');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save product'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Notebook'), findsOneWidget);
    expect(find.text('Rs 125.50'), findsOneWidget);
    await tester.runAsync(() async {
      final saved = (await store.findBarcode('NB-123'))!;
      expect(saved['category'], 'Stationery');
      expect(saved['cost'], 8029);
    });
    await tester.tap(find.byTooltip('Stock out'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextFormField))
            .first,
        '11');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough stock available'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => store.db.close());
  });
}
