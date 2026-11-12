import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import '../theme/haptics.dart';
import 'widgets/scale_on_tap.dart';

/// 5-second Eco-themed Splash Screen displaying:
/// - "SAVE TREES • RIDE ELECTRIC" eco message
/// - Custom vector animated EV scooter driven by a man on the road
/// - Parallax trees, floating green leaves, moving road dashes, and rotating wheels
/// - 5-second countdown progress bar with instant "Skip" action
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onComplete, this.durationSeconds = 5});

  final VoidCallback? onComplete;
  final int durationSeconds;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Timer _secondTimer;
  int _secondsRemaining = 5;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationSeconds;
    // Request location and Bluetooth permissions on application startup
    PermissionService.instance.requestStartupPermissions();

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    );

    _ctrl.forward();

    _secondTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });
  }

  void _finish() {
    if (_navigated) return;
    _navigated = true;
    _secondTimer.cancel();
    Haptics.select();

    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const AppShell(),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _secondTimer.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF04120B) : const Color(0xFFEAF5EE),
      body: SafeArea(
        child: Stack(
          children: [
            // Background ambient glow
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00E676).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Top Skip Button & Countdown badge
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: AppShape.pill,
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF00E676)),
                        const SizedBox(width: 5),
                        Text(
                          'ECO DRIVE • ${_secondsRemaining}s',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF00E676),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ScaleOnTap(
                    onTap: _finish,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.85),
                        borderRadius: AppShape.pill,
                        border: Border.all(color: c.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 11, color: c.onSurfaceMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header Hero Banner ("SAVE TREES • RIDE ELECTRIC")
            Positioned(
              top: 72,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Text(
                    '🌳 SAVE TREES',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ride 100% Electric',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: isDark ? Colors.white : const Color(0xFF0A291A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Every kilometer on your TVS iQube saves green trees, cuts emissions, and keeps our planet breathing.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark
                          ? Colors.white70
                          : const Color(0xFF2E5A44),
                    ),
                  ),
                ],
              ),
            ),

            // Central Canvas: Man Driving 100% Professional EV Scooty on Road with Parallax Trees
            Positioned(
              left: 0,
              right: 0,
              top: 190,
              bottom: 120,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ScooterDrivePainter(
                        progress: _ctrl.value,
                        isDark: isDark,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),

            // Bottom Eco Impact Counters and 5s Progress Bar
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                children: [
                  // Eco stats pill row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.9),
                      borderRadius: AppShape.inner,
                      border: Border.all(color: c.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const _EcoMetric(
                          icon: Icons.park_rounded,
                          label: 'Trees Saved',
                          value: '14+ 🌳',
                          color: Color(0xFF00E676),
                        ),
                        Container(width: 1, height: 28, color: c.hairline),
                        const _EcoMetric(
                          icon: Icons.cloud_off_rounded,
                          label: 'CO₂ Cut',
                          value: '180 kg',
                          color: Color(0xFF00E5FF),
                        ),
                        Container(width: 1, height: 28, color: c.hairline),
                        const _EcoMetric(
                          icon: Icons.bolt_rounded,
                          label: 'Clean Miles',
                          value: '100% EV',
                          color: Color(0xFFFFD600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Animated 5s linear progress bar
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius: AppShape.pill,
                        child: LinearProgressIndicator(
                          value: _ctrl.value,
                          minHeight: 6,
                          backgroundColor: c.hairline,
                          color: const Color(0xFF00E676),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'TVS iQube Electric Companion • Zero Tailpipe Emissions',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: c.onSurfaceMuted,
                      fontWeight: FontWeight.w500,
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

class _EcoMetric extends StatelessWidget {
  const _EcoMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: c.onSurfaceMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Canvas Painter: 100% Authentic Professional EV Scooty & Rider on Road
// ---------------------------------------------------------------------------

class _ScooterDrivePainter extends CustomPainter {
  _ScooterDrivePainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final roadTop = h * 0.63;
    final roadHeight = h * 0.30;
    final roadBottom = roadTop + roadHeight;

    // 1. Distant rolling green hills
    final hillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF0A2B1A), Color(0xFF06180E)]
            : const [Color(0xFFBBE5CA), Color(0xFFD4EEDC)],
      ).createShader(Rect.fromLTRB(0, roadTop - 90, w, roadTop));

    final hillPath = Path()
      ..moveTo(0, roadTop)
      ..quadraticBezierTo(w * 0.25, roadTop - 70, w * 0.5, roadTop - 35)
      ..quadraticBezierTo(w * 0.75, roadTop - 75, w, roadTop - 25)
      ..lineTo(w, roadTop)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    // 2. Parallax roadside trees (Save Tree theme)
    final treeOffsets = [0.08, 0.32, 0.58, 0.84, 1.12, 1.38];
    for (var i = 0; i < treeOffsets.length; i++) {
      const speed = 1.5;
      final x = ((treeOffsets[i] - progress * speed) % 1.3 - 0.15) * w;
      final treeY = roadTop - 6;
      _drawTree(canvas, x, treeY, scale: 0.85 + (i % 3) * 0.15);
    }

    // 3. Floating green leaves drifting in the wind
    final leafPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.7);
    for (var i = 0; i < 7; i++) {
      final lx = ((0.95 - progress * 2.0 + i * 0.18) % 1.2 - 0.1) * w;
      final ly = roadTop - 55 + math.sin(progress * 10 + i) * 32;
      canvas.save();
      canvas.translate(lx, ly);
      canvas.rotate(progress * 7 + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 4),
        leafPaint,
      );
      canvas.restore();
    }

    // 4. Asphalt Road
    final roadPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF1E242B), Color(0xFF12151B)]
            : const [Color(0xFF4A5568), Color(0xFF2D3748)],
      ).createShader(Rect.fromLTRB(0, roadTop, w, roadBottom));
    canvas.drawRect(Rect.fromLTRB(0, roadTop, w, roadBottom), roadPaint);

    // Road shoulder grass curb line
    final curbPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.8)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, roadTop), Offset(w, roadTop), curbPaint);

    // 5. Animated moving dashed center lines (speed illusion)
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const dashSpacing = 54.0;
    const dashLength = 28.0;
    final dashY = roadTop + roadHeight * 0.52;
    final shift = (progress * 4800) % dashSpacing;

    for (double dx = -shift; dx < w + dashSpacing; dx += dashSpacing) {
      if (dx + dashLength > 0 && dx < w) {
        canvas.drawLine(Offset(dx, dashY), Offset(dx + dashLength, dashY), dashPaint);
      }
    }

    // 6. Draw 100% Authentic Professional EV Scooty & Rider
    final scooterX = w * 0.44;
    // Micro suspension bobbing (1.4 px synced with speed)
    final bobY = math.sin(progress * 24 * math.pi) * 1.4;
    final groundY = roadTop + roadHeight * 0.38 + bobY;

    _drawProfessionalScooty(canvas, scooterX, groundY, progress);
  }

  void _drawTree(Canvas canvas, double x, double groundY, {double scale = 1.0}) {
    final trunkPaint = Paint()..color = const Color(0xFF5D4037);
    final trunkWidth = 6.0 * scale;
    final trunkHeight = 32.0 * scale;

    canvas.drawRect(
      Rect.fromLTWH(x - trunkWidth / 2, groundY - trunkHeight, trunkWidth, trunkHeight),
      trunkPaint,
    );

    final canopyPaint = Paint()
      ..color = isDark ? const Color(0xFF1B5E20) : const Color(0xFF2E7D32);
    final highlightPaint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.8);

    final cy = groundY - trunkHeight - 16 * scale;
    final cr = 24.0 * scale;

    canvas.drawCircle(Offset(x, cy), cr, canopyPaint);
    canvas.drawCircle(Offset(x - 10 * scale, cy + 4 * scale), cr * 0.75, canopyPaint);
    canvas.drawCircle(Offset(x + 10 * scale, cy + 4 * scale), cr * 0.75, canopyPaint);
    canvas.drawCircle(Offset(x - 4 * scale, cy - 6 * scale), cr * 0.5, highlightPaint);
  }

  void _drawProfessionalScooty(
      Canvas canvas, double cx, double groundY, double progress) {
    // -----------------------------------------------------------------------
    // Soft Ground Contact Shadow
    // -----------------------------------------------------------------------
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 2, groundY + 1),
        width: 140,
        height: 10,
      ),
      shadowPaint,
    );

    // -----------------------------------------------------------------------
    // Volumetric Projector Headlight Beam (Glowing on the Road)
    // -----------------------------------------------------------------------
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.42),
          const Color(0xFF00E5FF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(cx + 46, groundY - 78, cx + 180, groundY + 10));

    final beamPath = Path()
      ..moveTo(cx + 46, groundY - 72)
      ..lineTo(cx + 180, groundY - 50)
      ..lineTo(cx + 170, groundY + 8)
      ..lineTo(cx + 52, groundY - 60)
      ..close();
    canvas.drawPath(beamPath, beamPaint);

    // -----------------------------------------------------------------------
    // Rear Swingarm / BLDC Hub Motor Housing & Rear Shock
    // -----------------------------------------------------------------------
    final motorPaint = Paint()..color = const Color(0xFF1E293B);
    final swingarmPath = Path()
      ..moveTo(cx - 26, groundY - 18)
      ..lineTo(cx - 52, groundY - 16)
      ..lineTo(cx - 52, groundY - 24)
      ..lineTo(cx - 24, groundY - 26)
      ..close();
    canvas.drawPath(swingarmPath, motorPaint);

    final shockPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - 44, groundY - 18),
      Offset(cx - 34, groundY - 36),
      shockPaint,
    );

    // -----------------------------------------------------------------------
    // Wheels: 12-inch Diamond-cut 5-Spoke Alloy Wheels & Tubeless Tires
    // -----------------------------------------------------------------------
    const wheelRadius = 17.0;
    final rearWheelCenter = Offset(cx - 52, groundY - 17);
    final frontWheelCenter = Offset(cx + 56, groundY - 17);

    _drawProfessionalWheel(canvas, rearWheelCenter, wheelRadius, progress);
    _drawProfessionalWheel(canvas, frontWheelCenter, wheelRadius, progress, hasDisc: true);

    // -----------------------------------------------------------------------
    // Rear Mudguard & Front Mudguard (Aerodynamic Fenders)
    // -----------------------------------------------------------------------
    final fenderPaint = Paint()..color = const Color(0xFF1E293B);
    final rearFenderPath = Path()
      ..moveTo(scooterX(cx, -68), groundY - 15)
      ..quadraticBezierTo(scooterX(cx, -70), groundY - 35, scooterX(cx, -44), groundY - 35)
      ..lineTo(scooterX(cx, -42), groundY - 32)
      ..quadraticBezierTo(scooterX(cx, -66), groundY - 32, scooterX(cx, -65), groundY - 15)
      ..close();
    canvas.drawPath(rearFenderPath, fenderPaint);

    final bodyPaint = Paint()..color = const Color(0xFFF8FAFC);
    final frontFenderPath = Path()
      ..moveTo(cx + 38, groundY - 16)
      ..quadraticBezierTo(cx + 44, groundY - 38, cx + 58, groundY - 36)
      ..quadraticBezierTo(cx + 72, groundY - 34, cx + 72, groundY - 20)
      ..lineTo(cx + 69, groundY - 20)
      ..quadraticBezierTo(cx + 68, groundY - 32, cx + 56, groundY - 33)
      ..quadraticBezierTo(cx + 44, groundY - 33, cx + 40, groundY - 16)
      ..close();
    canvas.drawPath(frontFenderPath, bodyPaint);

    // Front Telescopic Fork (Silver Chrome Stanchion)
    final forkPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 48, groundY - 48),
      Offset(cx + 56, groundY - 17),
      forkPaint,
    );

    // -----------------------------------------------------------------------
    // Step-Through Floorboard & Battery Pack Base
    // -----------------------------------------------------------------------
    final floorboardPaint = Paint()..color = const Color(0xFF1E293B);
    final floorboardPath = Path()
      ..moveTo(cx - 26, groundY - 16)
      ..lineTo(cx + 26, groundY - 16)
      ..lineTo(cx + 24, groundY - 10)
      ..lineTo(cx - 24, groundY - 10)
      ..close();
    canvas.drawPath(floorboardPath, floorboardPaint);

    // Battery pack cyan neon accent strip
    final cyanAccentPaint = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 20, groundY - 12, 42, 3),
        const Radius.circular(1.5),
      ),
      cyanAccentPaint,
    );

    // -----------------------------------------------------------------------
    // Scooty Front Apron (The Signature Sweeping Shield)
    // -----------------------------------------------------------------------
    final apronPath = Path()
      ..moveTo(cx + 18, groundY - 16)
      ..cubicTo(cx + 28, groundY - 26, cx + 44, groundY - 46, cx + 52, groundY - 66)
      ..lineTo(cx + 42, groundY - 68)
      ..lineTo(cx + 34, groundY - 52)
      ..cubicTo(cx + 26, groundY - 38, cx + 16, groundY - 26, cx + 12, groundY - 16)
      ..close();
    canvas.drawPath(apronPath, bodyPaint);

    // Front nose cowl & apron front face
    final darkTrimPaint = Paint()..color = const Color(0xFF0F172A);
    final frontNosePath = Path()
      ..moveTo(cx + 38, groundY - 44)
      ..lineTo(cx + 52, groundY - 66)
      ..lineTo(cx + 56, groundY - 66)
      ..lineTo(cx + 42, groundY - 44)
      ..close();
    canvas.drawPath(frontNosePath, darkTrimPaint);

    // TVS iQube Signature Horizontal LED DRL strip across front apron
    final drlPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 46, groundY - 60),
      Offset(cx + 54, groundY - 60),
      drlPaint,
    );

    // -----------------------------------------------------------------------
    // Handlebar Cowl, TFT Cluster Visor & Rearview Mirror
    // -----------------------------------------------------------------------
    final cowlPath = Path()
      ..moveTo(cx + 32, groundY - 74)
      ..lineTo(cx + 48, groundY - 74)
      ..lineTo(cx + 44, groundY - 70)
      ..lineTo(cx + 30, groundY - 70)
      ..close();
    canvas.drawPath(cowlPath, bodyPaint);

    // Digital TFT Screen Visor
    final visorPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 33, groundY - 78, 10, 4),
        const Radius.circular(1.5),
      ),
      visorPaint,
    );

    // Rearview Mirror
    final mirrorPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(cx + 34, groundY - 74),
      Offset(cx + 28, groundY - 84),
      mirrorPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 26, groundY - 85),
        width: 8,
        height: 5,
      ),
      darkTrimPaint,
    );

    // Projector LED Headlamp Unit
    final headlampPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx + 47, groundY - 72), 2.5, headlampPaint);

    // -----------------------------------------------------------------------
    // Scooty Rear Sculpted Body Panels & Taillight
    // -----------------------------------------------------------------------
    final rearBodyPath = Path()
      ..moveTo(cx - 26, groundY - 16)
      ..cubicTo(cx - 28, groundY - 32, cx - 38, groundY - 40, cx - 58, groundY - 42)
      ..lineTo(cx - 74, groundY - 46) // Sharp tail
      ..lineTo(cx - 70, groundY - 36)
      ..cubicTo(cx - 60, groundY - 30, cx - 44, groundY - 22, cx - 28, groundY - 16)
      ..close();
    canvas.drawPath(rearBodyPath, bodyPaint);

    // Dark accent cut on side panel
    final accentCutPath = Path()
      ..moveTo(cx - 34, groundY - 26)
      ..lineTo(cx - 62, groundY - 38)
      ..lineTo(cx - 56, groundY - 35)
      ..lineTo(cx - 32, groundY - 24)
      ..close();
    canvas.drawPath(accentCutPath, darkTrimPaint);

    // TVS iQube Electric badge pill on rear flank
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 50, groundY - 36, 14, 3.5),
        const Radius.circular(1.5),
      ),
      cyanAccentPaint,
    );

    // LED Taillight strip (Ruby Red)
    final tailLightPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - 74, groundY - 46),
      Offset(cx - 71, groundY - 42),
      tailLightPaint,
    );

    // Metallic rear grab rail / spoiler
    final grabRailPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - 66, groundY - 48),
      Offset(cx - 76, groundY - 50),
      grabRailPaint,
    );

    // Ergonomic Stepped Saddle Seat (Charcoal dual-tone leather)
    final seatPaint = Paint()..color = const Color(0xFF0F172A);
    final seatPath = Path()
      ..moveTo(cx - 70, groundY - 47) // Pillion seat
      ..lineTo(cx - 44, groundY - 46) // Step down
      ..lineTo(cx - 18, groundY - 42) // Rider seat front
      ..lineTo(cx - 22, groundY - 38)
      ..lineTo(cx - 68, groundY - 43)
      ..close();
    canvas.drawPath(seatPath, seatPaint);

    // -----------------------------------------------------------------------
    // The Rider (Man Driving the Scooty in Comfortable Posture)
    // -----------------------------------------------------------------------
    const jacketColor = Color(0xFF0284C7); // Electric Cyan-Blue Commuter Jacket
    const jacketDark = Color(0xFF0369A1);  // Shadow / fold
    const pantsColor = Color(0xFF1E293B);  // Rider Denim
    const skinTone = Color(0xFFD4A373);    // Hands
    const shoeColor = Color(0xFF0F172A);   // Rider sneakers

    // 1. Rider Leg (Bent naturally, foot flat on floorboard)
    final legPaint = Paint()
      ..color = pantsColor
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final legPath = Path()
      ..moveTo(cx - 26, groundY - 44) // Hip on seat
      ..lineTo(cx - 6, groundY - 38)  // Thigh
      ..lineTo(cx + 4, groundY - 36)  // Knee bent comfortably forward
      ..lineTo(cx + 4, groundY - 18); // Lower leg down to floorboard
    canvas.drawPath(legPath, legPaint);

    // Rider Sneaker (resting flat on floorboard)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, groundY - 18, 14, 5.5),
        const Radius.circular(2.0),
      ),
      Paint()..color = shoeColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, groundY - 14, 14, 1.8),
        const Radius.circular(0.8),
      ),
      Paint()..color = Colors.white,
    );

    // 2. Rider Torso & Jacket (Upright commuting posture)
    final torsoPath = Path()
      ..moveTo(cx - 28, groundY - 44)
      ..lineTo(cx - 8, groundY - 70)  // Shoulder
      ..lineTo(cx - 2, groundY - 73)  // Collar
      ..lineTo(cx + 6, groundY - 70)  // Chest
      ..lineTo(cx - 12, groundY - 44) // Belly to hip
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = jacketColor);

    final jacketAccent = Path()
      ..moveTo(cx - 8, groundY - 70)
      ..lineTo(cx - 2, groundY - 73)
      ..lineTo(cx + 2, groundY - 60)
      ..lineTo(cx - 4, groundY - 58)
      ..close();
    canvas.drawPath(jacketAccent, Paint()..color = jacketDark);

    // 3. Arm & Hand gripping Handlebar
    final armPaint = Paint()
      ..color = jacketColor
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 2, groundY - 68),
      Offset(cx + 18, groundY - 60),
      armPaint,
    );
    canvas.drawLine(
      Offset(cx + 18, groundY - 60),
      Offset(cx + 32, groundY - 70),
      armPaint,
    );
    canvas.drawCircle(Offset(cx + 33, groundY - 70), 2.8, Paint()..color = skinTone);

    // 4. Full-Face Aerodynamic Helmet
    canvas.save();
    canvas.translate(cx - 2, groundY - 84);

    final helmetPath = Path()
      ..moveTo(-11, 2)
      ..cubicTo(-13, -12, 4, -14, 12, -4)
      ..cubicTo(13, 2, 8, 8, 3, 9)
      ..lineTo(-8, 9)
      ..close();
    canvas.drawPath(helmetPath, Paint()..color = const Color(0xFF0F172A));

    // Glossy helmet highlight arc
    final helmetHighlight = Path()
      ..moveTo(-7, -8)
      ..quadraticBezierTo(0, -12, 7, -5)
      ..quadraticBezierTo(0, -10, -7, -8);
    canvas.drawPath(
      helmetHighlight,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    // Aerodynamic Dark Visor (tinted glossy shield facing forward)
    final visorShieldPath = Path()
      ..moveTo(4, -5)
      ..lineTo(12, -3)
      ..lineTo(10, 4)
      ..lineTo(3, 3)
      ..close();
    canvas.drawPath(visorShieldPath, Paint()..color = const Color(0xFF00E5FF));

    final visorStreak = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(6, -2), const Offset(9, 2), visorStreak);

    canvas.restore();
  }

  void _drawProfessionalWheel(
      Canvas canvas, Offset center, double radius, double progress,
      {bool hasDisc = false}) {
    // 1. Black tire rubber
    final tirePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, radius, tirePaint);

    // Tread groove accents
    final treadPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.0;
    final angle = progress * 2 * math.pi * 14;
    for (var i = 0; i < 8; i++) {
      final a = angle + (i * math.pi / 4);
      final p1 = Offset(center.dx + math.cos(a) * (radius - 2),
          center.dy + math.sin(a) * (radius - 2));
      final p2 = Offset(center.dx + math.cos(a) * (radius + 2),
          center.dy + math.sin(a) * (radius + 2));
      canvas.drawLine(p1, p2, treadPaint);
    }

    // 2. Machined alloy rim ring
    final rimPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, radius - 3.5, rimPaint);

    // 3. Ventilated brake disc rotor & caliper
    if (hasDisc) {
      final discPaint = Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, radius - 6.5, discPaint);
      final caliperPaint = Paint()..color = const Color(0xFF00E5FF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx - 6, center.dy - 6),
            width: 5,
            height: 7,
          ),
          const Radius.circular(1.5),
        ),
        caliperPaint,
      );
    }

    // 4. Center hub & blue accent cap
    final hubPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(center, 3.5, hubPaint);
    final capPaint = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawCircle(center, 1.8, capPaint);

    // 5. 5-Spoke Diamond-cut Turbine Alloy Spokes
    final spokePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final spokeAngle = angle + (i * 2 * math.pi / 5);
      final p1 = Offset(
        center.dx + math.cos(spokeAngle) * 3.5,
        center.dy + math.sin(spokeAngle) * 3.5,
      );
      final p2 = Offset(
        center.dx + math.cos(spokeAngle + 0.15) * (radius - 3.5),
        center.dy + math.sin(spokeAngle + 0.15) * (radius - 3.5),
      );
      canvas.drawLine(p1, p2, spokePaint);
    }
  }

  double scooterX(double cx, double offset) => cx + offset;

  @override
  bool shouldRepaint(covariant _ScooterDrivePainter oldDelegate) => true;
}
