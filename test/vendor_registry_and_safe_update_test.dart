import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/backup_update_service.dart';
import 'package:desktop_starter/services/cloud_sync_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/qulop_service.dart';
import 'package:desktop_starter/services/vendor_license_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Vendor Registry, Update Gate & Zero-Loss Upgrade Tests', () {
    tearDown(() {
      QulopService.qulopNotifier.value = null;
    });
    test('1. Signed key stores businessType and allowUpdates flag accurately',
        () async {
      final mac = await QulopService.getDeviceMacAddress();
      final keyWithUpdatesBlocked = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Al-Shifa Pharma',
        tierCode: 'YRL',
        businessType: 'pharmacy',
        allowUpdates: false,
      );

      final verified = await QulopService.verifyQulopKey(keyWithUpdatesBlocked);
      expect(verified.isValid, isTrue);
      expect(verified.businessType, equals('pharmacy'));
      expect(verified.allowUpdates, isFalse);

      final keyWithUpdatesAllowed = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Metro Mart',
        tierCode: 'LFT',
        businessType: 'supermarket',
        allowUpdates: true,
      );
      final verifiedAllowed =
          await QulopService.verifyQulopKey(keyWithUpdatesAllowed);
      expect(verifiedAllowed.isValid, isTrue);
      expect(verifiedAllowed.businessType, equals('supermarket'));
      expect(verifiedAllowed.allowUpdates, isTrue);
    });

    test(
        '2. VendorLicenseRegistryService persists records, exports JSON/CSV, and hashes installer for version.json',
        () async {
      final tmpDir =
          await Directory.systemTemp.createTemp('vendor_registry_test_');
      try {
        final regFile = File(p.join(tmpDir.path, 'vendor_licenses.json'));
        final cfgFile = File(p.join(tmpDir.path, 'vendor_sync_config.json'));
        final registry = VendorLicenseRegistryService(
          registryFileOverride: regFile,
          configFileOverride: cfgFile,
        );

        const rec = VendorLicenseRecord(
          id: 'lic-1',
          clientName: 'City Medicos',
          businessType: 'pharmacy',
          contactInfo: '+92 300 1112233',
          machineId: 'HWID-1234567890AB',
          tierCode: 'YRL',
          tierLabel: 'Yearly (12 Months)',
          generatedAt: '2026-11-25',
          nextRenewalDate: '2027-11-25',
          allowUpdates: true,
          licenseKey: 'QULOP-YRL-TEST-KEY',
        );

        await registry.upsertRecord(rec);
        final loaded = await registry.loadRecords();
        expect(loaded.length, equals(1));
        expect(loaded.first.clientName, equals('City Medicos'));
        expect(loaded.first.businessType, equals('pharmacy'));
        expect(loaded.first.nextRenewalDate, equals('2027-11-25'));

        final csv = registry.buildExportCsv(loaded);
        expect(csv, contains('City Medicos'));
        expect(csv, contains('pharmacy'));
        expect(csv, contains('2027-11-25'));

        final installerDummy = File(p.join(tmpDir.path, 'Setup.exe'));
        final exeBytes = [0x4D, 0x5A, 1, 2, 3, 4, 5, 6];
        await installerDummy.writeAsBytes(exeBytes, flush: true);

        final manifest =
            await VendorLicenseRegistryService.buildUpdateManifestForFile(
          installerFilePath: installerDummy.path,
          version: '1.1.2',
          buildNumber: 4,
          downloadUrl: 'https://example.com/Setup.exe',
          releaseNotes: 'Bug fixes',
        );
        expect(manifest['version'], equals('1.1.2'));
        expect(manifest['build'], equals(4));
        expect(
          manifest['sha256'],
          equals(sha256.convert(exeBytes).toString().toLowerCase()),
        );
      } finally {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      }
    });

    test(
        '3. Semantic version comparator accurately compares versions and builds',
        () {
      expect(
          BackupUpdateService.isNewerVersion('1.1.2', currentVersion: '1.1.1'),
          isTrue);
      expect(
          BackupUpdateService.isNewerVersion('1.2.0', currentVersion: '1.1.9'),
          isTrue);
      expect(
        BackupUpdateService.isNewerVersion(
          '1.1.1',
          currentVersion: '1.1.1',
          remoteBuild: 4,
          currentBuild: 3,
        ),
        isTrue,
      );
      expect(
        BackupUpdateService.isNewerVersion(
          '1.1.1',
          currentVersion: '1.1.1',
          remoteBuild: 3,
          currentBuild: 3,
        ),
        isFalse,
      );
      expect(
          BackupUpdateService.isNewerVersion('1.0.9', currentVersion: '1.1.1'),
          isFalse);
    });

    test(
        '4. checkOnlineUpdate enforces license validity, allowUpdates flag, and remote verification',
        () async {
      final mac = await QulopService.getDeviceMacAddress();

      final mockClient = MockClient((req) async {
        if (req.url.path.endsWith('version.json')) {
          return http.Response(
            jsonEncode({
              'version': '1.2.0',
              'build': 5,
              'download_url': 'https://updates.example.com/setup.exe',
              'sha256': 'abcd',
              'release_notes': 'Safe release',
              'license_verify_url': 'https://updates.example.com/verify',
            }),
            200,
          );
        }
        final reqJson = jsonDecode(req.body) as Map<String, dynamic>;
        final allow = reqJson['business_name'] != 'Revoked Store';
        return http.Response(
          jsonEncode({
            'allow_update': allow,
            'message': allow ? 'OK' : 'Subscription expired on server',
          }),
          200,
        );
      });

      // a) Expired trial -> blocked locally
      final expiredSettings = BusinessSettings(
        purchaseKey: '',
        trialStartDate:
            DateTime.now().subtract(const Duration(days: 40)).toIso8601String(),
      );
      final resExpired = await BackupUpdateService.instance.checkOnlineUpdate(
        settings: expiredSettings,
        feedUrlOverride: 'https://updates.example.com/version.json',
        httpClient: mockClient,
      );
      expect(resExpired['update_allowed'], isFalse);
      expect(resExpired['has_update'], isFalse);

      // b) Valid license with allowUpdates = false -> blocked locally
      final blockedKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Blocked Store',
        tierCode: 'YRL',
        allowUpdates: false,
      );
      final resFlagBlocked =
          await BackupUpdateService.instance.checkOnlineUpdate(
        settings: BusinessSettings(
          businessName: 'Blocked Store',
          purchaseKey: blockedKey,
        ),
        feedUrlOverride: 'https://updates.example.com/version.json',
        httpClient: mockClient,
      );
      expect(resFlagBlocked['update_allowed'], isFalse);
      expect(resFlagBlocked['has_update'], isFalse);

      // c) Valid license, denied remotely on website -> blocked
      final validKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Revoked Store',
        tierCode: 'YRL',
        allowUpdates: true,
      );
      final resRemoteBlocked =
          await BackupUpdateService.instance.checkOnlineUpdate(
        settings: BusinessSettings(
          businessName: 'Revoked Store',
          purchaseKey: validKey,
        ),
        feedUrlOverride: 'https://updates.example.com/version.json',
        httpClient: mockClient,
      );
      expect(resRemoteBlocked['update_allowed'], isFalse);
      expect(resRemoteBlocked['blocked_reason'],
          contains('Subscription expired on server'));

      // d) Valid active license -> update allowed and detected
      final allowedKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Healthy Store',
        tierCode: 'YRL',
        allowUpdates: true,
      );
      final resOk = await BackupUpdateService.instance.checkOnlineUpdate(
        settings: BusinessSettings(
          businessName: 'Healthy Store',
          purchaseKey: allowedKey,
        ),
        feedUrlOverride: 'https://updates.example.com/version.json',
        httpClient: mockClient,
      );
      expect(resOk['update_allowed'], isTrue);
      expect(resOk['has_update'], isTrue);
      expect(resOk['latest_version'], equals('1.2.0'));
    });

    test(
        '5. downloadAndPrepareSafeUpdate verifies MZ + SHA-256 and creates encrypted pre-update backup',
        () async {
      final tmpDir = await Directory.systemTemp.createTemp('safe_update_test_');
      try {
        final fakeDb = File(p.join(tmpDir.path, 'smart_pos.db'));
        await fakeDb.writeAsString('SQLite format 3\x00dummy-sales-data');

        final backupDir = Directory(p.join(tmpDir.path, 'backups'));
        final stagingDir = Directory(p.join(tmpDir.path, 'updates'));

        final validExeBytes = <int>[0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x04];
        final validHash = sha256.convert(validExeBytes).toString();

        final mac = await QulopService.getDeviceMacAddress();
        final validKey = QulopService.generatePurchaseKey(
          macAddress: mac,
          clientName: 'Safe Store',
          tierCode: 'YRL',
          allowUpdates: true,
        );
        final settings =
            BusinessSettings(businessName: 'Safe Store', purchaseKey: validKey);

        // Wrong hash must abort before writing installer
        final badHashClient =
            MockClient((_) async => http.Response.bytes(validExeBytes, 200));
        final badRes =
            await BackupUpdateService.instance.downloadAndPrepareSafeUpdate(
          updateInfo: {
            'latest_version': '1.2.0',
            'download_url': 'https://updates.example.com/Setup.exe',
            'sha256': '0000000000000000',
          },
          settings: settings,
          httpClient: badHashClient,
          backupDirOverride: backupDir,
          stagingDirOverride: stagingDir,
          dbPathOverride: fakeDb.path,
        );
        expect(badRes['success'], isFalse);
        expect(badRes['error'], contains('SHA-256'));

        // Valid PE executable + matching SHA-256 creates encrypted DB backup & staged installer
        final okClient =
            MockClient((_) async => http.Response.bytes(validExeBytes, 200));
        final okRes =
            await BackupUpdateService.instance.downloadAndPrepareSafeUpdate(
          updateInfo: {
            'latest_version': '1.2.0',
            'download_url': 'https://updates.example.com/Setup.exe',
            'sha256': validHash,
          },
          settings: settings,
          httpClient: okClient,
          backupDirOverride: backupDir,
          stagingDirOverride: stagingDir,
          dbPathOverride: fakeDb.path,
        );
        expect(okRes['success'], isTrue);
        final stagedFile = File(okRes['installer_path'] as String);
        final backupFile = File(okRes['backup_path'] as String);
        expect(stagedFile.existsSync(), isTrue);
        expect(backupFile.existsSync(), isTrue);
        expect(await DatabaseEncryptionService.isEncryptedFile(backupFile),
            isTrue);
      } finally {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      }
    });

    test(
        '6. License accessMode (offline/hybrid/online) encodes cleanly and gates CloudSyncService',
        () async {
      final mac = await QulopService.getDeviceMacAddress();

      final offlineKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Offline Client',
        tierCode: 'YRL',
        accessMode: 'offline',
      );
      final hybridKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Hybrid Client',
        tierCode: 'YRL',
        accessMode: 'hybrid',
      );
      final onlineKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Online Client',
        tierCode: 'YRL',
        accessMode: 'online',
      );

      final vOff = await QulopService.verifyQulopKey(offlineKey);
      final vHyb = await QulopService.verifyQulopKey(hybridKey);
      final vOn = await QulopService.verifyQulopKey(onlineKey);

      expect(vOff.accessMode, equals('offline'));
      expect(vOff.allowsHybridSync, isFalse);
      expect(vOff.allowsOnlineApi, isFalse);

      expect(vHyb.accessMode, equals('hybrid'));
      expect(vHyb.allowsHybridSync, isTrue);
      expect(vHyb.allowsOnlineApi, isFalse);

      expect(vOn.accessMode, equals('online'));
      expect(vOn.allowsHybridSync, isTrue);
      expect(vOn.allowsOnlineApi, isTrue);

      final blockedSyncRes = await CloudSyncService.syncNow(
        BusinessSettings(
          purchaseKey: offlineKey,
          syncMode: 'hybrid',
          syncServerUrl: 'https://webpixels.net/api',
        ),
      );
      expect(blockedSyncRes['success'], isFalse);
      expect(blockedSyncRes['message'], contains('does not allow'));
    });

    test(
        '7. Commercial package tiers restrict modules and live license upgrade unlocks Full Featured',
        () async {
      final mac = await QulopService.getDeviceMacAddress();

      // Starter license omits messaging (SMS/WhatsApp), accounting_crm, hrm, cloud_sync
      final starterKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Starter Kiryana',
        tierCode: 'YRL',
        packageTier: QulopService.pkgStarter,
        enabledFeatures:
            QulopService.featuresForPackageTier(QulopService.pkgStarter),
      );

      final starterSettings = BusinessSettings(
        businessName: 'Starter Kiryana',
        businessType: 'general_store',
        isConfigured: true,
        purchaseKey: starterKey,
        enabledModules: [
          BusinessSettings.moduleExpenses,
          BusinessSettings.moduleReturns,
          BusinessSettings.moduleMessaging,
          BusinessSettings.moduleCloudSync,
          BusinessSettings.moduleAccountingCrm,
        ].join(','),
      );

      final statusStarter =
          await QulopService.checkCurrentQulop(starterSettings);
      expect(statusStarter.isValid, isTrue);
      expect(statusStarter.packageTier, equals(QulopService.pkgStarter));
      expect(statusStarter.isFullFeatured, isFalse);

      // Core starter modules allowed, messaging & cloudSync & accounting blocked by license ceiling
      expect(starterSettings.isModuleEnabled(BusinessSettings.moduleExpenses),
          isTrue);
      expect(starterSettings.isModuleEnabled(BusinessSettings.moduleReturns),
          isTrue);
      expect(starterSettings.isModuleEnabled(BusinessSettings.moduleMessaging),
          isFalse);
      expect(starterSettings.isModuleEnabled(BusinessSettings.moduleCloudSync),
          isFalse);
      expect(
          starterSettings.isModuleEnabled(BusinessSettings.moduleAccountingCrm),
          isFalse);

      // Upgrade to Enterprise Full Featured key unlocks all commercial modules live
      final fullKey = QulopService.generatePurchaseKey(
        macAddress: mac,
        clientName: 'Starter Kiryana',
        tierCode: 'YRL',
        accessMode: 'hybrid',
        packageTier: QulopService.pkgEnterprise,
        enabledFeatures: const ['*'],
      );
      final upgradedMods = {
        ...starterSettings.activeModules,
        ...BusinessSettings.commercialFeatureKeys,
      }.join(',');
      final upgradedSettings = starterSettings.copyWith(
        purchaseKey: fullKey,
        enabledModules: upgradedMods,
      );
      final statusFull = await QulopService.checkCurrentQulop(upgradedSettings);

      expect(statusFull.isValid, isTrue);
      expect(statusFull.isFullFeatured, isTrue);
      expect(upgradedSettings.isModuleEnabled(BusinessSettings.moduleMessaging),
          isTrue);
      expect(upgradedSettings.isModuleEnabled(BusinessSettings.moduleCloudSync),
          isTrue);
      expect(
          upgradedSettings
              .isModuleEnabled(BusinessSettings.moduleAccountingCrm),
          isTrue);
      expect(
          upgradedSettings.isModuleEnabled(BusinessSettings.moduleHrm), isTrue);
    });
  });
}
