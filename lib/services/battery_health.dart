import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/vehicle_service.dart';
import '../rides/ride.dart';

/// One month of battery data.
class BatteryMonth {
  BatteryMonth(this.month);

  /// "2026-11".
  final String month;
  double km = 0;
  int used = 0;
  int charged = 0;
  double _clusterSum = 0;
  int _clusterCount = 0;

  /// Real km per 1% of battery. Needs 5% used, since the scooter reports
  /// whole percents.
  double? get kmPerPercent => used >= 5 ? km / used : null;

  /// What a full charge gives with this month's riding.
  double? get fullRangeKm => kmPerPercent == null ? null : kmPerPercent! * 100;

  /// The cluster's own full-charge estimate (DTE / battery % x 100).
  double? get clusterRangeKm =>
      _clusterCount == 0 ? null : _clusterSum / _clusterCount;

  double get cycles => charged / 100;
}

/// Logs what the battery does, day by day, so wear shows up as a trend:
/// km per % on real rides (from RideSummary), % charged (any rise while the
/// ignition is off), and the cluster's DTE-based range. Kept for good in
/// SharedPreferences; a few hundred bytes per day.
class BatteryHealth extends ChangeNotifier {
  BatteryHealth._();
  static final BatteryHealth instance = BatteryHealth._();

  static const _key = 'batteryHealthDays';

  late SharedPreferences _prefs;

  /// "2026-11-08" -> {km, used, charged, dteSum, dteCount}.
  final Map<String, Map<String, num>> _days = {};
  int? _lastBattery;
  DateTime? _lastDteSample;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      json.forEach((day, v) => _days[day] = Map<String, num>.from(v as Map));
    }
    _lastBattery = _prefs.getInt('batteryHealthLast');
    // Start the trend from the GPS rides recorded before this existed.
    if (!(_prefs.getBool('batteryHealthBackfilled') ?? false)) {
      for (final r in RideStore.instance.rides) {
        final used = r.batteryUsed;
        if (used != null && used > 0) _add(r.end, km: r.distanceKm, used: used);
      }
      await _prefs.setBool('batteryHealthBackfilled', true);
      await _save();
    }
    VehicleService.instance.addListener(_onVehicle);
  }

  DateTime? get since {
    if (_days.isEmpty) return null;
    return DateTime.parse((_days.keys.toList()..sort()).first);
  }

  /// Called by RideSummary when the ignition goes off.
  void addRide({required double km, required int used}) {
    _add(DateTime.now(), km: km, used: used);
    _save();
    notifyListeners();
  }

  void _onVehicle() {
    final v = VehicleService.instance;
    final battery = v.batteryPercent;
    if (battery == null) return;
    var changed = false;

    // Any rise with the ignition off is charging. The last value is kept
    // across restarts, so a charge while the app was away still counts.
    final last = _lastBattery;
    if (battery != last) {
      if (last != null && battery > last && v.ignitionOn != true) {
        _add(DateTime.now(), charged: battery - last);
        changed = true;
      }
      _lastBattery = battery;
      _prefs.setInt('batteryHealthLast', battery);
    }

    // The cluster's range estimate, every 30 min. Below 30% it is too
    // coarse (1% = several km).
    final dte = v.dteKm;
    final now = DateTime.now();
    if (dte != null &&
        battery >= 30 &&
        (_lastDteSample == null ||
            now.difference(_lastDteSample!) > const Duration(minutes: 30))) {
      _lastDteSample = now;
      _add(now, dteFull: dte / battery * 100);
      changed = true;
    }

    if (changed) {
      _save();
      notifyListeners();
    }
  }

  void _add(DateTime at,
      {double km = 0, int used = 0, int charged = 0, double? dteFull}) {
    final day = at.toIso8601String().substring(0, 10);
    final d = _days.putIfAbsent(day, () => {});
    d['km'] = (d['km'] ?? 0) + km;
    d['used'] = (d['used'] ?? 0) + used;
    d['charged'] = (d['charged'] ?? 0) + charged;
    if (dteFull != null) {
      d['dteSum'] = (d['dteSum'] ?? 0) + dteFull;
      d['dteCount'] = (d['dteCount'] ?? 0) + 1;
    }
  }

  Future<void> _save() => _prefs.setString(_key, jsonEncode(_days));

  /// Months, oldest first.
  List<BatteryMonth> get months => monthsFrom(_days);

  @visibleForTesting
  static List<BatteryMonth> monthsFrom(Map<String, Map<String, num>> days) {
    final byMonth = <String, BatteryMonth>{};
    for (final day in days.keys.toList()..sort()) {
      final d = days[day]!;
      final m = byMonth.putIfAbsent(day.substring(0, 7), () => BatteryMonth(day.substring(0, 7)));
      m.km += (d['km'] ?? 0).toDouble();
      m.used += (d['used'] ?? 0).toInt();
      m.charged += (d['charged'] ?? 0).toInt();
      m._clusterSum += (d['dteSum'] ?? 0).toDouble();
      m._clusterCount += (d['dteCount'] ?? 0).toInt();
    }
    return byMonth.values.toList();
  }

  double get totalCycles => months.fold(0, (s, m) => s + m.cycles);
  double get totalKm => months.fold(0, (s, m) => s + m.km);

  /// Full-charge range over all tracked rides.
  double? get fullRangeKm {
    final used = months.fold<int>(0, (s, m) => s + m.used);
    return used >= 5 ? totalKm / used * 100 : null;
  }
}
