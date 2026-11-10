import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble/vehicle_service.dart';
import 'rides/ride.dart';
import 'services/app_settings.dart';
import 'services/background.dart';
import 'services/battery_health.dart';
import 'services/charge_tracker.dart';
import 'services/cluster_info.dart';
import 'services/cluster_music.dart';
import 'services/cluster_notifier.dart';
import 'services/ride_summary.dart';
import 'ui/charging_screen.dart';
import 'ui/common.dart';
import 'ui/home_screen.dart';
import 'ui/rides_screen.dart';
import 'ui/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await RideStore.instance.load();
  await ChargeTracker.instance.load();
  await BatteryHealth.instance.load();
  // Started here, not in the UI: the background service runs this engine
  // with no screen, and the scooter link must work without the app open.
  await VehicleService.instance.init();
  await ClusterNotifier.instance.init();
  ClusterInfo.instance.init();
  ClusterMusic.instance.init();
  RideSummary.instance.init();
  Background.init();
  runApp(const IQubeApp());
}

class IQubeApp extends StatelessWidget {
  const IQubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My iQube',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // BLE scan results on older Android + rides
      Permission.notification, // ongoing "Recording ride" notification
      Permission.phone, // incoming call number for the cluster
      Permission.contacts, // caller name for the cluster
    ].request();
    // Without this, vivo and similar phones kill the background service.
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    // Permissions may have just been granted: try the saved scooter again
    // and re-check notification access.
    await VehicleService.instance.reconnectSaved();
    await ClusterNotifier.instance.refreshAccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          RidesScreen(),
          ChargingScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Rides'),
          NavigationDestination(
              icon: Icon(Icons.ev_station_outlined),
              selectedIcon: Icon(Icons.ev_station),
              label: 'Charging'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
