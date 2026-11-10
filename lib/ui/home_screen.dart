import 'dart:async';

import 'package:flutter/material.dart';

import '../ble/vehicle_service.dart';
import '../rides/ride.dart';
import '../rides/ride_tracker.dart';
import '../services/app_settings.dart';
import '../services/charge_tracker.dart';
import '../services/cluster_notifier.dart';
import '../services/range_estimator.dart';
import '../services/ride_summary.dart';
import 'battery_health_screen.dart';
import 'common.dart';
import 'connect_sheet.dart';
import 'rides_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Refreshes "synced x ago" and the live ride clock.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        VehicleService.instance,
        RideTracker.instance,
        RideStore.instance,
        ChargeTracker.instance,
        AppSettings.instance,
        ClusterNotifier.instance,
        RideSummary.instance,
      ]),
      builder: (context, _) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          // Not const: the cards read the services directly, so they must be
          // rebuilt whenever this ListenableBuilder fires.
          // ignore: prefer_const_literals_to_create_immutables
          children: [
            // ignore: prefer_const_constructors
            _Header(),
            const SizedBox(height: 16),
            // ignore: prefer_const_constructors
            _BatteryCard(),
            const SizedBox(height: 12),
            // ignore: prefer_const_constructors
            _RideCard(),
            if (RideSummary.instance.last != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Last ride'),
                  subtitle: Text(RideSummary.instance.last!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Battery health'),
                subtitle: const Text('Range and charge cycles over the months'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BatteryHealthScreen())),
              ),
            ),
            const SectionTitle('All rides'),
            // ignore: prefer_const_constructors
            _TotalsCard(),
            const SizedBox(height: 12),
            // ignore: prefer_const_constructors
            _ClusterCard(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final v = VehicleService.instance;
    final theme = Theme.of(context);
    final (color, text) = switch (v.link) {
      VehicleLink.connected => (batteryGreen, 'Connected'),
      VehicleLink.connecting => (const Color(0xFFF2A516), 'Connecting...'),
      VehicleLink.disconnected =>
        (theme.colorScheme.outline, v.hasSavedScooter ? 'Offline' : 'Not paired'),
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My iQube',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: tvsBlue)),
              Text(v.deviceName ?? 'TVS iQube Electric',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        ActionChip(
          avatar: Icon(Icons.circle, size: 12, color: color),
          label: Text(text),
          onPressed: () {
            if (v.link == VehicleLink.connected) return;
            if (v.hasSavedScooter) {
              v.reconnectSaved();
            } else {
              showConnectSheet(context);
            }
          },
        ),
      ],
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard();

  @override
  Widget build(BuildContext context) {
    final v = VehicleService.instance;
    final charge = ChargeTracker.instance;
    final theme = Theme.of(context);
    final pct = v.batteryPercent;

    if (pct == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.electric_moped, size: 56, color: tvsBlue),
              const SizedBox(height: 12),
              Text(
                v.hasSavedScooter
                    ? 'Waiting for your scooter...'
                    : 'Pair your iQube to see battery and range',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (v.lastError != null && !v.isConnected) ...[
                const SizedBox(height: 6),
                Text(v.lastError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showConnectSheet(context),
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(v.hasSavedScooter ? 'Connect again' : 'Find my scooter'),
              ),
            ],
          ),
        ),
      );
    }

    final range = RangeEstimate.forBattery(pct)!;
    final charging = charge.isCharging;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _BatteryBar(percent: pct, charging: charging)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Range', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    if (v.dteKm != null)
                      _rangeRow('DTE', v.dteKm!.round(), theme.colorScheme.primary, theme),
                    _rangeRow('ECO', range.ecoKm, batteryGreen, theme),
                    _rangeRow('PWR', range.powerKm, const Color(0xFFF28C16), theme),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  charging ? Icons.bolt : Icons.sync,
                  size: 16,
                  color: charging ? batteryGreen : theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    charging
                        ? 'Charging  •  100% in ${formatDuration(charge.timeTo(pct, 100))}'
                        : v.lastFrameAt == null
                            ? ''
                            : 'Synced ${timeAgo(v.lastFrameAt!)}'
                                '${v.odometerKm != null ? '  •  ODO ${v.odometerKm!.toStringAsFixed(1)} km' : ''}'
                                '${range.learned ? '  •  range from your rides' : '  •  estimated range'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeRow(String mode, int km, Color c, ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
                width: 40,
                child: Text(mode,
                    style: TextStyle(color: c, fontWeight: FontWeight.w700))),
            Text('$km km',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _BatteryBar extends StatelessWidget {
  final int percent;
  final bool charging;
  const _BatteryBar({required this.percent, required this.charging});

  @override
  Widget build(BuildContext context) {
    final color = batteryColor(percent);
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: percent.clamp(0, 100) / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.85), color]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('$percent',
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87)),
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Text('%',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                ),
                if (charging)
                  const Icon(Icons.bolt, size: 32, color: Colors.black87),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard();

  Future<void> _start(BuildContext context) async {
    final error = await RideTracker.instance.start();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _stop(BuildContext context) async {
    final ride = await RideTracker.instance.stop();
    if (!context.mounted) return;
    if (ride == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride too short — not saved')));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RideDetailScreen(ride: ride)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RideTracker.instance;
    final theme = Theme.of(context);

    if (!t.isRecording) {
      final last = RideStore.instance.rides.firstOrNull;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ride', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      last == null
                          ? 'Record distance, speed and battery used'
                          : 'Last: ${last.distanceKm.toStringAsFixed(1)} km  •  '
                              '${formatDate(last.start)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _start(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start ride'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: tvsBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: tvsRed, size: 14),
                const SizedBox(width: 6),
                const Text('Riding',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => _stop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('End ride'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _live('${t.speedKmh.round()}', 'km/h'),
                _live(t.distanceKm.toStringAsFixed(2), 'km'),
                _live(formatClock(t.elapsed), 'time'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _live(String value, String unit) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
          Text(unit, style: const TextStyle(color: Colors.white70)),
        ],
      );
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard();

  @override
  Widget build(BuildContext context) {
    final store = RideStore.instance;
    return Card(
      child: Row(
        children: [
          Expanded(
              child: StatTile(
                  icon: Icons.route,
                  label: 'Total rides',
                  value: '${store.rides.length}')),
          Expanded(
              child: StatTile(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: store.totalKm.toStringAsFixed(0),
                  unit: 'km')),
          Expanded(
              child: StatTile(
                  icon: Icons.speed,
                  label: 'Top speed',
                  value: store.topSpeedKmh.toStringAsFixed(0),
                  unit: 'km/h')),
        ],
      ),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard();

  @override
  Widget build(BuildContext context) {
    final on = AppSettings.instance.clusterNotifications &&
        ClusterNotifier.instance.accessGranted;
    return Card(
      child: ListTile(
        leading: Icon(on ? Icons.notifications_active : Icons.notifications_off,
            color: on ? tvsBlue : null),
        title: const Text('Notifications on cluster'),
        subtitle: Text(on
            ? 'Calls and messages are sent to your scooter'
            : 'Off — turn on in Settings'),
      ),
    );
  }
}
