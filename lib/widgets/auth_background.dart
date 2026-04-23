/// CRED / JioHotstar-style animated mesh-gradient background.
/// Large vivid orbs with dramatic movement — clearly visible on mobile.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _MeshPainter(_ctrl.value),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.t);
  final double t; // 0..1 looping

  // Each orb: [relX, relY, radius_factor, driftX, driftY, speed, phase]
  static const _orbs = [
    // Top-left — big vivid orange
    [0.05, 0.08, 0.90, 0.18, 0.14, 0.80, 0.00],
    // Top-right — amber
    [0.90, 0.05, 0.75, -0.16, 0.18, 0.65, 0.22],
    // Centre — deep red-orange (biggest, anchors the scene)
    [0.50, 0.38, 1.10, 0.10, 0.10, 0.45, 0.55],
    // Bottom-left — warm amber
    [0.08, 0.80, 0.80, 0.14, -0.12, 0.70, 0.38],
    // Bottom-right — bright orange accent
    [0.92, 0.88, 0.70, -0.12, -0.10, 0.90, 0.72],
    // Mid-left — subtle deep orb for depth
    [0.20, 0.55, 0.60, 0.08, 0.15, 0.55, 0.85],
  ];

  static const _colors = [
    // center color, mid color
    [Color(0xFFFF6B1A), Color(0xFFE8380A)],
    [Color(0xFFFF8C00), Color(0xFFE05500)],
    [Color(0xFFCC3300), Color(0xFF8B1A00)],
    [Color(0xFFFF7722), Color(0xFFCC4400)],
    [Color(0xFFFFAA00), Color(0xFFE06600)],
    [Color(0xFF992200), Color(0xFF550A00)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Rich near-black base
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080407),
    );

    final w = size.width;
    final h = size.height;
    final minDim = math.min(w, h);

    for (int i = 0; i < _orbs.length; i++) {
      final o = _orbs[i];
      final c = _colors[i];

      final phase = (t * o[5] + o[6]) % 1.0;
      final angle = phase * math.pi * 2;

      // Position with drift
      final cx = (o[0] + math.sin(angle * 0.73) * o[2] * o[3]) * w;
      final cy = (o[1] + math.cos(angle * 0.61) * o[2] * o[4]) * h;

      // Breathe the radius
      final breathe = 1.0 + 0.12 * math.sin(angle * 1.7 + i);
      final radius = o[2] * minDim * breathe;

      // Inner bright core — very opaque
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              c[0].withValues(alpha: 0.82),
              c[1].withValues(alpha: 0.55),
              c[1].withValues(alpha: 0.20),
              Colors.transparent,
            ],
            stops: const [0.0, 0.30, 0.60, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: radius),
          ),
      );
    }

    // Soft dark vignette at edges — keeps card legible
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
          stops: const [0.40, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Very subtle dark centre overlay so card is always readable
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.55,
          colors: [
            Colors.black.withValues(alpha: 0.30),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.t != t;
}
