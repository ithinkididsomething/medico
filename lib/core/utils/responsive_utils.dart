import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Helper utility to distinguish phones, tablets, and orientation.
class ResponsiveUtils {
  ResponsiveUtils._();

  /// Returns true if screen width indicates a tablet or wide device.
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;
  }

  /// Returns true if screen width is phone form-factor.
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < AppConstants.tabletBreakpoint;
  }

  /// Responsive content max-width wrapper for larger tablet screens
  /// so clinical forms and cards don't become excessively stretched.
  static Widget constrainedContainer({
    required Widget child,
    double maxWidth = 800.0,
    AlignmentGeometry alignment = Alignment.topCenter,
  }) {
    if (maxWidth.isInfinite) {
      return child;
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
