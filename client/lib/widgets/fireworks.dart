import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A short volley of fireworks: shells launch from the bottom edge, climb,
/// and burst into falling sparks. Plays once and ignores touches.
class Fireworks extends StatefulWidget {
  /// Fixed seed for repeatable shells (tests); random otherwise.
  final int? seed;

  const Fireworks({super.key, this.seed});

  static const _shellCount = 7;
  static const _sparkLife = 1.5; // seconds a spark stays visible

  static const _colors = [
    NameDropTheme.gold,
    NameDropTheme.hotCoral,
    NameDropTheme.mintGreen,
    Color(0xFF64B5F6), // sky blue
    Color(0xFFFF80AB), // pink
    NameDropTheme.brightGold,
    NameDropTheme.cream,
  ];

  @override
  State<Fireworks> createState() => _FireworksState();
}

class _FireworksState extends State<Fireworks>
    with SingleTickerProviderStateMixin {
  late final List<_Shell> _shells = _Shell.volley(Random(widget.seed));
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_Shell.endOf(_shells) * 1000).ceil()),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _FireworksPainter(_shells, _controller),
        ),
      ),
    );
  }
}

class _Spark {
  final double angle;
  final double speed; // fraction of the screen's shorter side per second
  final bool white;

  const _Spark(this.angle, this.speed, this.white);
}

class _Shell {
  final double x; // launch position, fraction of width
  final double drift; // sideways travel while climbing, fraction of width
  final double burstY; // burst height, fraction of height from the top
  final double launchAt; // seconds
  final double rise; // seconds to reach burst height
  final Color color;
  final List<_Spark> sparks;

  const _Shell({
    required this.x,
    required this.drift,
    required this.burstY,
    required this.launchAt,
    required this.rise,
    required this.color,
    required this.sparks,
  });

  double get burstAt => launchAt + rise;

  static List<_Shell> volley(Random random) {
    final colors = [...Fireworks._colors]..shuffle(random);
    return [
      for (var i = 0; i < Fireworks._shellCount; i++)
        _Shell._random(i, colors[i % colors.length], random),
    ];
  }

  factory _Shell._random(int index, Color color, Random random) {
    double between(double lo, double hi) =>
        lo + random.nextDouble() * (hi - lo);
    final count = 50 + random.nextInt(16);
    final scale = between(0.75, 1.15); // some shells bigger than others
    return _Shell(
      // Alternate sides so bursts spread across the screen.
      x: index.isEven ? between(0.12, 0.5) : between(0.5, 0.88),
      drift: between(-0.06, 0.06),
      burstY: between(0.16, 0.42),
      launchAt: index * 0.32 + between(0, 0.12),
      rise: between(0.75, 1.0),
      color: color,
      sparks: [
        for (var k = 0; k < count; k++)
          _Spark(
            2 * pi * k / count + between(-0.08, 0.08),
            scale * between(0.6, 0.8),
            k % 6 == 0,
          ),
      ],
    );
  }

  /// When the last spark has faded, in seconds.
  static double endOf(List<_Shell> shells) =>
      shells.map((s) => s.burstAt).reduce(max) + Fireworks._sparkLife;
}

class _FireworksPainter extends CustomPainter {
  final List<_Shell> shells;
  final AnimationController controller;

  _FireworksPainter(this.shells, this.controller) : super(repaint: controller);

  static const _gravity = 0.25; // fraction of shorter side per second²
  static const _drag = 2.2;

  final _paint = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final t = controller.value *
        controller.duration!.inMicroseconds /
        Duration.microsecondsPerSecond;
    final unit = size.shortestSide;

    for (final shell in shells) {
      final sinceLaunch = t - shell.launchAt;
      if (sinceLaunch < 0) continue;
      if (sinceLaunch < shell.rise) {
        _paintRocket(canvas, size, shell, sinceLaunch);
      } else {
        _paintBurst(canvas, size, unit, shell, sinceLaunch - shell.rise);
      }
    }
  }

  Offset _rocketAt(Size size, _Shell shell, double progress) {
    final eased = 1 - pow(1 - progress, 2).toDouble(); // slows near the top
    final startY = size.height + 8;
    return Offset(
      (shell.x + shell.drift * progress) * size.width,
      startY - (startY - shell.burstY * size.height) * eased,
    );
  }

  void _paintRocket(Canvas canvas, Size size, _Shell shell, double since) {
    final progress = since / shell.rise;
    final color = Color.lerp(shell.color, Colors.white, 0.5)!;
    // A streak that fades out behind the head.
    for (var i = 6; i > 0; i--) {
      final from = progress - i * 0.02;
      if (from < 0) continue;
      _paint
        ..strokeWidth = 3.2 - i * 0.35
        ..color = color.withValues(alpha: 0.9 - i * 0.13);
      canvas.drawLine(_rocketAt(size, shell, from),
          _rocketAt(size, shell, from + 0.02), _paint);
    }
    _paint.color = Colors.white;
    canvas.drawCircle(_rocketAt(size, shell, progress), 2.4, _paint);
  }

  void _paintBurst(
      Canvas canvas, Size size, double unit, _Shell shell, double since) {
    if (since > Fireworks._sparkLife) return;
    final center = Offset(shell.x + shell.drift, shell.burstY)
        .scale(size.width, size.height);
    final life = since / Fireworks._sparkLife;

    // Brief flash at the moment of the burst.
    if (since < 0.18) {
      _paint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.5 * (1 - since / 0.18));
      canvas.drawCircle(center, 6 + 90 * since, _paint);
    }

    Offset sparkAt(_Spark spark, double s) {
      final distance = spark.speed * unit * (1 - exp(-_drag * s)) / _drag;
      final fall = 0.5 * _gravity * unit * s * s;
      return center +
          Offset(
              cos(spark.angle) * distance, sin(spark.angle) * distance + fall);
    }

    final fade = pow(1 - life, 1.6).toDouble();
    final width = 3.0 * (1 - 0.5 * life);
    for (var i = 0; i < shell.sparks.length; i++) {
      final spark = shell.sparks[i];
      final twinkle = life > 0.5 ? 0.7 + 0.3 * sin(since * 40 + i) : 1.0;
      final alpha = (fade * twinkle).clamp(0.0, 1.0);
      final color = spark.white ? NameDropTheme.cream : shell.color;
      // A short streak from where the spark just was, over a soft glow.
      final from = sparkAt(spark, max(0, since - 0.07));
      final to = sparkAt(spark, since);
      _paint
        ..strokeWidth = width * 3
        ..color = color.withValues(alpha: alpha * 0.25);
      canvas.drawLine(from, to, _paint);
      _paint
        ..strokeWidth = width
        ..color = color.withValues(alpha: alpha);
      canvas.drawLine(from, to, _paint);
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter oldDelegate) =>
      oldDelegate.shells != shells;
}
