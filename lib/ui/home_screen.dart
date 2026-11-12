import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ble/vehicle_service.dart';
import '../main.dart';
import '../rides/ride.dart';
import '../rides/ride_tracker.dart';
import '../services/app_settings.dart';
import '../services/charge_tracker.dart';
import '../services/cluster_notifier.dart';
import '../services/demo_mode.dart';
import '../services/range_estimator.dart';
import '../services/ride_summary.dart';
import '../theme/haptics.dart';
import 'battery_health_screen.dart';
import 'common.dart';
import 'connect_sheet.dart';
import 'rides_screen.dart';
import 'widgets/animated_gradient_border.dart';
import 'widgets/animated_gauge.dart';
import 'widgets/battery_orb.dart';
import 'widgets/kit.dart';
import 'widgets/particle_field.dart';
import 'widgets/scale_on_tap.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Refreshes "synced x ago" periodically without janking the frame rate.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        VehicleService.instance,
        RideTracker.instance,
        RideStore.instance,
        ChargeTracker.instance,
        AppSettings.instance,
        ClusterNotifier.instance,
        RideSummary.instance,
        DemoMode.instance,
      ]),
      builder: (context, _) {
        final lastRide = RideSummary.instance.last;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppShape.page, 12, AppShape.page, 28),
            children: [
              if (DemoMode.instance.enabled) ...[
                const _DemoBanner(),
                const SizedBox(height: 10),
              ],
              const Reveal(child: _Header()),
              const SizedBox(height: 14),
              const Reveal(index: 1, child: _QuickActionsRow()),
              const SizedBox(height: 14),
              const Reveal(index: 2, child: _BatteryCard()),
              const SizedBox(height: AppShape.gap),
              const Reveal(index: 3, child: _TodayStrip()),
              const SizedBox(height: AppShape.gap),
              const Reveal(index: 4, child: _WhereIsMyScooterCard()),
              const SizedBox(height: AppShape.gap),
              const Reveal(index: 5, child: _RangeRingCard()),
              const SizedBox(height: AppShape.gap),
              const Reveal(index: 6, child: _OdometerMilestoneCard()),
              const SizedBox(height: AppShape.gap),
              const Reveal(index: 7, child: _RideCard()),
              if (lastRide != null) ...[
                const SizedBox(height: AppShape.gap),
                _LinkCard(
                  icon: Icons.flag_rounded,
                  title: 'Last ride',
                  subtitle: lastRide,
                ),
              ],
              const SizedBox(height: AppShape.gap),
              Reveal(
                index: 8,
                child: _LinkCard(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Battery health',
                  subtitle: 'Range and charge cycles over the months',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BatteryHealthScreen())),
                ),
              ),
              const SectionTitle('All rides'),
              const Reveal(index: 9, child: _TotalsCard()),
              const SizedBox(height: AppShape.gap),
              const Reveal(index: 10, child: _ClusterCard()),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Maps navigation helper
// ---------------------------------------------------------------------------

Future<void> _launchMaps(double lat, double lng) async {
  final uri =
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------------------
// Greeting helper
// ---------------------------------------------------------------------------

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

// ---------------------------------------------------------------------------
// _DemoBanner
// ---------------------------------------------------------------------------

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.14),
        borderRadius: AppShape.inner,
        border: Border.all(color: c.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          PulseDot(color: c.warning, active: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW MODE ACTIVE',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: c.warning,
                  ),
                ),
                Text(
                  'Entire app running in live simulated condition',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: c.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          ScaleOnTap(
            onTap: () {
              Haptics.commit();
              DemoMode.instance.setEnabled(false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.warning,
                borderRadius: AppShape.pill,
              ),
              child: Text(
                'Exit Demo',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Header
// ---------------------------------------------------------------------------

class _Header extends StatefulWidget {
  const _Header();

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = VehicleService.instance;
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (color, text) = switch (v.link) {
      VehicleLink.connected => (c.energy, 'Connected'),
      VehicleLink.connecting => (c.warning, 'Connecting'),
      VehicleLink.disconnected =>
        (c.onSurfaceMuted, v.hasSavedScooter ? 'Offline' : 'Not paired'),
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  _greeting(),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Mtvs Connect',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                v.deviceName ?? 'TVS iQube Electric',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
        if (!DemoMode.instance.enabled && v.link != VehicleLink.connected) ...[
          ScaleOnTap(
            onTap: () {
              Haptics.commit();
              DemoMode.instance.setEnabled(true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.12),
                borderRadius: AppShape.pill,
                border: Border.all(color: c.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline_rounded,
                      size: 15, color: c.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Preview',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Dark/Light mode toggle button
        ScaleOnTap(
          onTap: () {
            Haptics.select();
            IQubeApp.of(context).toggleTheme();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: resolveMotion(context, motion.fast),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey('home_theme_toggle_$isDark'),
                  size: 20,
                  color: isDark ? c.warning : c.brand,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ScaleOnTap(
          onTap: () {
            if (v.link == VehicleLink.connected) return;
            Haptics.commit();
            if (v.hasSavedScooter) {
              v.reconnectSaved();
            } else {
              showConnectSheet(context);
            }
          },
          child: Material(
            color: c.surface,
            shape: StadiumBorder(side: BorderSide(color: c.hairline)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 12, 16, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseDot(
                      color: color,
                      active: v.link != VehicleLink.disconnected),
                  const SizedBox(width: 6),
                  Text(text, style: theme.textTheme.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _QuickActionsRow
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Row(
      children: [
        Expanded(
          child: ScaleOnTap(
            onTap: () {
              Haptics.commit();
              _showClusterTestSheet(context);
            },
            child: _ActionPill(
              icon: Icons.notifications_active_rounded,
              label: 'Test Cluster',
              color: c.brand,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ScaleOnTap(
            onTap: () async {
              Haptics.commit();
              final settings = AppSettings.instance;
              if (settings.lastParkedLat == null || settings.lastParkedLng == null) {
                try {
                  final pos = await Geolocator.getLastKnownPosition() ??
                      await Geolocator.getCurrentPosition(
                        locationSettings: const LocationSettings(
                          timeLimit: Duration(seconds: 4),
                        ),
                      );
                  settings.saveParkedLocation(pos.latitude, pos.longitude);
                } catch (_) {
                  // Fall back to default location
                  settings.saveParkedLocation(12.9716, 77.5946);
                }
              }
              final lat = settings.lastParkedLat ?? 12.9716;
              final lng = settings.lastParkedLng ?? 77.5946;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening Google Maps navigation to your scooter'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              await _launchMaps(lat, lng);
            },
            child: _ActionPill(
              icon: Icons.near_me_rounded,
              label: 'Find Scooter',
              color: c.energy,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ScaleOnTap(
            onTap: () {
              Haptics.commit();
              final store = RideStore.instance;
              if (store.rides.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RideDetailScreen(ride: store.rides.first),
                  ),
                );
              } else {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.electric_moped_rounded, color: c.brand),
                        const SizedBox(width: 10),
                        Text(
                          'No Recorded Rides',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    content: Text(
                      'You haven\'t recorded any rides yet. Turn on Preview Mode to explore simulated rides with speed maps, elevation charts, and GPX/CSV export.',
                      style: GoogleFonts.outfit(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Cancel', style: GoogleFonts.outfit()),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          DemoMode.instance.setEnabled(true);
                        },
                        child: Text('Enable Preview Mode',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }
            },
            child: _ActionPill(
              icon: Icons.share_rounded,
              label: 'Share Ride',
              color: c.warning,
            ),
          ),
        ),
      ],
    );
  }
}

void _showClusterTestSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _ClusterTestSheet(),
  );
}

class _ClusterTestSheet extends StatefulWidget {
  const _ClusterTestSheet();

  @override
  State<_ClusterTestSheet> createState() => _ClusterTestSheetState();
}

class _ClusterTestSheetState extends State<_ClusterTestSheet> {
  String _activePreview = 'Ready to ride!';
  String _activeType = 'SYSTEM';

  void _send(String text, String type, Future<bool> Function() action) async {
    Haptics.commit();
    setState(() {
      _activePreview = text;
      _activeType = type;
    });
    final ok = await action();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Transmitted to iQube TFT cluster'
              : 'Scooter offline — simulated on screen'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.onSurfaceMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.brand.withValues(alpha: 0.12),
                  borderRadius: AppShape.inner,
                ),
                child: Icon(Icons.speed_rounded, color: c.brand, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TFT Cluster Simulator',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.onSurface,
                    ),
                  ),
                  Text(
                    'Test notifications on the 7" iQube dashboard',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: c.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Cluster screen mock
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.brand.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: c.brand.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TVS iQube S',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white54,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.energy.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: c.energy, width: 0.8),
                      ),
                      child: Text(
                        'ECO MODE',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: c.energy,
                        ),
                      ),
                    ),
                    Text(
                      '78% SOC',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.energy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141923),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _activeType == 'CALL'
                            ? Icons.phone_in_talk_rounded
                            : _activeType == 'SMS'
                                ? Icons.sms_rounded
                                : _activeType == 'NAV'
                                    ? Icons.turn_right_rounded
                                    : Icons.electric_moped_rounded,
                        color: _activeType == 'CALL'
                            ? c.warning
                            : _activeType == 'NAV'
                                ? c.energy
                                : c.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeType,
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.white54,
                              ),
                            ),
                            Text(
                              _activePreview,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'SEND TEST FRAMES',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: c.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.phone_in_talk_rounded, size: 16),
                label: Text('Incoming Call', style: GoogleFonts.outfit(fontSize: 12)),
                onPressed: () => _send(
                  'Mom (+91 9876543210)',
                  'CALL',
                  () => ClusterNotifier.instance.sendCall('Mom'),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.sms_rounded, size: 16),
                label: Text('SMS Alert', style: GoogleFonts.outfit(fontSize: 12)),
                onPressed: () => _send(
                  'Arriving in 5 mins',
                  'SMS',
                  () => ClusterNotifier.instance.sendMessage('Arriving in 5m'),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.turn_right_rounded, size: 16),
                label: Text('Turn Navigation', style: GoogleFonts.outfit(fontSize: 12)),
                onPressed: () => _send(
                  'Turn Right in 200m',
                  'NAV',
                  () => ClusterNotifier.instance.sendMessage('Turn Right 200m'),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.waving_hand_rounded, size: 16),
                label: Text('Greeting Frame', style: GoogleFonts.outfit(fontSize: 12)),
                onPressed: () => _send(
                  'Ready to ride!',
                  'SYSTEM',
                  () => ClusterNotifier.instance.sendMessage('Ready to ride!'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppShape.inner,
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BatteryCard
// ---------------------------------------------------------------------------

class _BatteryCard extends StatelessWidget {
  const _BatteryCard();

  @override
  Widget build(BuildContext context) {
    final v = VehicleService.instance;
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final now = BatteryNow.read();
    final pct = now.percent;

    if (pct == null) {
      return HeroCard(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: BreathingGlow(
                  color: c.heroGlow,
                  size: 100,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.heroTrack,
                    ),
                    child: Icon(Icons.electric_moped_rounded,
                        size: 44, color: c.onHero),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  v.hasSavedScooter
                      ? 'Waiting for your scooter'
                      : 'Pair your iQube',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    textStyle: theme.textTheme.titleLarge?.copyWith(
                      color: c.onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Text(
                    v.lastError != null && !v.isConnected
                        ? v.lastError!
                        : v.hasSavedScooter
                            ? 'Switch the scooter on and stay close to it.'
                            : 'See battery, range and charging live.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: c.onHeroMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: ScaleOnTap(
                  child: FilledButton.icon(
                    onPressed: () {
                      Haptics.commit();
                      showConnectSheet(context);
                    },
                    icon: const Icon(Icons.bluetooth_searching_rounded),
                    label: Text(
                      v.hasSavedScooter ? 'Connect again' : 'Find my scooter',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final range = RangeEstimate.forBattery(pct)!;
    final charge = ChargeTracker.instance;
    final charging = now.charging;
    final level = c.heroLevel(pct);
    final status = charging
        ? 'Full in ${formatDuration(charge.timeTo(pct, 100))}'
        : now.demo
            ? 'Preview'
            : v.lastFrameAt == null
                ? 'Synced just now'
                : 'Synced ${timeAgo(v.lastFrameAt!)}';
    final odo = v.odometerKm;

    Widget card = HeroCard(
      glow: level,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(charging ? Icons.bolt_rounded : Icons.sync_rounded,
                    size: 16, color: charging ? level : c.onHeroMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(status,
                      style: AppText.unit.copyWith(color: c.onHeroMuted)),
                ),
                // Data age badge
                if (v.lastFrameAt != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.heroTrack,
                      borderRadius: AppShape.pill,
                    ),
                    child: Text(
                      'Updated ${timeAgo(v.lastFrameAt!)}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.onHeroMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (now.demo)
                  _Tag('PREVIEW', color: c.heroWarning)
                else if (odo != null)
                  Text('ODO ${odo.toStringAsFixed(1)} km',
                      style: AppText.unit.copyWith(color: c.onHeroMuted)),
              ],
            ),
            const SizedBox(height: 14),
            // BatteryOrb with ParticleField when charging - strictly centered with isolated repaint boundary
            Center(
              child: RepaintBoundary(
                child: charging
                    ? SizedBox.square(
                        dimension: 232,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: ParticleField(
                                color: level,
                              ),
                            ),
                            Center(
                              child: BatteryOrb(
                                percent: pct,
                                charging: charging,
                                caption: 'Charging',
                              ),
                            ),
                          ],
                        ),
                      )
                    : BatteryOrb(
                        percent: pct,
                        charging: charging,
                        caption: pct <= 15 ? 'Low battery' : null,
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (now.dteKm != null)
                  _AnimatedMetric(
                    label: 'Display',
                    value: now.dteKm!.roundToDouble(),
                    unit: 'km',
                    color: c.onHero,
                    muted: c.onHeroMuted,
                    accent: c.heroGlow,
                  ),
                _AnimatedMetric(
                  label: 'Eco',
                  value: range.ecoKm.toDouble(),
                  unit: 'km',
                  color: c.onHero,
                  muted: c.onHeroMuted,
                  accent: c.heroEnergy,
                ),
                _AnimatedMetric(
                  label: 'Power',
                  value: range.powerKm.toDouble(),
                  unit: 'km',
                  color: c.onHero,
                  muted: c.onHeroMuted,
                  accent: c.heroWarning,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                range.learned
                    ? 'Eco and Power range come from your own rides'
                    : 'Eco and Power range are estimates until you record rides',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: c.onHeroMuted),
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap in animated gradient border when charging
    if (charging) {
      card = AnimatedGradientBorder(
        borderRadius: AppShape.card,
        child: card,
      );
    }

    return card;
  }
}

// ---------------------------------------------------------------------------
// _TodayStrip
// ---------------------------------------------------------------------------

class _TodayStrip extends StatelessWidget {
  const _TodayStrip();

  @override
  Widget build(BuildContext context) {
    final store = RideStore.instance;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.today_rounded,
                    size: 16, color: AppColors.of(context).brand),
                const SizedBox(width: 6),
                Text(
                  "TODAY'S ACTIVITY",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.of(context).onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: AnimatedStatTile(
                  icon: Icons.route_rounded,
                  label: 'Ridden Today',
                  value: store.kmToday.toStringAsFixed(1),
                  unit: 'km',
                ),
              ),
              Expanded(
                child: AnimatedStatTile(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Battery Used',
                  value: '${store.batteryUsedToday}',
                  unit: '%',
                ),
              ),
              Expanded(
                child: AnimatedStatTile(
                  icon: Icons.moped_rounded,
                  label: 'Rides Today',
                  value: '${store.ridesToday.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WhereIsMyScooterCard
// ---------------------------------------------------------------------------

class _WhereIsMyScooterCard extends StatefulWidget {
  const _WhereIsMyScooterCard();

  @override
  State<_WhereIsMyScooterCard> createState() => _WhereIsMyScooterCardState();
}

class _WhereIsMyScooterCardState extends State<_WhereIsMyScooterCard> {
  final MapController _mapController = MapController();
  double? _distanceMeters;
  LatLng? _userPos;
  bool _updatingSpot = false;

  @override
  void initState() {
    super.initState();
    _checkDistance();
  }

  Future<void> _checkDistance() async {
    final settings = AppSettings.instance;
    final lat = settings.lastParkedLat;
    final lng = settings.lastParkedLng;
    if (lat == null || lng == null) return;

    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 4),
            ),
          );
      if (mounted) {
        final d = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, lat, lng);
        setState(() {
          _distanceMeters = d;
          _userPos = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {}
  }

  Future<void> _updateParkedSpot() async {
    Haptics.commit();
    setState(() => _updatingSpot = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 4),
        ),
      );
      AppSettings.instance.saveParkedLocation(pos.latitude, pos.longitude);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
      if (mounted) {
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
          _distanceMeters = 0;
          _updatingSpot = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parked location saved to current spot!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updatingSpot = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get GPS spot: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final c = AppColors.of(context);
    final lat = settings.lastParkedLat ?? 12.9716;
    final lng = settings.lastParkedLng ?? 77.5946;
    final parkedAt = settings.lastParkedAt;
    final hasRealLocation =
        settings.lastParkedLat != null && settings.lastParkedLng != null;

    final distanceStr = _distanceMeters != null
        ? (_distanceMeters! < 1000
            ? '${_distanceMeters!.round()} m away'
            : '${(_distanceMeters! / 1000).toStringAsFixed(1)} km away')
        : null;

    final parkedText = distanceStr != null
        ? '$distanceStr • ${parkedAt != null ? timeAgo(parkedAt) : "Parked"}'
        : (parkedAt != null
            ? 'Parked ${timeAgo(parkedAt)}'
            : (hasRealLocation
                ? 'Last known location'
                : 'Saved location (Bengaluru)'));

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.brand.withValues(alpha: 0.12),
                    borderRadius: AppShape.inner,
                  ),
                  child: Icon(Icons.location_on_rounded,
                      color: c.brand, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "WHERE'S MY SCOOTER",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: c.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parkedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // Update parked spot button
                ScaleOnTap(
                  onTap: _updatingSpot ? null : _updateParkedSpot,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      borderRadius: AppShape.pill,
                      border: Border.all(color: c.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _updatingSpot
                              ? Icons.sync_rounded
                              : Icons.bookmark_add_rounded,
                          size: 14,
                          color: c.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Park Here',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleOnTap(
                  onTap: () => _launchMaps(lat, lng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.brand,
                      borderRadius: AppShape.pill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_rounded,
                            size: 16, color: c.onBrand),
                        const SizedBox(width: 4),
                        Text(
                          'Navigate',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.onBrand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppShape.cardRadius)),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 16.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'muthumar.iqubtvs.com',
                      ),
                      if (_userPos != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_userPos!, LatLng(lat, lng)],
                              strokeWidth: 3,
                              color: c.brand.withValues(alpha: 0.6),
                              pattern: StrokePattern.dashed(segments: const [8, 6]),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_userPos != null)
                            Marker(
                              point: _userPos!,
                              width: 32,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.person_pin_circle_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          Marker(
                            point: LatLng(lat, lng),
                            width: 52,
                            height: 52,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.brand,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.brand.withValues(alpha: 0.45),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.electric_moped_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Floating re-center button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: ScaleOnTap(
                      onTap: () {
                        Haptics.select();
                        _mapController.move(LatLng(lat, lng), 16.0);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.hairline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(Icons.my_location_rounded,
                            size: 18, color: c.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RangeRingCard — Interactive reach map with fitted camera bounds & dual rings
// ---------------------------------------------------------------------------

class _RangeRingCard extends StatefulWidget {
  const _RangeRingCard();

  @override
  State<_RangeRingCard> createState() => _RangeRingCardState();
}

class _RangeRingCardState extends State<_RangeRingCard> {
  final MapController _mapController = MapController();

  LatLngBounds _computeBounds(double lat, double lng, double ecoKm) {
    // 1 degree latitude ~= 111.32 km
    final latDelta = (ecoKm * 1.18) / 111.32;
    final lngDelta =
        (ecoKm * 1.18) / (111.32 * math.cos(lat * math.pi / 180).abs().clamp(0.1, 1.0));
    return LatLngBounds(
      LatLng(lat - latDelta, lng - lngDelta),
      LatLng(lat + latDelta, lng + lngDelta),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final now = BatteryNow.read();
    final pct = now.percent ?? 50;
    final range = RangeEstimate.forBattery(pct)!;
    final settings = AppSettings.instance;
    final lat = settings.lastParkedLat ?? 12.9716;
    final lng = settings.lastParkedLng ?? 77.5946;
    final ecoMeters = range.ecoKm * 1000.0;
    final powerMeters = range.powerKm * 1000.0;
    final bounds = _computeBounds(lat, lng, range.ecoKm.toDouble());

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.energy.withValues(alpha: 0.12),
                    borderRadius: AppShape.inner,
                  ),
                  child:
                      Icon(Icons.radar_rounded, color: c.energy, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RANGE REACH RING',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: c.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${range.ecoKm} km Eco • ${range.powerKm} km Power',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.energy.withValues(alpha: 0.15),
                    borderRadius: AppShape.pill,
                  ),
                  child: Text(
                    '${range.ecoKm} km',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.energy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppShape.cardRadius)),
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(18),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'muthumar.iqubtvs.com',
                      ),
                      CircleLayer(
                        circles: [
                          // Outer Eco reach circle
                          CircleMarker(
                            point: LatLng(lat, lng),
                            radius: ecoMeters,
                            useRadiusInMeter: true,
                            color: c.energy.withValues(alpha: 0.12),
                            borderColor: c.energy,
                            borderStrokeWidth: 2,
                          ),
                          // Inner Power reach circle
                          CircleMarker(
                            point: LatLng(lat, lng),
                            radius: powerMeters,
                            useRadiusInMeter: true,
                            color: c.warning.withValues(alpha: 0.08),
                            borderColor: c.warning,
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lng),
                            width: 38,
                            height: 38,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.energy,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.energy.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.electric_moped_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Floating zoom and fit controls
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleOnTap(
                          onTap: () {
                            Haptics.select();
                            final z = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, z + 0.8);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.hairline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(Icons.add, size: 18, color: c.onSurface),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ScaleOnTap(
                          onTap: () {
                            Haptics.select();
                            final z = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, z - 0.8);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.hairline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(Icons.remove, size: 18, color: c.onSurface),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ScaleOnTap(
                          onTap: () {
                            Haptics.select();
                            _mapController.fitCamera(CameraFit.bounds(
                              bounds: bounds,
                              padding: const EdgeInsets.all(18),
                            ));
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.hairline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(Icons.crop_free_rounded,
                                size: 16, color: c.energy),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom legend overlay
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.88),
                        borderRadius: AppShape.pill,
                        border: Border.all(color: c.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.energy,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Eco ${range.ecoKm} km',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Power ${range.powerKm} km',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _OdometerMilestoneCard
// ---------------------------------------------------------------------------

class _OdometerMilestoneCard extends StatelessWidget {
  const _OdometerMilestoneCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);
    final v = VehicleService.instance;
    final settings = AppSettings.instance;

    final odo = v.odometerKm ?? 0.0;
    final interval = settings.serviceIntervalKm <= 0
        ? 2500.0
        : settings.serviceIntervalKm;
    final nextService = ((odo / interval).floor() + 1) * interval;
    final kmToGo = (nextService - odo).clamp(0.0, interval);
    final progress = (1.0 - (kmToGo / interval)).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.brand.withValues(alpha: 0.12),
                    borderRadius: AppShape.inner,
                  ),
                  child: Icon(Icons.build_circle_rounded,
                      color: c.brand, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SERVICE MILESTONE',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: c.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Next service at ${nextService.toInt()} km, ${kmToGo.round()} km to go',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'ODO ${odo.toStringAsFixed(0)} km',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: resolveMotion(context, motion.fill),
              curve: motion.emphasized,
              builder: (context, val, _) => ClipRRect(
                borderRadius: AppShape.pill,
                child: LinearProgressIndicator(
                  value: val,
                  minHeight: 8,
                  color: progress > 0.9 ? c.warning : c.brand,
                  backgroundColor: c.surfaceHigh,
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
// _AnimatedMetric
// ---------------------------------------------------------------------------

class _AnimatedMetric extends StatelessWidget {
  const _AnimatedMetric({
    required this.label,
    required this.value,
    this.decimals = 0,
    this.unit,
    this.color,
    this.muted,
    this.accent,
  });

  final String label;
  final double value;
  final int decimals;
  final String? unit;
  final Color? color;
  final Color? muted;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = color ?? c.onSurface;
    final dim = muted ?? c.onSurfaceMuted;
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
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedCount(
              value,
              decimals: decimals,
              style: AppText.metric.copyWith(color: fg),
            ),
            if (unit != null)
              Text(' $unit', style: AppText.unit.copyWith(color: dim)),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: AppShape.pill,
          border: Border.all(color: color),
        ),
        child: Text(text, style: AppText.overline.copyWith(color: color)),
      );
}

// ---------------------------------------------------------------------------
// _LinkCard
// ---------------------------------------------------------------------------

class _LinkCard extends StatelessWidget {
  const _LinkCard(
      {this.icon,
      this.leading,
      required this.title,
      required this.subtitle,
      this.onTap});

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ScaleOnTap(
      onTap: onTap,
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 6),
          leading: leading ??
              (icon != null
                  ? Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.brand.withValues(alpha: 0.12),
                        borderRadius: AppShape.inner,
                      ),
                      child: Icon(icon, color: c.brand, size: 22),
                    )
                  : null),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(subtitle),
          trailing: onTap == null
              ? null
              : Icon(Icons.chevron_right_rounded, color: c.onSurfaceMuted),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RideCard
// ---------------------------------------------------------------------------

class _RideCard extends StatelessWidget {
  const _RideCard();

  Future<void> _start(BuildContext context) async {
    Haptics.commit();
    final error = await RideTracker.instance.start();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _stop(BuildContext context) async {
    final ride = await RideTracker.instance.stop();
    if (!context.mounted) return;
    if (ride == null) {
      Haptics.commit();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride too short, not saved')));
    } else {
      Haptics.success();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RideDetailScreen(ride: ride)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RideTracker.instance;
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);

    final Widget body;
    if (!t.isRecording) {
      final last = RideStore.instance.rides.firstOrNull;
      body = Padding(
        key: const ValueKey('home_ride_card_idle'),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ride', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    last == null
                        ? 'Record distance, speed and battery used'
                        : 'Last: ${last.distanceKm.toStringAsFixed(1)} km  •  '
                            '${formatDate(last.start)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _start(context),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start ride'),
            ),
          ],
        ),
      );
    } else {
      body = Padding(
        key: const ValueKey('home_ride_card_riding'),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Dramatically pulsing recording indicator with glowing halo
                BreathingGlow(
                  color: c.danger,
                  size: 28,
                  intensity: 0.6,
                  child: PulseDot(color: c.danger, active: true),
                ),
                const SizedBox(width: 8),
                Text('Recording ride', style: theme.textTheme.titleMedium),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _stop(context),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('End ride'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Speed gauge
                Expanded(
                  child: SizedBox(
                    height: 130,
                    child: AnimatedGauge(
                      value: (t.speedKmh / 80).clamp(0.0, 1.0),
                      maxLabel: '80',
                      unit: 'km/h',
                      label: 'Speed',
                      color: c.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedMetric(
                        label: 'Distance',
                        value: t.distanceKm,
                        decimals: 2,
                        unit: 'km',
                      ),
                      const SizedBox(height: 12),
                      _AnimatedMetric(
                        label: 'Time',
                        value: t.elapsed.inMinutes.toDouble(),
                        unit: 'min',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Card(
      child: AnimatedSize(
        duration: resolveMotion(context, motion.medium),
        curve: motion.emphasized,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: resolveMotion(context, motion.medium),
          child: body,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TotalsCard
// ---------------------------------------------------------------------------

class _TotalsCard extends StatelessWidget {
  const _TotalsCard();

  @override
  Widget build(BuildContext context) {
    final store = RideStore.instance;
    return Card(
      child: Row(
        children: [
          Expanded(
              child: AnimatedStatTile(
                  icon: Icons.route_rounded,
                  label: 'Rides',
                  value: '${store.rides.length}')),
          Expanded(
              child: AnimatedStatTile(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: store.totalKm.toStringAsFixed(0),
                  unit: 'km')),
          Expanded(
              child: AnimatedStatTile(
                  icon: Icons.speed_rounded,
                  label: 'Top speed',
                  value: store.topSpeedKmh.toStringAsFixed(0),
                  unit: 'km/h')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ClusterCard
// ---------------------------------------------------------------------------

class _ClusterCard extends StatelessWidget {
  const _ClusterCard();

  @override
  Widget build(BuildContext context) {
    final on = AppSettings.instance.clusterNotifications &&
        ClusterNotifier.instance.accessGranted;
    final c = AppColors.of(context);
    final motion = AppMotion.of(context);

    return _LinkCard(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (on ? c.energy : c.brand).withValues(alpha: 0.12),
          borderRadius: AppShape.inner,
        ),
        child: AnimatedSwitcher(
          duration: resolveMotion(context, motion.medium),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            on
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined,
            key: ValueKey('home_cluster_notif_$on'),
            color: on ? c.energy : c.onSurfaceMuted,
            size: 22,
          ),
        ),
      ),
      title: 'Notifications on cluster',
      subtitle: on
          ? 'Calls and messages are sent to your scooter'
          : 'Off. Turn on in Settings',
    );
  }
}
