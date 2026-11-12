import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_settings.dart';
import '../services/battery_health.dart';
import 'common.dart';
import 'widgets/kit.dart';

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
      appBar: AppBar(
        title: Text('Battery Health',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [BatteryHealth.instance, AppSettings.instance]),
        builder: (context, _) {
          final h = BatteryHealth.instance;
          final settings = AppSettings.instance;
          final theme = Theme.of(context);
          final c = AppColors.of(context);
          final months = h.months;
          final range = h.fullRangeKm;
          final since = h.since;
          final withRange = months.where((m) => m.fullRangeKm != null).toList();
          final maxRange = withRange.fold<double>(
              0, (s, m) => m.fullRangeKm! > s ? m.fullRangeKm! : s);

          // Battery Health Score Calculation
          final baseline = settings.fullRangeEcoKm > 0 ? settings.fullRangeEcoKm : 100.0;
          final int? healthScore = range != null
              ? ((range / baseline) * 100).clamp(0, 100).round()
              : null;
          final int dropPct = healthScore != null ? (100 - healthScore).clamp(0, 100) : 0;

          final Color scoreColor;
          final String scoreLabel;
          if (healthScore == null) {
            scoreColor = c.onSurfaceMuted;
            scoreLabel = 'CALCULATING';
          } else if (healthScore >= 95) {
            scoreColor = c.energy;
            scoreLabel = 'EXCELLENT';
          } else if (healthScore >= 85) {
            scoreColor = c.brand;
            scoreLabel = 'GOOD';
          } else if (healthScore >= 75) {
            scoreColor = c.warning;
            scoreLabel = 'FAIR';
          } else {
            scoreColor = c.danger;
            scoreLabel = 'SERVICE ADVISABLE';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Battery Health Score Card
              Reveal(
                index: 0,
                child: Card(
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
                                Icon(Icons.health_and_safety_rounded,
                                    color: scoreColor, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'BATTERY HEALTH SCORE',
                                  style: AppText.overline
                                      .copyWith(color: c.onSurfaceMuted),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                scoreLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              healthScore != null ? '$healthScore%' : '—',
                              style: GoogleFonts.outfit(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: scoreColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                healthScore != null
                                    ? (dropPct == 0
                                        ? 'Battery capacity matches original ${baseline.round()} km baseline.'
                                        : 'Range is $dropPct% lower than initial baseline (${baseline.round()} km).')
                                    : 'Awaiting sufficient ride history to calculate wear.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: c.onSurfaceMuted,
                                ),
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

              // 2. Full-charge range summary card
              Reveal(
                index: 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Full-charge range, your riding',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        if (range == null)
                          Text('—',
                              style: theme.textTheme.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w600))
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AnimatedCount(
                                range.roundToDouble(),
                                decimals: 0,
                                style: theme.textTheme.displaySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'km',
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
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
              ),
              const SizedBox(height: 12),

              // 3. Stats row
              Reveal(
                index: 2,
                child: Card(
                  child: Row(
                    children: [
                      Expanded(
                          child: AnimatedStatTile(
                              icon: Icons.battery_charging_full,
                              label: 'Charge cycles',
                              value: h.totalCycles.toStringAsFixed(1))),
                      Expanded(
                          child: AnimatedStatTile(
                              icon: Icons.straighten,
                              label: 'Tracked',
                              value: h.totalKm.toStringAsFixed(0),
                              unit: 'km')),
                      Expanded(
                          child: AnimatedStatTile(
                              icon: Icons.event,
                              label: 'Since',
                              value: since == null ? '—' : formatDate(since))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Range Trend Line Chart
              if (withRange.length >= 2) ...[
                Reveal(
                  index: 3,
                  child: _RangeTrendChart(months: withRange),
                ),
                const SizedBox(height: 12),
              ],

              // 5. Full-charge range by month
              const SectionTitle('Full-charge range by month'),
              Reveal(
                index: 4,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: withRange.isEmpty
                        ? const Text(
                            'Ride for a while; each month gets a bar once '
                            'its rides use 5% battery.')
                        : Column(
                            children: [
                              for (var i = 0; i < withRange.length; i++)
                                _RangeBar(
                                  index: i,
                                  label: monthLabel(withRange[i].month),
                                  km: withRange[i].fullRangeKm!,
                                  fraction: maxRange > 0
                                      ? withRange[i].fullRangeKm! / maxRange
                                      : 0.0,
                                ),
                            ],
                          ),
                  ),
                ),
              ),
              const SectionTitle('Details'),

              // 6. Data table card
              Reveal(
                index: 5,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Reveal(
                        index: 6,
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
                                DataCell(Text(
                                    m.kmPerPercent?.toStringAsFixed(2) ?? '—')),
                                DataCell(Text(
                                    m.fullRangeKm?.round().toString() ?? '—')),
                                DataCell(Text(
                                    m.clusterRangeKm?.round().toString() ??
                                        '—')),
                                DataCell(Text(m.cycles.toStringAsFixed(1))),
                              ]),
                          ],
                        ),
                      ),
                    ),
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

/// Smooth Line Chart plotting Range Trend over time
class _RangeTrendChart extends StatelessWidget {
  const _RangeTrendChart({required this.months});
  final List<BatteryMonth> months;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final values = [for (final m in months) m.fullRangeKm ?? 0.0];
    final minRange = values.fold<double>(values.first, (s, v) => v < s ? v : s);
    final maxRange = values.fold<double>(values.first, (s, v) => v > s ? v : s);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: c.brand, size: 20),
                const SizedBox(width: 8),
                Text('RANGE RETENTION TREND',
                    style: AppText.overline.copyWith(color: c.onSurfaceMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest: ${values.last.round()} km',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface),
                ),
                Text(
                  'Peak: ${maxRange.round()} km  •  Min: ${minRange.round()} km',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: c.onSurfaceMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: _RangeTrendPainter(
                  values: values,
                  labels: [
                    for (final m in months)
                      BatteryHealthScreen.monthLabel(m.month)
                  ],
                  lineColor: c.brand,
                  minVal: minRange * 0.9,
                  maxVal: maxRange * 1.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeTrendPainter extends CustomPainter {
  _RangeTrendPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.minVal,
    required this.maxVal,
  });

  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final double minVal;
  final double maxVal;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final path = ui.Path();
    final fillPath = ui.Path();

    final chartH = size.height - 20;
    final stepX = size.width / (values.length - 1);
    final rangeY = maxVal - minVal;

    double getY(double v) =>
        chartH - ((v - minVal) / (rangeY > 0 ? rangeY : 1) * chartH);

    path.moveTo(0, getY(values.first));
    fillPath.moveTo(0, chartH);
    fillPath.lineTo(0, getY(values.first));

    final points = <Offset>[Offset(0, getY(values.first))];

    for (var i = 1; i < values.length; i++) {
      final x = i * stepX;
      final y = getY(values[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
      points.add(Offset(x, y));
    }

    fillPath.lineTo(size.width, chartH);
    fillPath.close();

    // Area fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.3),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Points with glow
    final dotPaint = Paint()..color = lineColor;
    for (final pt in points) {
      canvas.drawCircle(pt, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RangeTrendPainter old) =>
      old.values != values || old.lineColor != lineColor;
}

class _RangeBar extends StatefulWidget {
  const _RangeBar({
    required this.index,
    required this.label,
    required this.km,
    required this.fraction,
  });

  final int index;
  final String label;
  final double km;
  final double fraction;

  @override
  State<_RangeBar> createState() => _RangeBarState();
}

class _RangeBarState extends State<_RangeBar> {
  bool _start = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) setState(() => _start = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motion = AppMotion.of(context);
    final dur = resolveMotion(context, motion.fill);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(widget.label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final targetWidth =
                    c.maxWidth * widget.fraction.clamp(0.02, 1.0);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: _start ? targetWidth : 0.0,
                    ),
                    duration: dur,
                    curve: motion.emphasized,
                    builder: (context, animWidth, _) => Container(
                      height: 14,
                      width: animWidth,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: AppShape.pill,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${widget.km.round()} km',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
