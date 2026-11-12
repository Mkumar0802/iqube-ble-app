import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Semi-circular speed gauge for ride tracking.
///
/// [value] is 0..1 representing the fill percentage.
class AnimatedGauge extends StatelessWidget {
  const AnimatedGauge({
    super.key,
    required this.value,
    this.maxLabel = '80',
    this.unit = 'km/h',
    this.label = 'Speed',
    this.color,
  });

  /// Normalised value from 0.0 to 1.0.
  final double value;

  /// Label printed at the max end of the arc (e.g. "80").
  final String maxLabel;

  /// Unit text below the number (e.g. "km/h").
  final String unit;

  /// Label above the number (e.g. "Speed").
  final String label;

  /// Value arc colour. Defaults to [AppColors.brand].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final m = AppMotion.of(context);
    final dur = resolveMotion(context, m.fill);
    final gaugeColor = color ?? c.brand;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: dur,
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return CustomPaint(
          painter: _GaugePainter(
            value: animValue,
            trackColor: c.surfaceHigh,
            valueColor: gaugeColor,
            tickColor: c.onSurfaceMuted,
          ),
          child: child,
        );
      },
      child: _GaugeLabels(
        value: value,
        maxLabel: maxLabel,
        unit: unit,
        label: label,
        color: gaugeColor,
      ),
    );
  }
}

/// Textual labels placed in the centre of the gauge.
class _GaugeLabels extends StatelessWidget {
  const _GaugeLabels({
    required this.value,
    required this.maxLabel,
    required this.unit,
    required this.label,
    required this.color,
  });

  final double value;
  final String maxLabel;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Compute display number: value × maxLabel.
    final maxNum = double.tryParse(maxLabel) ?? 100;
    final display = (value.clamp(0.0, 1.0) * maxNum).round();

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Push text toward centre of the semi-circle.
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: AppText.overline.copyWith(color: c.onSurfaceMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '$display',
            style: AppText.hero.copyWith(color: color),
          ),
          Text(
            unit,
            style: AppText.unit.copyWith(color: c.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.trackColor,
    required this.valueColor,
    required this.tickColor,
  });

  final double value;
  final Color trackColor;
  final Color valueColor;
  final Color tickColor;

  /// Arc spans 240° starting at 150° (bottom-left).
  static const _startDeg = 150.0;
  static const _sweepDeg = 240.0;
  static const _startRad = _startDeg * math.pi / 180;
  static const _sweepRad = _sweepDeg * math.pi / 180;
  static const _strokeWidth = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final radius = math.min(size.width, size.height) / 2 - _strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track arc.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, _startRad, _sweepRad, false, trackPaint);

    // Value arc.
    final valueSweep = _sweepRad * value;
    if (value > 0) {
      final valuePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = valueColor;
      canvas.drawArc(rect, _startRad, valueSweep, false, valuePaint);

      // Glow at the tip of the value arc.
      final tipAngle = _startRad + valueSweep;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      final glowPaint = Paint()
        ..color = valueColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), _strokeWidth * 0.8, glowPaint);
    }

    // Tick marks every 20%.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = tickColor;
    for (var i = 0; i <= 5; i++) {
      final frac = i / 5;
      final angle = _startRad + _sweepRad * frac;
      final outerR = radius + _strokeWidth / 2 + 4;
      final innerR = radius + _strokeWidth / 2 + 10;
      canvas.drawLine(
        Offset(center.dx + outerR * math.cos(angle),
            center.dy + outerR * math.sin(angle)),
        Offset(center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.trackColor != trackColor ||
      old.valueColor != valueColor;
}
