import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-editable settings, persisted in SharedPreferences.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  late SharedPreferences _prefs;

  /// Range at 100% battery in Eco / Power mode, used until enough rides
  /// have been recorded to learn the real km-per-% figure.
  double fullRangeEcoKm = 100;
  double fullRangePowerKm = 75;

  /// Fallback charge speed (% per hour) until a charge has been observed.
  double chargeRatePctPerHour = 18;

  bool autoConnect = true;
  bool clusterNotifications = false;
  bool clusterPlaceWeather = true;
  bool clusterNavigation = true;
  bool clusterMusic = true;

  /// Android package names whose notifications are forwarded to the cluster.
  Set<String> clusterApps = {...defaultClusterApps.keys};

  static const Map<String, String> defaultClusterApps = {
    'com.whatsapp': 'WhatsApp',
    'com.whatsapp.w4b': 'WhatsApp Business',
    'com.google.android.apps.messaging': 'Messages',
    'com.android.mms': 'Messages (vendor)',
    'com.google.android.dialer': 'Phone calls',
    'com.android.dialer': 'Phone calls (AOSP)',
    'com.android.incallui': 'Phone calls (vendor)',
    'com.android.server.telecom': 'Phone calls (system)',
    'org.telegram.messenger': 'Telegram',
  };

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    fullRangeEcoKm = _prefs.getDouble('fullRangeEcoKm') ?? fullRangeEcoKm;
    fullRangePowerKm = _prefs.getDouble('fullRangePowerKm') ?? fullRangePowerKm;
    chargeRatePctPerHour =
        _prefs.getDouble('chargeRatePctPerHour') ?? chargeRatePctPerHour;
    autoConnect = _prefs.getBool('autoConnect') ?? autoConnect;
    clusterNotifications =
        _prefs.getBool('clusterNotifications') ?? clusterNotifications;
    clusterPlaceWeather =
        _prefs.getBool('clusterPlaceWeather') ?? clusterPlaceWeather;
    clusterNavigation =
        _prefs.getBool('clusterNavigation') ?? clusterNavigation;
    clusterMusic = _prefs.getBool('clusterMusic') ?? clusterMusic;
    final apps = _prefs.getStringList('clusterApps');
    if (apps != null) clusterApps = apps.toSet();
  }

  Future<void> update({
    double? fullRangeEcoKm,
    double? fullRangePowerKm,
    double? chargeRatePctPerHour,
    bool? autoConnect,
    bool? clusterNotifications,
    bool? clusterPlaceWeather,
    bool? clusterNavigation,
    bool? clusterMusic,
    Set<String>? clusterApps,
  }) async {
    if (fullRangeEcoKm != null) {
      this.fullRangeEcoKm = fullRangeEcoKm;
      await _prefs.setDouble('fullRangeEcoKm', fullRangeEcoKm);
    }
    if (fullRangePowerKm != null) {
      this.fullRangePowerKm = fullRangePowerKm;
      await _prefs.setDouble('fullRangePowerKm', fullRangePowerKm);
    }
    if (chargeRatePctPerHour != null) {
      this.chargeRatePctPerHour = chargeRatePctPerHour;
      await _prefs.setDouble('chargeRatePctPerHour', chargeRatePctPerHour);
    }
    if (autoConnect != null) {
      this.autoConnect = autoConnect;
      await _prefs.setBool('autoConnect', autoConnect);
    }
    if (clusterNotifications != null) {
      this.clusterNotifications = clusterNotifications;
      await _prefs.setBool('clusterNotifications', clusterNotifications);
    }
    if (clusterPlaceWeather != null) {
      this.clusterPlaceWeather = clusterPlaceWeather;
      await _prefs.setBool('clusterPlaceWeather', clusterPlaceWeather);
    }
    if (clusterNavigation != null) {
      this.clusterNavigation = clusterNavigation;
      await _prefs.setBool('clusterNavigation', clusterNavigation);
    }
    if (clusterMusic != null) {
      this.clusterMusic = clusterMusic;
      await _prefs.setBool('clusterMusic', clusterMusic);
    }
    if (clusterApps != null) {
      this.clusterApps = clusterApps;
      await _prefs.setStringList('clusterApps', clusterApps.toList());
    }
    notifyListeners();
  }
}
