import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ble/vehicle_service.dart';
import 'rides/ride.dart';
import 'rides/ride_tracker.dart';
import 'services/app_settings.dart';
import 'services/background.dart';
import 'services/battery_health.dart';
import 'services/charge_tracker.dart';
import 'services/cluster_info.dart';
import 'services/cluster_music.dart';
import 'services/cluster_notifier.dart';
import 'services/demo_mode.dart';
import 'services/permission_service.dart';
import 'services/ride_summary.dart';
import 'theme/haptics.dart';
import 'ui/charging_screen.dart';
import 'ui/common.dart';
import 'ui/connect_sheet.dart';
import 'ui/home_screen.dart';
import 'ui/rides_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await RideStore.instance.load();
  await ChargeTracker.instance.load();
  await BatteryHealth.instance.load();
  // Started here, not in the UI: the background service runs this engine
  // with no screen, and the scooter link must work without the app open.
  await VehicleService.instance.init();
  await ClusterNotifier.instance.init();
  ClusterInfo.instance.init();
  ClusterMusic.instance.init();
  RideSummary.instance.init();
  Background.init();
  runApp(const IQubeApp());
}

// ---------------------------------------------------------------------------
// App root — StatefulWidget with persistent themeMode and static IQubeApp.of(context)
// ---------------------------------------------------------------------------

class IQubeApp extends StatefulWidget {
  const IQubeApp({super.key, this.showSplash = true, this.home});

  final bool showSplash;
  final Widget? home;

  /// Returns the [IQubeAppState] so descendant screens (like Settings) can toggle theme.
  static IQubeAppState of(BuildContext context) =>
      context.findAncestorStateOfType<IQubeAppState>()!;

  @override
  State<IQubeApp> createState() => IQubeAppState();
}

class IQubeAppState extends State<IQubeApp> {
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = _parseThemeMode(AppSettings.instance.themeMode);
    AppSettings.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    final mode = _parseThemeMode(AppSettings.instance.themeMode);
    if (mode != _themeMode) {
      setState(() => _themeMode = mode);
    }
  }

  static ThemeMode _parseThemeMode(String raw) {
    switch (raw.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    AppSettings.instance.update(themeMode: _themeModeToString(mode));
  }

  void toggleTheme() {
    final next =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mtvs Connect',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOutCubic,
      home: widget.home ??
          (widget.showSplash ? const SplashScreen() : const AppShell()),
    );
  }
}

// ---------------------------------------------------------------------------
// App shell — Swipeable PageView with keep-alive, connection strip, and
// bottom nav with prominent centre Start/End ride button and status dots.
// ---------------------------------------------------------------------------

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final PageController _pageController;

  // Stagger entrance controller for bottom nav on launch.
  late final AnimationController _staggerCtrl;
  final List<Animation<double>> _staggerAnims = [];
  bool _staggerDone = false;

  // Live timer for ongoing ride in the centre button.
  Timer? _rideClock;

  static const _navItems = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home, 'Home'),
    _NavItem(Icons.route_outlined, Icons.route, 'Rides'),
    _NavItem(Icons.ev_station_outlined, Icons.ev_station, 'Charging'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  static const _tabs = <Widget>[
    HomeScreen(),
    RidesScreen(),
    ChargingScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _start();

    _pageController = PageController(initialPage: _tab);

    // Stagger animation across 4 tab icons + centre button.
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 630),
    );
    for (var i = 0; i < 5; i++) {
      final begin = (i * 70) / 630;
      final end = math.min(begin + 0.55, 1.0);
      _staggerAnims.add(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(begin, end, curve: Curves.easeOutBack),
        ),
      );
    }
    _staggerCtrl.forward().then((_) {
      if (mounted) setState(() => _staggerDone = true);
    });

    RideTracker.instance.addListener(_handleRideTrackerChange);
    _syncRideClock();
  }

  void _handleRideTrackerChange() {
    _syncRideClock();
    if (mounted) setState(() {});
  }

  void _syncRideClock() {
    if (RideTracker.instance.isRecording) {
      _rideClock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _rideClock?.cancel();
      _rideClock = null;
    }
  }

  Future<void> _start() async {
    await PermissionService.instance.requestStartupPermissions();
  }

  @override
  void dispose() {
    _rideClock?.cancel();
    RideTracker.instance.removeListener(_handleRideTrackerChange);
    _pageController.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _tab) return;
    Haptics.select();
    setState(() => _tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (index != _tab) {
      Haptics.select();
      setState(() => _tab = index);
    }
  }

  Future<void> _handleCentreAction() async {
    final tracker = RideTracker.instance;
    if (tracker.isRecording) {
      Haptics.commit();
      final ride = await tracker.stop();
      Haptics.success();
      if (ride != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ride saved: ${ride.distanceKm.toStringAsFixed(1)} km in ${formatDuration(ride.duration)}',
            ),
          ),
        );
      }
    } else {
      Haptics.commit();
      final err = await tracker.start();
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      } else {
        Haptics.success();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PageView with AutomaticKeepAlive tabs keeps scroll positions and map zooms intact
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const ClampingScrollPhysics(),
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _KeepAliveTab(
              key: PageStorageKey<String>('tab_$i'),
              active: i == _tab,
              child: _tabs[i],
            ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: Listenable.merge([
          VehicleService.instance,
          RideTracker.instance,
          ClusterNotifier.instance,
        ]),
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Slim connection strip across all tabs
              _ConnectionStrip(
                link: VehicleService.instance.link,
                deviceName: VehicleService.instance.deviceName,
                onTap: () {
                  Haptics.select();
                  final vs = VehicleService.instance;
                  if (vs.link == VehicleLink.connected) {
                    showConnectSheet(context);
                  } else {
                    vs.reconnectSaved();
                    if (vs.deviceId == null) {
                      showConnectSheet(context);
                    }
                  }
                },
              ),
              // 2. Bottom nav bar with centre ride button and animated indicators
              _AnimatedBottomNav(
                items: _navItems,
                selectedIndex: _tab,
                onTap: _onTabSelected,
                onCentreTap: _handleCentreAction,
                staggerAnimations: _staggerAnims,
                staggerDone: _staggerDone,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KeepAlive wrapper for PageView children
// ---------------------------------------------------------------------------

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({
    super.key,
    required this.child,
    required this.active,
  });

  final Widget child;
  final bool active;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(
      enabled: widget.active,
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Connection strip above bottom nav bar
// ---------------------------------------------------------------------------

class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({
    required this.link,
    required this.deviceName,
    required this.onTap,
  });

  final VehicleLink link;
  final String? deviceName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final Color dotColor;
    final String label;
    final bool isPulse;

    switch (link) {
      case VehicleLink.connected:
        dotColor = c.energy;
        label = 'Connected • ${deviceName ?? 'iQube EV'}';
        isPulse = false;
      case VehicleLink.connecting:
        dotColor = c.warning;
        label = 'Connecting to ${deviceName ?? 'iQube'}...';
        isPulse = true;
      case VehicleLink.disconnected:
        dotColor = c.onSurfaceMuted.withValues(alpha: 0.6);
        label = 'Scooter Offline • Tap to connect';
        isPulse = false;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: c.hairline.withValues(alpha: 0.4), width: 0.5),
            bottom: BorderSide(color: c.hairline.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavStatusDot(
              color: dotColor,
              pulse: isPulse,
              size: 6,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.onSurfaceMuted,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: c.onSurfaceMuted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav item metadata
// ---------------------------------------------------------------------------

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// ---------------------------------------------------------------------------
// Animated Bottom Navigation Bar
// - 5 slots: Home (0), Rides (1), Centre Action Button, Charging (2), Settings (3)
// - Horizontal sliding active indicator using AnimatedPositioned (320ms, easeOutCubic)
// - Status dots on Rides (recording), Charging (charging), Settings (missing permissions)
// - Prominent centre Start/End ride button
// ---------------------------------------------------------------------------

class _AnimatedBottomNav extends StatelessWidget {
  const _AnimatedBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.onCentreTap,
    required this.staggerAnimations,
    required this.staggerDone,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCentreTap;
  final List<Animation<double>> staggerAnimations;
  final bool staggerDone;

  int _slotForTab(int tabIndex) {
    if (tabIndex <= 1) return tabIndex;
    return tabIndex + 1; // Tab 2 -> slot 3, Tab 3 -> slot 4
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const navHeight = 72.0;
    const pillWidth = 56.0;
    const pillHeight = 32.0;

    final isRecording = RideTracker.instance.isRecording;
    final isCharging = BatteryNow.read().charging;
    final needsSettingsAttention = !ClusterNotifier.instance.accessGranted;

    return Container(
      height: navHeight,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.hairline, width: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / 5;
          final activeSlot = _slotForTab(selectedIndex);
          final pillLeft = activeSlot * slotWidth + (slotWidth - pillWidth) / 2;

          return Stack(
            children: [
              // 1. Sliding active indicator pill & glow
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: pillLeft,
                top: 10,
                width: pillWidth,
                height: pillHeight,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Subtle radial glow behind active icon
                    Positioned(
                      left: -8,
                      top: -8,
                      right: -8,
                      bottom: -8,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.brand.withValues(alpha: 0.15),
                              c.brand.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Active indicator pill
                    Container(
                      width: pillWidth,
                      height: pillHeight,
                      decoration: BoxDecoration(
                        borderRadius: AppShape.pill,
                        color: c.brand.withValues(alpha: 0.16),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Bottom nav row with 5 slots
              Row(
                children: [
                  // Slot 0: Home
                  Expanded(
                    child: _buildItem(
                      index: 0,
                      tabIndex: 0,
                      item: items[0],
                      statusDot: null,
                    ),
                  ),

                  // Slot 1: Rides (Red pulsing dot when recording)
                  Expanded(
                    child: _buildItem(
                      index: 1,
                      tabIndex: 1,
                      item: items[1],
                      statusDot: isRecording
                          ? _NavStatusDot(
                              color: c.danger,
                              pulse: true,
                            )
                          : null,
                    ),
                  ),

                  // Slot 2: Prominent Centre Start/End Ride Button
                  Expanded(
                    child: staggerDone
                        ? _CentreRideButton(
                            isRecording: isRecording,
                            onTap: onCentreTap,
                          )
                        : _StaggerEntrance(
                            animation: staggerAnimations[2],
                            child: _CentreRideButton(
                              isRecording: isRecording,
                              onTap: onCentreTap,
                            ),
                          ),
                  ),

                  // Slot 3: Charging (Green pulsing dot when charging)
                  Expanded(
                    child: _buildItem(
                      index: 3,
                      tabIndex: 2,
                      item: items[2],
                      statusDot: isCharging
                          ? _NavStatusDot(
                              color: c.energy,
                              pulse: true,
                            )
                          : null,
                    ),
                  ),

                  // Slot 4: Settings (Amber warning dot when notification access missing)
                  Expanded(
                    child: _buildItem(
                      index: 4,
                      tabIndex: 3,
                      item: items[3],
                      statusDot: needsSettingsAttention
                          ? _NavStatusDot(
                              color: c.warning,
                              pulse: false,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required int tabIndex,
    required _NavItem item,
    required Widget? statusDot,
  }) {
    final widget = _NavItemWidget(
      key: ValueKey('nav_item_${item.label}'),
      item: item,
      selected: tabIndex == selectedIndex,
      statusDot: statusDot,
      onTap: () => onTap(tabIndex),
    );

    if (staggerDone) return widget;
    return _StaggerEntrance(
      animation: staggerAnimations[index],
      child: widget,
    );
  }
}

// ---------------------------------------------------------------------------
// Individual navigation item with spring bounce on selection and status dot
// ---------------------------------------------------------------------------

class _NavItemWidget extends StatefulWidget {
  const _NavItemWidget({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.statusDot,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Widget? statusDot;

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // Spring bounce: 1.0 → 1.2 → 1.0
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void didUpdateWidget(covariant _NavItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _bounceCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final selected = widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 32,
              child: Center(
                child: AnimatedBuilder(
                  animation: _bounceCtrl,
                  builder: (context, child) {
                    final scale =
                        _bounceCtrl.isAnimating ? _scaleAnim.value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          selected ? widget.item.activeIcon : widget.item.icon,
                          key: ValueKey('nav_icon_${widget.item.label}_$selected'),
                          size: 24,
                          color: selected ? c.brand : c.onSurfaceMuted,
                        ),
                      ),
                      if (widget.statusDot != null)
                        Positioned(
                          right: -3,
                          top: -2,
                          child: widget.statusDot!,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? c.onSurface : c.onSurfaceMuted,
              ),
              child: Text(widget.item.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Centre Start/End Ride Button
// ---------------------------------------------------------------------------

class _CentreRideButton extends StatefulWidget {
  const _CentreRideButton({
    required this.isRecording,
    required this.onTap,
  });

  final bool isRecording;
  final VoidCallback onTap;

  @override
  State<_CentreRideButton> createState() => _CentreRideButtonState();
}

class _CentreRideButtonState extends State<_CentreRideButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isRecording) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _CentreRideButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final started = RideTracker.instance.startedAt;
    if (started == null) return '00:00';
    final d = DateTime.now().difference(started);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    final h = d.inHours;
    if (h > 0) {
      final remM = m.remainder(60);
      return '${h}h${remM.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isRecording = widget.isRecording;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, _) {
            final pulseVal = isRecording ? _pulseCtrl.value : 0.0;
            final bgCol = isRecording ? c.danger : c.brand;
            final glowCol = isRecording
                ? c.danger.withValues(alpha: 0.35 + 0.25 * pulseVal)
                : c.brand.withValues(alpha: 0.25);

            return Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: AppShape.pill,
                color: bgCol,
                boxShadow: [
                  BoxShadow(
                    color: glowCol,
                    blurRadius: isRecording ? 10 + 6 * pulseVal : 8,
                    spreadRadius: isRecording ? 1 + 2 * pulseVal : 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRecording ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: c.onBrand,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isRecording ? _formatElapsed() : 'Ride',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.onBrand,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status dot for nav icons (Rides, Charging, Settings, Connection strip)
// ---------------------------------------------------------------------------

class _NavStatusDot extends StatefulWidget {
  const _NavStatusDot({
    required this.color,
    this.pulse = false,
    this.size = 8,
  });

  final Color color;
  final bool pulse;
  final double size;

  @override
  State<_NavStatusDot> createState() => _NavStatusDotState();
}

class _NavStatusDotState extends State<_NavStatusDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _NavStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) {
      if (widget.pulse) {
        _ctrl ??= AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        );
        _ctrl!.repeat(reverse: true);
      } else {
        _ctrl?.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;
    if (!widget.pulse || _ctrl == null) {
      return Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 1.2,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, _) {
        final scale = 0.85 + 0.3 * _ctrl!.value;
        final opacity = 0.65 + 0.35 * _ctrl!.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: sz,
            height: sz,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5 * _ctrl!.value),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Stagger entrance on app launch (fade + scale up)
// ---------------------------------------------------------------------------

class _StaggerEntrance extends StatelessWidget {
  const _StaggerEntrance({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.scale(
            scale: 0.5 + 0.5 * progress,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
