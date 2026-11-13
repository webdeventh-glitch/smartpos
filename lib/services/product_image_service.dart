import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'app_logger.dart';

/// Handles persistent storage, resizing, compression, and resolution of product images.
class ProductImageService {
  ProductImageService._();

  static int _sequence = 0;

  /// Resolves the managed product images directory (`%LOCALAPPDATA%/SmartPOS/product_images`).
  static Directory resolveStorageDirectory({Directory? directoryOverride}) {
    if (directoryOverride != null) return directoryOverride;
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    return Directory(p.join(base, 'SmartPOS', 'product_images'));
  }

  /// Resolves an image path from `Product.imagePath` with fallback for legacy
  /// records that stored file paths inside `Product.imageColor`.
  static String? resolveImagePath({String? imagePath, String? imageColor}) {
    final direct = imagePath?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final legacy = imageColor?.trim() ?? '';
    if (legacy.isNotEmpty && !legacy.startsWith('#')) {
      return legacy;
    }
    return null;
  }

  /// Safely parses a hex color string (`#RRGGBB` or `#AARRGGBB`).
  static Color parseHexColor(
    String? hex, {
    Color fallback = const Color(0xFF004EEB),
  }) {
    final clean = (hex ?? '').trim();
    if (!clean.startsWith('#')) return fallback;
    final body = clean.substring(1);
    if (body.length != 6 && body.length != 8) return fallback;
    final parsed = int.tryParse(body.length == 6 ? 'FF$body' : body, radix: 16);
    return parsed != null ? Color(parsed) : fallback;
  }

  /// Copies, resizes (max [maxDimension]px), and compresses [sourcePath] into
  /// `SmartPOS/product_images/`. Returns the managed file path, or `null` if invalid.
  static Future<String?> saveCompressedProductImage(
    String sourcePath, {
    String? existingImagePath,
    Directory? directoryOverride,
    int maxDimension = 512,
    int jpegQuality = 82,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final bytes = await sourceFile.readAsBytes();
      if (bytes.isEmpty) return null;

      final dir = resolveStorageDirectory(directoryOverride: directoryOverride);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      _sequence++;
      final stamp = '${DateTime.now().millisecondsSinceEpoch}_$_sequence';
      final decoded = _tryDecode(bytes);

      String destination;
      Uint8List outputBytes;

      if (decoded != null) {
        final resized = _resizeIfNeeded(decoded, maxDimension);
        final needsAlpha = _hasTransparentPixels(resized);
        if (needsAlpha) {
          destination = p.join(dir.path, 'prod_$stamp.png');
          outputBytes = Uint8List.fromList(img.encodePng(resized, level: 6));
        } else {
          destination = p.join(dir.path, 'prod_$stamp.jpg');
          outputBytes =
              Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
        }
      } else {
        final rawExt = p.extension(sourcePath).toLowerCase();
        final ext = rawExt.isEmpty ? '.jpg' : rawExt;
        destination = p.join(dir.path, 'prod_$stamp$ext');
        outputBytes = bytes;
      }

      await File(destination).writeAsBytes(outputBytes, flush: true);

      if (existingImagePath != null && existingImagePath != destination) {
        await deleteManagedImage(
          existingImagePath,
          directoryOverride: directoryOverride,
        );
      }

      return destination;
    } catch (e, st) {
      AppLogger.warning(
        'ProductImageService',
        'Failed saving compressed product image "$sourcePath"',
        e,
        st,
      );
      return null;
    }
  }

  /// Deletes [imagePath] if it is owned inside SmartPOS's managed image folders.
  static Future<void> deleteManagedImage(
    String? imagePath, {
    Directory? directoryOverride,
  }) async {
    final clean = imagePath?.trim() ?? '';
    if (clean.isEmpty || clean.startsWith('#')) return;
    try {
      final managedDir = resolveStorageDirectory(
        directoryOverride: directoryOverride,
      );
      final normalizedTarget = p.normalize(clean).toLowerCase();
      final normalizedManaged = p.normalize(managedDir.path).toLowerCase();
      if (!p.isWithin(normalizedManaged, normalizedTarget)) {
        return;
      }
      final file = File(clean);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      AppLogger.warning(
        'ProductImageService',
        'Failed deleting old product image "$clean"',
        e,
        st,
      );
    }
  }

  static img.Image? _tryDecode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static img.Image _resizeIfNeeded(img.Image source, int maxDimension) {
    if (source.width <= maxDimension && source.height <= maxDimension) {
      return source;
    }
    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxDimension,
        interpolation: img.Interpolation.average,
      );
    }
    return img.copyResize(
      source,
      height: maxDimension,
      interpolation: img.Interpolation.average,
    );
  }

  static bool _hasTransparentPixels(img.Image image) {
    if (!image.hasAlpha) return false;
    for (final pixel in image) {
      if (pixel.a < 250) {
        return true;
      }
    }
    return false;
  }
}
