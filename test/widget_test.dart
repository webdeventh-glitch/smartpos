import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/setup/setup_wizard_screen.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/qulop_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUpAll(() async {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
    await QulopService.getDeviceMacAddress();
    await QulopService.getHardwareId();
  });

  setUp(() async {
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_root_widget_');
    db = await DatabaseService.initialize(
      customPath: p.join(tempDir.path, 'test.db'),
    );
  });

  tearDown(() async {
    await db.db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Fresh SetupWizardScreen renders without prefilled default credentials', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = BusinessSettings(isConfigured: false);

    await tester.pumpWidget(
      MaterialApp(
        home: SetupWizardScreen(
          settings: settings,
          onSetupComplete: (_) {},
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();

    expect(find.byType(SetupWizardScreen), findsOneWidget);
    expect(find.text('webdeventh'), findsNothing);
    expect(find.text('password'), findsNothing);
  });
}
