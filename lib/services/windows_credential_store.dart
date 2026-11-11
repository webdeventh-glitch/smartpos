import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'app_logger.dart';

const int _credTypeGeneric = 1;
const int _credPersistLocalMachine = 2;

final class _FILETIME extends Struct {
  @Uint32()
  external int dwLowDateTime;

  @Uint32()
  external int dwHighDateTime;
}

final class _CREDENTIALW extends Struct {
  @Uint32()
  external int flags;

  @Uint32()
  external int type;

  external Pointer<Utf16> targetName;
  external Pointer<Utf16> comment;
  external _FILETIME lastWritten;

  @Uint32()
  external int credentialBlobSize;

  external Pointer<Uint8> credentialBlob;

  @Uint32()
  external int persist;

  @Uint32()
  external int attributeCount;

  external Pointer<Void> attributes;
  external Pointer<Utf16> targetAlias;
  external Pointer<Utf16> userName;
}

typedef _CredWriteWNative = Int32 Function(
  Pointer<_CREDENTIALW> credential,
  Uint32 flags,
);
typedef _CredWriteWDart = int Function(
  Pointer<_CREDENTIALW> credential,
  int flags,
);

typedef _CredReadWNative = Int32 Function(
  Pointer<Utf16> targetName,
  Uint32 type,
  Uint32 flags,
  Pointer<Pointer<_CREDENTIALW>> credential,
);
typedef _CredReadWDart = int Function(
  Pointer<Utf16> targetName,
  int type,
  int flags,
  Pointer<Pointer<_CREDENTIALW>> credential,
);

typedef _CredDeleteWNative = Int32 Function(
  Pointer<Utf16> targetName,
  Uint32 type,
  Uint32 flags,
);
typedef _CredDeleteWDart = int Function(
  Pointer<Utf16> targetName,
  int type,
  int flags,
);

typedef _CredFreeNative = Void Function(Pointer<Void> buffer);
typedef _CredFreeDart = void Function(Pointer<Void> buffer);

/// Native Windows Credential Store wrapper using `advapi32.dll` (`CredWriteW`,
/// `CredReadW`, `CredDeleteW`) so encryption keys are never stored in plain files.
class WindowsCredentialStore {
  static bool useInMemoryForTest =
      Platform.environment.containsKey('FLUTTER_TEST');
  static final Map<String, String> _testMemoryStore = <String, String>{};

  static DynamicLibrary? _advapi32;
  static _CredWriteWDart? _credWriteW;
  static _CredReadWDart? _credReadW;
  static _CredDeleteWDart? _credDeleteW;
  static _CredFreeDart? _credFree;

  static void clearTestStore() {
    _testMemoryStore.clear();
  }

  static bool _ensureBindings() {
    if (!Platform.isWindows) return false;
    if (_advapi32 != null) return true;
    try {
      final lib = DynamicLibrary.open('advapi32.dll');
      _credWriteW = lib
          .lookupFunction<_CredWriteWNative, _CredWriteWDart>('CredWriteW');
      _credReadW =
          lib.lookupFunction<_CredReadWNative, _CredReadWDart>('CredReadW');
      _credDeleteW = lib
          .lookupFunction<_CredDeleteWNative, _CredDeleteWDart>('CredDeleteW');
      _credFree = lib.lookupFunction<_CredFreeNative, _CredFreeDart>('CredFree');
      _advapi32 = lib;
      return true;
    } catch (e, st) {
      AppLogger.error('WindowsCredentialStore', 'Failed to bind advapi32.dll', e, st);
      return false;
    }
  }

  /// Stores a UTF-8 secret securely inside Windows Credential Manager.
  static Future<bool> writeSecret({
    required String targetName,
    required String secret,
    String userName = 'SmartPOS',
    String comment = 'Smart POS Encryption Credential',
  }) async {
    if (useInMemoryForTest) {
      _testMemoryStore[targetName] = secret;
      return true;
    }
    if (!Platform.isWindows || !_ensureBindings()) {
      AppLogger.warning(
        'WindowsCredentialStore',
        'Native Windows Credential Store unavailable on ${Platform.operatingSystem}.',
      );
      return false;
    }

    final targetPtr = targetName.toNativeUtf16();
    final userPtr = userName.toNativeUtf16();
    final commentPtr = comment.toNativeUtf16();
    final secretBytes = Uint8List.fromList(utf8.encode(secret));
    final blobPtr = calloc<Uint8>(secretBytes.length);
    final credPtr = calloc<_CREDENTIALW>();

    try {
      blobPtr.asTypedList(secretBytes.length).setAll(0, secretBytes);
      credPtr.ref.flags = 0;
      credPtr.ref.type = _credTypeGeneric;
      credPtr.ref.targetName = targetPtr;
      credPtr.ref.comment = commentPtr;
      credPtr.ref.credentialBlobSize = secretBytes.length;
      credPtr.ref.credentialBlob = blobPtr;
      credPtr.ref.persist = _credPersistLocalMachine;
      credPtr.ref.attributeCount = 0;
      credPtr.ref.attributes = nullptr;
      credPtr.ref.targetAlias = nullptr;
      credPtr.ref.userName = userPtr;

      final ok = _credWriteW!(credPtr, 0) != 0;
      if (!ok) {
        AppLogger.error(
          'WindowsCredentialStore',
          'CredWriteW failed for target "$targetName".',
        );
      }
      return ok;
    } catch (e, st) {
      AppLogger.error('WindowsCredentialStore', 'CredWriteW exception', e, st);
      return false;
    } finally {
      // Zero out secret buffer before freeing
      blobPtr.asTypedList(secretBytes.length).fillRange(0, secretBytes.length, 0);
      calloc.free(targetPtr);
      calloc.free(userPtr);
      calloc.free(commentPtr);
      calloc.free(blobPtr);
      calloc.free(credPtr);
    }
  }

  /// Reads a stored secret from Windows Credential Manager, or null if absent.
  static Future<String?> readSecret(String targetName) async {
    if (useInMemoryForTest) {
      return _testMemoryStore[targetName];
    }
    if (!Platform.isWindows || !_ensureBindings()) {
      return null;
    }

    final targetPtr = targetName.toNativeUtf16();
    final outCredPtr = calloc<Pointer<_CREDENTIALW>>();

    try {
      final ok = _credReadW!(targetPtr, _credTypeGeneric, 0, outCredPtr) != 0;
      if (!ok) return null;

      final credPtr = outCredPtr.value;
      if (credPtr == nullptr) return null;

      try {
        final size = credPtr.ref.credentialBlobSize;
        if (size <= 0 || credPtr.ref.credentialBlob == nullptr) {
          return '';
        }
        final copied = Uint8List.fromList(
          credPtr.ref.credentialBlob.asTypedList(size),
        );
        return utf8.decode(copied);
      } finally {
        _credFree!(credPtr.cast<Void>());
      }
    } catch (e, st) {
      AppLogger.error('WindowsCredentialStore', 'CredReadW exception', e, st);
      return null;
    } finally {
      calloc.free(targetPtr);
      calloc.free(outCredPtr);
    }
  }

  /// Deletes a credential from Windows Credential Manager.
  static Future<bool> deleteSecret(String targetName) async {
    if (useInMemoryForTest) {
      return _testMemoryStore.remove(targetName) != null;
    }
    if (!Platform.isWindows || !_ensureBindings()) {
      return false;
    }

    final targetPtr = targetName.toNativeUtf16();
    try {
      return _credDeleteW!(targetPtr, _credTypeGeneric, 0) != 0;
    } catch (e, st) {
      AppLogger.error('WindowsCredentialStore', 'CredDeleteW exception', e, st);
      return false;
    } finally {
      calloc.free(targetPtr);
    }
  }
}

