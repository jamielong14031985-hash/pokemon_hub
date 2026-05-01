import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/pro_status_service.dart';

class PocketChaseBannerAd extends StatefulWidget {
  const PocketChaseBannerAd({super.key});

  @override
  State<PocketChaseBannerAd> createState() => _PocketChaseBannerAdState();
}

class _PocketChaseBannerAdState extends State<PocketChaseBannerAd> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  String get _testBannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  bool get _canShowAds {
    return !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        !ProStatusService.isProActive &&
        _testBannerAdUnitId.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    ProStatusService.isProNotifier.addListener(_handleProChanged);
    _loadAdIfNeeded();
  }

  @override
  void dispose() {
    ProStatusService.isProNotifier.removeListener(_handleProChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _handleProChanged() {
    if (!mounted) return;

    if (ProStatusService.isProActive) {
      _bannerAd?.dispose();
      _bannerAd = null;
      setState(() {
        _loaded = false;
      });
      return;
    }

    _loadAdIfNeeded();
  }

  void _loadAdIfNeeded() {
    if (!_canShowAds || _bannerAd != null) return;

    final banner = BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _loaded = false;
          });
        },
      ),
    );

    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canShowAds) return const SizedBox.shrink();

    final ad = _bannerAd;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        height: ad.size.height.toDouble(),
        alignment: Alignment.center,
        color: const Color(0xFF041B4A),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
