import 'package:flutter/material.dart';

import '../services/community_image_services.dart';

class StoredImage extends StatelessWidget {
  const StoredImage({
    super.key,
    required this.imageRef,
    required this.fit,
    this.width,
    this.height,
    this.errorChild,
  });

  final String? imageRef;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorChild;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageRef?.trim() ?? '';
    final fallback = errorChild ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFF16366E),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
        );

    if (trimmed.isEmpty) {
      return fallback;
    }

    if (FirebaseImageStorageService.isRemoteRef(trimmed)) {
      return Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFF16366E),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    final bytes = CommunityImageCodec.decode(trimmed);
    if (bytes == null) return fallback;

    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
