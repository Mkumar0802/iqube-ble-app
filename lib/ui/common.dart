import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

export '../theme/app_theme.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m min';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String formatDate(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${t.day} ${_months[t.month - 1]}${t.year != now.year ? ' ${t.year}' : ''}';
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 10) return 'just now';
  if (d.inMinutes < 1) return '${d.inSeconds}s ago';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return formatDate(t);
}

/// Small label + big value tile used across screens.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  const StatTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.unit});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.brand.withValues(alpha: 0.12),
              borderRadius: AppShape.inner,
            ),
            child: Icon(icon, size: 18, color: c.brand),
          ),
          const SizedBox(height: 10),
          Text(label.toUpperCase(),
              style: AppText.overline.copyWith(color: c.onSurfaceMuted)),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: value,
                style: AppText.metric.copyWith(color: c.onSurface)),
            if (unit != null)
              TextSpan(
                  text: ' $unit',
                  style: AppText.unit.copyWith(color: c.onSurfaceMuted)),
          ])),
        ],
      ),
    );
  }
}

/// A version of [StatTile] that counts up from 0 to its numeric value on first appear.
/// Falls back to static text if the value cannot be parsed as a number.
class AnimatedStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  const AnimatedStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);
    final parsed = double.tryParse(value);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.brand.withValues(alpha: 0.12),
              borderRadius: AppShape.inner,
            ),
            child: Icon(icon, size: 18, color: c.brand),
          ),
          const SizedBox(height: 10),
          Text(label.toUpperCase(),
              style: AppText.overline.copyWith(color: c.onSurfaceMuted)),
          const SizedBox(height: 4),
          if (parsed != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: parsed),
              duration: resolveMotion(context, motion.fill),
              curve: motion.emphasized,
              builder: (context, v, _) {
                final dotIndex = value.indexOf('.');
                final decimals =
                    dotIndex >= 0 ? value.length - dotIndex - 1 : 0;
                final formatted = v.toStringAsFixed(decimals);
                return Text.rich(TextSpan(children: [
                  TextSpan(
                      text: formatted,
                      style: AppText.metric.copyWith(color: c.onSurface)),
                  if (unit != null)
                    TextSpan(
                        text: ' $unit',
                        style: AppText.unit.copyWith(color: c.onSurfaceMuted)),
                ]));
              },
            )
          else
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: value,
                  style: AppText.metric.copyWith(color: c.onSurface)),
              if (unit != null)
                TextSpan(
                    text: ' $unit',
                    style: AppText.unit.copyWith(color: c.onSurfaceMuted)),
            ])),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 24, 6, 10),
        child: Text(text.toUpperCase(),
            style: AppText.overline
                .copyWith(color: AppColors.of(context).onSurfaceMuted)),
      );
}
