import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Floating EV-themed particles that drift upward behind hero sections.
class ParticleField extends StatefulWidget {
  const ParticleField({
    super.key,
    this.particleCount = 20,
    this.color,
    this.child,
  });

  final int particleCount;
  final Color? color;
  final Widget? child;

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _particles = List.generate(widget.particleCount, (_) => _Particle(_rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final particleColor = widget.color ?? c.brand;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  time: _ctrl.value,
                  color: particleColor,
                ),
              );
            },
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// Seed values for a single particle, generated once and reused every frame.
class _Particle {
  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        speed = 0.3 + rng.nextDouble() * 0.7,
        radius = 1.0 + rng.nextDouble() * 3.0,
        opacity = 0.15 + rng.nextDouble() * 0.45,
        phase = rng.nextDouble() * math.pi * 2;

  final double x;
  final double y;
  final double speed;
  final double radius;
  final double opacity;
  final double phase;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.time,
    required this.color,
  });

  final List<_Particle> particles;
  final double time;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Vertical: drift upward, wrap around.
      final rawY = (p.y - time * p.speed) % 1.0;
      final dy = rawY * size.height;

      // Horizontal: sine-wave drift.
      final dx =
          p.x * size.width + math.sin(time * math.pi * 2 + p.phase) * 12;

      paint.color = color.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.time != time;
}
