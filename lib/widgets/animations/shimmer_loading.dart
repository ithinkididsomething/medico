import 'package:flutter/material.dart';
import '../../core/animations/app_motion.dart';

/// Native shimmer animation effect for data loading skeletons.
///
/// Sweeps a soft gradient light effect across skeleton placeholders.
/// Automatically handles reduced motion and automated tests without blocking.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (!AppMotion.isTestEnvironment()) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context) || AppMotion.isTestEnvironment()) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : widget.baseColor;
    final highlightColor = isDark ? const Color(0xFF334155) : widget.highlightColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
              transform: _SlidingGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Reusable rounded skeleton container with shimmer compatibility.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? color;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Pre-built skeleton placeholder for hospital cards during search or load.
class HospitalCardSkeleton extends StatelessWidget {
  const HospitalCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShimmerLoading(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 1,
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 180, height: 20),
                  ShimmerBox(width: 60, height: 24, borderRadius: 12),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  ShimmerBox(width: 90, height: 16),
                  SizedBox(width: 12),
                  ShimmerBox(width: 70, height: 16),
                  SizedBox(width: 12),
                  ShimmerBox(width: 80, height: 16),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  ShimmerBox(width: 75, height: 26, borderRadius: 13),
                  SizedBox(width: 8),
                  ShimmerBox(width: 85, height: 26, borderRadius: 13),
                  SizedBox(width: 8),
                  ShimmerBox(width: 95, height: 26, borderRadius: 13),
                ],
              ),
              SizedBox(height: 16),
              ShimmerBox(width: double.infinity, height: 42, borderRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}
