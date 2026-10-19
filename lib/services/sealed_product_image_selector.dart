import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'sealed_product_price_service.dart';

/// Selects only marketplace photos that look like clean catalogue artwork.
/// Pricing still uses every matching listing; this affects display images only.
class SealedProductImageSelector {
  SealedProductImageSelector._();

  static const int _maximumCandidates = 20;
  static const int _maximumBytes = 5 * 1024 * 1024;
  // Retail catalogue photos are not always pure white/black around every edge.
  // The old 0.76 threshold rejected genuine standard ETBs and booster bundles.
  static const double _minimumCleanScore = 0.34;

  static Future<String> selectCleanProductImage(
    List<SealedProductListing> listings,
  ) async {
    final urls = listings
        .map((listing) => listing.imageUrl.trim())
        .where((url) => url.startsWith('https://'))
        .toSet()
        .take(_maximumCandidates)
        .toList(growable: false);
    if (urls.isEmpty) return '';

    final scored = await Future.wait(
      urls.map((url) async => (url: url, score: await _cleanBackgroundScore(url))),
    );
    scored.sort((a, b) => b.score.compareTo(a.score));
    final best = scored.first;
    if (best.score >= _minimumCleanScore) return best.url;

    // A marketplace CDN may refuse our inspection request while still loading
    // normally in Image.network. Because these listings have already passed the
    // exact product/type/edition matcher, keep the first real product image as
    // the last fallback instead of displaying an empty placeholder.
    if (scored.every((candidate) => candidate.score == 0)) return urls.first;
    return best.url;
  }

  static Future<double> _cleanBackgroundScore(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(
            const Duration(seconds: 5),
          );
      request.headers.set(HttpHeaders.userAgentHeader, 'PocketChase/1.0');
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) return 0;

      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 6))) {
        bytes.add(chunk);
        if (bytes.length > _maximumBytes) return 0;
      }
      if (bytes.length == 0) return 0;

      final codec = await ui.instantiateImageCodec(
        bytes.takeBytes(),
        targetWidth: 96,
        targetHeight: 96,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return 0;

      final width = image.width;
      final height = image.height;
      final pixels = data.buffer.asUint8List();
      var clean = 0;
      var sampled = 0;

      void inspect(int x, int y) {
        final offset = ((y * width) + x) * 4;
        final r = pixels[offset];
        final g = pixels[offset + 1];
        final b = pixels[offset + 2];
        final maxChannel = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final minChannel = r < g ? (r < b ? r : b) : (g < b ? g : b);
        final brightness = (r + g + b) / 3;
        final spread = maxChannel - minChannel;
        final neutralLight = brightness >= 205 && spread <= 48;
        final neutralDark = brightness <= 48 && spread <= 38;
        if (neutralLight || neutralDark) clean++;
        sampled++;
      }

      final insetX = (width * 0.04).round().clamp(0, width - 1).toInt();
      final insetY = (height * 0.04).round().clamp(0, height - 1).toInt();
      final stepX = (width / 24).floor().clamp(1, width).toInt();
      final stepY = (height / 24).floor().clamp(1, height).toInt();
      for (var x = 0; x < width; x += stepX) {
        inspect(x, insetY);
        inspect(x, height - 1 - insetY);
      }
      for (var y = 0; y < height; y += stepY) {
        inspect(insetX, y);
        inspect(width - 1 - insetX, y);
      }

      image.dispose();
      codec.dispose();
      return sampled == 0 ? 0 : clean / sampled;
    } catch (_) {
      return 0;
    } finally {
      client.close(force: true);
    }
  }
}
