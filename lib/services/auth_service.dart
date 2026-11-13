import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import '../models/models.dart';
import 'app_logger.dart';
import 'database_encryption_service.dart';
import 'database_service.dart';

class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;
  final bool isLockedOut;
  final int? remainingAttempts;
  final DateTime? lockedUntil;
  final bool mustChangePassword;

  const AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
    this.isLockedOut = false,
    this.remainingAttempts,
    this.lockedUntil,
    this.mustChangePassword = false,
  });
}

class _InMemoryAttemptState {
  int attempts = 0;
  DateTime? lockedUntil;
}

class AuthService {
  static final ValueNotifier<User?> currentUserNotifier =
      ValueNotifier<User?>(null);
  static final ValueNotifier<String?> sessionMessageNotifier =
      ValueNotifier<String?>(null);

  static User? get currentUser => currentUserNotifier.value;
  static bool get isAuthenticated => currentUserNotifier.value != null;

  // Brute-force lockout policy
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static final Map<String, _InMemoryAttemptState> _unknownUserAttempts =
      <String, _InMemoryAttemptState>{};

  // Session timeout tracking (default 8 hours = 480 minutes)
  static const int defaultSessionTimeoutMinutes = 480;
  static int _sessionTimeoutMinutes = defaultSessionTimeoutMinutes;
  static DateTime? _loginTime;
  static DateTime? _lastActivityTime;
  static DateTime Function() nowProvider = DateTime.now;

  // Legacy salt used strictly for one-time migration of pre-Argon2id hashes
  static const String _legacyMigrationSalt =
      'SMART_POS_SALT_v1_2026_SECURE_AUTH';

  static int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  static DateTime? get loginTime => _loginTime;
  static DateTime? get lastActivityTime => _lastActivityTime;

  static void configureSessionTimeout(int minutes) {
    _sessionTimeoutMinutes = minutes <= 0 ? 0 : minutes;
  }

  static void recordActivity() {
    if (currentUserNotifier.value != null) {
      _lastActivityTime = nowProvider();
    }
  }

  static bool get isSessionExpired {
    final user = currentUserNotifier.value;
    if (user == null || _sessionTimeoutMinutes <= 0) return false;
    final ref = _lastActivityTime ?? _loginTime;
    if (ref == null) return false;
    return nowProvider().difference(ref) >=
        Duration(minutes: _sessionTimeoutMinutes);
  }

  /// Checks active session validity; auto-logs out if idle past timeout.
  static Future<bool> checkSessionValidity() async {
    if (currentUserNotifier.value == null) return false;
    if (isSessionExpired) {
      final mins = _sessionTimeoutMinutes;
      final hoursLabel = mins >= 60 && mins % 60 == 0
          ? '${mins ~/ 60} hour(s)'
          : '$mins minute(s)';
      AppLogger.info(
        'AuthService',
        'Session timed out for "${currentUserNotifier.value?.username}" after $hoursLabel of inactivity.',
      );
      await logout(
        reason:
            'Your session timed out after $hoursLabel of inactivity. Please sign in again.',
      );
      return false;
    }
    return true;
  }

  /// Resets in-memory brute-force counters & session state (intended for tests).
  static void resetSecurityStateForTest() {
    _unknownUserAttempts.clear();
    _loginTime = null;
    _lastActivityTime = null;
    _sessionTimeoutMinutes = defaultSessionTimeoutMinutes;
    sessionMessageNotifier.value = null;
    nowProvider = DateTime.now;
  }

  /// Hashes a password with Argon2id and a unique 16-byte random salt.
  /// Stored format: `argon2id$v=19$m=4096,t=3,p=1$<saltB64>$<hashB64>`
  static String hashPassword(String password) {
    final clean = password.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }
    final rng = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );
    const memoryPow2 = 12; // 4096 KiB
    const iterations = 3;
    const lanes = 1;
    const keyLength = 32;

    final derivator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          salt,
          desiredKeyLength: keyLength,
          iterations: iterations,
          memoryPowerOf2: memoryPow2,
          lanes: lanes,
        ),
      );

    final hash = derivator.process(Uint8List.fromList(utf8.encode(clean)));
    return 'argon2id\$v=19\$m=${1 << memoryPow2},t=$iterations,p=$lanes\$${base64Url.encode(salt)}\$${base64Url.encode(hash)}';
  }

  /// Verifies an input password against an Argon2id stored hash using
  /// constant-time comparison. Never accepts plaintext passwords.
  static bool verifyPassword(String inputPassword, String storedHash) {
    final cleanInput = inputPassword.trim();
    final cleanStored = storedHash.trim();
    if (cleanInput.isEmpty || cleanStored.isEmpty) return false;
    if (!cleanStored.startsWith('argon2id\$')) return false;

    try {
      final parts = cleanStored.split('\$');
      // Expected: ['argon2id', 'v=19', 'm=4096,t=3,p=1', '<saltB64>', '<hashB64>']
      if (parts.length != 5) return false;

      int memoryKiB = 4096;
      int iterations = 3;
      int lanes = 1;
      for (final kv in parts[2].split(',')) {
        final pair = kv.split('=');
        if (pair.length != 2) continue;
        final v = int.tryParse(pair[1]);
        if (v == null) continue;
        if (pair[0] == 'm') memoryKiB = v;
        if (pair[0] == 't') iterations = v;
        if (pair[0] == 'p') lanes = v;
      }

      final salt = Uint8List.fromList(base64Url.decode(parts[3]));
      final expectedHash = Uint8List.fromList(base64Url.decode(parts[4]));

      final derivator = Argon2BytesGenerator()
        ..init(
          Argon2Parameters(
            Argon2Parameters.ARGON2_id,
            salt,
            desiredKeyLength: expectedHash.length,
            iterations: iterations,
            memory: memoryKiB,
            lanes: lanes,
          ),
        );

      final actualHash =
          derivator.process(Uint8List.fromList(utf8.encode(cleanInput)));
      return _constantTimeEquals(actualHash, expectedHash);
    } catch (e, st) {
      AppLogger.warning(
          'AuthService', 'Malformed password hash encountered', e, st);
      return false;
    }
  }

  /// Legacy SHA-256 verification ONLY used to upgrade old accounts during login.
  static bool _verifyLegacySha256(String inputPassword, String legacyHash) {
    if (!legacyHash.startsWith('sha256\$')) return false;
    final bytes = utf8
        .encode('$_legacyMigrationSalt:$inputPassword:$_legacyMigrationSalt');
    final digest = sha256.convert(bytes);
    return 'sha256\$${digest.toString()}' == legacyHash;
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Validates password strength for user creation & forced password rotation.
  static String? validatePasswordStrength(String password,
      {String? oldPassword}) {
    final p = password.trim();
    if (p.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (p.toLowerCase() == 'password' ||
        p.toLowerCase() == '12345678' ||
        p.toLowerCase() == 'admin123') {
      return 'Please choose a stronger password (common defaults are not allowed).';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'[0-9]').hasMatch(p)) {
      return 'Password must contain at least one letter and one number.';
    }
    if (oldPassword != null && p == oldPassword.trim()) {
      return 'New password must be different from your current password.';
    }
    return null;
  }

  /// Authenticate strictly against the SQLite `users` table with brute-force
  /// lockout protection and automatic legacy hash upgrade.
  static Future<AuthResult> loginDetailed(
    String username,
    String password,
  ) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanUser.isEmpty || cleanPass.isEmpty) {
      return const AuthResult(
        success: false,
        errorMessage: 'Username and password are required.',
      );
    }

    try {
      final db = await DatabaseService.initialize();
      final settings = await db.getBusinessSettings();
      configureSessionTimeout(settings.sessionTimeoutMinutes);

      final users = await db.getUsers();
      User? matched;
      for (final u in users) {
        if (u.username.trim().toLowerCase() == cleanUser) {
          matched = u;
          break;
        }
      }

      final now = nowProvider();

      // Unknown username — track brute-force attempts without revealing account existence
      if (matched == null) {
        final state = _unknownUserAttempts.putIfAbsent(
          cleanUser,
          () => _InMemoryAttemptState(),
        );
        if (state.lockedUntil != null && now.isBefore(state.lockedUntil!)) {
          final remainingMins =
              max(1, state.lockedUntil!.difference(now).inMinutes + 1);
          return AuthResult(
            success: false,
            isLockedOut: true,
            lockedUntil: state.lockedUntil,
            errorMessage:
                'Too many failed login attempts. Try again in $remainingMins minute(s).',
          );
        } else if (state.lockedUntil != null &&
            !now.isBefore(state.lockedUntil!)) {
          state.attempts = 0;
          state.lockedUntil = null;
        }

        state.attempts += 1;
        if (state.attempts >= maxFailedAttempts) {
          state.lockedUntil = now.add(lockoutDuration);
          AppLogger.warning(
            'AuthService',
            'Brute-force lockout triggered for unknown username "$cleanUser".',
          );
          return AuthResult(
            success: false,
            isLockedOut: true,
            lockedUntil: state.lockedUntil,
            remainingAttempts: 0,
            errorMessage:
                'Account temporarily locked after $maxFailedAttempts failed attempts. Try again in ${lockoutDuration.inMinutes} minutes.',
          );
        }

        final remaining = maxFailedAttempts - state.attempts;
        AppLogger.warning('AuthService',
            'Failed login attempt for unknown username "$cleanUser".');
        return AuthResult(
          success: false,
          remainingAttempts: remaining,
          errorMessage:
              'Invalid username or password. $remaining attempt(s) remaining before lockout.',
        );
      }

      // Inactive account check
      if (matched.status.toLowerCase() != 'active') {
        AppLogger.warning(
          'AuthService',
          'Login rejected for inactive user "${matched.username}".',
        );
        return const AuthResult(
          success: false,
          errorMessage: 'This account is inactive. Contact your administrator.',
        );
      }

      // Check active brute-force lockout persisted in DB
      if (matched.lockedUntil != null && matched.lockedUntil!.isNotEmpty) {
        final lockedDt = DateTime.tryParse(matched.lockedUntil!);
        if (lockedDt != null && now.isBefore(lockedDt)) {
          final remainingMins = max(1, lockedDt.difference(now).inMinutes + 1);
          AppLogger.warning(
            'AuthService',
            'Blocked login while locked for "${matched.username}" ($remainingMins min remaining).',
          );
          return AuthResult(
            success: false,
            isLockedOut: true,
            lockedUntil: lockedDt,
            remainingAttempts: 0,
            errorMessage:
                'Account locked due to $maxFailedAttempts failed attempts. Try again in $remainingMins minute(s).',
          );
        }
        // Lockout expired — reset counters
        matched = matched.copyWith(
          failedLoginAttempts: 0,
          clearLockedUntil: true,
        );
        await db.updateUser(matched);
      }

      bool valid = verifyPassword(cleanPass, matched.password);
      bool upgradedFromLegacyHash = false;

      if (!valid && _verifyLegacySha256(cleanPass, matched.password)) {
        valid = true;
        upgradedFromLegacyHash = true;
      }

      if (!valid) {
        final newAttempts = matched.failedLoginAttempts + 1;
        DateTime? lockTime;
        if (newAttempts >= maxFailedAttempts) {
          lockTime = now.add(lockoutDuration);
        }
        final updatedUser = matched.copyWith(
          failedLoginAttempts: newAttempts,
          lockedUntil: lockTime?.toIso8601String(),
        );
        await db.updateUser(updatedUser);

        try {
          await db.logAuditAction(
            action: lockTime != null ? 'login_lockout' : 'login_failed',
            entityType: 'user',
            entityId: '${matched.id ?? ''}',
            userId: matched.id,
            userName: matched.username,
            details: lockTime != null
                ? 'Locked account after $newAttempts failed login attempts.'
                : 'Failed login attempt ($newAttempts/$maxFailedAttempts).',
          );
        } catch (auditErr, auditSt) {
          AppLogger.warning('AuthService', 'Audit log failed on login failure',
              auditErr, auditSt);
        }

        if (lockTime != null) {
          AppLogger.warning(
            'AuthService',
            'Account "${matched.username}" locked for ${lockoutDuration.inMinutes} minutes.',
          );
          return AuthResult(
            success: false,
            isLockedOut: true,
            lockedUntil: lockTime,
            remainingAttempts: 0,
            errorMessage:
                'Account locked after $maxFailedAttempts failed attempts. Try again in ${lockoutDuration.inMinutes} minutes.',
          );
        }

        final remaining = maxFailedAttempts - newAttempts;
        AppLogger.warning(
          'AuthService',
          'Failed login for "${matched.username}" ($newAttempts/$maxFailedAttempts).',
        );
        return AuthResult(
          success: false,
          remainingAttempts: remaining,
          errorMessage:
              'Invalid username or password. $remaining attempt(s) remaining before lockout.',
        );
      }

      // Successful login: reset lockout counters, upgrade legacy hash, & load DB RBAC permissions
      final rawTokens = matched.permissions
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final hadStaleRbacCache =
          rawTokens.any((t) => t.toLowerCase() == '__rbac__');
      final cleanedDbPermissions = hadStaleRbacCache
          ? rawTokens
              .where((t) => t.startsWith('+') || t.startsWith('-'))
              .join(',')
          : matched.permissions;

      final baseUser = matched.copyWith(
        failedLoginAttempts: 0,
        clearLockedUntil: true,
        password:
            upgradedFromLegacyHash ? hashPassword(cleanPass) : matched.password,
        canViewCostPrice:
            matched.isSuperAdmin ? true : matched.canViewCostPrice,
        permissions: cleanedDbPermissions,
      );
      final effectivePerms =
          await db.authRepo.getEffectivePermissionsForUser(baseUser);
      final effectiveUser = baseUser.copyWith(
        permissions: {'__rbac__', ...effectivePerms}.join(','),
      );

      // Persist only baseUser (without resolved __rbac__ cache) so role updates stay dynamic.
      if (upgradedFromLegacyHash ||
          matched.failedLoginAttempts > 0 ||
          matched.lockedUntil != null ||
          hadStaleRbacCache) {
        await db.updateUser(baseUser);
      }

      _unknownUserAttempts.remove(cleanUser);
      _loginTime = now;
      _lastActivityTime = now;
      sessionMessageNotifier.value = null;
      currentUserNotifier.value = effectiveUser;

      AppLogger.info(
          'AuthService', 'User "${effectiveUser.username}" signed in.');
      try {
        await db.logAuditAction(
          action: 'login_success',
          entityType: 'user',
          entityId: '${effectiveUser.id ?? ''}',
          userId: effectiveUser.id,
          userName: effectiveUser.username,
          details: effectiveUser.mustChangePassword
              ? 'Signed in (password rotation required).'
              : 'Signed in successfully.',
        );
      } catch (auditErr, auditSt) {
        AppLogger.warning('AuthService', 'Audit log failed on login success',
            auditErr, auditSt);
      }

      return AuthResult(
        success: true,
        user: effectiveUser,
        mustChangePassword: effectiveUser.mustChangePassword,
      );
    } catch (e, st) {
      AppLogger.error('AuthService', 'Authentication system failure', e, st);
      return AuthResult(
        success: false,
        errorMessage: 'Authentication system error: $e',
      );
    }
  }

  /// Backward-compatible boolean login helper.
  static Future<bool> login(String username, String password) async {
    final res = await loginDetailed(username, password);
    return res.success;
  }

  /// Register or create Super Admin account with Argon2id + random salt.
  static Future<User> registerSuperAdmin({
    required String name,
    required String username,
    required String password,
    String email = '',
    String phone = '',
    bool mustChangePassword = false,
  }) async {
    final cleanUser = username.trim();
    if (cleanUser.isEmpty) {
      throw ArgumentError('Username cannot be empty.');
    }
    final hashedPassword = hashPassword(password);
    final user = User(
      name: name.trim().isNotEmpty ? name.trim() : 'Super Administrator',
      username: cleanUser,
      password: hashedPassword,
      email: email.trim(),
      phone: phone.trim(),
      role: 'superadmin',
      status: 'active',
      branchId: 1,
      branchName: 'Main Branch HQ',
      canViewCostPrice: true,
      canAccessInventory: true,
      canAccessReports: true,
      canAccessSettings: true,
      canManageUsers: true,
      canDeleteSale: true,
      canProcessReturn: true,
      canEditPrice: true,
      canGiveDiscount: true,
      maxDiscountPercent: 100.0,
      mustChangePassword: mustChangePassword,
      passwordChangedAt: DateTime.now().toIso8601String(),
    );
    final db = await DatabaseService.initialize();
    final id = await db.addUser(user);
    final persisted = user.copyWith(id: id);
    _loginTime = nowProvider();
    _lastActivityTime = _loginTime;
    currentUserNotifier.value = persisted;
    return persisted;
  }

  /// Rotates the currently logged-in user's password and clears `mustChangePassword`.
  static Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUserNotifier.value;
    if (user == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'No active user session.',
      );
    }

    final isCurrentValid = verifyPassword(currentPassword, user.password) ||
        _verifyLegacySha256(currentPassword, user.password);
    if (!isCurrentValid) {
      return const AuthResult(
        success: false,
        errorMessage: 'Current password is incorrect.',
      );
    }

    final strengthError = validatePasswordStrength(
      newPassword,
      oldPassword: currentPassword,
    );
    if (strengthError != null) {
      return AuthResult(success: false, errorMessage: strengthError);
    }

    final updated = user.copyWith(
      password: hashPassword(newPassword),
      mustChangePassword: false,
      passwordChangedAt: nowProvider().toIso8601String(),
      failedLoginAttempts: 0,
      clearLockedUntil: true,
    );

    final db = await DatabaseService.initialize();
    await db.updateUser(updated);
    currentUserNotifier.value = updated;
    recordActivity();

    try {
      await db.logAuditAction(
        action: 'password_changed',
        entityType: 'user',
        entityId: '${updated.id ?? ''}',
        userId: updated.id,
        userName: updated.username,
        details: 'User updated account password.',
      );
    } catch (e, st) {
      AppLogger.warning(
          'AuthService', 'Audit log failed after password change', e, st);
    }

    AppLogger.info(
        'AuthService', 'Password rotated for "${updated.username}".');
    return AuthResult(success: true, user: updated, mustChangePassword: false);
  }

  /// Sign out current user session and seal encrypted vault snapshot at rest.
  static Future<void> logout({String? reason}) async {
    final username = currentUserNotifier.value?.username;
    _loginTime = null;
    _lastActivityTime = null;
    sessionMessageNotifier.value = reason;
    currentUserNotifier.value = null;
    final openDb = DatabaseService.instanceOrNull;
    if (openDb != null && openDb.db.isOpen && openDb.dbFilePath != null) {
      try {
        await DatabaseEncryptionService.sealVaultSnapshot(openDb.dbFilePath!);
      } catch (e, st) {
        AppLogger.warning(
            'AuthService', 'Vault snapshot seal on logout skipped', e, st);
      }
    }
    if (username != null) {
      AppLogger.info('AuthService',
          'User "$username" logged out${reason != null ? ' ($reason)' : ''}.');
    }
  }

  /// Switch active logged-in user (admin-approved switch only)
  static void switchUser(User user) {
    _loginTime = nowProvider();
    _lastActivityTime = _loginTime;
    sessionMessageNotifier.value = null;
    currentUserNotifier.value = user;
  }
}
