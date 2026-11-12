import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The battery as a ring around a glass orb filled with liquid.
///
/// The ring and the liquid show the level. While charging, the liquid
/// swells, bubbles rise through it and light runs along the ring. With
/// animations turned off in the system settings it draws the same level,
/// still.
class BatteryOrb extends StatefulWidget {
  const BatteryOrb({
    super.key,
    required this.percent,
    required this.charging,
    this.size = 232,
    this.caption,
  });

  final int percent;
  final bool charging;
  final double size;

  /// Small line under the number, e.g. "Charging" or "46 km".
  final String? caption;

  @override
  State<BatteryOrb> createState() => _BatteryOrbState();
}

class _BatteryOrbState extends State<BatteryOrb> with TickerProviderStateMixin {
  // Wave, bubbles and ring light. Stops by itself when this tab is not
  // showing (TickerMode) or the app is in the background.
  late final AnimationController _loop = AnimationController(vsync: this);

  // The fill level, eased from the old value to the new one.
  late final AnimationController _level =
      AnimationController(vsync: this, value: 0);

  bool _still = false;

  double get _fraction => widget.percent.clamp(0, 100) / 100;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = AppMotion.of(context);
    _still = MediaQuery.disableAnimationsOf(context);
    _loop.duration = motion.wave;
    if (_still) {
      _loop.stop();
      _level.value = _fraction;
    } else {
      if (!_loop.isAnimating) _loop.repeat();
      _level.animateTo(_fraction,
          duration: motion.fill, curve: motion.emphasized);
    }
  }

  @override
  void didUpdateWidget(BatteryOrb old) {
    super.didUpdateWidget(old);
    if (old.percent == widget.percent) return;
    if (_still) {
      _level.value = _fraction;
    } else {
      final motion = AppMotion.of(context);
      _level.animateTo(_fraction,
          duration: motion.fill, curve: motion.emphasized);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);
    final big = widget.size >= 200;
    final scene = OrbScene(
      charging: widget.charging,
      level: c.heroLevel(widget.percent),
      track: c.heroTrack,
      orb: c.heroBottom,
      light: c.onHero,
    );

    return Semantics(
      label: 'Battery ${widget.percent} percent'
          '${widget.charging ? ', charging' : ''}'
          '${widget.caption != null ? ', ${widget.caption}' : ''}',
      child: ExcludeSemantics(
        child: Center(
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: OrbPainter(scene, loop: _loop, level: _level),
                      willChange: !_still,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.charging)
                      _Bolt(loop: _loop, color: c.onHero, size: big ? 26 : 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween:
                              Tween(begin: 0, end: widget.percent.toDouble()),
                          duration: resolveMotion(context, motion.fill),
                          curve: motion.emphasized,
                          builder: (context, v, _) => Text(
                            '${v.round()}',
                            style: (big ? AppText.hero : AppText.heroSmall)
                                .copyWith(color: c.onHero, shadows: [
                              Shadow(color: c.heroBottom, blurRadius: 12),
                            ]),
                          ),
                        ),
                        Text('%',
                            style: AppText.metric.copyWith(
                                color: c.onHero.withValues(alpha: 0.8))),
                      ],
                    ),
                    if (widget.caption != null) ...[
                      const SizedBox(height: 4),
                      Text(widget.caption!,
                          style: AppText.unit.copyWith(color: c.onHero)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The charging bolt, gently breathing.
class _Bolt extends StatelessWidget {
  const _Bolt({required this.loop, required this.color, required this.size});

  final Animation<double> loop;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) {
        final s = 0.5 + 0.5 * math.sin(loop.value * 2 * math.pi * 2);
        return Opacity(
          opacity: 0.6 + 0.4 * s,
          child: Transform.scale(scale: 0.94 + 0.1 * s, child: child),
        );
      },
      child: Icon(Icons.bolt_rounded, color: color, size: size),
    );
  }
}

/// Everything [OrbPainter] needs besides the two animations.
@immutable
class OrbScene {
  const OrbScene({
    required this.charging,
    required this.level,
    required this.track,
    required this.orb,
    required this.light,
  });

  final bool charging;
  final Color level;
  final Color track;
  final Color orb;
  final Color light;

  @override
  bool operator ==(Object other) =>
      other is OrbScene &&
      other.charging == charging &&
      other.level == level &&
      other.track == track &&
      other.orb == orb &&
      other.light == light;

  @override
  int get hashCode => Object.hash(charging, level, track, orb, light);
}

class OrbPainter extends CustomPainter {
  OrbPainter(this.scene, {required this.loop, required this.level})
      : super(repaint: Listenable.merge([loop, level]));

  final OrbScene scene;

  /// 0..1, repeating.
  final Animation<double> loop;

  /// 0..1, the fill level.
  final Animation<double> level;

  static const _bubbles = 9;

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _outerGlow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.bevel;
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Path _wave = Path();
  final Path _clip = Path();
  final Path _arcPath = Path();
  double _blurFor = -1;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final stroke = r * 0.085;
    final ringR = r - stroke * 1.2;
    final ring = Rect.fromCircle(center: c, radius: ringR);
    final f = level.value.clamp(0.0, 1.0);
    final t = loop.value;
    const top = -math.pi / 2;
    const turn = 2 * math.pi;

    // Subtle outer glow ring (2px larger than the main ring) with level color at 0.15 alpha
    if (f > 0) {
      _outerGlow
        ..strokeWidth = stroke + 4
        ..color = scene.level.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(c, ringR + 2, _outerGlow);
    }

    // Ring: track, glow, level.
    _stroke
      ..strokeWidth = stroke
      ..color = scene.track;
    canvas.drawCircle(c, ringR, _stroke);
    if (f > 0) {
      if (_blurFor != stroke) {
        _glow.maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.9);
        _blurFor = stroke;
      }
      _glow
        ..strokeWidth = stroke * 1.5
        ..color = scene.level.withValues(alpha: scene.charging ? 0.5 : 0.3);
      canvas.drawArc(ring, top, turn * f, false, _glow);
      _stroke.color = scene.level;
      canvas.drawArc(ring, top, turn * f, false, _stroke);

      // Light running along the ring while charging.
      if (scene.charging) {
        for (var i = 0; i < 2; i++) {
          final p = (t + i * 0.5) % 1;
          final head = turn * f * p;
          final tail = math.min(head, 0.5);
          _stroke.color = scene.light
              .withValues(alpha: 0.75 * math.sin(math.pi * p));
          canvas.drawArc(ring, top + head - tail, tail, false, _stroke);
        }
      }
    }

    // Orb and liquid.
    final ri = ringR - stroke / 2 - r * 0.075;
    _fill.color = scene.orb;
    canvas.drawCircle(c, ri, _fill);

    _clip
      ..reset()
      ..addOval(Rect.fromCircle(center: c, radius: ri));
    canvas.save();
    canvas.clipPath(_clip);

    final left = c.dx - ri;
    final right = c.dx + ri;
    final bottom = c.dy + ri;
    final surface = bottom - 2 * ri * f;
    // Flat when empty or full, liveliest in the middle.
    final swell = (4 * f * (1 - f)).clamp(0.25, 1.0);
    final amp = ri * (scene.charging ? 0.055 : 0.03) * swell;
    final length = ri * 1.7;

    void wave(double phase, double alpha, double lift) {
      _wave
        ..reset()
        ..moveTo(left, bottom);
      for (var x = left; x <= right + 4; x += 4) {
        final y = surface -
            lift +
            amp * math.sin((x - left) / length * turn + phase);
        _wave.lineTo(x, y);
      }
      _wave
        ..lineTo(right, bottom)
        ..close();
      _fill.color = scene.level.withValues(alpha: alpha);
      canvas.drawPath(_wave, _fill);
    }

    if (f > 0) {
      wave(turn * t + 1.3, 0.28, amp * 0.6);
      wave(-turn * t, 0.5, 0);
    }

    if (scene.charging && f > 0.04) {
      // 9 standard rising bubbles
      for (var i = 0; i < _bubbles; i++) {
        final seed = (i * 0.618034) % 1;
        final p = (t * (1 + i % 3) + seed * 7) % 1;
        final y = bottom - p * (bottom - surface);
        final x = c.dx +
            (seed * 2 - 1) * ri * 0.7 +
            math.sin(p * turn + i) * ri * 0.03;
        _fill.color =
            scene.light.withValues(alpha: 0.45 * math.sin(math.pi * p));
        canvas.drawCircle(Offset(x, y), ri * (0.018 + 0.022 * seed), _fill);
      }

      // 3 large slow bubbles (radius 0.04 - 0.06 * ri)
      for (var i = 0; i < 3; i++) {
        final seed = ((i + 13) * 0.414213) % 1;
        final p = (t * 0.45 + seed * 5) % 1;
        final y = bottom - p * (bottom - surface);
        final x = c.dx +
            (seed * 2 - 1) * ri * 0.55 +
            math.sin(p * turn * 0.8 + i * 2) * ri * 0.04;
        _fill.color =
            scene.light.withValues(alpha: 0.35 * math.sin(math.pi * p));
        final bubbleRadius = ri * (0.04 + 0.01 * (i % 3));
        canvas.drawCircle(Offset(x, y), bubbleRadius, _fill);
      }
    }
    canvas.restore();

    // Glass rim.
    _stroke
      ..strokeWidth = 1
      ..color = scene.light.withValues(alpha: 0.1);
    canvas.drawCircle(c, ri, _stroke);

    // Electric arcs when charging: draw 2-3 thin jagged lines from random points
    // on the ring inward, flickering based on loop.value.
    if (scene.charging && f > 0) {
      _arcPaint
        ..strokeWidth = 1.4
        ..color = scene.light.withValues(alpha: 0.6);

      for (var i = 0; i < 3; i++) {
        // Flicker: appears/disappears rapidly
        final flickerPhase = math.sin(t * turn * 7 + i * 2.3);
        if (flickerPhase < 0.2) continue;

        final baseAngle = top + (t * 0.8 + i * 0.33) * turn;
        final startX = c.dx + ringR * math.cos(baseAngle);
        final startY = c.dy + ringR * math.sin(baseAngle);

        _arcPath.reset();
        _arcPath.moveTo(startX, startY);

        final arcLength = ri * 0.35;
        const steps = 4;
        final cosA = math.cos(baseAngle);
        final sinA = math.sin(baseAngle);
        // Perpendicular vector for zigzag
        final perpX = -sinA;
        final perpY = cosA;

        for (var step = 1; step <= steps; step++) {
          final frac = step / steps;
          final inwardDist = arcLength * frac;
          // Inward toward center
          final targetX = startX - inwardDist * cosA;
          final targetY = startY - inwardDist * sinA;
          // Jagged offset alternating with pseudo-random vibration
          final zig = (step % 2 == 1 ? 1 : -1) *
              (4.0 + 2.0 * math.sin(t * 30 + step * 3 + i));
          _arcPath.lineTo(targetX + perpX * zig, targetY + perpY * zig);
        }

        canvas.drawPath(_arcPath, _arcPaint);
      }
    }
  }

  @override
  bool shouldRepaint(OrbPainter old) =>
      old.scene != scene || old.loop != loop || old.level != level;
}
