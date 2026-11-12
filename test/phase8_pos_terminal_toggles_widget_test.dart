import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/pos/pos_terminal_screen.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() async {
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_pos_toggles_');
    final dbPath = p.join(tempDir.path, 'pos_hidden_panel.db');
    await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    db = await DatabaseService.initialize(customPath: dbPath);
    await db.addProduct(Product(
      name: 'Tapal Danedar 400g',
      sku: 'TEA-400',
      barcode: '8961011001',
      purchasePrice: 500,
      sellingPrice: 620,
      stockQuantity: 40,
    ));
  });

  tearDown(() async {
    try {
      await db.db.close();
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets(
      'PosTerminalScreen hides right product panel when showPosProductPanel is false & moves barcode box into cart',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = BusinessSettings(
      isConfigured: true,
      showPosProductPanel: false,
      compactPosProductList: true,
      autoFocusBarcodeSearch: true,
      enableCounterTokenQueue: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PosTerminalScreen(settings: settings),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pump();

    // Right catalog filter pills should NOT be rendered when panel is hidden
    expect(find.text('Featured Products'), findsNothing);
    // Inline barcode search box inside Cart header SHOULD be present
    expect(
      find.text('Scan barcode / search item / 2*SKU [Esc]'),
      findsOneWidget,
    );
    // Counter token button SHOULD be present
    expect(find.text('Send Token'), findsOneWidget);

    // Clicking the sidebar toggle icon in POS top bar brings back product panel smoothly
    await tester.tap(find.byTooltip('Show Product Grid / List Panel'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    });
    await tester.pumpAndSettle();
    expect(find.text('Featured Products'), findsOneWidget);
  });
}
