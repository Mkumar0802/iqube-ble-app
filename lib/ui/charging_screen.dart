import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/vehicle_service.dart';
import '../services/app_settings.dart';
import '../services/charge_tracker.dart';
import '../services/demo_mode.dart';
import '../services/range_estimator.dart';
import '../theme/haptics.dart';
import 'common.dart';
import 'widgets/animated_gradient_border.dart';
import 'widgets/battery_orb.dart';
import 'widgets/kit.dart';
import 'widgets/particle_field.dart';
import 'widgets/scale_on_tap.dart';
import 'widgets/shimmer_effect.dart';

class ChargingScreen extends StatefulWidget {
  const ChargingScreen({super.key});

  @override
  State<ChargingScreen> createState() => _ChargingScreenState();
}

class _ChargingScreenState extends State<ChargingScreen> {
  // Target charge level: 80% (Optimal cell health) or 100% (Full trip).
  int _selectedTarget = 80;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Charging Dashboard',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          VehicleService.instance,
          ChargeTracker.instance,
          DemoMode.instance,
          AppSettings.instance,
        ]),
        builder: (context, _) {
          final now = BatteryNow.read();
          final pct = now.percent;
          final charge = ChargeTracker.instance;
          final settings = AppSettings.instance;
          final c = AppColors.of(context);
          final motion = AppMotion.of(context);

          if (pct == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ev_station_rounded,
                        size: 64, color: c.onSurfaceMuted),
                    const SizedBox(height: 16),
                    Text(
                      'No Scooter Connected',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect to your TVS iQube to view live EV charging telemetry, battery health & range projections.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: c.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final charging = now.charging;
          final range = RangeEstimate.forBattery(pct)!;
          final rate = charge.ratePctPerHour;
          final kmPerHour = RangeEstimate.forBattery(100)!.ecoKm / 100 * rate;
          final rateSource = charge.measuredRate != null
              ? 'Real-time telemetry'
              : charge.learnedRatePctPerHour != null
                  ? 'Historical session'
                  : 'Factory standard';

          // Power draw in kW (TVS iQube battery ~3.04 - 3.4 kWh pack).
          final powerKw = (rate * 0.032).clamp(0.40, 1.20);
          final samples = charge.samples;

          // Target calculations
          final isTargetDone = pct >= _selectedTarget;
          final timeToTarget = charge.timeTo(pct, _selectedTarget);
          final completionTime = DateTime.now().add(timeToTarget);
          final targetRange =
              RangeEstimate.forBattery(_selectedTarget)!.ecoKm;
          final rangeToAdd = math.max(0, targetRange - range.ecoKm);

          // Top Status Badge properties
          final (badgeText, badgeColor) = pct >= 100
              ? ('⚡ FULLY CHARGED • READY TO RIDE', c.energy)
              : charging
                  ? ('⚡ FAST AC CHARGE (650W) • 230V', c.electric)
                  : ('⚡ SCOOTER READY • UNPLUGGED', c.onSurfaceMuted);

          // -----------------------------------------------------------------
          // 1. Top EV Station Status Pill
          // -----------------------------------------------------------------
          final topStatusPill = Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: AppShape.pill,
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseDot(color: badgeColor, active: charging),
                  const SizedBox(width: 8),
                  Text(
                    badgeText,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
            ),
          );

          // -----------------------------------------------------------------
          // 2. Main Hero Stage
          // -----------------------------------------------------------------
          Widget heroCard = HeroCard(
            glow: c.heroLevel(pct),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Battery orb with particle field when charging - strictly centered with isolated repaint boundary
                  Center(
                    child: RepaintBoundary(
                      child: (charging && pct < 100)
                          ? SizedBox.square(
                              dimension: 240,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: ParticleField(
                                      color: c.heroLevel(pct),
                                    ),
                                  ),
                                  Center(
                                    child: BatteryOrb(
                                      percent: pct,
                                      charging: true,
                                      size: 240,
                                      caption: '${range.ecoKm} km Eco Range',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: BatteryOrb(
                                percent: pct,
                                charging: charging && pct < 100,
                                size: 240,
                                caption: '${range.ecoKm} km Eco Range',
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      pct >= 100
                          ? 'Battery Fully Charged'
                          : charging
                              ? 'Charging to $_selectedTarget%'
                              : 'Connected & Idle',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: c.onHero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      pct >= 100
                          ? 'Ready for your next commute'
                          : charging
                              ? isTargetDone
                                  ? '$_selectedTarget% target reached • Ready to ride'
                                  : 'Full by ${formatTime(completionTime)} (${formatDuration(timeToTarget)} left)'
                              : 'Plug in AC charger to view live charging',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.onHeroMuted,
                      ),
                    ),
                  ),
                  if (charging && pct < 100) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: c.heroTrack.withValues(alpha: 0.6),
                          borderRadius: AppShape.pill,
                          border: Border.all(
                            color: c.electric.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '⚡ ${powerKw.toStringAsFixed(2)} kW  •  230V AC  •  ${rate.toStringAsFixed(1)}% / hr',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: c.electric,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );

          if (charging && pct < 100) {
            heroCard = AnimatedGradientBorder(
              borderRadius: AppShape.card,
              child: heroCard,
            );
          }

          // -----------------------------------------------------------------
          // 3. Interactive Target Selector & Longevity Advice
          // -----------------------------------------------------------------
          final targetSection = GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: c.brand),
                      const SizedBox(width: 8),
                      Text(
                        'CHARGE TARGET & BATTERY HEALTH',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: c.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TargetChip(
                          target: 80,
                          title: '80% Optimal',
                          subtitle: 'Cell Health',
                          adviceTag: 'Recommended',
                          isSelected: _selectedTarget == 80,
                          timeString: pct >= 80
                              ? 'Reached'
                              : formatDuration(charge.timeTo(pct, 80)),
                          onTap: () {
                            Haptics.select();
                            setState(() => _selectedTarget = 80);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TargetChip(
                          target: 100,
                          title: '100% Full Trip',
                          subtitle: 'Max Range',
                          adviceTag: 'Long Ride',
                          isSelected: _selectedTarget == 100,
                          timeString: pct >= 100
                              ? 'Full'
                              : formatDuration(charge.timeTo(pct, 100)),
                          onTap: () {
                            Haptics.select();
                            setState(() => _selectedTarget = 100);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress bar to chosen target
                  Row(
                    children: [
                      Text(
                        'PROGRESS TO $_selectedTarget%',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.onSurfaceMuted,
                        ),
                      ),
                      const Spacer(),
                      AnimatedCount(
                        (pct / _selectedTarget * 100).clamp(0, 100).toDouble(),
                        decimals: 0,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isTargetDone ? c.energy : c.brand,
                        ),
                      ),
                      Text(
                        '%',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isTargetDone ? c.energy : c.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0,
                        end: (pct / _selectedTarget).clamp(0.0, 1.0)),
                    duration: resolveMotion(context, motion.fill),
                    curve: motion.emphasized,
                    builder: (context, v, _) {
                      Widget bar = ClipRRect(
                        borderRadius: AppShape.pill,
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 10,
                          color: isTargetDone ? c.energy : c.brand,
                          backgroundColor: c.surfaceHigh,
                        ),
                      );
                      if (charging && !isTargetDone) {
                        bar = ShimmerEffect(
                          baseColor: c.brand,
                          highlightColor: c.electric,
                          child: bar,
                        );
                      }
                      return bar;
                    },
                  ),
                  const SizedBox(height: 14),
                  // Battery longevity advice banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.surfaceHigh.withValues(alpha: 0.5),
                      borderRadius: AppShape.inner,
                      border: Border.all(
                        color: c.hairline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _selectedTarget == 80
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: _selectedTarget == 80 ? c.energy : c.brand,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedTarget == 80
                                ? '80% optimal charging prevents lithium dendrite formation and maintains pack longevity past 1,000+ charge cycles.'
                                : 'Charge to 100% prior to extended trips for full range. High-voltage cell balancing occurs in this top 20% tier.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              height: 1.35,
                              color: c.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          // -----------------------------------------------------------------
          // 4. EV Charging Metrics Matrix (4-card Grid)
          // -----------------------------------------------------------------
          final metricsMatrix = Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.bolt_rounded,
                      label: 'Power Rate',
                      value: powerKw.toStringAsFixed(2),
                      unit: 'kW',
                      subtext: '230V • 3.2A AC',
                      color: c.electric,
                    ),
                  ),
                  const SizedBox(width: AppShape.gap),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.speed_rounded,
                      label: 'Charge Speed',
                      value: rate.toStringAsFixed(1),
                      unit: '% / h',
                      subtext: rateSource,
                      color: c.brand,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppShape.gap),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Range Added',
                      value: kmPerHour.toStringAsFixed(0),
                      unit: 'km / h',
                      subtext: '+$rangeToAdd km to $_selectedTarget%',
                      color: c.energy,
                    ),
                  ),
                  const SizedBox(width: AppShape.gap),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.access_time_filled_rounded,
                      label: 'Target ETA',
                      value: isTargetDone
                          ? 'Done'
                          : formatTime(completionTime),
                      unit: isTargetDone ? '' : '',
                      subtext: isTargetDone
                          ? '$_selectedTarget% reached'
                          : 'Full to $_selectedTarget%',
                      color: c.warning,
                    ),
                  ),
                ],
              ),
            ],
          );

          // -----------------------------------------------------------------
          // 5. Target Alerts Card
          // -----------------------------------------------------------------
          final targetAlertsCard = _TargetAlertsCard(
            currentAlert: settings.chargeTargetAlert,
            onChanged: (val) {
              Haptics.select();
              settings.update(chargeTargetAlert: val);
            },
          );

          // -----------------------------------------------------------------
          // 6. Charge Curve Chart & History Session Log
          // -----------------------------------------------------------------
          final recentSamples = samples.reversed.take(5).toList();
          final historySection = Card(
            child: samples.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No charging sessions recorded today yet',
                      style: GoogleFonts.outfit(color: c.onSurfaceMuted),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (samples.length >= 2) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                          child: Row(
                            children: [
                              Icon(Icons.show_chart_rounded,
                                  size: 18, color: c.brand),
                              const SizedBox(width: 8),
                              Text(
                                'LIVE CHARGE CURVE',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: c.onSurfaceMuted,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.energy.withValues(alpha: 0.14),
                                  borderRadius: AppShape.pill,
                                ),
                                child: Text(
                                  '${samples.first.$2}% → ${samples.last.$2}%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: c.energy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: AppShape.inner,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  c.brand.withValues(alpha: 0.08),
                                  c.brand.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            child: Sparkline(samples: samples),
                          ),
                        ),
                        // Time markers under sparkline
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Started ${formatTime(samples.first.$1)} (${samples.first.$2}%)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: c.onSurfaceMuted,
                                ),
                              ),
                              Text(
                                'Now ${formatTime(samples.last.$1)} (${samples.last.$2}%)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: c.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                      ],
                      // Session Log with energy in kWh and cost in ₹
                      _ChargeSessionLogItem(
                        samples: samples,
                        electricityRate: settings.electricityRatePerKwh,
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                        child: Text(
                          'RECENT CHARGE TELEMETRY',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: c.onSurfaceMuted,
                          ),
                        ),
                      ),
                      for (var i = 0; i < recentSamples.length; i++)
                        Reveal(
                          index: 4 + i,
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: c
                                    .level(recentSamples[i].$2)
                                    .withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.battery_charging_full_rounded,
                                size: 16,
                                color: c.level(recentSamples[i].$2),
                              ),
                            ),
                            title: Text(
                              '${recentSamples[i].$2}% State of Charge',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: Text(
                              formatTime(recentSamples[i].$1),
                              style: GoogleFonts.outfit(
                                color: c.onSurfaceMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      if (charge.lastFullChargeAt != null) ...[
                        const Divider(),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.history_rounded),
                          title: Text(
                            'Last 100% full charge: ${formatDate(charge.lastFullChargeAt!)}, ${formatTime(charge.lastFullChargeAt!)}',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppShape.page, 4, AppShape.page, 28),
            children: [
              topStatusPill,
              Reveal(child: heroCard),
              const SizedBox(height: AppShape.gap),
              Reveal(index: 1, child: targetSection),
              const SectionTitle('Charging Telemetry Matrix'),
              Reveal(index: 2, child: metricsMatrix),
              const SectionTitle('Target Notifications & Alerts'),
              Reveal(index: 3, child: targetAlertsCard),
              const SectionTitle('Charge Curve & Session Log'),
              Reveal(index: 4, child: historySection),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                child: Text(
                  'Charging speed slows dynamically above 80% to protect cell chemistry. Keep app connected for live battery telemetry.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: c.onSurfaceMuted,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TargetAlertsCard — Charge alert settings
// ---------------------------------------------------------------------------

class _TargetAlertsCard extends StatelessWidget {
  const _TargetAlertsCard({
    required this.currentAlert,
    required this.onChanged,
  });

  final int currentAlert;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    size: 18, color: c.brand),
                const SizedBox(width: 8),
                Text(
                  'CHARGE LEVEL ALERTS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: c.onSurfaceMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ScaleOnTap(
                    onTap: () => onChanged(80),
                    child: _AlertOptionTile(
                      target: 80,
                      label: '80% Full Alert',
                      subtext: 'Preserves cell health',
                      isSelected: currentAlert == 80,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ScaleOnTap(
                    onTap: () => onChanged(100),
                    child: _AlertOptionTile(
                      target: 100,
                      label: '100% Full Alert',
                      subtext: 'Ready for long trip',
                      isSelected: currentAlert == 100,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surfaceHigh.withValues(alpha: 0.5),
                borderRadius: AppShape.inner,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: c.onSurfaceMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Push alert sounds when your iQube reaches $currentAlert%, reminding you to unplug.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.onSurfaceMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertOptionTile extends StatelessWidget {
  const _AlertOptionTile({
    required this.target,
    required this.label,
    required this.subtext,
    required this.isSelected,
  });

  final int target;
  final String label;
  final String subtext;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? c.brand.withValues(alpha: 0.12)
            : c.surfaceHigh.withValues(alpha: 0.3),
        borderRadius: AppShape.inner,
        border: Border.all(
          color: isSelected ? c.brand : c.hairline,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: isSelected ? c.brand : c.onSurfaceMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? c.brand : c.onSurface,
                  ),
                ),
                Text(
                  subtext,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: c.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChargeSessionLogItem — Energy (kWh) and Cost (₹) breakdown
// ---------------------------------------------------------------------------

class _ChargeSessionLogItem extends StatelessWidget {
  const _ChargeSessionLogItem({
    required this.samples,
    required this.electricityRate,
  });

  final List<(DateTime, int)> samples;
  final double electricityRate;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    // Compute session details:
    // If samples available, compute from start to finish
    final startPct = samples.isNotEmpty ? samples.first.$2 : 20;
    final endPct = samples.isNotEmpty ? samples.last.$2 : 80;
    final deltaPct = math.max(1, endPct - startPct);

    final duration = samples.length >= 2
        ? samples.last.$1.difference(samples.first.$1)
        : Duration(minutes: (deltaPct * 3).toInt());

    // TVS iQube usable battery is ~3.04 kWh
    final energyKwh = deltaPct * 3.04 / 100.0;
    final costRs = energyKwh * electricityRate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 16, color: c.brand),
              const SizedBox(width: 6),
              Text(
                'LATEST CHARGE SESSION & COST',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: c.onSurfaceMuted,
                ),
              ),
              const Spacer(),
              Text(
                '@ ₹${electricityRate.toStringAsFixed(1)}/kWh',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.onSurfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SessionStatBox(
                  label: 'LEVEL GAINED',
                  value: '$startPct% → $endPct%',
                  subtext: '+$deltaPct% charged',
                  color: c.energy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SessionStatBox(
                  label: 'ENERGY ADDED',
                  value: '${energyKwh.toStringAsFixed(2)} kWh',
                  subtext: formatDuration(duration),
                  color: c.electric,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SessionStatBox(
                  label: 'EST. COST',
                  value: '₹${costRs.toStringAsFixed(1)}',
                  subtext: 'Home tariff',
                  color: c.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionStatBox extends StatelessWidget {
  const _SessionStatBox({
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
  });

  final String label;
  final String value;
  final String subtext;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceHigh.withValues(alpha: 0.4),
        borderRadius: AppShape.inner,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: c.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            subtext,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: c.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TargetChip — Interactive chip to toggle 80% vs 100%
// ---------------------------------------------------------------------------

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.target,
    required this.title,
    required this.subtitle,
    required this.adviceTag,
    required this.isSelected,
    required this.timeString,
    required this.onTap,
  });

  final int target;
  final String title;
  final String subtitle;
  final String adviceTag;
  final bool isSelected;
  final String timeString;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final borderColor = isSelected ? c.brand : c.hairline;
    final bgColor = isSelected
        ? c.brand.withValues(alpha: 0.12)
        : c.surface.withValues(alpha: 0.6);

    return ScaleOnTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppShape.inner,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: c.brand.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? c.brand : c.onSurface,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: c.brand),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isSelected ? c.brand : c.surfaceHigh)
                    .withValues(alpha: 0.2),
                borderRadius: AppShape.pill,
              ),
              child: Text(
                timeString,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? c.brand : c.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MetricCard — Tesla-style EV telemetry card
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.subtext,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String subtext;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final numericValue = double.tryParse(value);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: c.onSurfaceMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (numericValue != null)
                  AnimatedCount(
                    numericValue,
                    decimals: value.contains('.')
                        ? value.length - value.indexOf('.') - 1
                        : 0,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: c.onSurface,
                    ),
                  )
                else
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: c.onSurface,
                    ),
                  ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: c.onSurfaceMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
