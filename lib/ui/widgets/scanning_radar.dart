import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Radar sweep animation shown while BLE scanning is active.
class ScanningRadar extends StatefulWidget {
  const ScanningRadar({
    super.key,
    this.size = 200,
    this.color,
    this.scanning = false,
  });

  final double size;

  /// Colour of the sweep arc and rings. Defaults to [AppColors.brand].
  final Color? color;

  /// Whether scanning is currently in progress.
  final bool scanning;

  @override
  State<ScanningRadar> createState() => _ScanningRadarState();
}

class _ScanningRadarState extends State<ScanningRadar>
    with TickerProviderStateMixin {
  late final AnimationController _sweep;
  late final AnimationController _pulse;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.scanning ? 1.0 : 0.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(ScanningRadar old) {
    super.didUpdateWidget(old);
    if (old.scanning != widget.scanning) _syncAnimations();
  }

  void _syncAnimations() {
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (widget.scanning && !disabled) {
      if (!_sweep.isAnimating) _sweep.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      _fade.animateTo(1.0);
    } else {
      _fade.animateTo(0.0).whenComplete(() {
        if (!mounted) return;
        _sweep.stop();
        _pulse.stop();
      });
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = widget.color ?? c.brand;

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_sweep, _pulse, _fade]),
        builder: (context, _) {
          return CustomPaint(
            painter: _RadarPainter(
              sweep: _sweep.value,
              pulseScale: _pulse.value,
              fadeIn: _fade.value,
              color: color,
              trackColor: c.surfaceHigh,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.sweep,
    required this.pulseScale,
    required this.fadeIn,
    required this.color,
    required this.trackColor,
  });

  final double sweep;
  final double pulseScale;
  final double fadeIn;
  final Color color;
  final Color trackColor;

  static const _ringFractions = [0.35, 0.65, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = trackColor;

    // Draw concentric rings.
    for (final f in _ringFractions) {
      canvas.drawCircle(center, maxR * f, ringPaint);
    }

    // Sweep arc (only when fading in or fully visible).
    if (fadeIn > 0) {
      const sweepAngle = math.pi / 3; // 60-degree arc
      final startAngle = sweep * math.pi * 2 - math.pi / 2;

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.8 * fadeIn);

      final rect = Rect.fromCircle(center: center, radius: maxR);
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

      // Trailing fade shader.
      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle - sweepAngle,
          endAngle: startAngle,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.3 * fadeIn),
          ],
        ).createShader(rect);

      canvas.drawArc(rect, startAngle - sweepAngle, sweepAngle, false, trailPaint);
    }

    // Center dot with pulsing.
    final dotRadius = 5.0 + (fadeIn > 0 ? pulseScale * 3 : 0);
    final dotPaint = Paint()..color = color.withValues(alpha: 0.6 + 0.4 * fadeIn);
    canvas.drawCircle(center, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweep != sweep ||
      old.pulseScale != pulseScale ||
      old.fadeIn != fadeIn;
}
