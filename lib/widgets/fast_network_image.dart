import 'package:flutter/material.dart';

class FastNetworkImage extends StatelessWidget {
  const FastNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.errorChild,
    this.loadingColor = const Color(0xFF0E2A5E),
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? errorChild;
  final Color loadingColor;

  int? _scaledCacheSize({
    required BuildContext context,
    required double? logicalSize,
    required int? providedSize,
  }) {
    if (providedSize != null) return providedSize;
    if (logicalSize == null || logicalSize <= 0) return null;

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final scaled = (logicalSize * pixelRatio).round();

    // Keep cache sizes sensible so lists of card images do not waste memory.
    return scaled.clamp(96, 1200);
  }

  Widget _buildPlaceholder({double? progress}) {
    return Container(
      width: width,
      height: height,
      color: loadingColor,
      alignment: Alignment.center,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      ),
    );
  }

  Widget _buildError() {
    return errorChild ??
        Container(
          width: width,
          height: height,
          color: loadingColor,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported,
            color: Colors.white,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      return _buildError();
    }

    final effectiveCacheWidth = _scaledCacheSize(
      context: context,
      logicalSize: width,
      providedSize: cacheWidth,
    );

    final effectiveCacheHeight = _scaledCacheSize(
      context: context,
      logicalSize: height,
      providedSize: cacheHeight,
    );

    return Image.network(
      trimmedUrl,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: effectiveCacheWidth,
      cacheHeight: effectiveCacheHeight,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      isAntiAlias: false,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return _buildPlaceholder();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        final expectedBytes = loadingProgress.expectedTotalBytes;
        final loadedBytes = loadingProgress.cumulativeBytesLoaded;

        final progress = expectedBytes == null || expectedBytes <= 0
            ? null
            : (loadedBytes / expectedBytes).clamp(0.0, 1.0);

        return _buildPlaceholder(progress: progress);
      },
      errorBuilder: (_, __, ___) => _buildError(),
    );
  }
}