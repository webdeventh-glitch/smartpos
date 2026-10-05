import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/stock_store.dart';
import 'package:desktop_starter/documents_page.dart';
import 'package:desktop_starter/features/pos/pos_repository.dart';

void main() {
  testWidgets('sale history posts a return and shows persisted refund',
      (tester) async {
    late StockStore store;
    await tester.runAsync(() async {
      store = await StockStore.open(path: inMemoryDatabasePath);
      await store.save(
          name: 'Tea', sku: 'T', price: 100, minimum: 0, quantity: 2);
      final id = (await store.products()).single['id'] as int;
      await PosRepository(store).checkout(
          token: 'sale',
          lines: [OrderLine(id, 1, 100)],
          payments: {'Cash': 100});
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> settleDatabase() async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DocumentsPage(
                store: store,
                kind: 'sale',
                allowCreate: false,
                onChanged: () async {}))));
    await settleDatabase();
    await tester.tap(find.byType(ListTile));
    await settleDatabase();
    await tester.tap(find.text('Return items'));
    await settleDatabase();
    await tester.tap(find.text('Return all remaining'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Return reason'), 'Unwanted');
    await tester.pumpAndSettle();
    expect(find.text('Refund: Rs 1.00'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Record return'));
    await settleDatabase();
    await settleDatabase();
    for (var i = 0;
        i < 8 && find.text('Return history').evaluate().isEmpty;
        i++) {
      await settleDatabase();
    }
    expect(find.text('Return history'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    expect(find.text('Net sale after refunds: Rs 0.00'), findsOneWidget);
    await tester.runAsync(() async {
      expect((await store.products()).single['quantity'], 2);
      expect(
          (await store.db.query('sale_returns')).single['reason'], 'Unwanted');
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => store.db.close());
  });
}
