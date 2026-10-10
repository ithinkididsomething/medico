import 'package:flutter/material.dart';
import '../../core/animations/app_motion.dart';

/// Reusable staggered entrance animation widget that fades and slides its child into view.
///
/// Features:
/// - Configurable start delay for staggered lists and dashboards
/// - Smooth deceleration curve
/// - Automatically disables motion if reduced-motion is requested or in test mode
class EntranceFader extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const EntranceFader({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.durationMedium,
    this.offset = const Offset(0, 16),
    this.curve = AppMotion.curveStandard,
  });

  @override
  State<EntranceFader> createState() => _EntranceFaderState();
}

class _EntranceFaderState extends State<EntranceFader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _startAnimation();
  }

  void _startAnimation() {
    if (AppMotion.isTestEnvironment()) {
      _controller.value = 1.0;
      return;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (!_isDisposed && mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
