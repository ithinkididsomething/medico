import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/screens/splash/splash_screen.dart';

void main() {
  group('SplashScreen Animation & Layout Tests', () {
    testWidgets('renders MEDICO brand, medical emblem, tagline and telemetry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(nextRoute: '/login'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MEDICO'), findsOneWidget);
      expect(find.text('Clinical Referral Decision-Support System'), findsOneWidget);
      expect(find.text('Indore Metropolitan Grid • v2.4 Active'), findsOneWidget);
      expect(find.byIcon(Icons.local_hospital_rounded), findsOneWidget);
    });

    testWidgets('tapping splash screen triggers fast-forward navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/login': (ctx) => const Scaffold(body: Text('Login Destination Screen')),
          },
          home: const SplashScreen(
            nextRoute: '/login',
            targetScreen: Scaffold(body: Text('Login Destination Screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SplashScreen));
      await tester.pumpAndSettle();

      expect(find.text('Login Destination Screen'), findsOneWidget);
    });
  });
}
