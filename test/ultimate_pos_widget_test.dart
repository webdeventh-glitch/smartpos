import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/screens/main_shell.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets('MainShell renders Ultimate POS header, sidebar and dashboard', (tester) async {
    // Initialize in-memory database in runAsync
    await tester.runAsync(() async {
      await DatabaseService.initialize(customPath: inMemoryDatabasePath);
    });

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = BusinessSettings(
      businessName: 'Ultimate POS Superstore',
      branchName: 'Main Branch',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: MainShell(initialSettings: settings),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Verify Header Elements (Store name and POS button)
    expect(find.textContaining('Ultimate POS Superstore'), findsWidgets);
    expect(find.text('POS'), findsOneWidget);

    // Verify Navigation Sidebar Items (Screenshots 1-4)
    expect(find.text('Search menu...'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Purchases'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Stock Transfers'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Dashboard Content (Screenshot 1)
    expect(find.textContaining('Welcome Admin'), findsOneWidget);
    expect(find.text('Total Sales'), findsOneWidget);
    expect(find.text('Total purchase'), findsOneWidget);
    expect(find.text('Sales Last 30 Days'), findsOneWidget);

    // Click on POS button in Header (navigates to POS terminal Screenshot 2)
    await tester.tap(find.text('POS'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Verify POS Terminal rendered (Screenshot 2)
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Multiple Pay'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('TOTAL PAYABLE'), findsOneWidget);
  });
}
