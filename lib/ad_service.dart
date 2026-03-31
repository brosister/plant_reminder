import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;

class AdSettings {
  const AdSettings({
    required this.adMode,
    required this.iosBannerAdId,
    required this.iosInterstitialAdId,
    required this.androidBannerAdId,
    required this.androidInterstitialAdId,
  });

  final String adMode;
  final String iosBannerAdId;
  final String iosInterstitialAdId;
  final String androidBannerAdId;
  final String androidInterstitialAdId;

  String get bannerAdUnitId => Platform.isIOS ? iosBannerAdId : androidBannerAdId;
  String get interstitialAdUnitId => Platform.isIOS ? iosInterstitialAdId : androidInterstitialAdId;

  factory AdSettings.fromJson(Map<String, dynamic> json) {
    return AdSettings(
      adMode: (json['ad_mode'] ?? 'test').toString(),
      iosBannerAdId: (json['ios_banner_ad_id'] ?? '').toString(),
      iosInterstitialAdId: (json['ios_interstitial_ad_id'] ?? '').toString(),
      androidBannerAdId: (json['android_banner_ad_id'] ?? '').toString(),
      androidInterstitialAdId: (json['android_interstitial_ad_id'] ?? '').toString(),
    );
  }
}

class AdService {
  AdService._();

  static const String _baseUrl = 'https://app-master.officialsite.kr';
  static AdSettings? _settings;
  static bool _initialized = false;
  static int _meaningfulActionCount = 0;

  static AdSettings? get settings => _settings;

  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _settings = await fetchSettings();
    _initialized = true;
  }

  static Future<AdSettings?> fetchSettings() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/admin/plant-reminder/ad-settings'));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true || decoded['data'] == null) return null;
      return AdSettings.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
    } catch (_) {
      return null;
    }
  }

  static Future<BannerAd?> loadBanner(int screenWidth) async {
    final s = _settings;
    if (s == null || s.bannerAdUnitId.isEmpty) return null;
    final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(screenWidth);
    if (adSize == null) return null;

    final completer = Completer<BannerAd?>();
    final banner = BannerAd(
      size: adSize,
      adUnitId: s.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) => completer.complete(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          completer.complete(null);
        },
      ),
      request: const AdRequest(),
    );
    await banner.load();
    return completer.future;
  }

  static Future<void> showInterstitialIfNeeded() async {
    _meaningfulActionCount += 1;
    if (_meaningfulActionCount % 3 != 0) return;
    final s = _settings;
    if (s == null || s.interstitialAdUnitId.isEmpty) return;

    await InterstitialAd.load(
      adUnitId: s.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, error) => ad.dispose(),
          );
          ad.show();
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }
}
