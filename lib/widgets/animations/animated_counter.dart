import 'package:flutter/material.dart';
import '../../core/animations/app_motion.dart';

/// Animated counter widget that smoothly increments numerical indicators.
///
/// Ideal for statistics cards, capacity counters, and triage metrics.
class AnimatedCounter extends StatelessWidget {
  final num value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 700),
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
    this.curve = AppMotion.curveStandard,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context) || AppMotion.isTestEnvironment()) {
      final formatted = fractionDigits == 0
          ? value.toInt().toString()
          : value.toStringAsFixed(fractionDigits);
      return Text('$prefix$formatted$suffix', style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, val, child) {
        final formatted = fractionDigits == 0
            ? val.toInt().toString()
            : val.toStringAsFixed(fractionDigits);
        return Text('$prefix$formatted$suffix', style: style);
      },
    );
  }
}
