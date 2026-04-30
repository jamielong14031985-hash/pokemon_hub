import 'package:flutter/material.dart';

import '../services/pokemon_tcg_service.dart';
import 'fast_network_image.dart';

class ResolvedSetLogo extends StatelessWidget {
  const ResolvedSetLogo({
    super.key,
    required this.setId,
    required this.setName,
    required this.fallbackLogoUrl,
    required this.height,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.cacheHeight,
    this.textStyle,
  });

  final String setId;
  final String setName;
  final String? fallbackLogoUrl;
  final double height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final TextStyle? textStyle;

  Widget _buildTextFallback() {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: Text(
          setName,
          textAlign: TextAlign.center,
          style: textStyle ??
              const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }

  Widget _buildLogo(String logoUrl) {
    return SizedBox(
      height: height,
      child: FastNetworkImage(
        imageUrl: logoUrl,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorChild: _buildTextFallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: PokemonTcgService.resolveSetLogoUrl(
        setId: setId,
        setName: setName,
        fallbackLogoUrl: fallbackLogoUrl,
      ),
      builder: (context, snapshot) {
        final resolvedLogoUrl = snapshot.data?.trim();

        if (resolvedLogoUrl != null && resolvedLogoUrl.isNotEmpty) {
          return _buildLogo(resolvedLogoUrl);
        }

        return _buildTextFallback();
      },
    );
  }
}

class SetLogoTile extends StatelessWidget {
  const SetLogoTile({
    super.key,
    required this.setId,
    required this.setName,
    required this.logoUrl,
  });

  final String setId;
  final String setName;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ResolvedSetLogo(
            setId: setId,
            setName: setName,
            fallbackLogoUrl: logoUrl,
            height: 54,
          ),
        ),
      ),
    );
  }
}
