import 'package:flutter/material.dart';

import '../services/battery_health.dart';
import 'common.dart';

/// The battery's trend over the months: real full-charge range from rides,
/// the cluster's own estimate, and charge cycles.
class BatteryHealthScreen extends StatelessWidget {
  const BatteryHealthScreen({super.key});

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String monthLabel(String month) =>
      '${_monthNames[int.parse(month.substring(5, 7)) - 1]} ${month.substring(2, 4)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battery health')),
      body: ListenableBuilder(
        listenable: BatteryHealth.instance,
        builder: (context, _) {
          final h = BatteryHealth.instance;
          final theme = Theme.of(context);
          final months = h.months;
          final range = h.fullRangeKm;
          final since = h.since;
          final withRange = months.where((m) => m.fullRangeKm != null).toList();
          final maxRange = withRange.fold<double>(
              0, (s, m) => m.fullRangeKm! > s ? m.fullRangeKm! : s);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Full-charge range, your riding',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(range == null ? '—' : '${range.round()} km',
                          style: theme.textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                          range == null
                              ? 'Needs rides that use at least 5% battery in total.'
                              : 'From ${h.totalKm.toStringAsFixed(0)} km of rides.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Row(
                  children: [
                    Expanded(
                        child: StatTile(
                            icon: Icons.battery_charging_full,
                            label: 'Charge cycles',
                            value: h.totalCycles.toStringAsFixed(1))),
                    Expanded(
                        child: StatTile(
                            icon: Icons.straighten,
                            label: 'Tracked',
                            value: h.totalKm.toStringAsFixed(0),
                            unit: 'km')),
                    Expanded(
                        child: StatTile(
                            icon: Icons.event,
                            label: 'Since',
                            value: since == null ? '—' : formatDate(since))),
                  ],
                ),
              ),
              const SectionTitle('Full-charge range by month'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: withRange.isEmpty
                      ? const Text('Ride for a while; each month gets a bar once '
                          'its rides use 5% battery.')
                      : Column(
                          children: [
                            for (final m in withRange)
                              _RangeBar(
                                label: monthLabel(m.month),
                                km: m.fullRangeKm!,
                                fraction: m.fullRangeKm! / maxRange,
                              ),
                          ],
                        ),
                ),
              ),
              const SectionTitle('Details'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DataTable(
                    columnSpacing: 16,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(label: Text('Month')),
                      DataColumn(label: Text('km/%'), numeric: true),
                      DataColumn(label: Text('Range'), numeric: true),
                      DataColumn(label: Text('Display'), numeric: true),
                      DataColumn(label: Text('Cycles'), numeric: true),
                    ],
                    rows: [
                      for (final m in months.reversed)
                        DataRow(cells: [
                          DataCell(Text(monthLabel(m.month))),
                          DataCell(Text(m.kmPerPercent?.toStringAsFixed(2) ?? '—')),
                          DataCell(Text(m.fullRangeKm?.round().toString() ?? '—')),
                          DataCell(Text(m.clusterRangeKm?.round().toString() ?? '—')),
                          DataCell(Text(m.cycles.toStringAsFixed(1))),
                        ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A battery wears slowly: watch for the range falling over many '
                'months, not one. Hot weather, Power mode, a passenger or lots '
                'of stops lower a single month too. "Display" is the '
                'scooter\'s own full-charge estimate (DTE ÷ battery %).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar(
      {required this.label, required this.km, required this.fraction});

  final String label;
  final double km;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 14,
                  width: c.maxWidth * fraction.clamp(0.02, 1.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius:
                        const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text('${km.round()} km',
                textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
