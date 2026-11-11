import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app_logger.dart';
import 'database_service.dart';
import 'windows_credential_store.dart';

/// Manages AES-256-GCM encryption keys (stored in Windows Credential Store)
/// for securing sensitive database fields, encrypted database vaults, and
/// encrypted database backups, along with legacy plaintext migration.
class DatabaseEncryptionService {
  static const String credentialTargetMasterKey = 'SmartPOS/DatabaseMasterKey';
  static const String credentialTargetSalt = 'SmartPOS/DatabaseKeySalt';
  static const String fieldPrefix = 'enc:gcm1:';
  static final Uint8List _fileMagicHeader = utf8.encode('SMPOSENC1'); // 9 bytes

  static Uint8List? _cachedKey;

  /// Clears cached in-memory key (useful on logout/reset/tests).
  static void clearKeyCache() {
    _cachedKey = null;
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// Retrieves or provisions a 256-bit master encryption key stored in
  /// Windows Credential Store.
  static Future<Uint8List> getOrCreateMasterKey() async {
    if (_cachedKey != null && _cachedKey!.length == 32) {
      return _cachedKey!;
    }

    final storedB64 = await WindowsCredentialStore.readSecret(
      credentialTargetMasterKey,
    );
    if (storedB64 != null && storedB64.isNotEmpty) {
      try {
        final decoded = base64Decode(storedB64);
        if (decoded.length == 32) {
          _cachedKey = Uint8List.fromList(decoded);
          return _cachedKey!;
        }
      } catch (e, st) {
        AppLogger.warning(
          'DatabaseEncryption',
          'Stored key malformed; regenerating master key.',
          e,
          st,
        );
      }
    }

    final generated = _randomBytes(32);
    final written = await WindowsCredentialStore.writeSecret(
      targetName: credentialTargetMasterKey,
      secret: base64Encode(generated),
      comment: 'Smart POS AES-256 Database Encryption Master Key',
    );

    if (!written) {
      AppLogger.warning(
        'DatabaseEncryption',
        'Could not persist master key to Windows Credential Store; using ephemeral session key.',
      );
    } else {
      AppLogger.info(
        'DatabaseEncryption',
        'Provisioned new 256-bit database encryption key in Windows Credential Store.',
      );
    }

    _cachedKey = generated;
    return generated;
  }

  /// Derives and stores a 256-bit key from a user-supplied passphrase via Argon2id.
  static Future<void> configureUserPassphrase(String passphrase) async {
    final clean = passphrase.trim();
    if (clean.length < 8) {
      throw ArgumentError('Encryption passphrase must be at least 8 characters.');
    }

    final salt = _randomBytes(16);
    final derivator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          salt,
          desiredKeyLength: 32,
          iterations: 3,
          memoryPowerOf2: 12,
          lanes: 1,
        ),
      );
    final derivedKey = derivator.process(Uint8List.fromList(utf8.encode(clean)));

    await WindowsCredentialStore.writeSecret(
      targetName: credentialTargetSalt,
      secret: base64Encode(salt),
      comment: 'Smart POS Passphrase KDF Salt',
    );
    await WindowsCredentialStore.writeSecret(
      targetName: credentialTargetMasterKey,
      secret: base64Encode(derivedKey),
      comment: 'Smart POS Passphrase-Derived Database Key',
    );
    _cachedKey = derivedKey;
    AppLogger.info(
      'DatabaseEncryption',
      'Updated database encryption key in Windows Credential Store from custom passphrase.',
    );
  }

  /// Safely rotates the encryption key across ALL encrypted tables (`business_settings`,
  /// `ai_settings`, `sms_gateways`) and re-seals the vault snapshot so no saved
  /// secrets become undecryptable after changing the master passphrase.
  static Future<void> rotateEncryptionPassphrase(
    DatabaseService dbService,
    String passphrase,
  ) async {
    // 1. Decrypt all sensitive fields under the current key BEFORE changing it
    final db = dbService.db;
    final settingsRows = await db.query('business_settings');
    final decryptedSettings = <int, Map<String, String>>{};
    for (final row in settingsRows) {
      final id = row['id'] as int?;
      if (id == null) continue;
      decryptedSettings[id] = {
        'db_password': await decryptString(row['db_password'] as String?),
        'sync_api_key': await decryptString(row['sync_api_key'] as String?),
      };
    }

    final aiRows = await db.query('ai_settings');
    final decryptedAi = <int, String>{};
    for (final row in aiRows) {
      final id = row['id'] as int?;
      final raw = row['api_key'] as String?;
      if (id != null && raw != null && raw.isNotEmpty) {
        decryptedAi[id] = await decryptString(raw);
      }
    }

    final smsRows = await db.query('sms_gateways');
    final decryptedSms = <int, Map<String, String>>{};
    for (final row in smsRows) {
      final id = row['id'] as int?;
      if (id == null) continue;
      decryptedSms[id] = {
        'api_key': await decryptString(row['api_key'] as String?),
        'api_secret': await decryptString(row['api_secret'] as String?),
      };
    }

    // 2. Derive and store the new master key in Windows Credential Store
    await configureUserPassphrase(passphrase);

    // 3. Pre-compute re-encrypted values under the NEW key, then commit atomically
    final reEncryptedSettings = <int, Map<String, String>>{};
    for (final entry in decryptedSettings.entries) {
      reEncryptedSettings[entry.key] = {
        'db_password': entry.value['db_password']!.isEmpty
            ? ''
            : await encryptString(entry.value['db_password']!),
        'sync_api_key': entry.value['sync_api_key']!.isEmpty
            ? ''
            : await encryptString(entry.value['sync_api_key']!),
      };
    }
    final reEncryptedAi = <int, String>{};
    for (final entry in decryptedAi.entries) {
      reEncryptedAi[entry.key] =
          entry.value.isEmpty ? '' : await encryptString(entry.value);
    }
    final reEncryptedSms = <int, Map<String, String>>{};
    for (final entry in decryptedSms.entries) {
      reEncryptedSms[entry.key] = {
        'api_key': entry.value['api_key']!.isEmpty
            ? ''
            : await encryptString(entry.value['api_key']!),
        'api_secret': entry.value['api_secret']!.isEmpty
            ? ''
            : await encryptString(entry.value['api_secret']!),
      };
    }

    await db.transaction((txn) async {
      for (final entry in reEncryptedSettings.entries) {
        await txn.update(
          'business_settings',
          entry.value,
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
      for (final entry in reEncryptedAi.entries) {
        await txn.update(
          'ai_settings',
          {'api_key': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
      for (final entry in reEncryptedSms.entries) {
        await txn.update(
          'sms_gateways',
          entry.value,
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });

    if (dbService.dbFilePath != null &&
        dbService.dbFilePath != inMemoryDatabasePath) {
      await dbService.checkpointWal();
      await sealVaultSnapshot(dbService.dbFilePath!);
    }
  }

  /// Returns true if the string is already AES-256-GCM encrypted.
  static bool isEncryptedValue(String? value) {
    return value != null && value.startsWith(fieldPrefix);
  }

  /// Encrypts a sensitive string using AES-256-GCM. Empty strings stay empty.
  static Future<String> encryptString(String plaintext) async {
    if (plaintext.isEmpty) return '';
    if (isEncryptedValue(plaintext)) return plaintext;

    final key = await getOrCreateMasterKey();
    final nonce = _randomBytes(12);
    final input = Uint8List.fromList(utf8.encode(plaintext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    final output = cipher.process(input);

    return '$fieldPrefix${base64Encode(nonce)}:${base64Encode(output)}';
  }

  /// Decrypts an `enc:gcm1:...` string. Legacy plaintext values pass through cleanly.
  static Future<String> decryptString(String? stored) async {
    if (stored == null || stored.isEmpty) return '';
    if (!isEncryptedValue(stored)) return stored;

    try {
      final payload = stored.substring(fieldPrefix.length);
      final parts = payload.split(':');
      if (parts.length != 2) {
        throw const FormatException('Invalid encrypted field payload');
      }
      final nonce = base64Decode(parts[0]);
      final cipherText = base64Decode(parts[1]);
      final key = await getOrCreateMasterKey();

      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
        );
      final plainBytes = cipher.process(cipherText);
      return utf8.decode(plainBytes);
    } catch (e, st) {
      AppLogger.error(
        'DatabaseEncryption',
        'Failed to decrypt sensitive database field.',
        e,
        st,
      );
      return '';
    }
  }

  /// Encrypts raw bytes into `SMPOSENC1` + 12-byte nonce + AES-256-GCM payload.
  static Future<Uint8List> encryptBytes(Uint8List plainBytes) async {
    final key = await getOrCreateMasterKey();
    final nonce = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, nonce, _fileMagicHeader),
      );
    final cipherBytes = cipher.process(plainBytes);

    final out = BytesBuilder(copy: false)
      ..add(_fileMagicHeader)
      ..add(nonce)
      ..add(cipherBytes);
    return out.toBytes();
  }

  /// Decrypts an `SMPOSENC1` payload back into raw bytes.
  static Future<Uint8List> decryptBytes(Uint8List encryptedBytes) async {
    if (!hasEncryptedHeader(encryptedBytes)) {
      return encryptedBytes; // Legacy unencrypted file bytes
    }
    const headerLen = 9;
    const nonceLen = 12;
    if (encryptedBytes.length <= headerLen + nonceLen + 16) {
      throw const FormatException('Encrypted database file is truncated.');
    }
    final nonce = encryptedBytes.sublist(headerLen, headerLen + nonceLen);
    final cipherText = encryptedBytes.sublist(headerLen + nonceLen);
    final key = await getOrCreateMasterKey();

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), 128, nonce, _fileMagicHeader),
      );
    return cipher.process(cipherText);
  }

  static bool hasEncryptedHeader(Uint8List bytes) {
    if (bytes.length < _fileMagicHeader.length) return false;
    for (int i = 0; i < _fileMagicHeader.length; i++) {
      if (bytes[i] != _fileMagicHeader[i]) return false;
    }
    return true;
  }

  static Future<bool> isEncryptedFile(File file) async {
    if (!file.existsSync()) return false;
    final raf = await file.open();
    try {
      final header = await raf.read(_fileMagicHeader.length);
      return hasEncryptedHeader(header);
    } finally {
      await raf.close();
    }
  }

  /// Encrypts a file (e.g., `smart_pos.db` -> `smart_pos.db.enc`).
  static Future<File> encryptFile(File source, File destination) async {
    final plainBytes = await source.readAsBytes();
    final encBytes = await encryptBytes(plainBytes);
    await destination.writeAsBytes(encBytes, flush: true);
    return destination;
  }

  /// Decrypts an encrypted file (or copies if already unencrypted SQLite).
  static Future<File> decryptFile(File source, File destination) async {
    final raw = await source.readAsBytes();
    final plainBytes = await decryptBytes(raw);
    await destination.writeAsBytes(plainBytes, flush: true);
    return destination;
  }

  /// Path to the encrypted vault file alongside `smart_pos.db`.
  static String vaultPathFor(String dbPath) => '$dbPath.enc';

  /// If `smart_pos.db.enc` exists and active `smart_pos.db` does not, unseal it.
  static Future<void> unsealVaultIfNeeded(String dbPath) async {
    if (dbPath == inMemoryDatabasePath) return;
    final dbFile = File(dbPath);
    final vaultFile = File(vaultPathFor(dbPath));

    if (!dbFile.existsSync() && vaultFile.existsSync()) {
      AppLogger.info(
        'DatabaseEncryption',
        'Restoring local database from encrypted vault ${vaultFile.path}.',
      );
      await decryptFile(vaultFile, dbFile);
    } else if (dbFile.existsSync() && await isEncryptedFile(dbFile)) {
      // Legacy case if db file itself was encrypted in place
      final bytes = await dbFile.readAsBytes();
      final decrypted = await decryptBytes(bytes);
      await dbFile.writeAsBytes(decrypted, flush: true);
    }
  }

  /// Seals an encrypted snapshot vault (`smart_pos.db.enc`) of the active database.
  static Future<void> sealVaultSnapshot(String dbPath) async {
    if (dbPath == inMemoryDatabasePath) return;
    final openInst = DatabaseService.instanceOrNull;
    if (openInst != null && openInst.dbFilePath == dbPath) {
      await openInst.checkpointWal();
    }
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) return;
    final vaultFile = File(vaultPathFor(dbPath));
    await encryptFile(dbFile, vaultFile);
  }

  /// Migrates legacy plaintext secrets inside an existing SQLite database to
  /// AES-256-GCM encrypted format and updates the encrypted vault snapshot.
  static Future<int> migratePlaintextSecrets(Database db, {String? dbPath}) async {
    await getOrCreateMasterKey();
    int migratedCount = 0;

    // 1. Encrypt business_settings credentials (db_password, sync_api_key)
    final settingsRows = await db.query('business_settings');
    for (final row in settingsRows) {
      final id = row['id'];
      final updates = <String, Object?>{};
      for (final col in ['db_password', 'sync_api_key']) {
        final raw = row[col] as String?;
        if (raw != null && raw.isNotEmpty && !isEncryptedValue(raw)) {
          updates[col] = await encryptString(raw);
          migratedCount++;
        }
      }
      if (updates.isNotEmpty && id != null) {
        await db.update('business_settings', updates, where: 'id = ?', whereArgs: [id]);
      }
    }

    // 2. Encrypt ai_settings api_key
    try {
      final aiRows = await db.query('ai_settings');
      for (final row in aiRows) {
        final id = row['id'];
        final raw = row['api_key'] as String?;
        if (raw != null && raw.isNotEmpty && !isEncryptedValue(raw)) {
          await db.update(
            'ai_settings',
            {'api_key': await encryptString(raw)},
            where: 'id = ?',
            whereArgs: [id],
          );
          migratedCount++;
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseEncryption', 'Skipped ai_settings secret migration', e, st);
    }

    // 3. Encrypt sms_gateways api_key & api_secret
    try {
      final gwRows = await db.query('sms_gateways');
      for (final row in gwRows) {
        final id = row['id'];
        final updates = <String, Object?>{};
        for (final col in ['api_key', 'api_secret']) {
          final raw = row[col] as String?;
          if (raw != null && raw.isNotEmpty && !isEncryptedValue(raw)) {
            updates[col] = await encryptString(raw);
            migratedCount++;
          }
        }
        if (updates.isNotEmpty && id != null) {
          await db.update('sms_gateways', updates, where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseEncryption', 'Skipped sms_gateways secret migration', e, st);
    }

    if (dbPath != null && dbPath != inMemoryDatabasePath) {
      try {
        await sealVaultSnapshot(dbPath);
      } catch (e, st) {
        AppLogger.warning('DatabaseEncryption', 'Could not seal vault snapshot', e, st);
      }
    }

    if (migratedCount > 0) {
      AppLogger.info(
        'DatabaseEncryption',
        'Migrated $migratedCount plaintext credential field(s) to AES-256-GCM.',
      );
    }
    return migratedCount;
  }
}

