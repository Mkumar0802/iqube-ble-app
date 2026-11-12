import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A shimmering highlight sweep over [child], used as a loading placeholder.
///
/// Set [enabled] to `false` to show the child without the shimmer.
class ShimmerEffect extends StatefulWidget {
  const ShimmerEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final bool enabled;

  /// The dark stripe colour. Defaults to theme surface.
  final Color? baseColor;

  /// The light sweep colour. Defaults to `surfaceHigh`.
  final Color? highlightColor;

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use a default shimmer duration (~1.5 s).
    const fallback = Duration(milliseconds: 1500);
    final resolved = resolveMotion(context, fallback);
    _ctrl.duration = resolved;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(ShimmerEffect old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.enabled && (_ctrl.duration ?? Duration.zero) > Duration.zero) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final c = AppColors.of(context);
    final base = widget.baseColor ?? c.surfaceHigh;
    final highlight = widget.highlightColor ?? c.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: [
                _clamp(_animation.value - 0.3),
                _clamp(_animation.value),
                _clamp(_animation.value + 0.3),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }

  static double _clamp(double v) => v.clamp(0.0, 1.0);
}
