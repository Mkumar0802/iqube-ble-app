import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Works out whether the scooter is charging and how long it will take,
/// purely from how the battery % moves over time.
class ChargeTracker extends ChangeNotifier {
  ChargeTracker._();
  static final ChargeTracker instance = ChargeTracker._();

  /// One sample per battery % change: (time, percent).
  final List<(DateTime, int)> _samples = [];
  late SharedPreferences _prefs;

  /// Last measured charge speed, remembered across sessions.
  double? learnedRatePctPerHour;
  DateTime? lastFullChargeAt;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    learnedRatePctPerHour = _prefs.getDouble('learnedChargeRate');
    final full = _prefs.getInt('lastFullChargeAt');
    if (full != null) {
      lastFullChargeAt = DateTime.fromMillisecondsSinceEpoch(full);
    }
  }

  List<(DateTime, int)> get samples => List.unmodifiable(_samples);

  void addSample(int percent, DateTime at) {
    if (_samples.isNotEmpty && _samples.last.$2 == percent) return;
    _samples.add((at, percent));
    if (_samples.length > 200) _samples.removeAt(0);

    if (percent >= 100 && (_samples.length < 2 || _samples[_samples.length - 2].$2 < 100)) {
      lastFullChargeAt = at;
      _prefs.setInt('lastFullChargeAt', at.millisecondsSinceEpoch);
    }
    final rate = measuredRate;
    if (rate != null) {
      learnedRatePctPerHour = rate;
      _prefs.setDouble('learnedChargeRate', rate);
    }
    notifyListeners();
  }

  /// True if the battery % went up within the last 20 minutes.
  bool get isCharging {
    if (_samples.length < 2) return false;
    final last = _samples.last;
    final prev = _samples[_samples.length - 2];
    return last.$2 > prev.$2 &&
        DateTime.now().difference(last.$1) < const Duration(minutes: 20);
  }

  /// % per hour over the latest run of increasing samples (needs >= 2%).
  double? get measuredRate {
    if (_samples.length < 3) return null;
    var start = _samples.length - 1;
    while (start > 0 && _samples[start - 1].$2 < _samples[start].$2) {
      start--;
    }
    final first = _samples[start];
    final last = _samples.last;
    final gained = last.$2 - first.$2;
    final hours = last.$1.difference(first.$1).inSeconds / 3600;
    if (gained < 2 || hours <= 0) return null;
    return gained / hours;
  }

  double get ratePctPerHour =>
      measuredRate ??
      learnedRatePctPerHour ??
      AppSettings.instance.chargeRatePctPerHour;

  /// Time from [fromPercent] to [target]%. Charging slows above 80%, so
  /// that part is counted at half speed.
  Duration timeTo(int fromPercent, int target) {
    if (fromPercent >= target) return Duration.zero;
    final rate = ratePctPerHour;
    final below80 = (target.clamp(0, 80) - fromPercent).clamp(0, 100);
    final above80 = (target - fromPercent.clamp(80, 100)).clamp(0, 100);
    final hours = below80 / rate + above80 / (rate / 2);
    return Duration(minutes: (hours * 60).round());
  }
}
