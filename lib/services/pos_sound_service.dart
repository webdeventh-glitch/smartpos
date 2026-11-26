import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'app_logger.dart';

typedef _PlaySoundWNative = Int32 Function(
    Pointer<Utf16> pszSound, IntPtr hmod, Uint32 fdwSound);
typedef _PlaySoundWDart = int Function(
    Pointer<Utf16> pszSound, int hmod, int fdwSound);

/// Synthesizes and plays non-blocking pleasant POS chimes on Windows
/// (Product Add, Sale Complete, and Sale Cancel) using `winmm.dll`.
class PosSoundService {
  PosSoundService._();

  static const int _sampleRate = 44100;
  static const int _sndAsync = 0x0001;
  static const int _sndNoDefault = 0x0002;
  static const int _sndFilename = 0x00020000;

  static _PlaySoundWDart? _playSoundW;
  static bool _initAttempted = false;
  static final Map<String, String> _cachedPaths = {};

  static void _ensureWinmm() {
    if (_initAttempted) return;
    _initAttempted = true;
    if (!Platform.isWindows) return;
    try {
      final winmm = DynamicLibrary.open('winmm.dll');
      _playSoundW = winmm
          .lookupFunction<_PlaySoundWNative, _PlaySoundWDart>('PlaySoundW');
    } catch (e) {
      AppLogger.warning('PosSoundService', 'winmm.dll unavailable', e);
    }
  }

  /// Plays a crisp ascending two-note chime when a product is added to cart.
  static void playAddProduct({required bool enabled}) {
    if (!enabled) return;
    _playClip('add_product.wav', () => _buildAddProductWav());
  }

  /// Plays a warm 4-note ascending chime when a POS transaction completes.
  static void playSaleComplete({required bool enabled}) {
    if (!enabled) return;
    _playClip('sale_complete.wav', () => _buildSaleCompleteWav());
  }

  /// Plays a gentle descending two-note tone when a cart/sale is cancelled.
  static void playCancel({required bool enabled}) {
    if (!enabled) return;
    _playClip('cancel_sale.wav', () => _buildCancelWav());
  }

  static void _playClip(String fileName, Uint8List Function() builder) {
    if (!Platform.isWindows) return;
    _ensureWinmm();
    final fn = _playSoundW;
    if (fn == null) return;

    try {
      String? filePath = _cachedPaths[fileName];
      if (filePath == null || !File(filePath).existsSync()) {
        final dir =
            Directory(p.join(Directory.systemTemp.path, 'SmartPOS', 'sounds'));
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        filePath = p.join(dir.path, fileName);
        if (!File(filePath).existsSync()) {
          File(filePath).writeAsBytesSync(builder(), flush: true);
        }
        _cachedPaths[fileName] = filePath;
      }

      final ptr = filePath.toNativeUtf16();
      try {
        fn(ptr, 0, _sndFilename | _sndAsync | _sndNoDefault);
      } finally {
        calloc.free(ptr);
      }
    } catch (e) {
      AppLogger.warning('PosSoundService', 'Failed playing $fileName', e);
    }
  }

  static Uint8List _buildAddProductWav() {
    // Crisp E6 -> A6 pop chime (~125 ms)
    return _renderNotes(const [
      _ToneNote(freq: 1318.51, startSec: 0.00, durationSec: 0.055, gain: 0.30),
      _ToneNote(freq: 1760.00, startSec: 0.045, durationSec: 0.080, gain: 0.32),
    ]);
  }

  static Uint8List _buildSaleCompleteWav() {
    // Pretty C5 -> E5 -> G5 -> C6 ascending chime (~440 ms)
    return _renderNotes(const [
      _ToneNote(freq: 523.25, startSec: 0.00, durationSec: 0.14, gain: 0.28),
      _ToneNote(freq: 659.25, startSec: 0.07, durationSec: 0.16, gain: 0.28),
      _ToneNote(freq: 783.99, startSec: 0.14, durationSec: 0.18, gain: 0.30),
      _ToneNote(freq: 1046.50, startSec: 0.21, durationSec: 0.24, gain: 0.34),
    ]);
  }

  static Uint8List _buildCancelWav() {
    // Gentle descending G4 -> D4 tone (~250 ms)
    return _renderNotes(const [
      _ToneNote(freq: 392.00, startSec: 0.00, durationSec: 0.11, gain: 0.28),
      _ToneNote(freq: 293.66, startSec: 0.09, durationSec: 0.16, gain: 0.30),
    ]);
  }

  static Uint8List _renderNotes(List<_ToneNote> notes) {
    double totalSec = 0;
    for (final n in notes) {
      final end = n.startSec + n.durationSec;
      if (end > totalSec) totalSec = end;
    }
    final numSamples = (totalSec * _sampleRate).ceil();
    final mix = Float64List(numSamples);

    for (final note in notes) {
      final startIdx = (note.startSec * _sampleRate).round();
      final lenIdx = (note.durationSec * _sampleRate).round();
      final attackIdx = math.max(1, (0.008 * _sampleRate).round());
      for (int i = 0; i < lenIdx && (startIdx + i) < numSamples; i++) {
        final t = i / _sampleRate;
        final attack = i < attackIdx ? (i / attackIdx) : 1.0;
        final decay = math.exp(-4.5 * (i / lenIdx));
        final env = attack * decay;
        // Fundamental + gentle 2nd harmonic for warm bell timbre
        final wave = math.sin(2 * math.pi * note.freq * t) * 0.82 +
            math.sin(2 * math.pi * note.freq * 2 * t) * 0.18;
        mix[startIdx + i] += wave * env * note.gain;
      }
    }

    final dataSize = numSamples * 2;
    final byteData = ByteData(44 + dataSize);
    // RIFF header
    byteData.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    byteData.setUint32(4, 36 + dataSize, Endian.little);
    byteData.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    // fmt subchunk
    byteData.setUint32(12, 0x666D7420, Endian.big); // "fmt "
    byteData.setUint32(16, 16, Endian.little); // PCM
    byteData.setUint16(20, 1, Endian.little); // Linear PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, _sampleRate, Endian.little);
    byteData.setUint32(28, _sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little); // Block align
    byteData.setUint16(34, 16, Endian.little); // Bits per sample
    // data subchunk
    byteData.setUint32(36, 0x64617461, Endian.big); // "data"
    byteData.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final clamped = mix[i].clamp(-0.98, 0.98);
      final pcm = (clamped * 32767).round();
      byteData.setInt16(44 + i * 2, pcm, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }
}

class _ToneNote {
  final double freq;
  final double startSec;
  final double durationSec;
  final double gain;

  const _ToneNote({
    required this.freq,
    required this.startSec,
    required this.durationSec,
    required this.gain,
  });
}
