import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../rides/ride.dart';
import 'common.dart';

class RidesScreen extends StatelessWidget {
  const RidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rides')),
      body: ListenableBuilder(
        listenable: RideStore.instance,
        builder: (context, _) {
          final store = RideStore.instance;
          if (store.rides.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No rides yet.\nTap "Start ride" on the Home tab before you ride.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final kmPerPct = store.learnedKmPerPercent;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Row(
                  children: [
                    Expanded(
                        child: StatTile(
                            icon: Icons.route,
                            label: 'Rides',
                            value: '${store.rides.length}')),
                    Expanded(
                        child: StatTile(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: store.totalKm.toStringAsFixed(1),
                            unit: 'km')),
                    Expanded(
                        child: StatTile(
                            icon: Icons.battery_charging_full,
                            label: 'Efficiency',
                            value: kmPerPct == null
                                ? '–'
                                : kmPerPct.toStringAsFixed(2),
                            unit: kmPerPct == null ? null : 'km/%')),
                  ],
                ),
              ),
              const SectionTitle('History'),
              for (final r in store.rides) ...[
                _RideTile(ride: r),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  final Ride ride;
  const _RideTile({required this.ride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = ride.batteryUsed;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(child: Icon(Icons.electric_moped)),
        title: Text('${ride.distanceKm.toStringAsFixed(1)} km  •  '
            '${formatDuration(ride.duration)}'),
        subtitle: Text('${formatDate(ride.start)}, ${formatTime(ride.start)}'
            '${used != null ? '  •  $used% battery' : ''}'),
        trailing: Text('${ride.avgSpeedKmh.round()} km/h',
            style: theme.textTheme.bodySmall),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RideDetailScreen(ride: ride))),
      ),
    );
  }
}

class RideDetailScreen extends StatelessWidget {
  final Ride ride;
  const RideDetailScreen({super.key, required this.ride});

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this ride?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await RideStore.instance.delete(ride.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in ride.route) LatLng(p[0], p[1])];
    final used = ride.batteryUsed;
    // Petrol scooter ~45 km/l, 2.3 kg CO2 per litre.
    final co2 = ride.distanceKm / 45 * 2.3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride detail'),
        actions: [
          IconButton(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (points.length >= 2)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 260,
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(32),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.iqube_ble_app',
                    ),
                    PolylineLayer(polylines: [
                      Polyline(points: points, strokeWidth: 5, color: tvsBlue),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                          point: points.first,
                          child: const Icon(Icons.circle,
                              color: batteryGreen, size: 16)),
                      Marker(
                          point: points.last,
                          child: const Icon(Icons.location_on,
                              color: tvsRed, size: 30)),
                    ]),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _timeRow(Icons.circle, batteryGreen, ride.start),
                  const SizedBox(height: 8),
                  _timeRow(Icons.location_on, tvsRed, ride.end),
                ],
              ),
            ),
          ),
          const SectionTitle('Overall ride'),
          Card(
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                      child: StatTile(
                          icon: Icons.straighten,
                          label: 'Distance',
                          value: ride.distanceKm.toStringAsFixed(1),
                          unit: 'km')),
                  Expanded(
                      child: StatTile(
                          icon: Icons.schedule,
                          label: 'Ride time',
                          value: formatDuration(ride.duration))),
                  Expanded(
                      child: StatTile(
                          icon: Icons.battery_5_bar,
                          label: 'Battery used',
                          value: used == null ? '–' : '$used',
                          unit: used == null ? null : '%')),
                ]),
                const Divider(height: 1),
                Row(children: [
                  Expanded(
                      child: StatTile(
                          icon: Icons.speed,
                          label: 'Top speed',
                          value: ride.topSpeedKmh.toStringAsFixed(0),
                          unit: 'km/h')),
                  Expanded(
                      child: StatTile(
                          icon: Icons.av_timer,
                          label: 'Avg speed',
                          value: ride.avgSpeedKmh.toStringAsFixed(0),
                          unit: 'km/h')),
                  Expanded(
                      child: StatTile(
                          icon: Icons.eco,
                          label: 'CO₂ saved',
                          value: co2.toStringAsFixed(1),
                          unit: 'kg')),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(IconData icon, Color color, DateTime t) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text('${formatTime(t)}, ${formatDate(t)}'),
        ],
      );
}
