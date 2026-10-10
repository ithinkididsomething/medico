import 'package:flutter/material.dart';
import '../../navigation/app_navigation.dart';

/// Centralized utility for safe, crash-proof navigation across web and mobile.
/// Prevents popping past the root route and handles browser reloads gracefully.
class SafeNavigation {
  SafeNavigation._();

  /// Safely navigates back.
  /// If the current route can be popped, it pops normally.
  /// If at the root or if the browser was refreshed, it safely navigates
  /// to the MainNavigationScreen without ever crashing.
  static void pop(BuildContext context, {int fallbackTab = 0}) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => MainNavigationScreen(initialIndex: fallbackTab),
        ),
        (route) => false,
      );
    }
  }

  /// Safely returns to the Dashboard tab without popping into an empty stack.
  static void toDashboard(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainNavigationScreen(initialIndex: 0),
        ),
        (route) => false,
      );
    }
  }
}
