import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Fades and slides its child in once, [index] steps after the first item,
/// so a screen's cards arrive one after another.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    this.index = 0,
    this.slideOffset = 0.06,
    this.scaleFrom = 0.97,
    required this.child,
  });

  final int index;

  /// Vertical slide distance as a fraction of the widget height.
  final double slideOffset;

  /// Initial scale factor (< 1 means it grows in).
  final double scaleFrom;

  final Widget child;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion = AppMotion.of(context);
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    _c.duration = motion.slow;
    _delay = Timer(motion.stagger * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _c, curve: AppMotion.of(context).enter);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: widget.scaleFrom, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween(
            begin: Offset(0, widget.slideOffset),
            end: Offset.zero,
          ).animate(curved),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A number that counts to its new value.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(this.value,
      {super.key, this.decimals = 0, this.style});

  final double value;
  final int decimals;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: resolveMotion(context, motion.fill),
      curve: motion.emphasized,
      builder: (context, v, _) =>
          Text(v.toStringAsFixed(decimals), style: style),
    );
  }
}

/// The dark gradient card that carries the battery.
/// A shimmer sweep runs once on first build.
class HeroCard extends StatefulWidget {
  const HeroCard({super.key, required this.child, this.glow});

  final Widget child;

  /// Tint of the soft light behind the content.
  final Color? glow;

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _shimmer.forward();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);
    return AnimatedContainer(
      duration: resolveMotion(context, motion.slow),
      curve: motion.enter,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppShape.card,
        border: Border.all(color: c.heroTrack),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.heroTop, c.heroBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.glow ?? c.heroGlow).withValues(alpha: 0.22),
            blurRadius: 32,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft light in the top corner, tinted by the battery level.
          PositionedDirectional(
            top: -90,
            end: -70,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: resolveMotion(context, motion.slow),
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    (widget.glow ?? c.heroGlow).withValues(alpha: 0.28),
                    (widget.glow ?? c.heroGlow).withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: widget.child,
          ),
          // Shimmer sweep overlay.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) {
                  if (!_shimmer.isAnimating && _shimmer.isCompleted) {
                    return const SizedBox.shrink();
                  }
                  return Opacity(
                    opacity: 1.0 - _shimmer.value * 0.3,
                    child: CustomPaint(
                      painter: _ShimmerPainter(progress: _shimmer.value),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Shimmer band width.
    final bandWidth = w * 0.6;
    // Current center x of the band – sweeps from -bandWidth to w+bandWidth.
    final cx = -bandWidth + (w + 2 * bandWidth) * progress;

    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0),
      ],
      stops: [
        ((cx - bandWidth / 2) / w).clamp(0.0, 1.0),
        (cx / w).clamp(0.0, 1.0),
        ((cx + bandWidth / 2) / w).clamp(0.0, 1.0),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

/// A dot that pulses while [active], for the connection status.
/// Includes a second, larger delayed outer ring for a double-pulse effect.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final AnimationController _c2 = AnimationController(vsync: this);

  void _sync() {
    final dur = AppMotion.of(context).pulse;
    _c.duration = dur;
    _c2.duration = dur;
    final run = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
      // Start the second ring slightly delayed.
      Future.delayed(dur * 0.35, () {
        if (mounted && widget.active) _c2.repeat();
      });
    } else if (!run) {
      _c
        ..stop()
        ..value = 0;
      _c2
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    _c2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _c2]),
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring (delayed, larger).
            if (_c2.isAnimating)
              Container(
                width: 10 + 14 * _c2.value,
                height: 10 + 14 * _c2.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.2 * (1 - _c2.value)),
                    width: 1.5,
                  ),
                ),
              ),
            // Inner pulse ring.
            if (_c.isAnimating)
              Container(
                width: 8 + 10 * _c.value,
                height: 8 + 10 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
                ),
              ),
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label over a big value, used on the hero card and in stat rows.
/// Animates the value counting up from 0 when first appearing,
/// falling back to static text if the value can't be parsed.
class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.muted,
    this.accent,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final Color? muted;

  /// Colour of the small bar beside the label.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);
    final fg = color ?? c.onSurface;
    final dim = muted ?? c.onSurfaceMuted;

    // Try to parse the value for count-up animation.
    final parsed = double.tryParse(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accent != null) ...[
              Container(
                width: 4,
                height: 12,
                decoration:
                    BoxDecoration(color: accent, borderRadius: AppShape.pill),
              ),
              const SizedBox(width: 6),
            ],
            Text(label.toUpperCase(),
                style: AppText.overline.copyWith(color: dim)),
          ],
        ),
        const SizedBox(height: 4),
        if (parsed != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: parsed),
            duration: resolveMotion(context, motion.fill),
            curve: motion.emphasized,
            builder: (context, v, _) {
              // Preserve the original formatting (decimals).
              final dotIndex = value.indexOf('.');
              final decimals = dotIndex >= 0 ? value.length - dotIndex - 1 : 0;
              final formatted = v.toStringAsFixed(decimals);
              return Text.rich(TextSpan(children: [
                TextSpan(
                    text: formatted,
                    style: AppText.metric.copyWith(color: fg)),
                if (unit != null)
                  TextSpan(
                      text: ' $unit',
                      style: AppText.unit.copyWith(color: dim)),
              ]));
            },
          )
        else
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: AppText.metric.copyWith(color: fg)),
            if (unit != null)
              TextSpan(
                  text: ' $unit', style: AppText.unit.copyWith(color: dim)),
          ])),
      ],
    );
  }
}

/// A battery-over-time line from (time, percent) samples.
/// Animates the line drawing from left to right on first build,
/// with a gradient fill and glowing endpoint dot.
class Sparkline extends StatefulWidget {
  const Sparkline({super.key, required this.samples, this.height = 96});

  final List<(DateTime, int)> samples;
  final double height;

  @override
  State<Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<Sparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_draw.isAnimating && _draw.value == 0) {
      final motion = AppMotion.of(context);
      if (MediaQuery.disableAnimationsOf(context)) {
        _draw.value = 1;
      } else {
        _draw.duration = motion.fill;
        _draw.forward();
      }
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final first = widget.samples.first;
    final last = widget.samples.last;
    final span = last.$1.difference(first.$1).inSeconds;
    // Positions as fractions of the box: x by time, y by percent.
    final points = [
      for (final s in widget.samples)
        Offset(
          span == 0 ? 1 : s.$1.difference(first.$1).inSeconds / span,
          1 - s.$2.clamp(0, 100) / 100,
        ),
    ];
    return Semantics(
      label: 'Battery went from ${first.$2} to ${last.$2} percent',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _draw,
              builder: (context, _) => CustomPaint(
                painter: _SparkPainter(
                  points: points,
                  line: c.level(last.$2),
                  grid: c.hairline,
                  drawProgress: _draw.value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.drawProgress,
  });

  final List<Offset> points;
  final Color line;
  final Color grid;
  final double drawProgress;

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _fill = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    _stroke
      ..strokeWidth = 1
      ..color = grid;
    for (final y in const [0.0, 0.5, 1.0]) {
      canvas.drawLine(
          Offset(0, size.height * y), Offset(size.width, size.height * y), _stroke);
    }
    if (points.isEmpty) return;

    Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final fullPath = Path();
    final start = at(points.first);
    fullPath.moveTo(start.dx, start.dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      fullPath.lineTo(o.dx, o.dy);
    }

    // Extract the portion of the path to draw based on progress.
    Path drawnPath = fullPath;
    Offset endPoint = at(points.last);

    if (drawProgress < 1.0) {
      final metrics = fullPath.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final totalLength = metrics.fold<double>(0, (s, m) => s + m.length);
        final targetLength = totalLength * drawProgress;
        drawnPath = Path();
        var remaining = targetLength;
        for (final metric in metrics) {
          if (remaining <= 0) break;
          final extractLen = math.min(remaining, metric.length);
          final extracted = metric.extractPath(0, extractLen);
          drawnPath.addPath(extracted, Offset.zero);
          remaining -= extractLen;
          // Compute the endpoint position.
          final tangent = metric.getTangentForOffset(extractLen);
          if (tangent != null) endPoint = tangent.position;
        }
      }
    }

    // Gradient fill under the drawn path.
    final areaPath = Path.from(drawnPath)
      ..lineTo(endPoint.dx, size.height)
      ..lineTo(start.dx, size.height)
      ..close();

    final fillAlpha = drawProgress.clamp(0.0, 1.0);
    _fill.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      [
        line.withValues(alpha: 0.22 * fillAlpha),
        line.withValues(alpha: 0.02 * fillAlpha),
      ],
    );
    canvas.drawPath(areaPath, _fill);
    _fill.shader = null;

    // Draw the line.
    _stroke
      ..strokeWidth = 2.5
      ..color = line;
    canvas.drawPath(drawnPath, _stroke);

    // Glowing endpoint dot.
    final pulse = 0.5 + 0.5 * math.sin(drawProgress * math.pi * 2);
    _fill
      ..color = line.withValues(alpha: 0.25 + 0.15 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(endPoint, 8, _fill);
    _fill
      ..color = line
      ..maskFilter = null;
    canvas.drawCircle(endPoint, 4, _fill);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.points != points ||
      old.line != line ||
      old.grid != grid ||
      old.drawProgress != drawProgress;
}

/// Pulses a radial gradient glow behind its child.
class BreathingGlow extends StatefulWidget {
  const BreathingGlow({
    super.key,
    required this.color,
    required this.child,
    this.intensity = 0.3,
    this.size = 200,
  });

  final Color color;
  final Widget child;
  final double intensity;
  final double size;

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final opacity = widget.intensity * 0.3 +
            (widget.intensity - widget.intensity * 0.3) * _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: opacity),
                    widget.color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
