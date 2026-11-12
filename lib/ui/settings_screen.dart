import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/explorer_screen.dart';
import '../ble/telemetry_screen.dart';
import '../ble/vehicle_service.dart';
import '../rides/ride.dart';
import '../services/app_settings.dart';
import '../services/cluster_info.dart';
import '../services/cluster_music.dart';
import '../services/cluster_navigation.dart';
import '../services/cluster_notifier.dart';
import '../services/demo_mode.dart';
import 'common.dart';
import 'connect_sheet.dart';
import 'widgets/kit.dart';
import 'widgets/scale_on_tap.dart';

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
    final controller = TextEditingController(text: value.toStringAsFixed(1));
    final result = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  Future<void> _exportBackup() async {
    final ridesJson = RideStore.instance.exportBackupJson();
    final settings = AppSettings.instance;
    final backupMap = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'rides': jsonDecode(ridesJson),
      'settings': {
        'petrolPrice': settings.petrolPricePerLitre,
        'electricityRate': settings.electricityRatePerKwh,
        'serviceInterval': settings.serviceIntervalKm,
        'fullRangeEco': settings.fullRangeEcoKm,
        'fullRangePower': settings.fullRangePowerKm,
      },
    };
    final fullJson = const JsonEncoder.withIndent('  ').convert(backupMap);
    await Clipboard.setData(ClipboardData(text: fullJson));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup JSON copied to clipboard!')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Restore Backup',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paste your exported JSON backup text below:',
                style: GoogleFonts.outfit(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText: '{\n  "version": 1,\n  "rides": [...]\n}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      try {
        final map = jsonDecode(controller.text) as Map<String, dynamic>;
        var count = 0;
        if (map.containsKey('rides')) {
          count = await RideStore.instance
              .restoreBackupJson(jsonEncode(map['rides']));
        }
        if (map.containsKey('settings')) {
          final s = map['settings'] as Map<String, dynamic>;
          await AppSettings.instance.update(
            petrolPricePerLitre: (s['petrolPrice'] as num?)?.toDouble(),
            electricityRatePerKwh: (s['electricityRate'] as num?)?.toDouble(),
            serviceIntervalKm: (s['serviceInterval'] as num?)?.toDouble(),
            fullRangeEcoKm: (s['fullRangeEco'] as num?)?.toDouble(),
            fullRangePowerKm: (s['fullRangePower'] as num?)?.toDouble(),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restored $count rides and settings!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore backup: $e')),
          );
        }
      }
    }
  }

  Widget _buildSwitchIcon({
    required bool active,
    required IconData activeIcon,
    required IconData inactiveIcon,
    Color? activeColor,
    Color? inactiveColor,
  }) {
    final motion = AppMotion.of(context);
    final c = AppColors.of(context);
    return AnimatedSwitcher(
      duration: resolveMotion(context, motion.fast),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Icon(
        active ? activeIcon : inactiveIcon,
        key: ValueKey('settings_switch_${activeIcon.codePoint}_$active'),
        color: active
            ? (activeColor ?? c.brand)
            : (inactiveColor ?? c.onSurfaceMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          AppSettings.instance,
          VehicleService.instance,
          ClusterNotifier.instance,
          ClusterInfo.instance,
          ClusterNavigation.instance,
          ClusterMusic.instance,
          DemoMode.instance,
        ]),
        builder: (context, _) {
          final s = AppSettings.instance;
          final v = VehicleService.instance;
          final cluster = ClusterNotifier.instance;
          final info = ClusterInfo.instance;
          final nav = ClusterNavigation.instance;
          final music = ClusterMusic.instance;
          final c = AppColors.of(context);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Scooter Card
              const SectionTitle('Scooter'),
              Reveal(
                index: 0,
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: v.isConnected
                            ? BreathingGlow(
                                color: c.energy,
                                size: 38,
                                intensity: 0.5,
                                child: Icon(Icons.electric_moped,
                                    color: c.energy),
                              )
                            : const Icon(Icons.electric_moped),
                        title: Text(v.deviceName ?? 'No scooter paired',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(v.deviceId ?? 'Tap to find your iQube'),
                        onTap: () => showConnectSheet(context),
                      ),
                      SwitchListTile(
                        secondary: _buildSwitchIcon(
                          active: s.autoConnect,
                          activeIcon: Icons.autorenew,
                          inactiveIcon: Icons.sync_disabled_rounded,
                        ),
                        title: const Text('Auto-connect'),
                        subtitle: const Text(
                            'Reconnect whenever the scooter is nearby'),
                        value: s.autoConnect,
                        onChanged: (x) => s.update(autoConnect: x),
                      ),
                      SwitchListTile(
                        secondary: _buildSwitchIcon(
                          active: s.clusterPlaceWeather,
                          activeIcon: Icons.wb_cloudy,
                          inactiveIcon: Icons.wb_cloudy_outlined,
                        ),
                        title: const Text('Location & weather on cluster'),
                        subtitle: Text(info.place == null
                            ? 'Area name and weather, like TVS Connect'
                            : '${info.place}  •  ${info.weather ?? 'no weather yet'}'),
                        value: s.clusterPlaceWeather,
                        onChanged: (x) => s.update(clusterPlaceWeather: x),
                      ),
                      SwitchListTile(
                        secondary: _buildSwitchIcon(
                          active: s.clusterNavigation,
                          activeIcon: Icons.navigation,
                          inactiveIcon: Icons.navigation_outlined,
                        ),
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
                        secondary: _buildSwitchIcon(
                          active: s.clusterMusic,
                          activeIcon: Icons.music_note,
                          inactiveIcon: Icons.music_note_outlined,
                        ),
                        title: const Text('Music on cluster'),
                        subtitle: Text([
                          if (music.songLine.isNotEmpty)
                            '${music.playing ? 'Playing' : 'Paused'}: ${music.songLine}'
                          else
                            'Song name on the display; handlebar buttons control music',
                          if (music.lastButton != null)
                            'Last button: ${music.lastButton}',
                        ].join('\n')),
                        value: s.clusterMusic,
                        onChanged: (x) => s.update(clusterMusic: x),
                      ),
                      if (v.hasSavedScooter)
                        ScaleOnTap(
                          onTap: v.forget,
                          child: ListTile(
                            leading: Icon(Icons.link_off, color: c.danger),
                            title: Text('Forget this scooter',
                                style: TextStyle(color: c.danger)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2. Notifications Card
              const SectionTitle('Notifications on cluster (experimental)'),
              Reveal(
                index: 1,
                child: Card(
                  child: Column(
                    children: [
                      if (!cluster.accessGranted)
                        ListTile(
                          leading: Icon(Icons.warning_amber, color: c.danger),
                          title: const Text('Allow notification access'),
                          subtitle: const Text(
                              'Needed to read calls and messages. Tap, then turn on "My iQube BLE".'),
                          onTap: cluster.openAccessSettings,
                        ),
                      SwitchListTile(
                        secondary: _buildSwitchIcon(
                          active: s.clusterNotifications,
                          activeIcon: Icons.notifications_active,
                          inactiveIcon: Icons.notifications_off_outlined,
                        ),
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
                          runSpacing: 8,
                          children: [
                            ScaleOnTap(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    cluster.sendMessage('Test message'),
                                icon: const Icon(Icons.message, size: 18),
                                label: const Text('Test message'),
                              ),
                            ),
                            ScaleOnTap(
                              child: OutlinedButton.icon(
                                onPressed: () => cluster.sendCall('Test call'),
                                icon: const Icon(Icons.call, size: 18),
                                label: const Text('Test call'),
                              ),
                            ),
                            ScaleOnTap(
                              child: OutlinedButton.icon(
                                onPressed: nav.sendTest,
                                icon: const Icon(Icons.turn_left, size: 18),
                                label: const Text('Test directions'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final line in cluster.sentLog.take(5))
                        ListTile(dense: true, title: Text(line)),
                    ],
                  ),
                ),
              ),

              // 3. Pricing & Maintenance (NEW)
              const SectionTitle('Pricing & Maintenance'),
              Reveal(
                index: 2,
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.local_gas_station_rounded,
                            color: c.warning),
                        title: const Text('Petrol price per litre'),
                        subtitle: const Text('Used to calculate savings vs ICE scooter'),
                        trailing: Text('₹${s.petrolPricePerLitre.toStringAsFixed(1)} / L',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        onTap: () => _editNumber(
                            'Petrol price per litre',
                            '₹ / L',
                            s.petrolPricePerLitre,
                            (x) => s.update(petrolPricePerLitre: x)),
                      ),
                      ListTile(
                        leading: Icon(Icons.bolt_rounded, color: c.energy),
                        title: const Text('Electricity rate per kWh'),
                        subtitle: const Text('Used to estimate recharge cost'),
                        trailing: Text('₹${s.electricityRatePerKwh.toStringAsFixed(1)} / kWh',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        onTap: () => _editNumber(
                            'Electricity tariff',
                            '₹ / kWh',
                            s.electricityRatePerKwh,
                            (x) => s.update(electricityRatePerKwh: x)),
                      ),
                      ListTile(
                        leading: Icon(Icons.build_circle_outlined, color: c.brand),
                        title: const Text('Service reminder interval'),
                        subtitle: const Text('Odometer interval between maintenance checkups'),
                        trailing: Text('${s.serviceIntervalKm.round()} km',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        onTap: () => _editNumber(
                            'Service interval',
                            'km',
                            s.serviceIntervalKm,
                            (x) => s.update(serviceIntervalKm: x)),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Range & Charging
              const SectionTitle('Range & charging'),
              Reveal(
                index: 3,
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.eco, color: c.energy),
                        title: const Text('Full-charge range (Eco)'),
                        trailing: Text('${s.fullRangeEcoKm.round()} km'),
                        onTap: () => _editNumber(
                            'Eco range at 100%',
                            'km',
                            s.fullRangeEcoKm,
                            (x) => s.update(fullRangeEcoKm: x)),
                      ),
                      ListTile(
                        leading: Icon(Icons.flash_on, color: c.warning),
                        title: const Text('Full-charge range (Power)'),
                        trailing: Text('${s.fullRangePowerKm.round()} km'),
                        onTap: () => _editNumber(
                            'Power range at 100%',
                            'km',
                            s.fullRangePowerKm,
                            (x) => s.update(fullRangePowerKm: x)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.battery_charging_full),
                        title: const Text('Default charge speed'),
                        trailing: Text('${s.chargeRatePctPerHour.round()} %/h'),
                        onTap: () => _editNumber(
                            'Charge speed',
                            '% per hour',
                            s.chargeRatePctPerHour,
                            (x) => s.update(chargeRatePctPerHour: x)),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Backup & Restore (NEW)
              const SectionTitle('Backup & Restore'),
              Reveal(
                index: 4,
                child: Card(
                  child: Column(
                    children: [
                      ScaleOnTap(
                        onTap: _exportBackup,
                        child: ListTile(
                          leading: Icon(Icons.file_upload_outlined, color: c.brand),
                          title: const Text('Export backup (JSON)'),
                          subtitle: const Text('Copies all rides and preferences to clipboard'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                      ScaleOnTap(
                        onTap: _restoreBackup,
                        child: ListTile(
                          leading: Icon(Icons.file_download_outlined, color: c.energy),
                          title: const Text('Restore backup (JSON)'),
                          subtitle: const Text('Import rides and preferences from pasted JSON'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. App
              const SectionTitle('App'),
              Reveal(
                index: 5,
                child: Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: _buildSwitchIcon(
                          active: s.haptics,
                          activeIcon: Icons.vibration_rounded,
                          inactiveIcon: Icons.mobile_off_outlined,
                        ),
                        title: const Text('Haptic feedback'),
                        subtitle:
                            const Text('Small vibrations on taps and rides'),
                        value: s.haptics,
                        onChanged: (x) => s.update(haptics: x),
                      ),
                      SwitchListTile(
                        secondary: _buildSwitchIcon(
                          active: DemoMode.instance.enabled,
                          activeIcon: Icons.auto_awesome_rounded,
                          inactiveIcon: Icons.auto_awesome_outlined,
                        ),
                        title: const Text('Preview mode'),
                        subtitle: const Text(
                            'Shows a pretend charging scooter on Home and Charging. '
                            'Nothing is sent or saved.'),
                        value: DemoMode.instance.enabled,
                        onChanged: DemoMode.instance.setEnabled,
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Developer & Diagnostics
              const SectionTitle('Developer'),
              Reveal(
                index: 6,
                child: Card(
                  child: Column(
                    children: [
                      ScaleOnTap(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const DiagnosticsScreen())),
                        child: ListTile(
                          leading: Icon(Icons.monitor_heart_outlined, color: c.brand),
                          title: const Text('Diagnostics'),
                          subtitle: const Text('Live BLE RSSI, frame rate & reconnect telemetry'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                      ScaleOnTap(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TelemetryScreen())),
                        child: const ListTile(
                          leading: Icon(Icons.data_object),
                          title: Text('Raw scooter data'),
                          subtitle: Text('Every frame that changed, in hex'),
                          trailing: Icon(Icons.chevron_right),
                        ),
                      ),
                      ScaleOnTap(
                        onTap: () async {
                          await v.disconnect();
                          if (!context.mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const BleExplorerScreen()));
                        },
                        child: const ListTile(
                          leading: Icon(Icons.explore),
                          title: Text('BLE Explorer'),
                          subtitle: Text('Disconnects the scooter first'),
                          trailing: Icon(Icons.chevron_right),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Diagnostics Screen showing live BLE RSSI, frame rate, last frame hex, reconnects, and exportable log
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  int? _rssi;
  int _frameCount = 0;
  double _fps = 0.0;
  DateTime _lastSec = DateTime.now();
  int _framesInLastSec = 0;
  StreamSubscription? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refreshRssi();
    _sub = VehicleService.instance.frames.listen((_) {
      _frameCount++;
      _framesInLastSec++;
      final now = DateTime.now();
      final diff = now.difference(_lastSec).inMilliseconds;
      if (diff >= 1000) {
        if (mounted) {
          setState(() {
            _fps = (_framesInLastSec * 1000.0) / diff;
            _framesInLastSec = 0;
            _lastSec = now;
          });
        }
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshRssi());
  }

  Future<void> _refreshRssi() async {
    final val = await VehicleService.instance.readRssi();
    if (mounted) setState(() => _rssi = val);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = VehicleService.instance;
    final c = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Diagnostics',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRssi,
            tooltip: 'Refresh RSSI',
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy Frame Log',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: v.frameLog.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Frame log copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: v,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bluetooth_connected_rounded,
                              color: v.isConnected ? c.energy : c.onSurfaceMuted,
                              size: 20),
                          const SizedBox(width: 8),
                          Text('LINK TELEMETRY',
                              style: AppText.overline
                                  .copyWith(color: c.onSurfaceMuted)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _rssi != null ? '$_rssi dBm' : (v.isConnected ? 'Measuring...' : 'Offline'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: _rssi != null && _rssi! >= -75 ? c.energy : c.warning,
                                  ),
                                ),
                                Text('Signal (RSSI)',
                                    style: AppText.caption
                                        .copyWith(color: c.onSurfaceMuted)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_fps.toStringAsFixed(1)} fps',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: c.brand,
                                  ),
                                ),
                                Text('Live throughput',
                                    style: AppText.caption
                                        .copyWith(color: c.onSurfaceMuted)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${v.reconnectCount}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: v.reconnectCount > 0 ? c.warning : c.onSurface,
                                  ),
                                ),
                                Text('Reconnects',
                                    style: AppText.caption
                                        .copyWith(color: c.onSurfaceMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.memory_rounded, color: c.brand, size: 20),
                          const SizedBox(width: 8),
                          Text('LAST RECEIVED FRAME',
                              style: AppText.overline
                                  .copyWith(color: c.onSurfaceMuted)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v.frameLog.isNotEmpty
                              ? v.frameLog.first
                              : 'No frame received yet.',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Total frames processed: $_frameCount',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: c.onSurfaceMuted)),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Recent Frame Log'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: v.frameLog.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text('Frame log is empty.'),
                          ),
                        )
                      : Column(
                          children: [
                            for (final frame in v.frameLog.take(25))
                              ListTile(
                                dense: true,
                                title: Text(
                                  frame,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
