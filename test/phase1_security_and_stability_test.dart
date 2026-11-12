import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/app_logger.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/backup_update_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/local_api_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    AppLogger.resetConfiguration();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase1_sec_');
  });

  tearDown(() async {
    AuthService.resetSecurityStateForTest();
    AppLogger.resetConfiguration();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Phase 1.1: Authentication Hardening', () {
    test('Argon2id hashes use unique random salts and remove all hardcoded backdoors', () async {
      final db = await DatabaseService.initialize(
        customPath: p.join(tempDir.path, 'auth_hardening.db'),
      );
      try {
        // Fresh DB must have zero seeded default accounts
        expect(await db.getUsers(), isEmpty);

        // No hardcoded fallback logins work
        for (final badUser in ['admin', 'webdeventh', 'superadmin', 'salesman1']) {
          final res = await AuthService.loginDetailed(badUser, 'password');
          expect(res.success, isFalse);
        }

        // Password strength checks
        expect(AuthService.validatePasswordStrength('short'), isNotNull);
        expect(AuthService.validatePasswordStrength('password'), isNotNull);
        expect(AuthService.validatePasswordStrength('OnlyLettersHere'), isNotNull);
        expect(AuthService.validatePasswordStrength('1234567890'), isNotNull);
        expect(AuthService.validatePasswordStrength('StrongPos#2026'), isNull);

        // Setup Wizard creates sole superadmin with Argon2id hash
        final admin = await AuthService.registerSuperAdmin(
          name: 'Usman Tariq',
          username: 'usman_owner',
          password: 'OwnerStrong#2026',
        );
        expect(admin.isSuperAdmin, isTrue);
        expect(admin.password, startsWith('argon2id\$'));

        // Unique salts for same plaintext
        final h1 = AuthService.hashPassword('SameSecret#99');
        final h2 = AuthService.hashPassword('SameSecret#99');
        expect(h1, isNot(equals(h2)));
        expect(AuthService.verifyPassword('SameSecret#99', h1), isTrue);
        expect(AuthService.verifyPassword('SameSecret#99', h2), isTrue);
      } finally {
        await db.db.close();
      }
    });

    test('Brute-force lockout activates after 5 failed attempts and expires after 15 minutes', () async {
      final db = await DatabaseService.initialize(
        customPath: p.join(tempDir.path, 'lockout.db'),
      );
      try {
        DateTime fakeNow = DateTime(2026, 11, 11, 10, 0, 0);
        AuthService.nowProvider = () => fakeNow;

        await AuthService.registerSuperAdmin(
          name: 'Owner',
          username: 'lockowner',
          password: 'LockOwner#2026',
        );

        for (int i = 1; i <= 4; i++) {
          final res = await AuthService.loginDetailed('lockowner', 'WrongPass!$i');
          expect(res.success, isFalse);
          expect(res.isLockedOut, isFalse);
        }

        // 5th attempt triggers 15-minute lockout
        final fifth = await AuthService.loginDetailed('lockowner', 'WrongPass!5');
        expect(fifth.success, isFalse);
        expect(fifth.isLockedOut, isTrue);

        // Even the real password is rejected while locked out
        final blockedValid = await AuthService.loginDetailed('lockowner', 'LockOwner#2026');
        expect(blockedValid.success, isFalse);
        expect(blockedValid.isLockedOut, isTrue);

        // Advance clock by 16 minutes -> lockout clears automatically
        fakeNow = fakeNow.add(const Duration(minutes: 16));
        final recovered = await AuthService.loginDetailed('lockowner', 'LockOwner#2026');
        expect(recovered.success, isTrue);
      } finally {
        await db.db.close();
      }
    });

    test('Configurable session timeout logs out idle user and Forced Password Change completes', () async {
      final db = await DatabaseService.initialize(
        customPath: p.join(tempDir.path, 'session_force.db'),
      );
      try {
        DateTime fakeNow = DateTime(2026, 11, 11, 12, 0, 0);
        AuthService.nowProvider = () => fakeNow;
        AuthService.configureSessionTimeout(30);

        final currentSettings = await db.getBusinessSettings();
        await db.updateBusinessSettings(
          currentSettings.copyWith(sessionTimeoutMinutes: 30),
        );

        await AuthService.registerSuperAdmin(
          name: 'Admin User',
          username: 'sysadmin',
          password: 'InitialTemp#2026',
          mustChangePassword: true,
        );

        final loginRes = await AuthService.loginDetailed('sysadmin', 'InitialTemp#2026');
        expect(loginRes.success, isTrue);
        expect(loginRes.mustChangePassword, isTrue);
        expect(AuthService.currentUser?.mustChangePassword, isTrue);
        expect(AuthService.sessionTimeoutMinutes, 30);

        // Change password completes mandatory rotation
        final changeRes = await AuthService.changePassword(
          currentPassword: 'InitialTemp#2026',
          newPassword: 'RotatedAdmin#2026',
        );
        expect(changeRes.success, isTrue);
        expect(AuthService.currentUser?.mustChangePassword, isFalse);

        // Still valid after 20 minutes
        fakeNow = fakeNow.add(const Duration(minutes: 20));
        expect(await AuthService.checkSessionValidity(), isTrue);

        // Activity resets timer
        AuthService.recordActivity();
        fakeNow = fakeNow.add(const Duration(minutes: 20));
        expect(await AuthService.checkSessionValidity(), isTrue);

        // Idle for > 30 minutes expires session
        fakeNow = fakeNow.add(const Duration(minutes: 31));
        expect(await AuthService.checkSessionValidity(), isFalse);
        expect(AuthService.isAuthenticated, isFalse);
        expect(AuthService.sessionMessageNotifier.value, isNotNull);
      } finally {
        await db.db.close();
      }
    });

    test('Legacy SHA-256 hash seamlessly upgrades to Argon2id on login', () async {
      final db = await DatabaseService.initialize(
        customPath: p.join(tempDir.path, 'sha_upgrade.db'),
      );
      try {
        const legacySalt = 'SMART_POS_SALT_v1_2026_SECURE_AUTH';
        final legacyDigest = sha256
            .convert(utf8.encode('$legacySalt:Legacy@Pass2026:$legacySalt'))
            .toString();
        await db.addUser(User(
          name: 'Legacy User',
          username: 'legacy_sha',
          password: 'sha256\$$legacyDigest',
          role: 'manager',
          status: 'active',
        ));

        final res = await AuthService.loginDetailed('legacy_sha', 'Legacy@Pass2026');
        expect(res.success, isTrue);

        final refreshed = (await db.getUsers())
            .firstWhere((u) => u.username == 'legacy_sha');
        expect(refreshed.password, startsWith('argon2id\$'));
      } finally {
        await db.db.close();
      }
    });
  });

  group('Phase 1.2: Versioned Schema Migration (v1 -> v3)', () {
    test('Upgrades legacy v1 SQLite database preserving rows and hashing plaintext passwords', () async {
      final v1Path = p.join(tempDir.path, 'legacy_v1.db');
      final rawDb = await databaseFactoryFfi.openDatabase(
        v1Path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                username TEXT NOT NULL UNIQUE,
                password TEXT NOT NULL,
                role TEXT DEFAULT 'cashier',
                status TEXT DEFAULT 'active'
              )
            ''');
            await db.execute('''
              CREATE TABLE business_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                business_name TEXT NOT NULL,
                db_password TEXT DEFAULT ''
              )
            ''');
            await db.execute('''
              CREATE TABLE products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                sku TEXT NOT NULL UNIQUE,
                barcode TEXT NOT NULL,
                purchase_price REAL DEFAULT 0.0,
                selling_price REAL DEFAULT 0.0,
                stock_quantity REAL DEFAULT 0.0
              )
            ''');
            await db.insert('users', {
              'name': 'Old Owner',
              'username': 'old_owner',
              'password': 'oldPlainPassword',
              'role': 'superadmin',
              'status': 'active',
            });
            await db.insert('business_settings', {
              'id': 1,
              'business_name': 'Old Pharmacy',
              'db_password': 'plainMysqlSecret!',
            });
            await db.insert('products', {
              'name': 'Preserved Aspirin',
              'sku': 'ASP-100',
              'barcode': '896000001001',
              'purchase_price': 10.0,
              'selling_price': 15.0,
              'stock_quantity': 75.0,
            });
          },
        ),
      );
      await rawDb.close();

      // Re-open with current DatabaseService -> should upgrade v1 -> v3
      final upgraded = await DatabaseService.initialize(customPath: v1Path);
      try {
        expect(await upgraded.db.getVersion(), DatabaseService.currentSchemaVersion);

        // Verify schema_migrations table recorded v2 through v7 migrations
        final migrations = await upgraded.db.query('schema_migrations', orderBy: 'version ASC');
        expect(migrations.map((m) => m['version']).toList(), [2, 3, 4, 5, 6, 7]);

        // Verify PRAGMA added new columns to users & business_settings
        final userCols = await upgraded.db.rawQuery('PRAGMA table_info(users)');
        final userColNames = userCols.map((r) => r['name']).toSet();
        expect(userColNames.containsAll([
          'must_change_password',
          'failed_login_attempts',
          'locked_until',
          'password_changed_at',
        ]), isTrue);

        // Preserved product data
        final products = await upgraded.getProducts();
        expect(products.any((p) => p.sku == 'ASP-100' && p.stockQuantity == 75.0), isTrue);

        // Legacy plaintext password hashed to Argon2id with forced change flag
        final migratedUser = (await upgraded.getUsers())
            .firstWhere((u) => u.username == 'old_owner');
        expect(migratedUser.password, startsWith('argon2id\$'));
        expect(migratedUser.mustChangePassword, isTrue);
        expect(AuthService.verifyPassword('oldPlainPassword', migratedUser.password), isTrue);

        // Legacy plaintext DB password encrypted in raw table & decrypted on getter
        final rawSettings = (await upgraded.db.query('business_settings')).first;
        expect(rawSettings['db_password'].toString(), startsWith('enc:gcm1:'));
        final settings = await upgraded.getBusinessSettings();
        expect(settings.dbPassword, 'plainMysqlSecret!');
      } finally {
        await upgraded.db.close();
      }
    });
  });

  group('Phase 1.4 & 1.5: AES-256-GCM Encryption, Backups & AppLogger Rotation', () {
    test('AES-256-GCM field encryption detects tampering and encrypts stored secrets', () async {
      const secret = 'sk-live-secret-api-token-9988';
      final cipher = await DatabaseEncryptionService.encryptString(secret);
      expect(cipher, startsWith('enc:gcm1:'));
      expect(await DatabaseEncryptionService.decryptString(cipher), secret);

      // Tampering ciphertext/tag bytes must fail GCM authentication cleanly (empty string on field decrypt, exception on byte decrypt)
      final encParts = cipher.substring('enc:gcm1:'.length).split(':');
      expect(encParts.length, 2);
      final rawCipher = base64Decode(encParts[1]);
      rawCipher[rawCipher.length - 1] ^= 0xFF;
      final tampered = 'enc:gcm1:${encParts[0]}:${base64Encode(rawCipher)}';
      expect(await DatabaseEncryptionService.decryptString(tampered), isEmpty);

      final encBytes = await DatabaseEncryptionService.encryptBytes(
        Uint8List.fromList(utf8.encode('sensitive-vault-payload')),
      );
      encBytes[encBytes.length - 1] ^= 0xFF;
      await expectLater(
        DatabaseEncryptionService.decryptBytes(encBytes),
        throwsA(anything),
      );
    });

    test('Encrypted backup (.db.enc) & legacy .db restore roundtrip', () async {
      final dbPath = p.join(tempDir.path, 'backup_live.db');
      final db = await DatabaseService.initialize(customPath: dbPath);
      final prodId = await db.addProduct(
        Product(
          name: 'Backup Product Alpha',
          sku: 'BK-ALP-1',
          barcode: '896009998877',
          purchasePrice: 50.0,
          sellingPrice: 80.0,
          stockQuantity: 33.0,
        ),
      );
      await db.db.close();

      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final backupFile = await BackupUpdateService.instance.createBackup(
        targetDir: backupDir,
        dbPathOverride: dbPath,
      );
      expect(backupFile.path, endsWith('.db.enc'));
      expect(await DatabaseEncryptionService.isEncryptedFile(backupFile), isTrue);

      // Save an unencrypted legacy .db snapshot before closing to also verify legacy restore
      final legacyCopy = File(p.join(backupDir.path, 'legacy_plain.db'));
      await legacyCopy.parent.create(recursive: true);
      await File(dbPath).copy(legacyCopy.path);

      // Delete live DB, then restore from encrypted .db.enc backup
      await File(dbPath).delete();
      final ok = await BackupUpdateService.instance.restoreFromBackup(
        backupFile.path,
        dbPathOverride: dbPath,
      );
      expect(ok, isTrue);

      final restored = await DatabaseService.initialize(customPath: dbPath);
      try {
        final item = await restored.getProductById(prodId);
        expect(item, isNotNull);
        expect(item!.name, 'Backup Product Alpha');
        expect(item.stockQuantity, 33.0);
      } finally {
        await restored.db.close();
      }

      // Restore from legacy unencrypted .db backup as well
      await File(dbPath).delete();
      final legacyOk = await BackupUpdateService.instance.restoreFromBackup(
        legacyCopy.path,
        dbPathOverride: dbPath,
      );
      expect(legacyOk, isTrue);
      final restoredLegacy = await DatabaseService.initialize(customPath: dbPath);
      try {
        expect((await restoredLegacy.getProductById(prodId))?.name, 'Backup Product Alpha');
      } finally {
        await restoredLegacy.db.close();
      }
    });

    test('AppLogger writes to file and rotates when exceeding size limit', () {
      final logsDir = Directory(p.join(tempDir.path, 'logs'));
      AppLogger.configureForTest(
        logsDirectory: logsDir,
        enableFileWrites: true,
        maxBytes: 240,
        keepFiles: 3,
      );

      for (int i = 0; i < 12; i++) {
        AppLogger.error('RotationTest', 'Entry number $i with enough padding to rotate file');
      }

      final logFiles = logsDir.listSync().whereType<File>().toList();
      expect(logFiles.isNotEmpty, isTrue);
      expect(logFiles.length, lessThanOrEqualTo(3));
      final combined = logFiles.map((f) => f.readAsStringSync()).join('\n');
      expect(combined, contains('[ERROR] [RotationTest]'));
    });

    test('rotateEncryptionPassphrase preserves business, AI, and SMS encrypted secrets', () async {
      final dbPath = p.join(tempDir.path, 'key_rotation.db');
      final db = await DatabaseService.initialize(customPath: dbPath);
      try {
        final s = await db.getBusinessSettings();
        await db.updateBusinessSettings(
          s.copyWith(
            dbPassword: 'mysql-secret-pass',
            syncApiKey: 'sync-secret-token-77',
          ),
        );
        await db.saveAiSettings(
          AiSettings(provider: 'gemini', apiKey: 'AIzaTestSecretKey99', isEnabled: true),
        );
        await db.addSmsGateway(
          SmsGateway(
            name: 'Gateway 1',
            provider: 'generic_http',
            apiUrl: 'https://sms.example/send',
            apiKey: 'sms-key-123',
            apiSecret: 'sms-sec-456',
            isActive: true,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );

        await DatabaseEncryptionService.rotateEncryptionPassphrase(
          db,
          'RotatedStrongPass#2026',
        );

        final afterSettings = await db.getBusinessSettings();
        final afterAi = await db.getAiSettings();
        final afterSms = (await db.getSmsGateways())
            .firstWhere((g) => g.name == 'Gateway 1');
        expect(afterSettings.dbPassword, 'mysql-secret-pass');
        expect(afterSettings.syncApiKey, 'sync-secret-token-77');
        expect(afterAi.apiKey, 'AIzaTestSecretKey99');
        expect(afterSms.apiKey, 'sms-key-123');
        expect(afterSms.apiSecret, 'sms-sec-456');

        // Also verify ciphertext in raw SQLite rows starts with enc:gcm1:
        final rawAi = (await db.db.query('ai_settings')).first['api_key'].toString();
        final rawSms = (await db.db.query(
          'sms_gateways',
          where: 'name = ?',
          whereArgs: ['Gateway 1'],
        ))
            .first['api_secret']
            .toString();
        expect(rawAi, startsWith('enc:gcm1:'));
        expect(rawSms, startsWith('enc:gcm1:'));
      } finally {
        await db.db.close();
      }
    });

    test('addUser rejects duplicate username and factoryReset logs out active session', () async {
      final db = await DatabaseService.initialize(
        customPath: p.join(tempDir.path, 'user_collision.db'),
      );
      try {
        await AuthService.registerSuperAdmin(
          name: 'Primary Owner',
          username: 'owner_unique',
          password: 'OwnerStrong#2026',
        );
        expect(AuthService.isAuthenticated, isTrue);

        // Attempting to add another user with the same username must throw instead of overwriting owner
        await expectLater(
          db.addUser(
            User(
              name: 'Hijacker',
              username: 'owner_unique',
              password: AuthService.hashPassword('HijackPass#2026'),
              role: 'cashier',
            ),
          ),
          throwsStateError,
        );

        // Factory reset clears session cleanly
        await db.factoryResetForNewBusiness();
        expect(AuthService.isAuthenticated, isFalse);
        expect(AuthService.currentUser, isNull);
        expect(await db.getUsers(), isEmpty);
      } finally {
        await db.db.close();
      }
    });

    test('Live restore succeeds while DatabaseService handle is open on disk', () async {
      final dbPath = p.join(tempDir.path, 'live_restore.db');
      final db = await DatabaseService.initialize(customPath: dbPath);
      final prodId = await db.addProduct(
        Product(
          name: 'Pre-Snapshot Item',
          sku: 'LIVE-01',
          barcode: '896000010101',
          purchasePrice: 10.0,
          sellingPrice: 20.0,
          stockQuantity: 15.0,
        ),
      );
      final backupDir = Directory(p.join(tempDir.path, 'live_backups'));
      final backupFile = await BackupUpdateService.instance.createBackup(
        targetDir: backupDir,
        dbPathOverride: dbPath,
      );

      // Mutate live open DB after backup
      await db.addProduct(
        Product(
          name: 'Post-Snapshot Item',
          sku: 'LIVE-02',
          barcode: '896000020202',
          purchasePrice: 10.0,
          sellingPrice: 20.0,
          stockQuantity: 5.0,
        ),
      );

      // Restore WHILE live handle `db` is still open
      final ok = await BackupUpdateService.instance.restoreFromBackup(
        backupFile.path,
        dbPathOverride: dbPath,
      );
      expect(ok, isTrue);

      final reopened = DatabaseService.instance;
      try {
        expect((await reopened.getProductById(prodId))?.name, 'Pre-Snapshot Item');
        final products = await reopened.getProducts();
        expect(products.any((p) => p.sku == 'LIVE-02'), isFalse);
      } finally {
        await reopened.db.close();
      }
    });

    test('LocalApiService enforces Bearer/X-API-Key authentication when syncApiKey is set', () async {
      final db = await DatabaseService.initialize(
        customPath: p.join(tempDir.path, 'local_api_auth.db'),
      );
      final api = LocalApiService.instance;
      try {
        final s = await db.getBusinessSettings();
        await db.updateBusinessSettings(s.copyWith(syncApiKey: 'lan-secret-2026'));

        final started = await api.startServer(port: 9097);
        expect(started, isTrue);

        final client = HttpClient();
        try {
          final healthReq = await client.getUrl(Uri.parse('http://127.0.0.1:9097/health'));
          final healthRes = await healthReq.close();
          expect(healthRes.statusCode, HttpStatus.ok);

          final unauthReq = await client.getUrl(Uri.parse('http://127.0.0.1:9097/products'));
          final unauthRes = await unauthReq.close();
          expect(unauthRes.statusCode, HttpStatus.unauthorized);

          final authReq = await client.getUrl(Uri.parse('http://127.0.0.1:9097/products'));
          authReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer lan-secret-2026');
          final authRes = await authReq.close();
          expect(authRes.statusCode, HttpStatus.ok);
        } finally {
          client.close();
        }
      } finally {
        await api.stopServer();
        await db.db.close();
      }
    });

    test('WindowsCredentialStore native advapi32.dll roundtrip works on Windows', () async {
      if (!Platform.isWindows) return;
      final uniqueTarget = 'SmartPOS/SelfTest_${DateTime.now().microsecondsSinceEpoch}';
      const secretPayload = 'win32-cred-ffi-secret-key-256bit';

      WindowsCredentialStore.useInMemoryForTest = false;
      try {
        final wrote = await WindowsCredentialStore.writeSecret(
          targetName: uniqueTarget,
          secret: secretPayload,
        );
        expect(wrote, isTrue);

        final readBack = await WindowsCredentialStore.readSecret(uniqueTarget);
        expect(readBack, secretPayload);

        final deleted = await WindowsCredentialStore.deleteSecret(uniqueTarget);
        expect(deleted, isTrue);
        expect(await WindowsCredentialStore.readSecret(uniqueTarget), isNull);
      } finally {
        await WindowsCredentialStore.deleteSecret(uniqueTarget);
        WindowsCredentialStore.useInMemoryForTest = true;
      }
    });
  });
}
