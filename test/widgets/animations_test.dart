import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/core/animations/app_motion.dart';
import 'package:smart_referral/widgets/animations/animations.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('AppMotion tokens and utility tests', () {
    test('AppMotion defines appropriate clinical animation durations', () {
      expect(AppMotion.durationInstant.inMilliseconds, equals(100));
      expect(AppMotion.durationFast.inMilliseconds, equals(180));
      expect(AppMotion.durationMedium.inMilliseconds, equals(280));
      expect(AppMotion.durationSlow.inMilliseconds, equals(350));
      expect(AppMotion.durationSplash.inMilliseconds, equals(1800));
    });

    test('AppMotion detects automated test binding', () {
      expect(AppMotion.isTestEnvironment(), isTrue);
    });

    testWidgets('AppMotion detects reduced motion settings', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              expect(AppMotion.isReducedMotion(context), isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('EntranceFader Widget Tests', () {
    testWidgets('renders child content immediately in test environment', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const EntranceFader(
            child: Text('Clinical Telemetry Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinical Telemetry Content'), findsOneWidget);
    });

    testWidgets('respects reduced-motion setting without animating', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: wrapWidget(
            const EntranceFader(
              child: Text('Static Non-Motion Text'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Static Non-Motion Text'), findsOneWidget);
    });
  });

  group('PressableScale Widget Tests', () {
    testWidgets('executes onTap and renders child', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        wrapWidget(
          PressableScale(
            onTap: () => tapped = true,
            child: const Text('Tap Action Target'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tap Action Target'), findsOneWidget);

      await tester.tap(find.text('Tap Action Target'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('AnimatedCounter Widget Tests', () {
    testWidgets('renders integer value with prefix and suffix', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AnimatedCounter(
            value: 42,
            prefix: 'Active: ',
            suffix: ' cases',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active: 42 cases'), findsOneWidget);
    });

    testWidgets('renders decimal value with specified fraction digits', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AnimatedCounter(
            value: 99.4,
            fractionDigits: 1,
            suffix: '%',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99.4%'), findsOneWidget);
    });
  });

  group('PulsingBadge and PulsingDot Widget Tests', () {
    testWidgets('PulsingBadge renders wrapped child safely in test mode', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const PulsingBadge(
            child: Text('Emergency Status Pill'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Status Pill'), findsOneWidget);
    });

    testWidgets('PulsingDot renders cleanly without animation timer timeout', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const PulsingDot(
            color: Color(0xFF10B981),
            size: 8,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PulsingDot), findsOneWidget);
    });
  });

  group('ShimmerLoading and Skeleton Widget Tests', () {
    testWidgets('ShimmerLoading renders child skeleton components', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const ShimmerLoading(
            child: ShimmerBox(width: 120, height: 24),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(ShimmerBox), findsOneWidget);
    });

    testWidgets('HospitalCardSkeleton builds card skeleton hierarchy', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const HospitalCardSkeleton(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HospitalCardSkeleton), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('AnimatedCheckmark Widget Tests', () {
    testWidgets('renders AnimatedCheckmark and fires onComplete in test mode', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        wrapWidget(
          AnimatedCheckmark(
            onComplete: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedCheckmark), findsOneWidget);
      expect(completed, isTrue);
    });
  });
}
