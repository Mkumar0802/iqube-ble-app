import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ble/frame_parser.dart';
import '../ble/gatt_constants.dart';
import '../ble/vehicle_service.dart';
import 'battery_health.dart';

/// A ride as the scooter sees it: ignition on to ignition off, measured
/// with its own odometer and battery %, so it needs no GPS or Start button.
/// When the ignition goes off the summary goes to a phone notification and,
/// while the display is still awake, to the cluster.
class RideSummary extends ChangeNotifier {
  RideSummary._();
  static final RideSummary instance = RideSummary._();

  static const _service = MethodChannel('iqube/service');

  // Assumptions for the money line. A 3.4 kWh pack matches this scooter's
  // DTE (~106 km at 100%); the petrol side is a 110 cc scooter in Chennai.
  static const batteryKwh = 3.4;
  static const rupeesPerKwh = 8.0;
  static const petrolRupeesPerLitre = 101.0;
  static const petrolKmPerLitre = 50.0;

  DateTime? _start;
  double? _odoStart;
  int? _batteryStart;
  bool? _ignition;

  /// The last finished ride, shown on Home.
  String? last;

  void init() => VehicleService.instance.addListener(_onVehicle);

  void _onVehicle() {
    final v = VehicleService.instance;
    // The odometer can arrive after the ignition frame.
    if (_start != null) {
      _odoStart ??= v.odometerKm;
      _batteryStart ??= v.batteryPercent;
    }
    final on = v.ignitionOn;
    if (on == null || on == _ignition) return;
    _ignition = on;
    if (on) {
      _start = DateTime.now();
      _odoStart = v.odometerKm;
      _batteryStart = v.batteryPercent;
    } else if (_start != null) {
      _finish(v);
    }
  }

  void _finish(VehicleService v) {
    final start = _start!;
    final odoStart = _odoStart;
    final batteryStart = _batteryStart;
    _start = null;
    final odoEnd = v.odometerKm;
    if (odoStart == null || odoEnd == null) return;
    final km = odoEnd - odoStart;
    if (km < 0.1) return; // ignition on without riding

    final minutes = DateTime.now().difference(start).inMinutes;
    final used = batteryStart != null && v.batteryPercent != null
        ? (batteryStart - v.batteryPercent!).clamp(0, 100)
        : null;
    final summary = summarize(km: km, minutes: minutes, batteryUsed: used);
    last = summary.text;
    if (used != null) BatteryHealth.instance.addRide(km: km, used: used);
    notifyListeners();
    debugPrint('IQRIDE ${summary.text}');

    _service.invokeMethod('alert', {
      'id': 1,
      'title': 'Ride: ${km.toStringAsFixed(1)} km',
      'text': summary.text,
    }).catchError((_) {});
    v.send(FrameParser.textFrame(DataId.sms, summary.cluster));
  }

  /// The summary for a ride, as phone text and a 17-character cluster line.
  static ({String text, String cluster}) summarize(
      {required double km, required int minutes, int? batteryUsed}) {
    final distance = km.toStringAsFixed(1);
    final parts = <String>[
      '$distance km in $minutes min',
      if (minutes > 0) 'avg ${(km / minutes * 60).round()} km/h',
    ];
    int? saved;
    if (batteryUsed != null) {
      parts.add(batteryUsed > 0
          ? '$batteryUsed% battery (${(km / batteryUsed).toStringAsFixed(1)} km per %)'
          : 'under 1% battery');
      final electric = batteryUsed / 100 * batteryKwh * rupeesPerKwh;
      final petrol = km / petrolKmPerLitre * petrolRupeesPerLitre;
      saved = (petrol - electric).round();
      parts.add('cost ₹${electric.toStringAsFixed(0)}, saved ₹$saved vs petrol');
    }
    final cluster = saved == null ? '${distance}km ${minutes}min' : '${distance}km Saved Rs$saved';
    return (text: parts.join(' • '), cluster: cluster);
  }
}
