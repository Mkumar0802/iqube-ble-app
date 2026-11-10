import 'package:flutter/services.dart';

import '../ble/vehicle_service.dart';

/// Keeps ScooterService (the Android foreground service) running once a
/// scooter is paired, and mirrors the connection state in its notification.
class Background {
  Background._();

  static const _channel = MethodChannel('iqube/service');
  static bool _started = false;
  static String? _lastStatus;

  static void init() {
    VehicleService.instance.addListener(_onVehicle);
    _onVehicle();
  }

  static void _onVehicle() {
    final v = VehicleService.instance;
    if (!v.hasSavedScooter) return;
    if (!_started) {
      _started = true;
      _channel.invokeMethod('start').catchError((_) => _started = false);
    }
    final status = switch (v.link) {
      VehicleLink.connected => [
          'Connected',
          if (v.batteryPercent != null) '${v.batteryPercent}%',
          if (v.dteKm != null) 'DTE ${v.dteKm!.round()} km',
        ].join('  •  '),
      VehicleLink.connecting => 'Connecting…',
      VehicleLink.disconnected => 'Waiting for your iQube',
    };
    if (status == _lastStatus) return;
    _lastStatus = status;
    _channel.invokeMethod('status', {'text': status}).catchError((_) {});
  }
}
