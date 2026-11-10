import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class Ride {
  final String id;
  final DateTime start;
  final DateTime end;
  final double distanceKm;
  final double topSpeedKmh;
  final int? batteryStart;
  final int? batteryEnd;

  /// Route as [lat, lng] pairs, thinned to roughly one point per 20 m.
  final List<List<double>> route;

  Ride({
    required this.id,
    required this.start,
    required this.end,
    required this.distanceKm,
    required this.topSpeedKmh,
    required this.batteryStart,
    required this.batteryEnd,
    required this.route,
  });

  Duration get duration => end.difference(start);

  double get avgSpeedKmh {
    final h = duration.inSeconds / 3600;
    return h > 0 ? distanceKm / h : 0;
  }

  int? get batteryUsed => (batteryStart != null && batteryEnd != null)
      ? (batteryStart! - batteryEnd!).clamp(0, 100)
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'km': distanceKm,
        'top': topSpeedKmh,
        'bs': batteryStart,
        'be': batteryEnd,
        'route': route,
      };

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
        id: j['id'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(j['end'] as int),
        distanceKm: (j['km'] as num).toDouble(),
        topSpeedKmh: (j['top'] as num).toDouble(),
        batteryStart: j['bs'] as int?,
        batteryEnd: j['be'] as int?,
        route: [
          for (final p in j['route'] as List)
            [(p[0] as num).toDouble(), (p[1] as num).toDouble()]
        ],
      );
}

/// Saved rides, newest first.
class RideStore extends ChangeNotifier {
  RideStore._();
  static final RideStore instance = RideStore._();

  static const _key = 'rides_v1';
  late SharedPreferences _prefs;
  List<Ride> rides = [];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      rides = [
        for (final r in jsonDecode(raw) as List)
          Ride.fromJson(r as Map<String, dynamic>)
      ];
    } catch (_) {
      rides = [];
    }
  }

  Future<void> add(Ride ride) async {
    rides.insert(0, ride);
    await _save();
  }

  Future<void> delete(String id) async {
    rides.removeWhere((r) => r.id == id);
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode([for (final r in rides) r.toJson()]));
    notifyListeners();
  }

  double get totalKm => rides.fold(0, (s, r) => s + r.distanceKm);
  double get topSpeedKmh => rides.fold(0, (s, r) => r.topSpeedKmh > s ? r.topSpeedKmh : s);

  /// Real-world km per battery %, from rides with battery data.
  /// Null until at least 10% of battery has been used across rides.
  double? get learnedKmPerPercent {
    var km = 0.0;
    var pct = 0;
    for (final r in rides) {
      final used = r.batteryUsed;
      if (used == null || used == 0) continue;
      km += r.distanceKm;
      pct += used;
    }
    return pct >= 10 ? km / pct : null;
  }
}
