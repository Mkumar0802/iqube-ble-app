import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'frame_parser.dart';

/// Generic BLE explorer — needs NO prior knowledge of your vehicle's
/// Service/Characteristic UUIDs. Use this FIRST against your own iQube:
///   1. Scan, tap your vehicle in the list.
///   2. It connects and discovers every GATT service + characteristic.
///   3. It auto-subscribes to every characteristic that supports notify,
///      and prints every value that arrives, live, with a timestamp.
///   4. Ride around / charge / brake etc. on your own vehicle and watch
///      which characteristic's bytes change — that tells you which one
///      is your telemetry channel and what its real UUID is.
///
/// Once you know the UUIDs, copy them into gatt_constants.dart and use
/// TelemetryScreen for a proper parsed dashboard instead of this raw view.
class BleExplorerScreen extends StatefulWidget {
  const BleExplorerScreen({super.key});

  @override
  State<BleExplorerScreen> createState() => _BleExplorerScreenState();
}

class _BleExplorerScreenState extends State<BleExplorerScreen> {
  final List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothDevice? _connectedDevice;
  final List<_CharacteristicLog> _logs = [];
  final List<StreamSubscription> _notifySubs = [];
  bool _scanning = false;

  @override
  void dispose() {
    _scanSub?.cancel();
    for (final s in _notifySubs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanResults.clear();
      _scanning = true;
    });
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults
          ..clear()
          ..addAll(results);
      });
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    setState(() => _scanning = false);
  }

  Future<void> _connect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _logs.clear();
      _connectedDevice = device;
    });

    try {
      await device.connect(timeout: const Duration(seconds: 15));
    } catch (e) {
      _log('Connect failed: $e');
      return;
    }

    _log('Connected to ${device.platformName} (${device.remoteId}). '
        'Discovering services...');

    final services = await device.discoverServices();
    _log('Found ${services.length} service(s).');

    for (final service in services) {
      _log('SERVICE ${service.uuid}');
      for (final c in service.characteristics) {
        final props = <String>[
          if (c.properties.read) 'read',
          if (c.properties.write) 'write',
          if (c.properties.writeWithoutResponse) 'writeNoResp',
          if (c.properties.notify) 'notify',
          if (c.properties.indicate) 'indicate',
        ];
        _log('  CHAR ${c.uuid}  props=[${props.join(", ")}]');

        if (c.properties.read) {
          try {
            final value = await c.read();
            _log('    = ${FrameParser.parse(value)}');
          } catch (e) {
            _log('    could not read ${c.uuid}: $e');
          }
        }

        if (c.properties.notify || c.properties.indicate) {
          try {
            await c.setNotifyValue(true);
            final sub = c.onValueReceived.listen((value) {
              final parsed = FrameParser.parse(value);
              _log('    <- ${c.uuid}: $parsed');
            });
            _notifySubs.add(sub);
            _log('    subscribed to notifications on ${c.uuid}');
          } catch (e) {
            _log('    could not subscribe to ${c.uuid}: $e');
          }
        }
      }
    }
  }

  Future<void> _disconnect() async {
    for (final s in _notifySubs) {
      s.cancel();
    }
    _notifySubs.clear();
    await _connectedDevice?.disconnect();
    setState(() => _connectedDevice = null);
  }

  void _log(String message) {
    setState(() {
      _logs.insert(
        0,
        _CharacteristicLog(DateTime.now(), message),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Explorer (no UUID needed)')),
      body: _connectedDevice == null ? _buildScanList() : _buildLogView(),
      floatingActionButton: _connectedDevice == null
          ? FloatingActionButton.extended(
              onPressed: _scanning ? null : _startScan,
              label: Text(_scanning ? 'Scanning...' : 'Scan'),
              icon: const Icon(Icons.bluetooth_searching),
            )
          : FloatingActionButton.extended(
              onPressed: _disconnect,
              label: const Text('Disconnect'),
              icon: const Icon(Icons.bluetooth_disabled),
            ),
    );
  }

  Widget _buildScanList() {
    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final r = _scanResults[index];
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : '(unnamed)';
        return ListTile(
          title: Text(name),
          subtitle: Text('${r.device.remoteId}  rssi=${r.rssi}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _connect(r.device),
        );
      },
    );
  }

  Widget _buildLogView() {
    return ListView.builder(
      reverse: false,
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final entry = _logs[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(
            '[${entry.time.toIso8601String().substring(11, 19)}] ${entry.message}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        );
      },
    );
  }
}

class _CharacteristicLog {
  final DateTime time;
  final String message;
  _CharacteristicLog(this.time, this.message);
}
