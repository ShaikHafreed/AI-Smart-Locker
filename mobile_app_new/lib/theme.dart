import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// AI Smart Cupboard — design system
/// A surveillance-console visual language: deep void backgrounds,
/// gradient "panels" with a hairline top-light, restrained neon
/// glows, and monospace telemetry readouts.
/// ─────────────────────────────────────────────────────────────

class AppColors {
  static const bg          = Color(0xFF0A0E1A); // base void
  static const surface     = Color(0xFF111827); // raised (nav, sheets)
  static const panelTop    = Color(0xFF1B2231); // card gradient — top
  static const panelBottom = Color(0xFF131A28); // card gradient — bottom
  static const line        = Color(0xFF2A3550); // hairline border
  static const lineLit     = Color(0xFF3B4A6B); // top-edge highlight

  static const cyan   = Color(0xFF00D4FF); // signal / primary
  static const mint   = Color(0xFF00FF88); // armed / verified
  static const coral  = Color(0xFFFF3B5C); // intrusion / danger
  static const amber  = Color(0xFFFFB800); // caution / pending
  static const violet = Color(0xFFB48EFF); // evidence

  static const textHi = Color(0xFFE8EDF5);
  static const textLo = Color(0xFF6B7A99);
}

/// Monospace family used for all telemetry (counts, timestamps, labels).
const String kMono = 'monospace';

/// Uppercase, letter-spaced "system label" with a leading tick — the
/// structural device that marks every section as a console readout.
class SystemLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Widget? trailing;
  const SystemLabel(this.text, {super.key, this.color = AppColors.textLo, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 2,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontFamily: kMono,
            fontSize: 11,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// The core surface: a vertical gradient panel with a hairline border,
/// a subtle top-light, and an optional colored glow to read as "powered".
class PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow,
    this.borderColor,
    this.radius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? AppColors.line;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.panelTop, AppColors.panelBottom],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          // ambient depth
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          // optional neon glow
          if (glow != null)
            BoxShadow(
              color: glow!.withOpacity(0.18),
              blurRadius: 26,
              spreadRadius: -6,
            ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// A tinted, softly-glowing rounded chip housing an icon — the standard
/// way accents are presented across the app.
class GlowChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double padding;
  const GlowChip(this.icon, this.color, {super.key, this.size = 20, this.padding = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 14, spreadRadius: -4),
        ],
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Sentinel Core — the signature element.
/// Concentric scanner rings + tick ring + a rotating scan arc, with a
/// breathing glow around a central shield. Colour communicates state:
/// mint = armed, coral = intruder pending, grey = offline.
/// Motion is disabled automatically when the OS requests reduced motion.
/// ─────────────────────────────────────────────────────────────
class SentinelCore extends StatefulWidget {
  final double size;
  final Color color;
  final bool armed; // false → dim, no sweep
  final IconData icon;
  const SentinelCore({
    super.key,
    this.size = 168,
    this.color = AppColors.mint,
    this.armed = true,
    this.icon = Icons.lock_rounded,
  });

  @override
  State<SentinelCore> createState() => _SentinelCoreState();
}

class _SentinelCoreState extends State<SentinelCore> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate = widget.armed && !reduceMotion;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = animate ? _c.value : 0.0;
          // Breathing 0.6 → 1.0 on a sine curve.
          final glow = animate ? 0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)) : 0.6;
          final disc = widget.size * 0.42;
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _CorePainter(color: widget.color, t: t, armed: widget.armed),
              ),
              Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(0.30),
                      widget.color.withOpacity(0.04),
                    ],
                  ),
                  border: Border.all(color: widget.color.withOpacity(0.55), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.28 * glow),
                      blurRadius: 34 * glow,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: widget.color, size: disc * 0.46),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CorePainter extends CustomPainter {
  final Color color;
  final double t;
  final bool armed;
  _CorePainter({required this.color, required this.t, required this.armed});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Faint concentric grid rings.
    for (int i = 0; i < 3; i++) {
      final rr = r * (0.48 + i * 0.20);
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withOpacity(0.10 - i * 0.025),
      );
    }

    // Tick ring — major ticks every 5.
    const ticks = 60;
    for (int i = 0; i < ticks; i++) {
      final a = (i / ticks) * 2 * math.pi;
      final major = i % 5 == 0;
      final r1 = r * 0.90;
      final r2 = r * (major ? 0.82 : 0.86);
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r1, c.dy + math.sin(a) * r1),
        Offset(c.dx + math.cos(a) * r2, c.dy + math.sin(a) * r2),
        Paint()
          ..strokeWidth = major ? 1.6 : 1.1
          ..strokeCap = StrokeCap.round
          ..color = color.withOpacity(major ? 0.30 : 0.14),
      );
    }

    // Rotating scan arc.
    if (armed) {
      final sweepR = r * 0.90;
      final rect = Rect.fromCircle(center: c, radius: sweepR);
      final start = t * 2 * math.pi;
      const sweep = math.pi * 0.55;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweep,
            colors: [color.withOpacity(0.0), color.withOpacity(0.55)],
          ).createShader(rect),
      );
    }

    // Bright inner progress ring.
    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(armed ? 0.55 : 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _CorePainter old) =>
      old.t != t || old.color != color || old.armed != armed;
}
