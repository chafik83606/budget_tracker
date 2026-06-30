import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

/// Configuration centralisée — remplacez les IDs AdMob par vos valeurs production
/// depuis https://admob.google.com (application + unités publicitaires).
class AppConfig {
  AppConfig._();

  static const String proProductId = 'budget_tracker_pro';
  static const Color seedColor = Color(0xFF2E7D32);

  static const String appDisplayName = 'Budget Tracker';
  static const String publisherName = 'Dynaweb';
  static const String privacyPolicyUrl =
      'https://chafik83606.github.io/budgetraker/';
  static const String supportEmail = 'direction@novasoft.solutions';

  // IDs production — remplacer avant publication Play Store / App Store.
  static const String _prodAdmobAndroidAppId =
      'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY';
  static const String _prodAdmobAndroidInterstitialId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodAdmobIosAppId =
      'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY';
  static const String _prodAdmobIosInterstitialId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  static const String _testAdmobAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testAdmobAndroidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testAdmobIosAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testAdmobIosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  static bool get useProductionAds => kReleaseMode;

  static String get admobAndroidAppId =>
      useProductionAds ? _prodAdmobAndroidAppId : _testAdmobAndroidAppId;

  static String get admobAndroidInterstitialId => useProductionAds
      ? _prodAdmobAndroidInterstitialId
      : _testAdmobAndroidInterstitialId;

  static String get admobIosAppId =>
      useProductionAds ? _prodAdmobIosAppId : _testAdmobIosAppId;

  static String get admobIosInterstitialId => useProductionAds
      ? _prodAdmobIosInterstitialId
      : _testAdmobIosInterstitialId;
}
