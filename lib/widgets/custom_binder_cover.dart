import 'package:flutter/material.dart';

import 'stored_image.dart';

class CustomBinderCover extends StatelessWidget {
  const CustomBinderCover({
    super.key,
    required this.imageBase64,
    this.size = 96,
    this.borderRadius = 20,
  });

  final String? imageBase64;
  final double size;
  final double borderRadius;

  Widget _fallbackCover() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.photo_album_outlined, color: Color(0xFFF7DE77), size: 34),
        SizedBox(height: 8),
        Text(
          'Custom\nBinder',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBase64 != null && imageBase64!.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          colors: [Color(0xFF21468B), Color(0xFF102754)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? StoredImage(
              imageRef: imageBase64,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorChild: _fallbackCover(),
            )
          : _fallbackCover(),
    );
  }
}
