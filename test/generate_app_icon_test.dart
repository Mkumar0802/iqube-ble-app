import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate Mtvs Connect Scooty + EV Leaves App Icons', () async {
    final sizes = {
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    };

    for (final entry in sizes.entries) {
      final size = entry.value;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      );

      _drawMtvsConnectAppIcon(canvas, size.toDouble());

      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(byteData, isNotNull);

      final file = File(entry.key);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(byteData!.buffer.asUint8List());
      expect(file.existsSync(), isTrue);
    }
  });
}

void _drawMtvsConnectAppIcon(Canvas canvas, double size) {
  // Normalize canvas coordinate space to 512x512
  final s = size / 512.0;
  canvas.save();
  canvas.scale(s, s);

  const totalSize = 512.0;

  // 1. Deep EV Emerald & Obsidian Squircle Background
  final bgRect = const Rect.fromLTWH(0, 0, totalSize, totalSize);
  final bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(116));

  final bgPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F3D26), // Rich EV emerald green
        Color(0xFF072115), // Deep dark spruce
        Color(0xFF03100A), // Obsidian shadow
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(bgRect);
  canvas.drawRRect(bgRRect, bgPaint);

  // Outer ambient rim glow
  final rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF00E676),
        Color(0xFF00E5FF),
        Color(0x2200E676),
      ],
    ).createShader(bgRect);
  canvas.drawRRect(bgRRect, rimPaint);

  // Concentric subtle circular energy halo
  final haloPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.18);
  canvas.drawCircle(const Offset(256, 256), 212, haloPaint);

  // 2. EV Eco Leaves (Arching proudly over top of the Scooty)
  _drawEcoLeaves(canvas);

  // 3. 100% Authentic Electric Scooty
  _drawElectricScooty(canvas);

  canvas.restore();
}

void _drawEcoLeaves(Canvas canvas) {
  // Main Emerald Green Leaf
  final leaf1Paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF00E676), // Bright neon emerald
        Color(0xFF00B0FF), // Electric cyan tip blend
      ],
    ).createShader(const Rect.fromLTWH(180, 50, 180, 140));

  final leaf1Path = Path()
    ..moveTo(310, 175) // Stem base
    ..cubicTo(325, 125, 290, 65, 220, 68) // Top arch to tip
    ..cubicTo(185, 105, 195, 170, 310, 175) // Bottom arch back to base
    ..close();
  canvas.drawPath(leaf1Path, leaf1Paint);

  // Leaf 1 Center Vein
  final veinPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.8)
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(305, 170), const Offset(228, 76), veinPaint);

  // Secondary Fresh Mint Leaf
  final leaf2Paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0xFF69F0AE),
        Color(0xFF00E676),
      ],
    ).createShader(const Rect.fromLTWH(290, 80, 140, 110));

  final leaf2Path = Path()
    ..moveTo(315, 172)
    ..cubicTo(365, 150, 395, 110, 360, 85)
    ..cubicTo(315, 95, 305, 140, 315, 172)
    ..close();
  canvas.drawPath(leaf2Path, leaf2Paint);

  // Center Vein Leaf 2
  canvas.drawLine(const Offset(318, 168), const Offset(356, 92), veinPaint);

  // Glowing Electric Energy Bolt at leaf junction
  final boltPaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..style = PaintingStyle.fill;
  final boltPath = Path()
    ..moveTo(268, 126)
    ..lineTo(256, 144)
    ..lineTo(264, 144)
    ..lineTo(250, 166)
    ..lineTo(266, 148)
    ..lineTo(258, 148)
    ..close();
  canvas.drawPath(boltPath, boltPaint);
}

void _drawElectricScooty(Canvas canvas) {
  const cx = 256.0;
  const groundY = 398.0;

  // 1. Soft Contact Shadow beneath tires
  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.55)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(cx, groundY + 4),
      width: 290,
      height: 24,
    ),
    shadowPaint,
  );

  // 2. Wheels: Diamond-Cut 5-Spoke Alloy Rims & Tubeless Rubber Tires
  const wheelRadius = 40.0;
  final rearCenter = const Offset(cx - 110, groundY - 40);
  final frontCenter = const Offset(cx + 115, groundY - 40);

  _drawIconWheel(canvas, rearCenter, wheelRadius);
  _drawIconWheel(canvas, frontCenter, wheelRadius, hasDisc: true);

  // 3. Rear Swingarm / BLDC Motor Housing
  final motorPaint = Paint()..color = const Color(0xFF1E293B);
  final swingarmPath = Path()
    ..moveTo(cx - 55, groundY - 42)
    ..lineTo(cx - 110, groundY - 38)
    ..lineTo(cx - 110, groundY - 56)
    ..lineTo(cx - 50, groundY - 60)
    ..close();
  canvas.drawPath(swingarmPath, motorPaint);

  // 4. Rear Mudguard & Front Mudguard (Aerodynamic Fenders)
  final fenderPaint = Paint()..color = const Color(0xFF1E293B);
  final rearFenderPath = Path()
    ..moveTo(cx - 146, groundY - 35)
    ..quadraticBezierTo(cx - 150, groundY - 82, cx - 94, groundY - 82)
    ..lineTo(cx - 90, groundY - 74)
    ..quadraticBezierTo(cx - 140, groundY - 74, cx - 138, groundY - 35)
    ..close();
  canvas.drawPath(rearFenderPath, fenderPaint);

  final bodyPaint = Paint()..color = const Color(0xFFF8FAFC);
  final frontFenderPath = Path()
    ..moveTo(cx + 75, groundY - 38)
    ..quadraticBezierTo(cx + 90, groundY - 88, cx + 120, groundY - 84)
    ..quadraticBezierTo(cx + 152, groundY - 78, cx + 152, groundY - 46)
    ..lineTo(cx + 144, groundY - 46)
    ..quadraticBezierTo(cx + 142, groundY - 74, cx + 116, groundY - 76)
    ..quadraticBezierTo(cx + 90, groundY - 76, cx + 80, groundY - 38)
    ..close();
  canvas.drawPath(frontFenderPath, bodyPaint);

  // Front Telescopic Suspension Fork
  final forkPaint = Paint()
    ..color = const Color(0xFF94A3B8)
    ..strokeWidth = 6.0
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    const Offset(cx + 98, groundY - 110),
    const Offset(cx + 115, groundY - 40),
    forkPaint,
  );

  // 5. Flat Step-Through Floorboard & Battery Pack Base
  final floorboardPaint = Paint()..color = const Color(0xFF1E293B);
  final floorboardPath = Path()
    ..moveTo(cx - 56, groundY - 38)
    ..lineTo(cx + 54, groundY - 38)
    ..lineTo(cx + 50, groundY - 24)
    ..lineTo(cx - 52, groundY - 24)
    ..close();
  canvas.drawPath(floorboardPath, floorboardPaint);

  // Battery Pack Cyan Neon Accent Strip
  final cyanAccentPaint = Paint()..color = const Color(0xFF00E5FF);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(cx - 44, groundY - 28, 88, 6),
      const Radius.circular(3),
    ),
    cyanAccentPaint,
  );

  // 6. Scooty Front Apron (Signature Sweeping Shield)
  final apronPath = Path()
    ..moveTo(cx + 38, groundY - 38)
    ..cubicTo(cx + 60, groundY - 60, cx + 92, groundY - 105, cx + 108, groundY - 150)
    ..lineTo(cx + 86, groundY - 154)
    ..lineTo(cx + 70, groundY - 118)
    ..cubicTo(cx + 54, groundY - 86, cx + 34, groundY - 60, cx + 24, groundY - 38)
    ..close();
  canvas.drawPath(apronPath, bodyPaint);

  final darkTrimPaint = Paint()..color = const Color(0xFF0F172A);
  final frontNosePath = Path()
    ..moveTo(cx + 80, groundY - 100)
    ..lineTo(cx + 108, groundY - 150)
    ..lineTo(cx + 116, groundY - 150)
    ..lineTo(cx + 88, groundY - 100)
    ..close();
  canvas.drawPath(frontNosePath, darkTrimPaint);

  // TVS iQube Signature Horizontal LED DRL strip across front apron
  final drlPaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..strokeWidth = 5.5
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    const Offset(cx + 94, groundY - 136),
    const Offset(cx + 112, groundY - 136),
    drlPaint,
  );

  // 7. Handlebar Cowl, TFT Screen Visor & Rearview Mirror
  final cowlPath = Path()
    ..moveTo(cx + 66, groundY - 168)
    ..lineTo(cx + 102, groundY - 168)
    ..lineTo(cx + 94, groundY - 160)
    ..lineTo(cx + 62, groundY - 160)
    ..close();
  canvas.drawPath(cowlPath, bodyPaint);

  final visorPaint = Paint()..color = const Color(0xFF0F172A);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(cx + 68, groundY - 176, 22, 8),
      const Radius.circular(3),
    ),
    visorPaint,
  );

  // Rearview Mirror
  final mirrorPaint = Paint()
    ..color = const Color(0xFF475569)
    ..strokeWidth = 3.0;
  canvas.drawLine(
    const Offset(cx + 70, groundY - 168),
    const Offset(cx + 56, groundY - 190),
    mirrorPaint,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(cx + 52, groundY - 192),
      width: 18,
      height: 11,
    ),
    darkTrimPaint,
  );

  // Projector LED Headlamp Unit
  final headlampPaint = Paint()..color = Colors.white;
  canvas.drawCircle(const Offset(cx + 100, groundY - 164), 5.0, headlampPaint);

  // 8. Scooty Rear Sculpted Body Panels & Ruby Taillight
  final rearBodyPath = Path()
    ..moveTo(cx - 56, groundY - 38)
    ..cubicTo(cx - 60, groundY - 72, cx - 82, groundY - 90, cx - 124, groundY - 94)
    ..lineTo(cx - 158, groundY - 104) // Sharp aerodynamic tail
    ..lineTo(cx - 150, groundY - 82)
    ..cubicTo(cx - 130, groundY - 68, cx - 96, groundY - 50, cx - 60, groundY - 38)
    ..close();
  canvas.drawPath(rearBodyPath, bodyPaint);

  final accentCutPath = Path()
    ..moveTo(cx - 74, groundY - 60)
    ..lineTo(cx - 134, groundY - 86)
    ..lineTo(cx - 120, groundY - 78)
    ..lineTo(cx - 70, groundY - 54)
    ..close();
  canvas.drawPath(accentCutPath, darkTrimPaint);

  // TVS iQube Electric badge pill on rear flank
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(cx - 108, groundY - 82, 30, 8),
      const Radius.circular(3),
    ),
    cyanAccentPaint,
  );

  // LED Taillight strip (Ruby Red)
  final tailLightPaint = Paint()
    ..color = const Color(0xFFFF1744)
    ..strokeWidth = 5.0
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    const Offset(cx - 158, groundY - 104),
    const Offset(cx - 152, groundY - 94),
    tailLightPaint,
  );

  // Metallic rear grab rail / spoiler
  final grabRailPaint = Paint()
    ..color = const Color(0xFF94A3B8)
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    const Offset(cx - 140, groundY - 108),
    const Offset(cx - 162, groundY - 112),
    grabRailPaint,
  );

  // Ergonomic Stepped Saddle Seat (Charcoal dual-tone leather)
  final seatPaint = Paint()..color = const Color(0xFF0F172A);
  final seatPath = Path()
    ..moveTo(cx - 150, groundY - 105)
    ..lineTo(cx - 94, groundY - 104)
    ..lineTo(cx - 40, groundY - 94)
    ..lineTo(cx - 48, groundY - 86)
    ..lineTo(cx - 146, groundY - 96)
    ..close();
  canvas.drawPath(seatPath, seatPaint);
}

void _drawIconWheel(Canvas canvas, Offset center, double radius,
    {bool hasDisc = false}) {
  // 1. Black tire rubber
  final tirePaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 11.0;
  canvas.drawCircle(center, radius, tirePaint);

  // 2. Machined alloy rim ring
  final rimPaint = Paint()
    ..color = const Color(0xFF475569)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;
  canvas.drawCircle(center, radius - 8, rimPaint);

  // 3. Ventilated brake disc rotor & caliper
  if (hasDisc) {
    final discPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 15, discPaint);
    final caliperPaint = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx - 14, center.dy - 14),
          width: 11,
          height: 16,
        ),
        const Radius.circular(3),
      ),
      caliperPaint,
    );
  }

  // 4. Center hub & blue accent cap
  final hubPaint = Paint()..color = const Color(0xFF0F172A);
  canvas.drawCircle(center, 8.0, hubPaint);
  final capPaint = Paint()..color = const Color(0xFF00E5FF);
  canvas.drawCircle(center, 4.0, capPaint);

  // 5. 5-Spoke Diamond-cut Turbine Alloy Spokes
  final spokePaint = Paint()
    ..color = const Color(0xFFCBD5E1)
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round;

  for (var i = 0; i < 5; i++) {
    final spokeAngle = (i * 2 * math.pi / 5);
    final p1 = Offset(
      center.dx + math.cos(spokeAngle) * 8.0,
      center.dy + math.sin(spokeAngle) * 8.0,
    );
    final p2 = Offset(
      center.dx + math.cos(spokeAngle + 0.15) * (radius - 8.0),
      center.dy + math.sin(spokeAngle + 0.15) * (radius - 8.0),
    );
    canvas.drawLine(p1, p2, spokePaint);
  }
}
