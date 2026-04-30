import 'package:flutter/material.dart';

// Put your own PocketChase logo image here:
// assets/images/pocketdex_icon.png
const String kCustomAppLogoAsset = 'assets/images/pocketdex_icon.png';

class CustomAppLogo extends StatelessWidget {
  const CustomAppLogo({
    super.key,
    required this.height,
    required this.fallbackIcon,
    this.width,
    this.fallbackColor,
  });

  final double height;
  final double? width;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kCustomAppLogoAsset,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        return Icon(
          fallbackIcon,
          color: fallbackColor,
          size: height,
        );
      },
    );
  }
}
