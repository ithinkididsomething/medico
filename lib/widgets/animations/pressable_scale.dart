import 'package:flutter/material.dart';
import '../../core/animations/app_motion.dart';

/// Reusable tactile press-scale animation widget.
///
/// Shrinks slightly on touch press-down (to e.g. 0.97 scale) and smoothly
/// springs back to 1.0 on release, providing satisfying tactile feedback.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
    this.duration = AppMotion.durationFast,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null || AppMotion.isReducedMotion(context)) {
      return GestureDetector(
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: AppMotion.curveStandard,
        child: widget.child,
      ),
    );
  }
}
