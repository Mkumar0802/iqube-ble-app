import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/ble/vehicle_service.dart';
import 'package:iqube_ble_app/rides/ride.dart';
import 'package:iqube_ble_app/services/app_settings.dart';
import 'package:iqube_ble_app/services/battery_health.dart';
import 'package:iqube_ble_app/services/charge_tracker.dart';
import 'package:iqube_ble_app/services/demo_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  test('DemoMode activates simulated EV state across all stores', () {
    final demo = DemoMode.instance;
    final v = VehicleService.instance;
    final rides = RideStore.instance;
    final charges = ChargeTracker.instance;
    final health = BatteryHealth.instance;

    expect(demo.enabled, isFalse);

    // Turn Demo Mode ON
    demo.setEnabled(true);
    expect(demo.enabled, isTrue);
    expect(v.link, VehicleLink.connected);
    expect(v.deviceName, contains('Demo'));
    expect(v.batteryPercent, 78);
    expect(v.odometerKm, greaterThan(2000));
    expect(rides.rides, isNotEmpty);
    expect(charges.samples, isNotEmpty);
    expect(health.months, isNotEmpty);

    // Turn Demo Mode OFF
    demo.setEnabled(false);
    expect(demo.enabled, isFalse);
    expect(rides.rides, isEmpty);
    expect(charges.samples, isEmpty);
  });

  test('Ride export generates valid GPX and CSV data with speeds', () {
    final now = DateTime.now();
    final ride = Ride(
      id: 'test-ride-1',
      start: now.subtract(const Duration(minutes: 25)),
      end: now,
      distanceKm: 14.8,
      topSpeedKmh: 68.0,
      batteryStart: 85,
      batteryEnd: 72,
      tag: 'Commute',
      route: [
        [12.9716, 77.5946, 25.0, now.millisecondsSinceEpoch.toDouble(), 920.0],
        [12.9750, 77.5980, 52.0, (now.millisecondsSinceEpoch + 10000).toDouble(), 925.0],
      ],
    );

    expect(ride.whPerKm, greaterThan(0));
    expect(ride.moneySaved(102.0), greaterThan(0));

    final gpx = ride.toGpx();
    expect(gpx, contains('<?xml version="1.0"'));
    expect(gpx, contains('<trkpt lat="12.9716" lon="77.5946">'));
    expect(gpx, contains('<speed>25.0</speed>'));
    expect(gpx, contains('<ele>920.0</ele>'));

    final csv = ride.toCsv();
    expect(csv, contains('latitude,longitude,speed_kmh,timestamp,elevation'));
    expect(csv, contains('12.9716,77.5946,25.0'));
  });

  test('AppSettings persists theme mode and parked location', () {
    final s = AppSettings.instance;
    s.update(themeMode: 'dark');
    expect(s.themeMode, 'dark');

    s.update(themeMode: 'light');
    expect(s.themeMode, 'light');

    s.saveParkedLocation(12.9716, 77.5946);
    expect(s.lastParkedLat, 12.9716);
    expect(s.lastParkedLng, 77.5946);
    expect(s.lastParkedAt, isNotNull);
  });
}
