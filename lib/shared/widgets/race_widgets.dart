import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/racing_theme.dart';

/// Staggered entrance: fade + slide-up. Use in a list to animate children in.
class RaceEntrance extends StatefulWidget {
  const RaceEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = const Offset(0, 0.06),
    this.duration = const Duration(milliseconds: 420),
  });
  final Widget child;
  final Duration delay;
  final Offset from;
  final Duration duration;

  @override
  State<RaceEntrance> createState() => _RaceEntranceState();
}

class _RaceEntranceState extends State<RaceEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: widget.from, end: Offset.zero).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// A neon-bordered glass panel used everywhere in the cockpit.
class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.color = RaceColors.neonBlue,
    this.radius = 22,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });
  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final deco = RaceColors.panelDeco(
      border: color,
      radius: radius,
      fill: RaceColors.panel,
    );
    final body = Container(
      padding: padding,
      decoration: deco,
      child: child,
    );
    return onTap == null
        ? body
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: body,
            ),
          );
  }
}

/// Primary CTA styled like a glowing race-start button.
class RaceButton extends StatelessWidget {
  const RaceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.color = RaceColors.neonBlue,
    this.danger = false,
    this.busy = false,
    this.fullWidth = true,
    this.height = 60,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color color;
  final bool danger;
  final bool busy;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = danger ? RaceColors.danger : color;
    final child = Container(
      height: height,
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [effectiveColor, effectiveColor.withValues(alpha: .75)],
        ),
        boxShadow: [
          BoxShadow(color: effectiveColor.withValues(alpha: .5), blurRadius: 24),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: busy ? null : onPressed,
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.black, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    return child;
  }
}

/// Animated circular gauge (think speedometer / RPM dial).
class RaceGauge extends StatefulWidget {
  const RaceGauge({
    super.key,
    required this.value,
    required this.max,
    this.label = '',
    this.unit = '',
    this.centerLabel,
    this.color = RaceColors.neonBlue,
    this.size = 150,
  });
  final double value;
  final double max;
  final String label;
  final String unit;
  final String? centerLabel;
  final Color color;
  final double size;

  @override
  State<RaceGauge> createState() => _RaceGaugeState();
}

class _RaceGaugeState extends State<RaceGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant RaceGauge old) {
    super.didUpdateWidget(old);
    _from = old.value;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sweep = (widget.max <= 0 ? 0 : (widget.value / widget.max))
        .clamp(0.0, 1.0);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) {
          final t = _anim.value;
          final current = (_from + (widget.value - _from) * t).clamp(
            0.0,
            widget.max,
          );
          return CustomPaint(
            painter: _GaugePainter(
              progress: sweep * t,
              color: widget.color,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.centerLabel ?? current.toStringAsFixed(0),
                    style: RaceText.display.copyWith(
                      fontSize: widget.size * 0.30,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.unit.isNotEmpty)
                    Text(
                      widget.unit,
                      style: RaceText.label.copyWith(
                        color: widget.color,
                        fontSize: widget.size * 0.07,
                      ),
                    ),
                  if (widget.label.isNotEmpty)
                    Text(
                      widget.label,
                      style: RaceText.label.copyWith(
                        fontSize: widget.size * 0.065,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const start = -220.0;
    const sweepTotal = 260.0;
    final stroke = size.width * 0.085;
    final radius = size.width / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Track
    final track = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _rad(start),
      _rad(sweepTotal),
      false,
      track,
    );

    // Active arc with glow
    if (progress > 0) {
      final active = Paint()
        ..shader = SweepGradient(
          startAngle: _rad(start),
          endAngle: _rad(start + sweepTotal),
          colors: [
            color.withValues(alpha: .2),
            color,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _rad(start),
        _rad(sweepTotal * progress.clamp(0, 1)),
        false,
        active,
      );
    }

    // Tick marks
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i <= 10; i++) {
      final a = _rad(start + sweepTotal * i / 10);
      final inner = radius + stroke * 0.7;
      final outer = radius + stroke * 1.15;
      canvas.drawLine(
        center + Offset(cos(a), sin(a)) * inner,
        center + Offset(cos(a), sin(a)) * outer,
        tick,
      );
    }
  }

  double _rad(double deg) => deg * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}

/// Pulsing status dot (GPS locked, live, etc).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = RaceColors.lime, this.label, this.size = 10});
  final Color color;
  final String? label;
  final double size;
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _c,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [RaceColors.glow(widget.color, .8)],
              ),
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(width: 8),
            Text(
              widget.label!,
              style: RaceText.hud.copyWith(color: widget.color),
            ),
          ],
        ],
      );
}

/// Shimmering skeleton placeholder for loading states.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.height = 120,
    this.radius = 22,
    this.margin = EdgeInsets.zero,
  });
  final double height;
  final double radius;
  final EdgeInsetsGeometry margin;
  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final value = _c.value;
          return Container(
            height: widget.height,
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1 + value * 2, 0),
                end: Alignment(1 + value * 2, 0),
                colors: const [
                  Color(0xFF0C1118),
                  Color(0xFF1B2430),
                  Color(0xFF0C1118),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          );
        },
      );
}

/// Vertical sparkline / bar meter with neon fill.
class RaceBar extends StatelessWidget {
  const RaceBar({
    super.key,
    required this.value,
    required this.max,
    this.color = RaceColors.neonBlue,
    this.height = 90,
  });
  final double value;
  final double max;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ratio = (max <= 0 ? 0 : value / max).clamp(0.04, 1.0).toDouble();
    return Container(
      width: double.infinity,
      height: height,
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: ratio,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color.withValues(alpha: .4), color],
            ),
            boxShadow: [RaceColors.glow(color, .6)],
          ),
        ),
      ),
    );
  }
}

class RaceStatusPill extends StatelessWidget {
  const RaceStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.pulse = false,
    this.icon,
  });
  final String label;
  final Color color;
  final bool pulse;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: RaceColors.ink,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .6), width: 1.4),
          boxShadow: [RaceColors.glow(color, .45)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulse)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PulseDot(color: color, size: 9, label: null),
              )
            else if (icon != null) ...[
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class LiveSpeedo extends StatelessWidget {
  const LiveSpeedo({
    super.key,
    required this.speedKmh,
    this.max = 200,
    this.color = RaceColors.neonBlue,
    this.size = 150,
  });
  final double speedKmh;
  final double max;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => RaceGauge(
        value: speedKmh,
        max: max,
        unit: 'km/h',
        color: color,
        size: size,
        centerLabel: speedKmh.toStringAsFixed(0),
      );
}