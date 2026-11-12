import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/navigation/app_routes.dart';
import 'package:desktop_starter/screens/products/discount_rules_screen.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';
import 'package:desktop_starter/widgets/skeleton_loader.dart';
import 'package:desktop_starter/widgets/smart_sidebar.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase8_golden_');
  });

  tearDown(() async {
    try {
      final inst = DatabaseService.instanceOrNull;
      if (inst != null &&
          inst.db.isOpen &&
          inst.dbFilePath != null &&
          inst.dbFilePath!.startsWith(tempDir.path)) {
        await DatabaseService.closeOpenInstanceIfPathMatches(inst.dbFilePath!);
      }
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('Golden: SmartSidebar expanded light theme', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: SmartSidebar(
            selectedRoute: AppRoute.dashboard,
            onSelect: (_) {},
            isCollapsed: false,
            settings: BusinessSettings(
              businessName: 'Golden Pharmacy',
              businessType: 'pharmacy',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(SmartSidebar),
      matchesGoldenFile('goldens/smart_sidebar_expanded_light.png'),
    );
  });

  testWidgets('Golden: SmartSidebar collapsed dark theme', (tester) async {
    tester.view.physicalSize = const Size(120, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SmartSidebar(
            selectedRoute: AppRoute.posTerminal,
            onSelect: (_) {},
            isCollapsed: true,
            settings: BusinessSettings(
              businessName: 'Golden Store',
              businessType: 'universal',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(SmartSidebar),
      matchesGoldenFile('goldens/smart_sidebar_collapsed_dark.png'),
    );
  });

  testWidgets('Golden: DashboardSkeletonView frame 0', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFFF8FAFC),
          body: DashboardSkeletonView(),
        ),
      ),
    );
    await tester.pump(Duration.zero);

    await expectLater(
      find.byType(DashboardSkeletonView),
      matchesGoldenFile('goldens/dashboard_skeleton_light.png'),
    );
  });

  testWidgets('Golden: DiscountRulesScreen clean empty state', (tester) async {
    final dbPath = p.join(tempDir.path, 'golden_discounts.db');
    await tester.runAsync(() async {
      await DatabaseService.initialize(customPath: dbPath);
    });

    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: DiscountRulesScreen(
            settings: BusinessSettings(
              businessName: 'Golden Mart',
              currencySymbol: 'Rs',
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();

    await expectLater(
      find.byType(DiscountRulesScreen),
      matchesGoldenFile('goldens/discount_rules_empty.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() async {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    });
  });
}
