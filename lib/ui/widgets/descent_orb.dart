import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';

/// A slow, burning sigil: concentric arcs, an ember core, and drifting sparks.
class DescentOrb extends StatefulWidget {
  final double size;

  const DescentOrb({super.key, this.size = 96});

  @override
  State<DescentOrb> createState() => _DescentOrbState();
}

class _DescentOrbState extends State<DescentOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.enabledOf(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0.12;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _OrbPainter(
            rotation: _controller.value,
            primary: scheme.primary,
            secondary: scheme.tertiary,
            core: scheme.onPrimaryContainer,
            pulse: 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double rotation;
  final Color primary;
  final Color secondary;
  final Color core;
  final double pulse;

  const _OrbPainter({
    required this.rotation,
    required this.primary,
    required this.secondary,
    required this.core,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.35 + pulse * 0.15),
          primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 1.1));
    canvas.drawCircle(center, maxRadius, glow);

    for (var ring = 0; ring < 5; ring++) {
      final radius = maxRadius * (0.34 + ring * 0.125);
      final start = rotation * math.pi * 2 * (ring.isEven ? 1 : -1);
      final sweep = math.pi * (0.75 + ring * 0.12);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring == 0 ? 2.4 : 1.2
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [
            primary.withValues(alpha: 0.05),
            primary.withValues(alpha: 0.9),
            secondary.withValues(alpha: 0.25),
            primary.withValues(alpha: 0.05),
          ],
          stops: const [0, 0.45, 0.75, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );

      final dotAngle = start + sweep;
      canvas.drawCircle(
        center + Offset(math.cos(dotAngle), math.sin(dotAngle)) * radius,
        ring == 0 ? 2.6 : 1.8,
        Paint()..color = primary.withValues(alpha: 0.8),
      );
    }

    final coreRadius = maxRadius * (0.2 + pulse * 0.025);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            core.withValues(alpha: 0.95),
            primary.withValues(alpha: 0.2),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
    );
    canvas.drawCircle(
      center,
      coreRadius * 0.45,
      Paint()..color = core.withValues(alpha: 0.9),
    );

    for (var spark = 0; spark < 7; spark++) {
      final angle = rotation * math.pi * 2 * 0.6 + spark * 0.9;
      final radius = maxRadius * (0.52 + 0.08 * math.sin(spark * 2.3));
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        1.2 + 0.8 * math.sin(rotation * math.pi * 2 + spark),
        Paint()..color = secondary.withValues(alpha: 0.65),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.pulse != pulse;
}
