import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/stock_store.dart';
import 'package:desktop_starter/documents_page.dart';

void main() {
  testWidgets(
      'sale form adds an item and posts stock; purchase view fits narrow width',
      (tester) async {
    late StockStore store;
    await tester.runAsync(() async {
      store = await StockStore.open(path: inMemoryDatabasePath);
      await store.save(
          name: 'Pen', sku: 'P', price: 12500, minimum: 1, quantity: 10);
    });
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DocumentsPage(
                store: store, kind: 'sale', onChanged: () async {}))));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('New sale'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pen | Stock: 10').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Total: Rs 125.00'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Save sale'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect((await store.products()).single['quantity'], 9);
      expect((await store.documents('sale')).single['total'], 12500);
    });
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 700);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DocumentsPage(
                key: const ValueKey('purchase'),
                store: store,
                kind: 'purchase',
                onChanged: () async {}))));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('New purchase'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => store.db.close());
  });
}
