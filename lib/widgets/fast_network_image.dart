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

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          width: width,
          height: height,
          color: loadingColor,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
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
      },
    );
  }
}
