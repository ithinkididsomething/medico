import 'package:flutter/material.dart';

/// Central animation and motion design system for MEDICO.
///
/// Provides consistent clinical-grade durations, easing curves,
/// custom PageRouteBuilders, and accessibility motion checks.
class AppMotion {
  AppMotion._();

  // ===========================================================================
  // 1. DURATION TOKENS
  // ===========================================================================

  /// Instant micro-interaction (taps, icon switches): 100ms
  static const Duration durationInstant = Duration(milliseconds: 100);

  /// Fast interaction (button press feedback, chip toggle): 180ms
  static const Duration durationFast = Duration(milliseconds: 180);

  /// Standard interaction (card expansion, tab crossfade): 280ms
  static const Duration durationMedium = Duration(milliseconds: 280);

  /// Deliberate transition (page navigation, bottom sheet entrance): 350ms
  static const Duration durationSlow = Duration(milliseconds: 350);

  /// Extended introductory animation (splash screen): 1800ms
  static const Duration durationSplash = Duration(milliseconds: 1800);

  // ===========================================================================
  // 2. EASING CURVES
  // ===========================================================================

  /// Default clinical easing: smooth entry with deceleration
  static const Curve curveStandard = Curves.easeOutCubic;

  /// Swift entry for high-urgency interactions
  static const Curve curveDecelerate = Curves.easeOutQuart;

  /// Symmetrical easing for modal and shared-element transitions
  static const Curve curveEmphasis = Curves.easeInOutCubic;

  /// Subtle tactile spring for small button touch releases
  static const Curve curveSpring = Curves.easeOutBack;

  // ===========================================================================
  // 3. ACCESSIBILITY HELPER
  // ===========================================================================

  /// Checks whether system reduced-motion is requested or animations are disabled.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Checks if running in an automated widget test environment.
  static bool isTestEnvironment() {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }
}

/// Custom clinical page route with a smooth fade and subtle horizontal slide.
class MedicoPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  MedicoPageRoute({
    required this.child,
    super.settings,
    Duration duration = AppMotion.durationMedium,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (AppMotion.isReducedMotion(context)) {
              return child;
            }

            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AppMotion.curveStandard,
              reverseCurve: AppMotion.curveStandard.flipped,
            );

            // Subtle slide from right (3% of screen width) combined with fade
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// Custom scale-and-fade route for splash transitions and modal focus.
class MedicoScaleFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  MedicoScaleFadeRoute({
    required this.child,
    super.settings,
    Duration duration = AppMotion.durationMedium,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (AppMotion.isReducedMotion(context)) {
              return child;
            }

            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AppMotion.curveEmphasis,
              reverseCurve: AppMotion.curveEmphasis.flipped,
            );

            return ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curvedAnimation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// PageTransitionsBuilder implementing smooth fade and subtle slide across all platforms.
class MedicoPageTransitionsBuilder extends PageTransitionsBuilder {
  const MedicoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.isReducedMotion(context)) {
      return child;
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curveStandard,
      reverseCurve: AppMotion.curveStandard.flipped,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.03, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
