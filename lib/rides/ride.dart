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
  final String? tag;

  /// Route as [lat, lng, speedKmh?, timestampMs?, elevation?] points,
  /// thinned to roughly one point per 20 m.
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
    this.tag,
  });

  Duration get duration => end.difference(start);

  double get avgSpeedKmh {
    final h = duration.inSeconds / 3600;
    return h > 0 ? distanceKm / h : 0;
  }

  int? get batteryUsed => (batteryStart != null && batteryEnd != null)
      ? (batteryStart! - batteryEnd!).clamp(0, 100)
      : null;

  /// Specific energy consumption in Wh/km (assuming TVS iQube 3.04 kWh battery pack).
  double? get whPerKm {
    if (batteryUsed == null || distanceKm <= 0.1) return null;
    return (batteryUsed! / 100.0 * 3040.0) / distanceKm;
  }

  /// Estimated money saved compared to a petrol scooter (45 km/L)
  double moneySaved(double petrolPrice) {
    final petrolCost = (distanceKm / 45.0) * petrolPrice;
    final electricCost = ((batteryUsed ?? (distanceKm / 0.8)) / 100.0) * 3.04 * 7.5;
    final saved = petrolCost - electricCost;
    return saved > 0 ? saved : 0;
  }

  /// Whether route points have speed coordinates.
  bool get hasSpeedData => route.any((p) => p.length > 2 && p[2] > 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'km': distanceKm,
        'top': topSpeedKmh,
        'bs': batteryStart,
        'be': batteryEnd,
        'tag': tag,
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
        tag: j['tag'] as String?,
        route: [
          for (final p in j['route'] as List)
            [
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
              if ((p as List).length > 2) (p[2] as num).toDouble(),
              if (p.length > 3) (p[3] as num).toDouble(),
              if (p.length > 4) (p[4] as num).toDouble(),
            ]
        ],
      );

  /// Exports route as a standard GPX file.
  String toGpx() {
    final b = StringBuffer();
    b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    b.writeln('<gpx version="1.1" creator="My iQube BLE Companion">');
    b.writeln('  <trk>');
    b.writeln('    <name>Ride ${start.toIso8601String()}</name>');
    b.writeln('    <trkseg>');
    for (final p in route) {
      final lat = p[0];
      final lon = p[1];
      final ele = p.length > 4 ? p[4] : 0.0;
      final timeStr = p.length > 3
          ? DateTime.fromMillisecondsSinceEpoch(p[3].toInt()).toUtc().toIso8601String()
          : null;
      b.write('      <trkpt lat="$lat" lon="$lon">');
      if (ele != 0.0) b.write('<ele>$ele</ele>');
      if (timeStr != null) b.write('<time>$timeStr</time>');
      final speed = p.length > 2 ? p[2] : null;
      if (speed != null) b.write('<speed>$speed</speed>');
      b.writeln('</trkpt>');
    }
    b.writeln('    </trkseg>');
    b.writeln('  </trk>');
    b.writeln('</gpx>');
    return b.toString();
  }

  /// Exports route as CSV.
  String toCsv() {
    final b = StringBuffer('latitude,longitude,speed_kmh,timestamp,elevation\n');
    for (final p in route) {
      final lat = p[0];
      final lon = p[1];
      final spd = p.length > 2 ? p[2] : 0.0;
      final time = p.length > 3 ? p[3].toInt() : 0;
      final ele = p.length > 4 ? p[4] : 0.0;
      b.writeln('$lat,$lon,$spd,$time,$ele');
    }
    return b.toString();
  }
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

  Future<void> updateTag(String id, String? tag) async {
    final idx = rides.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final old = rides[idx];
      rides[idx] = Ride(
        id: old.id,
        start: old.start,
        end: old.end,
        distanceKm: old.distanceKm,
        topSpeedKmh: old.topSpeedKmh,
        batteryStart: old.batteryStart,
        batteryEnd: old.batteryEnd,
        route: old.route,
        tag: tag,
      );
      await _save();
    }
  }

  Future<void> delete(String id) async {
    rides.removeWhere((r) => r.id == id);
    await _save();
  }

  /// Rides that started on today's calendar date.
  List<Ride> get ridesToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rides.where((r) {
      final rDay = DateTime(r.start.year, r.start.month, r.start.day);
      return rDay == today;
    }).toList();
  }

  double get kmToday => ridesToday.fold(0.0, (s, r) => s + r.distanceKm);

  int get batteryUsedToday =>
      ridesToday.fold(0, (s, r) => s + (r.batteryUsed ?? 0));

  /// Injects realistic sample rides for Demo / Preview mode.
  void injectDemoRides() {
    if (rides.isNotEmpty) return;
    final now = DateTime.now();
    rides.addAll([
      Ride(
        id: 'demo_ride_1',
        start: now.subtract(const Duration(hours: 3)),
        end: now.subtract(const Duration(hours: 2, minutes: 32)),
        distanceKm: 14.8,
        topSpeedKmh: 58.0,
        batteryStart: 84,
        batteryEnd: 68,
        tag: 'Commute',
        route: [
          [12.9716, 77.5946, 0.0, now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch.toDouble(), 920.0],
          [12.9730, 77.5960, 24.0, now.subtract(const Duration(hours: 2, minutes: 58)).millisecondsSinceEpoch.toDouble(), 921.0],
          [12.9760, 77.6010, 42.0, now.subtract(const Duration(hours: 2, minutes: 54)).millisecondsSinceEpoch.toDouble(), 924.0],
          [12.9810, 77.6080, 54.0, now.subtract(const Duration(hours: 2, minutes: 50)).millisecondsSinceEpoch.toDouble(), 925.0],
          [12.9880, 77.6150, 48.0, now.subtract(const Duration(hours: 2, minutes: 45)).millisecondsSinceEpoch.toDouble(), 928.0],
          [12.9940, 77.6220, 36.0, now.subtract(const Duration(hours: 2, minutes: 40)).millisecondsSinceEpoch.toDouble(), 926.0],
          [13.0010, 77.6300, 52.0, now.subtract(const Duration(hours: 2, minutes: 36)).millisecondsSinceEpoch.toDouble(), 930.0],
          [13.0050, 77.6350, 20.0, now.subtract(const Duration(hours: 2, minutes: 32)).millisecondsSinceEpoch.toDouble(), 931.0],
        ],
      ),
      Ride(
        id: 'demo_ride_2',
        start: now.subtract(const Duration(days: 1, hours: 5)),
        end: now.subtract(const Duration(days: 1, hours: 4, minutes: 5)),
        distanceKm: 32.5,
        topSpeedKmh: 72.0,
        batteryStart: 100,
        batteryEnd: 64,
        tag: 'Weekend',
        route: [
          [12.9716, 77.5946, 0.0, now.subtract(const Duration(days: 1, hours: 5)).millisecondsSinceEpoch.toDouble(), 920.0],
          [12.9650, 77.5850, 35.0, now.subtract(const Duration(days: 1, hours: 4, minutes: 50)).millisecondsSinceEpoch.toDouble(), 915.0],
          [12.9550, 77.5700, 58.0, now.subtract(const Duration(days: 1, hours: 4, minutes: 35)).millisecondsSinceEpoch.toDouble(), 935.0],
          [12.9400, 77.5500, 72.0, now.subtract(const Duration(days: 1, hours: 4, minutes: 20)).millisecondsSinceEpoch.toDouble(), 960.0],
          [12.9300, 77.5350, 45.0, now.subtract(const Duration(days: 1, hours: 4, minutes: 5)).millisecondsSinceEpoch.toDouble(), 980.0],
        ],
      ),
      Ride(
        id: 'demo_ride_3',
        start: now.subtract(const Duration(days: 2, hours: 2)),
        end: now.subtract(const Duration(days: 2, hours: 1, minutes: 45)),
        distanceKm: 6.2,
        topSpeedKmh: 44.0,
        batteryStart: 68,
        batteryEnd: 61,
        tag: 'Errand',
        route: [
          [12.9716, 77.5946, 0.0, now.subtract(const Duration(days: 2, hours: 2)).millisecondsSinceEpoch.toDouble(), 920.0],
          [12.9750, 77.5980, 32.0, now.subtract(const Duration(days: 2, hours: 1, minutes: 55)).millisecondsSinceEpoch.toDouble(), 922.0],
          [12.9800, 77.6020, 44.0, now.subtract(const Duration(days: 2, hours: 1, minutes: 50)).millisecondsSinceEpoch.toDouble(), 923.0],
          [12.9840, 77.6050, 15.0, now.subtract(const Duration(days: 2, hours: 1, minutes: 45)).millisecondsSinceEpoch.toDouble(), 921.0],
        ],
      ),
    ]);
    notifyListeners();
  }

  void clearDemoRides() {
    rides.removeWhere((r) => r.id.startsWith('demo_ride_'));
    notifyListeners();
  }

  /// Export backup JSON string of all rides.
  String exportBackupJson() => jsonEncode([for (final r in rides) r.toJson()]);

  /// Restore rides from backup JSON string.
  Future<int> restoreBackupJson(String rawJson) async {
    final list = jsonDecode(rawJson) as List;
    var count = 0;
    for (final item in list) {
      final r = Ride.fromJson(item as Map<String, dynamic>);
      if (!rides.any((existing) => existing.id == r.id)) {
        rides.add(r);
        count++;
      }
    }
    rides.sort((a, b) => b.start.compareTo(a.start));
    await _save();
    return count;
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
