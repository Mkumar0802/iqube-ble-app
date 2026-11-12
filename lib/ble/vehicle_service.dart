import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_settings.dart';
import '../services/charge_tracker.dart';
import 'frame_parser.dart';
import 'gatt_constants.dart';

enum VehicleLink { disconnected, connecting, connected }

/// Owns the one BLE connection to the scooter (it only accepts one at a
/// time), keeps it alive with the TVS-style heartbeat, and exposes the
/// decoded state to the UI.
class VehicleService extends ChangeNotifier {
  VehicleService._();
  static final VehicleService instance = VehicleService._();

  VehicleLink link = VehicleLink.disconnected;
  String? deviceId;
  String? deviceName;
  int? batteryPercent;
  double? dteKm;
  double? odometerKm;

  /// From 0x11 payload[3]; null until the scooter has reported it.
  bool? ignitionOn;
  DateTime? lastFrameAt;
  String? lastError;

  /// Latest raw frame per DataId, for the developer screen.
  final Map<int, List<int>> lastFrames = {};

  /// Changed frames only, newest first (capped).
  final List<String> frameLog = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<int>>? _notifySub;

  /// Every frame from the scooter, for services that react to buttons
  /// (the cluster's music controls).
  final _frames = StreamController<ParsedFrame>.broadcast();
  Stream<ParsedFrame> get frames => _frames.stream;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  Timer? _heartbeat;
  Timer? _reconnect;
  bool _userDisconnected = false;
  int _failedReconnects = 0;
  late SharedPreferences _prefs;

  bool get isConnected => link == VehicleLink.connected;
  bool get hasSavedScooter => deviceId != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    deviceId = _prefs.getString('deviceId');
    deviceName = _prefs.getString('deviceName');
    if (deviceId != null && AppSettings.instance.autoConnect) {
      unawaited(reconnectSaved());
    }
  }

  /// Scan results that look like a TVS scooter come first.
  Stream<List<ScanResult>> scan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    return FlutterBluePlus.scanResults.map((results) {
      final sorted = [...results]..sort((a, b) {
          final ta = _looksLikeScooter(a) ? 0 : 1;
          final tb = _looksLikeScooter(b) ? 0 : 1;
          return ta != tb ? ta - tb : b.rssi - a.rssi;
        });
      return sorted;
    });
  }

  static bool _looksLikeScooter(ScanResult r) {
    final n = r.device.platformName.toUpperCase();
    return n.contains('TVS') || n.contains('IQUBE');
  }

  static bool looksLikeScooter(ScanResult r) => _looksLikeScooter(r);

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> reconnectSaved() async {
    if (deviceId == null || link != VehicleLink.disconnected) return;
    await connect(BluetoothDevice.fromId(deviceId!), name: deviceName);
  }

  Future<void> connect(BluetoothDevice device, {String? name}) async {
    _reconnect?.cancel();
    _userDisconnected = false;
    await FlutterBluePlus.stopScan();
    _device = device;
    link = VehicleLink.connecting;
    lastError = null;
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.str.toLowerCase() == GattConstants.serviceUuid,
        orElse: () => throw StateError('This is not an iQube (TVS service missing)'),
      );
      BluetoothCharacteristic? notifyChar;
      for (final c in service.characteristics) {
        final u = c.uuid.str.toLowerCase();
        if (u == GattConstants.notifyCharacteristicUuid) notifyChar = c;
        if (u == GattConstants.writeCharacteristicUuid) _writeChar = c;
      }
      if (notifyChar == null || _writeChar == null) {
        throw StateError('TVS data characteristics missing');
      }

      await notifyChar.setNotifyValue(true);
      _notifySub = notifyChar.onValueReceived.listen(_onFrame);
      _stateSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) _onDisconnected();
      });

      // Same opening sequence as TVS Connect: hello, then a time heartbeat
      // every 2 s, which keeps the scooter streaming.
      await _writeChar!.write(FrameParser.helloFrame());
      _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
        send(FrameParser.timeHeartbeatFrame(DateTime.now()));
      });

      deviceId = device.remoteId.str;
      deviceName = (name?.isNotEmpty ?? false) ? name : device.platformName;
      await _prefs.setString('deviceId', deviceId!);
      if (deviceName != null) await _prefs.setString('deviceName', deviceName!);
      link = VehicleLink.connected;
      _failedReconnects = 0;
      notifyListeners();
    } catch (e) {
      lastError = '$e';
      await _cleanup();
      try {
        await device.disconnect();
      } catch (_) {}
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _reconnect?.cancel();
    await _device?.disconnect();
    await _cleanup();
  }

  /// Forget the saved scooter (stops auto-reconnect).
  Future<void> forget() async {
    await disconnect();
    deviceId = null;
    deviceName = null;
    batteryPercent = null;
    await _prefs.remove('deviceId');
    await _prefs.remove('deviceName');
    notifyListeners();
  }

  /// Writes one 20-byte frame to the scooter. Returns false if not connected.
  Future<bool> send(List<int> frame) async {
    final c = _writeChar;
    if (c == null || !isConnected) return false;
    try {
      await c.write(frame);
      return true;
    } catch (e) {
      lastError = 'write failed: $e';
      return false;
    }
  }

  void _onFrame(List<int> value) {
    final parsed = FrameParser.parse(value);
    lastFrameAt = DateTime.now();
    _frames.add(parsed);
    final id = parsed.dataId ?? -1;
    final previous = lastFrames[id];
    lastFrames[id] = value;
    if (previous == null || !listEquals(previous, value)) {
      final label = parsed.looksLikeTaggedFrame
          ? FrameParser.labelForDataId(id)
          : 'RAW';
      final line =
          '${lastFrameAt!.toIso8601String().substring(11, 19)}  $label  ${parsed.hexDump}';
      frameLog.insert(0, line);
      if (frameLog.length > 300) frameLog.removeLast();
      // Lets a developer capture changes over USB: adb logcat | grep IQFRAME
      debugPrint('IQFRAME $line');
    }

    final ignition = FrameParser.ignitionOn(parsed);
    if (ignition != null && ignition != ignitionOn) {
      ignitionOn = ignition;
      if (!ignition) {
        _recordParkedLocation();
      }
      notifyListeners();
    }
    dteKm = FrameParser.dteKm(parsed) ?? dteKm;
    odometerKm = FrameParser.odometerKm(parsed) ?? odometerKm;

    final battery = FrameParser.batteryPercent(parsed);
    if (battery != null) {
      ChargeTracker.instance.addSample(battery, lastFrameAt!);
      if (battery != batteryPercent) {
        batteryPercent = battery;
        notifyListeners();
        return;
      }
    }
    if (previous == null || !listEquals(previous, value)) notifyListeners();
  }

  Future<void> _recordParkedLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(timeLimit: Duration(seconds: 4)));
        await AppSettings.instance.saveParkedLocation(pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  int get reconnectCount => _failedReconnects;

  Future<int?> readRssi() async {
    try {
      final dev = _device;
      if (dev != null && isConnected) {
        final rssi = await dev.readRssi();
        return rssi;
      }
    } catch (_) {}
    return null;
  }

  void _onDisconnected() {
    if (link == VehicleLink.disconnected) return;
    _recordParkedLocation();
    _cleanup().then((_) => _scheduleReconnect());
  }

  void _scheduleReconnect() {
    if (_userDisconnected || !AppSettings.instance.autoConnect) return;
    if (deviceId == null) return;
    _reconnect?.cancel();
    // Back off while the scooter is out of range, to save the phone battery.
    _failedReconnects++;
    final wait = _failedReconnects <= 3
        ? const Duration(seconds: 8)
        : const Duration(seconds: 30);
    _reconnect = Timer(wait, reconnectSaved);
  }

  Future<void> _cleanup() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _notifySub?.cancel();
    await _stateSub?.cancel();
    _notifySub = null;
    _stateSub = null;
    _writeChar = null;
    link = VehicleLink.disconnected;
    notifyListeners();
  }
}
