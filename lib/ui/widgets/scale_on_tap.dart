import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Micro-interaction: the child shrinks on press and springs back on release.
class ScaleOnTap extends StatefulWidget {
  const ScaleOnTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  final Widget child;

  /// Fires on tap-up, like a regular button.
  final VoidCallback? onTap;

  /// Scale factor when pressed. 1.0 = no effect, 0.0 = disappears.
  final double scale;

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final m = AppMotion.of(context);
    final dur = resolveMotion(context, m.fast);

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: dur,
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
