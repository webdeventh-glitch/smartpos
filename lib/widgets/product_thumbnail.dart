import 'dart:io';
import 'package:flutter/material.dart';
import '../services/product_image_service.dart';

/// Shared product thumbnail widget that renders a compressed local file image
/// (with decoded `cacheWidth` bounds for smooth scrolling) and falls back to
/// the product's tinted badge icon when no valid image exists.
class ProductThumbnail extends StatelessWidget {
  final String? imagePath;
  final String? imageColor;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final double? fallbackIconSize;
  final BoxFit fit;

  const ProductThumbnail({
    super.key,
    this.imagePath,
    this.imageColor,
    this.size = 40,
    this.borderRadius = 8,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.fallbackIconSize,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = ProductImageService.resolveImagePath(
      imagePath: imagePath,
      imageColor: imageColor,
    );
    final accent = ProductImageService.parseHexColor(imageColor);
    final hasValidFile = resolved != null && File(resolved).existsSync();
    final cacheExtent = (size * 2).round().clamp(64, 512);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasValidFile
          ? Image.file(
              File(resolved),
              width: size,
              height: size,
              fit: fit,
              cacheWidth: cacheExtent,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => _buildFallback(accent),
            )
          : _buildFallback(accent),
    );
  }

  Widget _buildFallback(Color accent) {
    return Center(
      child: Icon(
        fallbackIcon,
        size: fallbackIconSize ?? (size * 0.5).clamp(14.0, 48.0),
        color: accent,
      ),
    );
  }
}

