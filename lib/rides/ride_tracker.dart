import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../ble/vehicle_service.dart';
import 'ride.dart';

/// Records a ride from the phone's GPS. Runs as a foreground service (with
/// an ongoing notification) so it keeps going with the screen off — which
/// also keeps the app alive for the scooter connection.
class RideTracker extends ChangeNotifier {
  RideTracker._();
  static final RideTracker instance = RideTracker._();

  bool get isRecording => _sub != null;
  DateTime? startedAt;
  double distanceKm = 0;
  double speedKmh = 0;
  double topSpeedKmh = 0;
  int? batteryStart;
  final List<List<double>> _route = [];
  Position? _last;
  StreamSubscription<Position>? _sub;

  /// Returns an error message, or null when recording started.
  Future<String?> start() async {
    if (isRecording) return null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on Location (GPS) to record a ride.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return 'Location permission is needed to record rides.';
    }

    startedAt = DateTime.now();
    distanceKm = 0;
    speedKmh = 0;
    topSpeedKmh = 0;
    _route.clear();
    _last = null;
    batteryStart = VehicleService.instance.batteryPercent;

    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Recording ride',
          notificationText: 'My iQube is tracking your ride',
          notificationChannelName: 'Ride recording',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).listen(_onPosition);
    notifyListeners();
    return null;
  }

  void _onPosition(Position p) {
    if (p.accuracy > 30) return; // ignore poor fixes (tunnels, indoors)
    final last = _last;
    if (last != null) {
      final meters = Geolocator.distanceBetween(
          last.latitude, last.longitude, p.latitude, p.longitude);
      final seconds = p.timestamp.difference(last.timestamp).inMilliseconds / 1000;
      // Drop GPS jumps that would mean > 120 km/h.
      if (seconds > 0 && meters / seconds > 33) return;
      distanceKm += meters / 1000;
    }
    _last = p;
    speedKmh = p.speed > 0 ? p.speed * 3.6 : 0;
    if (speedKmh > topSpeedKmh && speedKmh < 120) topSpeedKmh = speedKmh;

    if (_route.isEmpty ||
        Geolocator.distanceBetween(_route.last[0], _route.last[1],
                p.latitude, p.longitude) >
            20) {
      _route.add([
        p.latitude,
        p.longitude,
        speedKmh,
        p.timestamp.millisecondsSinceEpoch.toDouble(),
        p.altitude,
      ]);
    }
    notifyListeners();
  }

  Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  /// Stops recording and saves the ride (if it went anywhere).
  Future<Ride?> stop() async {
    await _sub?.cancel();
    _sub = null;
    final start = startedAt;
    startedAt = null;
    speedKmh = 0;
    notifyListeners();
    if (start == null || distanceKm < 0.05) return null;

    final ride = Ride(
      id: start.millisecondsSinceEpoch.toString(),
      start: start,
      end: DateTime.now(),
      distanceKm: distanceKm,
      topSpeedKmh: topSpeedKmh,
      batteryStart: batteryStart,
      batteryEnd: VehicleService.instance.batteryPercent,
      route: List.of(_route),
    );
    await RideStore.instance.add(ride);
    return ride;
  }
}
