import 'package:flutter/material.dart';
import '../../core/animations/app_motion.dart';

/// Animated checkmark widget featuring an expanding circle and progressive stroke drawing.
///
/// Ideal for referral submission confirmation, success sheets, and clinical milestone completion.
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Color circleColor;
  final double strokeWidth;
  final Duration duration;
  final VoidCallback? onComplete;

  const AnimatedCheckmark({
    super.key,
    this.size = 72.0,
    this.color = Colors.white,
    this.circleColor = const Color(0xFF10B981),
    this.strokeWidth = 3.5,
    this.duration = const Duration(milliseconds: 900),
    this.onComplete,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleScaleAnimation;
  late final Animation<double> _checkProgressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _circleScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _checkProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    if (AppMotion.isTestEnvironment()) {
      _controller.value = 1.0;
      widget.onComplete?.call();
    } else {
      _controller.forward().then((_) {
        if (mounted) widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.circleColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          color: widget.color,
          size: widget.size * 0.6,
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CheckmarkPainter(
              circleScale: _circleScaleAnimation.value,
              checkProgress: _checkProgressAnimation.value,
              circleColor: widget.circleColor,
              strokeColor: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double circleScale;
  final double checkProgress;
  final Color circleColor;
  final Color strokeColor;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.circleScale,
    required this.checkProgress,
    required this.circleColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * circleScale;

    // 1. Draw circle background
    if (circleScale > 0) {
      final circlePaint = Paint()
        ..color = circleColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, circlePaint);
    }

    // 2. Draw animated checkmark stroke
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final p1 = Offset(size.width * 0.28, size.height * 0.52);
      final p2 = Offset(size.width * 0.44, size.height * 0.68);
      final p3 = Offset(size.width * 0.72, size.height * 0.36);

      final fullPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);

      for (final metric in fullPath.computeMetrics()) {
        final length = metric.length * checkProgress;
        final animatedPath = metric.extractPath(0.0, length);
        canvas.drawPath(animatedPath, checkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.circleScale != circleScale ||
        oldDelegate.checkProgress != checkProgress;
  }
}
