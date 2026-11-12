import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../rides/ride.dart';
import '../services/app_settings.dart';
import 'common.dart';
import 'widgets/kit.dart';
import 'widgets/scale_on_tap.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  String _selectedTag = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _availableTags = ['All', 'Commute', 'Weekend', 'Errand', 'Other'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Rides',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([RideStore.instance, AppSettings.instance]),
        builder: (context, _) {
          final store = RideStore.instance;
          final settings = AppSettings.instance;

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
          final totalSavedMoney = store.rides.fold<double>(
              0.0, (s, r) => s + r.moneySaved(settings.petrolPricePerLitre));
          final totalCo2 = store.totalKm / 45 * 2.3;

          // Filter rides
          final filteredRides = store.rides.where((r) {
            if (_selectedTag != 'All') {
              if (_selectedTag == 'Other') {
                if (r.tag != null &&
                    _availableTags.sublist(1, 4).contains(r.tag)) {
                  return false;
                }
              } else if (r.tag != _selectedTag) {
                return false;
              }
            }
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final dateStr =
                  '${formatDate(r.start)} ${formatTime(r.start)}'.toLowerCase();
              final tagStr = (r.tag ?? '').toLowerCase();
              final kmStr = '${r.distanceKm.toStringAsFixed(1)} km';
              if (!dateStr.contains(query) &&
                  !tagStr.contains(query) &&
                  !kmStr.contains(query)) {
                return false;
              }
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Overall stats card
              Reveal(
                index: 0,
                child: Card(
                  child: Row(
                    children: [
                      Expanded(
                          child: AnimatedStatTile(
                              icon: Icons.route,
                              label: 'Rides',
                              value: '${store.rides.length}')),
                      Expanded(
                          child: AnimatedStatTile(
                              icon: Icons.straighten,
                              label: 'Distance',
                              value: store.totalKm.toStringAsFixed(1),
                              unit: 'km')),
                      Expanded(
                          child: AnimatedStatTile(
                              icon: Icons.battery_charging_full,
                              label: 'Efficiency',
                              value: kmPerPct == null
                                  ? '–'
                                  : kmPerPct.toStringAsFixed(2),
                              unit: kmPerPct == null ? null : 'km/%')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Savings & Environmental Impact Card with 7-Day Chart
              Reveal(
                index: 1,
                child: _SavingsImpactCard(
                  totalSavedMoney: totalSavedMoney,
                  totalCo2: totalCo2,
                  rides: store.rides,
                ),
              ),
              const SizedBox(height: 12),

              // 3. Search & Tag Filter Bar
              Reveal(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search rides by date, tag, or distance...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.of(context).surface,
                        border: OutlineInputBorder(
                          borderRadius: AppShape.card,
                          borderSide: BorderSide(
                              color: AppColors.of(context).hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppShape.card,
                          borderSide: BorderSide(
                              color: AppColors.of(context).hairline),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tag in _availableTags) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(tag,
                                    style: GoogleFonts.outfit(fontSize: 13)),
                                selected: _selectedTag == tag,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedTag = tag);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Ride History'),

              if (filteredRides.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No rides match your filter.',
                        style: AppText.caption.copyWith(
                            color: AppColors.of(context).onSurfaceMuted)),
                  ),
                )
              else
                for (var i = 0; i < filteredRides.length; i++) ...[
                  Reveal(
                    index: i + 3,
                    child: _RideTile(ride: filteredRides[i]),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Savings card with Petrol vs EV financial savings and 7-day km chart
class _SavingsImpactCard extends StatelessWidget {
  const _SavingsImpactCard({
    required this.totalSavedMoney,
    required this.totalCo2,
    required this.rides,
  });

  final double totalSavedMoney;
  final double totalCo2;
  final List<Ride> rides;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final now = DateTime.now();

    // Group last 7 days km
    final days = List.generate(7, (i) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      final dayKm = rides.where((r) {
        final rDay = DateTime(r.start.year, r.start.month, r.start.day);
        return rDay == date;
      }).fold<double>(0.0, (s, r) => s + r.distanceKm);
      return (date, dayKm);
    });

    final maxKm = days.fold<double>(1.0, (s, d) => d.$2 > s ? d.$2 : s);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_rounded, color: c.energy, size: 20),
                const SizedBox(width: 8),
                Text('SAVINGS & IMPACT',
                    style: AppText.overline.copyWith(color: c.onSurfaceMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹${totalSavedMoney.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: c.energy,
                          )),
                      Text('Saved vs Petrol',
                          style: AppText.caption.copyWith(color: c.onSurfaceMuted)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${totalCo2.toStringAsFixed(1)} kg',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: c.brand,
                          )),
                      Text('CO₂ Prevented',
                          style: AppText.caption.copyWith(color: c.onSurfaceMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('PAST 7 DAYS ACTIVITY',
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceMuted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days) ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: (d.$2 / maxKm * 32).clamp(4.0, 32.0),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: d.$2 > 0 ? c.brand : c.surfaceHigh,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.$1.weekday - 1],
                            style: GoogleFonts.outfit(
                                fontSize: 10, color: c.onSurfaceMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    final c = AppColors.of(context);
    final used = ride.batteryUsed;

    return ScaleOnTap(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RideDetailScreen(ride: ride)),
      ),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Hero(
            tag: 'ride-map-${ride.id}',
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.brand.withValues(alpha: 0.12),
                  borderRadius: AppShape.inner,
                ),
                child: Icon(Icons.electric_moped_rounded,
                    color: c.brand, size: 22),
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                '${ride.distanceKm.toStringAsFixed(1)} km  •  ${formatDuration(ride.duration)}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              if (ride.tag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ride.tag!,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.brand,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${formatDate(ride.start)}, ${formatTime(ride.start)}'
            '${used != null ? '  •  $used% battery' : ''}',
            style: GoogleFonts.outfit(fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${ride.avgSpeedKmh.round()} km/h',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color)),
              Text('avg speed',
                  style: GoogleFonts.outfit(
                      fontSize: 10, color: c.onSurfaceMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class RideDetailScreen extends StatefulWidget {
  final Ride ride;
  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  late Ride _ride;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => const _DeleteConfirmationDialog(),
    );
    if (ok == true) {
      await RideStore.instance.delete(_ride.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _exportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export Ride Data',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Export GPX File'),
                subtitle: const Text('Standard track for Strava, Garmin & Maps'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: _ride.toGpx()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('GPX copied to clipboard!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export CSV Telemetry'),
                subtitle: const Text('Full raw GPS, speed & elevation log'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: _ride.toCsv()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTag(String? newTag) async {
    await RideStore.instance.updateTag(_ride.id, newTag);
    setState(() {
      _ride = Ride(
        id: _ride.id,
        start: _ride.start,
        end: _ride.end,
        distanceKm: _ride.distanceKm,
        topSpeedKmh: _ride.topSpeedKmh,
        batteryStart: _ride.batteryStart,
        batteryEnd: _ride.batteryEnd,
        route: _ride.route,
        tag: newTag,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in _ride.route) LatLng(p[0], p[1])];
    final c = AppColors.of(context);
    final used = _ride.batteryUsed;
    final co2 = _ride.distanceKm / 45 * 2.3;
    final store = RideStore.instance;
    final avgKmPerPct = store.learnedKmPerPercent;

    // Build speed-coloured route polylines
    final List<Polyline> polylines = [];
    if (_ride.hasSpeedData && _ride.route.length >= 2) {
      for (var i = 0; i < _ride.route.length - 1; i++) {
        final p1 = _ride.route[i];
        final p2 = _ride.route[i + 1];
        final spd = p1.length > 2 ? p1[2] : (p2.length > 2 ? p2[2] : 0.0);
        final Color segColor;
        if (spd < 25) {
          segColor = c.energy;
        } else if (spd <= 45) {
          segColor = c.warning;
        } else {
          segColor = c.danger;
        }
        polylines.add(
          Polyline(
            points: [LatLng(p1[0], p1[1]), LatLng(p2[0], p2[1])],
            strokeWidth: 5,
            color: segColor,
          ),
        );
      }
    } else if (points.length >= 2) {
      polylines.add(
        Polyline(points: points, strokeWidth: 5, color: c.brand),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Ride Detail',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            onPressed: () => _exportDialog(context),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export & Share',
          ),
          IconButton(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Map with Speed Color Segments & Legend
          if (points.length >= 2) ...[
            Reveal(
              index: 0,
              child: Hero(
                tag: 'ride-map-${_ride.id}',
                child: ClipRRect(
                  borderRadius: AppShape.card,
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCameraFit: CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(points),
                              padding: const EdgeInsets.all(36),
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'muthumar.iqubtvs.com',
                            ),
                            PolylineLayer(polylines: polylines),
                            MarkerLayer(markers: [
                              Marker(
                                  point: points.first,
                                  child: Icon(Icons.circle,
                                      color: c.energy, size: 16)),
                              Marker(
                                  point: points.last,
                                  child: Icon(Icons.location_on,
                                      color: c.danger, size: 30)),
                            ]),
                          ],
                        ),
                        // Speed legend
                        if (_ride.hasSpeedData)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: c.surface.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: c.hairline),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _LegendDot(color: c.energy, label: '<25 km/h'),
                                  const SizedBox(width: 8),
                                  _LegendDot(color: c.warning, label: '25-45'),
                                  const SizedBox(width: 8),
                                  _LegendDot(color: c.danger, label: '>45'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Tag selector chips
          Reveal(
            index: 1,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.label_outline, color: c.brand, size: 18),
                    const SizedBox(width: 8),
                    Text('Tag:',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final t in ['Commute', 'Weekend', 'Errand', 'Casual']) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(t, style: GoogleFonts.outfit(fontSize: 12)),
                                  selected: _ride.tag == t,
                                  onSelected: (sel) => _selectTag(sel ? t : null),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Time card
          Reveal(
            index: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _timeRow(Icons.circle, c.energy, _ride.start),
                    const SizedBox(height: 8),
                    _timeRow(Icons.location_on, c.danger, _ride.end),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Speed & Elevation Profile Charts
          if (_ride.route.length >= 2) ...[
            Reveal(
              index: 3,
              child: _RouteProfileChart(route: _ride.route),
            ),
            const SizedBox(height: 12),
          ],

          // 5. Efficiency per ride card
          Reveal(
            index: 4,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco_rounded, color: c.energy, size: 20),
                        const SizedBox(width: 8),
                        Text('EFFICIENCY & ENERGY CONSUMPTION',
                            style: AppText.overline.copyWith(color: c.onSurfaceMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ride.whPerKm != null
                                    ? '${_ride.whPerKm!.toStringAsFixed(1)} Wh/km'
                                    : '–',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: c.energy,
                                ),
                              ),
                              Text('Specific Energy',
                                  style: AppText.caption.copyWith(color: c.onSurfaceMuted)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                used != null && used > 0
                                    ? '${(_ride.distanceKm / used).toStringAsFixed(2)} km/%'
                                    : '–',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: c.brand,
                                ),
                              ),
                              Text(
                                avgKmPerPct != null
                                    ? 'Avg: ${avgKmPerPct.toStringAsFixed(2)} km/%'
                                    : 'Real-world rate',
                                style: AppText.caption.copyWith(color: c.onSurfaceMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 6. Overall stats card
          const SectionTitle('Overall ride stats'),
          Reveal(
            index: 5,
            child: Card(
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                        child: AnimatedStatTile(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: _ride.distanceKm.toStringAsFixed(1),
                            unit: 'km')),
                    Expanded(
                        child: AnimatedStatTile(
                            icon: Icons.schedule,
                            label: 'Ride time',
                            value: formatDuration(_ride.duration))),
                    Expanded(
                        child: AnimatedStatTile(
                            icon: Icons.battery_5_bar,
                            label: 'Battery used',
                            value: used == null ? '–' : '$used',
                            unit: used == null ? null : '%')),
                  ]),
                  const Divider(height: 1),
                  Row(children: [
                    Expanded(
                        child: AnimatedStatTile(
                            icon: Icons.speed,
                            label: 'Top speed',
                            value: _ride.topSpeedKmh.toStringAsFixed(0),
                            unit: 'km/h')),
                    Expanded(
                        child: AnimatedStatTile(
                            icon: Icons.av_timer,
                            label: 'Avg speed',
                            value: _ride.avgSpeedKmh.toStringAsFixed(0),
                            unit: 'km/h')),
                    Expanded(
                        child: AnimatedStatTile(
                            icon: Icons.eco,
                            label: 'CO₂ saved',
                            value: co2.toStringAsFixed(1),
                            unit: 'kg')),
                  ]),
                ],
              ),
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
          Text('${formatTime(t)}, ${formatDate(t)}',
              style: GoogleFonts.outfit()),
        ],
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).onSurface)),
      ],
    );
  }
}

/// Speed & Elevation telemetry curve painter
class _RouteProfileChart extends StatefulWidget {
  const _RouteProfileChart({required this.route});
  final List<List<double>> route;

  @override
  State<_RouteProfileChart> createState() => _RouteProfileChartState();
}

class _RouteProfileChartState extends State<_RouteProfileChart> {
  bool _showElevation = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasElevation =
        widget.route.any((p) => p.length > 4 && p[4] > 0);

    // Extract series
    final List<double> values = [];
    if (_showElevation && hasElevation) {
      for (final p in widget.route) {
        values.add(p.length > 4 ? p[4] : 0.0);
      }
    } else {
      for (final p in widget.route) {
        values.add(p.length > 2 ? p[2] : 0.0);
      }
    }

    final maxVal = values.fold<double>(1.0, (s, v) => v > s ? v : s);
    final minVal = _showElevation && hasElevation
        ? values.fold<double>(maxVal, (s, v) => v < s ? v : s)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                        _showElevation
                            ? Icons.terrain_rounded
                            : Icons.show_chart_rounded,
                        color: c.brand,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _showElevation ? 'ELEVATION PROFILE' : 'SPEED PROFILE',
                      style: AppText.overline.copyWith(color: c.onSurfaceMuted),
                    ),
                  ],
                ),
                if (hasElevation)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Speed')),
                      ButtonSegment(value: true, label: Text('Elev')),
                    ],
                    selected: {_showElevation},
                    onSelectionChanged: (val) =>
                        setState(() => _showElevation = val.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showElevation
                      ? 'Peak: ${maxVal.round()} m  •  Min: ${minVal.round()} m'
                      : 'Max speed: ${maxVal.round()} km/h',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: CustomPaint(
                painter: _ProfileChartPainter(
                  values: values,
                  minVal: minVal,
                  maxVal: maxVal > minVal ? maxVal : minVal + 1.0,
                  lineColor: _showElevation ? c.energy : c.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChartPainter extends CustomPainter {
  _ProfileChartPainter({
    required this.values,
    required this.minVal,
    required this.maxVal,
    required this.lineColor,
  });

  final List<double> values;
  final double minVal;
  final double maxVal;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final path = ui.Path();
    final fillPath = ui.Path();

    final stepX = size.width / (values.length - 1);
    final rangeY = maxVal - minVal;

    double getY(double v) =>
        size.height - ((v - minVal) / rangeY * (size.height - 10)) - 5;

    path.moveTo(0, getY(values.first));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(values.first));

    for (var i = 1; i < values.length; i++) {
      final x = i * stepX;
      final y = getY(values[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Area gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.35),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_ProfileChartPainter old) =>
      old.values != values || old.lineColor != lineColor;
}

class _DeleteConfirmationDialog extends StatefulWidget {
  const _DeleteConfirmationDialog();

  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    return AnimatedScale(
      scale: _visible ? 1.0 : 0.92,
      duration: resolveMotion(context, motion.fast),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: resolveMotion(context, motion.fast),
        curve: motion.enter,
        child: AlertDialog(
          title: const Text('Delete this ride?'),
          content: const Text('This will permanently delete this ride entry.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      ),
    );
  }
}
