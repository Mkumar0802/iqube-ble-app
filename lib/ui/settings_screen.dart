import 'package:flutter/material.dart';

import '../ble/explorer_screen.dart';
import '../ble/telemetry_screen.dart';
import '../ble/vehicle_service.dart';
import '../services/app_settings.dart';
import '../services/cluster_info.dart';
import '../services/cluster_music.dart';
import '../services/cluster_navigation.dart';
import '../services/cluster_notifier.dart';
import 'common.dart';
import 'connect_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from Android's Notification access page.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ClusterNotifier.instance.refreshAccess();
    }
  }

  Future<void> _editNumber(String title, String unit, double value,
      Future<void> Function(double) save) async {
    final controller = TextEditingController(text: value.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(suffixText: unit),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) await save(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          AppSettings.instance,
          VehicleService.instance,
          ClusterNotifier.instance,
          ClusterInfo.instance,
          ClusterNavigation.instance,
          ClusterMusic.instance,
        ]),
        builder: (context, _) {
          final s = AppSettings.instance;
          final v = VehicleService.instance;
          final cluster = ClusterNotifier.instance;
          final info = ClusterInfo.instance;
          final nav = ClusterNavigation.instance;
          final music = ClusterMusic.instance;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle('Scooter'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.electric_moped),
                      title: Text(v.deviceName ?? 'No scooter paired'),
                      subtitle: Text(v.deviceId ?? 'Tap to find your iQube'),
                      onTap: () => showConnectSheet(context),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.autorenew),
                      title: const Text('Auto-connect'),
                      subtitle: const Text('Reconnect whenever the scooter is nearby'),
                      value: s.autoConnect,
                      onChanged: (x) => s.update(autoConnect: x),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.wb_cloudy_outlined),
                      title: const Text('Location & weather on cluster'),
                      subtitle: Text(info.place == null
                          ? 'Area name and weather, like TVS Connect'
                          : '${info.place}  •  ${info.weather ?? 'no weather yet'}'),
                      value: s.clusterPlaceWeather,
                      onChanged: (x) => s.update(clusterPlaceWeather: x),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.navigation_outlined),
                      title: const Text('Google Maps directions on cluster'),
                      subtitle: Text(nav.step != null
                          ? '${nav.step!.metresToTurn} m  •  ${nav.step!.clusterText}'
                          : nav.lastMaps != null
                              ? 'Maps: ${nav.lastMaps}'
                              : 'Start navigation in Google Maps (needs notification access)'),
                      value: s.clusterNavigation,
                      onChanged: (x) => s.update(clusterNavigation: x),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.music_note_outlined),
                      title: const Text('Music on cluster'),
                      subtitle: Text([
                        if (music.songLine.isNotEmpty)
                          '${music.playing ? 'Playing' : 'Paused'}: ${music.songLine}'
                        else
                          'Song name on the display; handlebar buttons control music',
                        if (music.lastButton != null) 'Last button: ${music.lastButton}',
                      ].join('\n')),
                      value: s.clusterMusic,
                      onChanged: (x) => s.update(clusterMusic: x),
                    ),
                    if (v.hasSavedScooter)
                      ListTile(
                        leading: const Icon(Icons.link_off),
                        title: const Text('Forget this scooter'),
                        onTap: v.forget,
                      ),
                  ],
                ),
              ),
              const SectionTitle('Notifications on cluster (experimental)'),
              Card(
                child: Column(
                  children: [
                    if (!cluster.accessGranted)
                      ListTile(
                        leading: const Icon(Icons.warning_amber, color: tvsRed),
                        title: const Text('Allow notification access'),
                        subtitle: const Text(
                            'Needed to read calls and messages. Tap, then turn on "My iQube BLE".'),
                        onTap: cluster.openAccessSettings,
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active),
                      title: const Text('Send to scooter display'),
                      value: s.clusterNotifications,
                      onChanged: (x) => s.update(clusterNotifications: x),
                    ),
                    for (final e in AppSettings.defaultClusterApps.entries)
                      CheckboxListTile(
                        dense: true,
                        title: Text(e.value),
                        value: s.clusterApps.contains(e.key),
                        onChanged: s.clusterNotifications
                            ? (x) => s.update(
                                clusterApps: x == true
                                    ? {...s.clusterApps, e.key}
                                    : ({...s.clusterApps}..remove(e.key)))
                            : null,
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => cluster.sendMessage('Test message'),
                            icon: const Icon(Icons.message, size: 18),
                            label: const Text('Test message'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => cluster.sendCall('Test call'),
                            icon: const Icon(Icons.call, size: 18),
                            label: const Text('Test call'),
                          ),
                          OutlinedButton.icon(
                            onPressed: nav.sendTest,
                            icon: const Icon(Icons.turn_left, size: 18),
                            label: const Text('Test directions'),
                          ),
                        ],
                      ),
                    ),
                    for (final line in cluster.sentLog.take(5))
                      ListTile(dense: true, title: Text(line)),
                  ],
                ),
              ),
              const SectionTitle('Range & charging'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.eco, color: batteryGreen),
                      title: const Text('Full-charge range (Eco)'),
                      trailing: Text('${s.fullRangeEcoKm.round()} km'),
                      onTap: () => _editNumber('Eco range at 100%', 'km',
                          s.fullRangeEcoKm, (x) => s.update(fullRangeEcoKm: x)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.flash_on, color: Color(0xFFF28C16)),
                      title: const Text('Full-charge range (Power)'),
                      trailing: Text('${s.fullRangePowerKm.round()} km'),
                      onTap: () => _editNumber('Power range at 100%', 'km',
                          s.fullRangePowerKm, (x) => s.update(fullRangePowerKm: x)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.battery_charging_full),
                      title: const Text('Default charge speed'),
                      trailing: Text('${s.chargeRatePctPerHour.round()} %/h'),
                      onTap: () => _editNumber('Charge speed', '% per hour',
                          s.chargeRatePctPerHour,
                          (x) => s.update(chargeRatePctPerHour: x)),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Developer'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.data_object),
                      title: const Text('Raw scooter data'),
                      subtitle: const Text('Every frame that changed, in hex'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const TelemetryScreen())),
                    ),
                    ListTile(
                      leading: const Icon(Icons.explore),
                      title: const Text('BLE Explorer'),
                      subtitle: const Text('Disconnects the scooter first'),
                      onTap: () async {
                        await v.disconnect();
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const BleExplorerScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
