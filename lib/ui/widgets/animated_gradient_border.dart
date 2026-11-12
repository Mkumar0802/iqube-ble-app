import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A container whose border is a continuously rotating gradient.
///
/// Wrap premium cards in this widget to give them a luminous animated edge.
class AnimatedGradientBorder extends StatefulWidget {
  const AnimatedGradientBorder({
    super.key,
    required this.child,
    this.borderRadius,
    this.strokeWidth = 2,
    this.colors,
    this.duration,
  });

  final Widget child;

  /// Defaults to [AppShape.cardRadius].
  final BorderRadius? borderRadius;

  /// Width of the gradient stroke.
  final double strokeWidth;

  /// Gradient colours. Defaults to a brand→energy sweep when omitted.
  final List<Color>? colors;

  /// Full rotation duration. Falls back to 3 s.
  final Duration? duration;

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dur = widget.duration ?? const Duration(milliseconds: 3000);
    final resolved = resolveMotion(context, dur);
    _ctrl.duration = resolved;
    if (resolved == Duration.zero) {
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
    final colors = widget.colors ?? [c.brand, c.energy, c.brand];
    final radius = widget.borderRadius ?? AppShape.card;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _GradientBorderPainter(
            progress: _ctrl.value,
            colors: colors,
            strokeWidth: widget.strokeWidth,
            borderRadius: radius,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(widget.strokeWidth),
        child: SizedBox(
          width: double.infinity,
          child: widget.child,
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.progress,
    required this.colors,
    required this.strokeWidth,
    required this.borderRadius,
  });

  final double progress;
  final List<Color> colors;
  final double strokeWidth;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.resolve(TextDirection.ltr).toRRect(rect).deflate(strokeWidth / 2);

    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: colors,
      transform: GradientRotation(progress * math.pi * 2),
    );

    final paint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Draw the glow pass.
    canvas.drawRRect(rrect, paint);

    // Draw the crisp pass on top.
    paint.maskFilter = null;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}
