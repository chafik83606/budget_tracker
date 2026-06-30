import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';

class AdService {
  AdService._internal();
  static final AdService instance = AdService._internal();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('AdMob init failed: $e');
    }
  }

  String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return AppConfig.admobAndroidInterstitialId;
    if (Platform.isIOS) return AppConfig.admobIosInterstitialId;
    return '';
  }

  Future<void> showInterstitialAd() async {
    final adUnitId = interstitialAdUnitId;
    if (adUnitId.isEmpty) return;

    final completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete();
            },
            onAdFailedToShowFullScreenContent:
                (InterstitialAd ad, AdError error) {
                  ad.dispose();
                  if (!completer.isCompleted) completer.complete();
                },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }
}
