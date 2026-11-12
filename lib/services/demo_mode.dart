import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/vehicle_service.dart';
import '../rides/ride.dart';
import 'app_settings.dart';
import 'battery_health.dart';
import 'charge_tracker.dart';

/// Full interactive simulation mode for evaluating and presenting the
/// entire iQube application without needing a live physical scooter.
class DemoMode extends ChangeNotifier {
  DemoMode._();
  static final DemoMode instance = DemoMode._();

  bool enabled = false;
  int percent = 78;
  Timer? _timer;

  // Stashed state to restore when demo mode turns off.
  VehicleLink? _realLink;
  String? _realName;
  String? _realId;
  int? _realBattery;
  double? _realOdo;
  double? _realDte;
  bool? _realIgnition;

  void setEnabled(bool on) {
    if (on == enabled) return;
    enabled = on;
    _timer?.cancel();
    _timer = null;

    final v = VehicleService.instance;
    final s = AppSettings.instance;

    if (on) {
      // Stash real values
      _realLink = v.link;
      _realName = v.deviceName;
      _realId = v.deviceId;
      _realBattery = v.batteryPercent;
      _realOdo = v.odometerKm;
      _realDte = v.dteKm;
      _realIgnition = v.ignitionOn;

      // Populate connected scooter telemetry
      percent = 78;
      v.link = VehicleLink.connected;
      v.deviceName = 'TVS iQube S (Demo)';
      v.deviceId = 'DEMO-IQUBE-EV-42';
      v.batteryPercent = 78;
      v.odometerKm = 2418.5;
      v.dteKm = 74.0;
      v.ignitionOn = true;
      v.lastFrameAt = DateTime.now();

      // Ensure demo location is set if empty
      if (s.lastParkedLat == null || s.lastParkedLng == null) {
        s.lastParkedLat = 12.9716;
        s.lastParkedLng = 77.5946;
        s.lastParkedAt = DateTime.now().subtract(const Duration(minutes: 42));
      }

      // Inject demo rides, charges, and battery health
      RideStore.instance.injectDemoRides();
      ChargeTracker.instance.injectDemoSamples();
      BatteryHealth.instance.injectDemoData();

      // Gentle telemetry oscillation
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        percent = (percent >= 90) ? 72 : percent + 1;
        v.batteryPercent = percent;
        v.dteKm = percent * 0.95;
        v.lastFrameAt = DateTime.now();
        notifyListeners();
      });
    } else {
      // Restore real values
      v.link = _realLink ?? VehicleLink.disconnected;
      v.deviceName = _realName;
      v.deviceId = _realId;
      v.batteryPercent = _realBattery;
      v.odometerKm = _realOdo;
      v.dteKm = _realDte;
      v.ignitionOn = _realIgnition;

      // Clean up demo datasets
      RideStore.instance.clearDemoRides();
      ChargeTracker.instance.clearDemoSamples();
      BatteryHealth.instance.clearDemoData();

      if (v.hasSavedScooter && s.autoConnect) {
        v.reconnectSaved();
      }
    }

    notifyListeners();
  }
}

/// What the battery screens show: the real scooter, or the demo.
class BatteryNow {
  const BatteryNow(
      {required this.percent,
      required this.charging,
      required this.dteKm,
      required this.demo});

  final int? percent;
  final bool charging;
  final double? dteKm;
  final bool demo;

  static BatteryNow read() {
    final demo = DemoMode.instance;
    if (demo.enabled) {
      return BatteryNow(
          percent: demo.percent,
          charging: demo.percent < 100,
          dteKm: demo.percent * 1.06,
          demo: true);
    }
    final v = VehicleService.instance;
    return BatteryNow(
        percent: v.batteryPercent,
        charging: ChargeTracker.instance.isCharging,
        dteKm: v.dteKm,
        demo: false);
  }
}
