import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/vehicle_service.dart';
import 'cluster_notifier.dart';

/// Service responsible for orchestrating essential EV permissions at app startup:
/// - Bluetooth (Scan & Connect to discover and link to the iQube scooter)
/// - Location (Fine GPS for ride tracking, speed recording, and parked spot finder)
/// - Notifications & Foreground Services (Ongoing ride telemetry & charging alerts)
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  bool isBluetoothGranted = false;
  bool isLocationGranted = false;

  /// Prompts the user for all necessary permissions sequentially on application startup.
  Future<void> requestStartupPermissions() async {
    try {
      // 1. Bluetooth permissions (Android 12+ scan & connect, plus legacy Bluetooth)
      final btMap = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
      ].request();

      isBluetoothGranted = (btMap[Permission.bluetoothScan]?.isGranted ?? false) ||
          (btMap[Permission.bluetoothConnect]?.isGranted ?? false) ||
          (btMap[Permission.bluetooth]?.isGranted ?? false);

      // 2. Location permissions (Fine & Coarse GPS location for ride logging & BLE scanning)
      var locStatus = await Permission.locationWhenInUse.request();
      if (!locStatus.isGranted) {
        locStatus = await Permission.location.request();
      }

      // Also ensure Geolocator permission channel is checked and synchronized
      var geoPerm = await Geolocator.checkPermission();
      if (geoPerm == LocationPermission.denied) {
        geoPerm = await Geolocator.requestPermission();
      }

      isLocationGranted = locStatus.isGranted ||
          geoPerm == LocationPermission.always ||
          geoPerm == LocationPermission.whileInUse;

      // 3. Notifications (foreground service updates, charging targets & ride tracking)
      await Permission.notification.request();

      // 4. Optional Phone & Contacts permissions for cluster caller ID
      await [
        Permission.phone,
        Permission.contacts,
      ].request();

      // 5. Battery optimization ignore (keeps background BLE telemetry alive)
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      // 6. If Bluetooth is granted, immediately trigger reconnection to saved scooter
      if (isBluetoothGranted) {
        await VehicleService.instance.reconnectSaved();
      }
      await ClusterNotifier.instance.refreshAccess();
    } catch (e) {
      debugPrint('Startup permission request error: $e');
    }
  }

  /// Checks if both Bluetooth and Location are currently granted.
  Future<bool> hasRequiredPermissions() async {
    try {
      final btScan = await Permission.bluetoothScan.isGranted;
      final btConnect = await Permission.bluetoothConnect.isGranted;
      final btLegacy = await Permission.bluetooth.isGranted;
      final loc = await Permission.locationWhenInUse.isGranted;
      final geoPerm = await Geolocator.checkPermission();

      final btOk = btScan || btConnect || btLegacy;
      final locOk = loc ||
          geoPerm == LocationPermission.always ||
          geoPerm == LocationPermission.whileInUse;

      return btOk && locOk;
    } catch (_) {
      return false;
    }
  }

  /// Opens the device settings page for the user to grant permissions manually.
  Future<bool> openSettings() => openAppSettings();
}

