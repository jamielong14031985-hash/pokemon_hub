import 'package:flutter/material.dart';

class CardImageWithFallback extends StatefulWidget {
  const CardImageWithFallback({
    super.key,
    required this.imageUrls,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.backgroundColor = const Color(0xFF102754),
    this.borderRadius,
  });

  final List<String> imageUrls;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final Color backgroundColor;
  final BorderRadius? borderRadius;

  @override
  State<CardImageWithFallback> createState() => _CardImageWithFallbackState();
}

class _CardImageWithFallbackState extends State<CardImageWithFallback> {
  int _currentIndex = 0;

  List<String> get _cleanUrls {
    final seen = <String>{};
    final result = <String>[];

    for (final url in widget.imageUrls) {
      final clean = url.trim();
      if (clean.isEmpty || clean.toLowerCase() == 'null') continue;
      if (seen.add(clean)) result.add(clean);
    }

    return result;
  }

  @override
  void didUpdateWidget(covariant CardImageWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrls.join('|') != widget.imageUrls.join('|')) {
      _currentIndex = 0;
    }
  }

  void _tryNextImage() {
    final urls = _cleanUrls;
    if (_currentIndex >= urls.length - 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex += 1;
      });
    });
  }

  Widget _placeholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor,
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.white70,
          size: 34,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _cleanUrls;

    if (urls.isEmpty) {
      return _placeholder();
    }

    final safeIndex = _currentIndex.clamp(0, urls.length - 1).toInt();
    final url = urls[safeIndex];

    final image = Image.network(
      url,
      key: ValueKey<String>(url),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return Container(
          width: widget.width,
          height: widget.height,
          color: widget.backgroundColor,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7DE77)),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        _tryNextImage();
        if (safeIndex < urls.length - 1) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: widget.backgroundColor,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7DE77)),
              ),
            ),
          );
        }

        return _placeholder();
      },
    );

    if (widget.borderRadius == null) {
      return image;
    }

    return ClipRRect(
      borderRadius: widget.borderRadius!,
      child: image,
    );
  }
}
