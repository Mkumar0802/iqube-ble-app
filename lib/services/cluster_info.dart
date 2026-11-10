import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../ble/frame_parser.dart';
import '../ble/gatt_constants.dart';
import '../ble/vehicle_service.dart';
import 'app_settings.dart';

/// Shows the area name and weather on the cluster, like TVS Connect does
/// ("Kamaraja Puram", "Clouds 28⁰ C"), and warns when rain is coming
/// within the hour ("Rain soon 28⁰ C" plus a one-off message card).
///
/// The place name comes from Android's geocoder. The weather comes from
/// Open-Meteo (free, no key); only the position rounded to ~1 km is sent.
class ClusterInfo extends ChangeNotifier {
  ClusterInfo._();
  static final ClusterInfo instance = ClusterInfo._();

  static const _geo = MethodChannel('iqube/geo');
  static const _service = MethodChannel('iqube/service');

  String? place;
  String? weather;

  /// Minutes until rain is expected (within the hour), or null.
  int? rainInMinutes;
  DateTime? _rainAlertedAt;
  DateTime? updatedAt;

  Timer? _resend;
  Timer? _refresh;
  bool _wasConnected = false;

  void init() {
    VehicleService.instance.addListener(_onVehicle);
    AppSettings.instance.addListener(_onVehicle);
    unawaited(_askLocation());
    _onVehicle();
  }

  /// Weather needs the position, also with the app in the background.
  /// Android asks "while in use" first; "all the time" opens the app's
  /// location settings. Fails quietly when started with no screen.
  Future<void> _askLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('IQINFO location permission: $e');
    }
  }

  void _onVehicle() {
    final on = VehicleService.instance.isConnected &&
        AppSettings.instance.clusterPlaceWeather;
    if (on == _wasConnected) return;
    _wasConnected = on;
    _resend?.cancel();
    _refresh?.cancel();
    if (!on) return;
    // The cluster ignores frames sent right after the hello, so the first
    // update waits a few seconds; the last weather is shown meanwhile.
    Timer(const Duration(seconds: 3), () {
      if (_wasConnected) unawaited(_update());
    });
    // TVS Connect repeats these every 2 s; every 10 s keeps them on screen.
    _resend = Timer.periodic(const Duration(seconds: 10), (_) => _send());
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) => _update());
  }

  bool _updating = false;

  Future<void> _update() async {
    if (_updating) return;
    _updating = true;
    try {
      Position? pos;
      try {
        // A fresh fix each minute, so the place and weather follow the ride.
        pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 20)));
      } catch (e) {
        debugPrint('IQINFO fresh position failed: $e');
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) throw StateError('no position');
      place = await _placeName(pos.latitude, pos.longitude) ?? place;
      weather = await _weather(pos.latitude, pos.longitude) ?? weather;
      updatedAt = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('IQINFO update failed: $e');
    } finally {
      _updating = false;
    }
    _send();
    _rainAlert();
  }

  /// Once an hour at most: message card on the cluster and a phone alert.
  void _rainAlert() {
    final minutes = rainInMinutes;
    if (minutes == null) return;
    final last = _rainAlertedAt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 1)) {
      return;
    }
    _rainAlertedAt = DateTime.now();
    final text = minutes <= 0 ? 'Rain starting now' : 'Rain in $minutes min';
    VehicleService.instance.send(FrameParser.textFrame(DataId.sms, text));
    _service.invokeMethod('alert', {
      'id': 2,
      'title': text,
      'text': '$text at ${place ?? 'your location'}. Ride safe.',
    }).catchError((_) {});
  }

  void _send() {
    final v = VehicleService.instance;
    if (place != null) {
      v.send(FrameParser.textFrame(DataId.currentLocation, place!));
    }
    // Weather is UTF-8 (TVS sends the "⁰" sign), so it bypasses textFrame's
    // ASCII clean-up. "-" is what TVS sends when it has no weather.
    v.send(FrameParser.bytesFrame(
        DataId.climateOrWeather, utf8.encode(weather ?? '-')));
  }

  Future<String?> _placeName(double lat, double lon) async {
    try {
      return await _geo.invokeMethod<String>('placeName', {'lat': lat, 'lon': lon});
    } catch (_) {
      return null;
    }
  }

  /// "Clouds 28⁰ C", using OpenWeatherMap-style condition words as TVS does.
  Future<String?> _weather(double lat, double lon) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(2),
        'longitude': lon.toStringAsFixed(2),
        'current': 'temperature_2m,weather_code,precipitation',
        'minutely_15': 'precipitation',
        'forecast_minutely_15': '4',
      });
      final res = await (await client.getUrl(uri)).close();
      if (res.statusCode != 200) return null;
      final json = jsonDecode(await res.transform(utf8.decoder).join());
      final current = json['current'] as Map<String, dynamic>;
      final temp = (current['temperature_2m'] as num).round();
      final code = current['weather_code'] as int;
      rainInMinutes = rainSoon(
        rainingNow: (current['precipitation'] as num? ?? 0) > 0 || code >= 51,
        next15min: [
          for (final p in (json['minutely_15']?['precipitation'] as List? ?? []))
            (p as num?)?.toDouble() ?? 0,
        ],
      );
      final cond = rainInMinutes != null ? 'Rain soon' : _condition(code);
      return '$cond $temp⁰ C';
    } catch (e) {
      debugPrint('IQINFO weather failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Minutes until rain from Open-Meteo's 15-minute slots (slot 0 is the
  /// current quarter hour), or null if it is raining already or stays dry.
  @visibleForTesting
  static int? rainSoon({required bool rainingNow, required List<double> next15min}) {
    if (rainingNow) return null;
    for (var i = 0; i < next15min.length; i++) {
      if (next15min[i] >= 0.2) return i * 15;
    }
    return null;
  }

  /// WMO weather code -> short condition word.
  static String _condition(int code) => switch (code) {
        0 => 'Clear',
        1 || 2 || 3 => 'Clouds',
        45 || 48 => 'Fog',
        >= 51 && <= 57 => 'Drizzle',
        >= 61 && <= 67 || >= 80 && <= 82 => 'Rain',
        >= 71 && <= 77 || 85 || 86 => 'Snow',
        >= 95 => 'Storm',
        _ => 'Clouds',
      };

  @override
  void dispose() {
    _resend?.cancel();
    _refresh?.cancel();
    super.dispose();
  }
}
