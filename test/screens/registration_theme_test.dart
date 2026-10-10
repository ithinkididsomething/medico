import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/core/theme/app_theme.dart';
import 'package:smart_referral/screens/auth/login_screen.dart';

void main() {
  testWidgets('Test navigating to RegistrationScreen with AppTheme.lightTheme and switching to DoctorRegistrationScreen', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Create Account
    final createAccount = find.text('Create Account');
    expect(createAccount, findsOneWidget);
    await tester.ensureVisible(createAccount);
    await tester.pumpAndSettle();
    await tester.tap(createAccount);
    await tester.pumpAndSettle();

    expect(find.text('Account Registration'), findsOneWidget);

    // Tap Doctor Form button inside the Doctor Regulatory Onboarding banner
    final doctorFormButton = find.text('Doctor Form');
    expect(doctorFormButton, findsOneWidget);
    await tester.tap(doctorFormButton);
    await tester.pumpAndSettle();

    expect(find.text('Doctor Credential Registration'), findsOneWidget);
  });

  testWidgets('Test DoctorRegistrationScreen OTP dialog and return to Login with AppTheme.lightTheme', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final regDoctor = find.text('Register as a Doctor');
    expect(regDoctor, findsOneWidget);
    await tester.ensureVisible(regDoctor);
    await tester.pumpAndSettle();
    await tester.tap(regDoctor);
    await tester.pumpAndSettle();

    expect(find.text('Doctor Credential Registration'), findsOneWidget);

    // Verify OTP button can be tapped without layout constraints crash
    final verifyOtp = find.text('Verify OTP');
    expect(verifyOtp, findsOneWidget);
    await tester.tap(verifyOtp);
    await tester.pumpAndSettle();

    // Dialog is visible
    expect(find.text('Verify Mobile Number'), findsOneWidget);
    final cancelBtn = find.text('Cancel');
    expect(cancelBtn, findsOneWidget);
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Tap 'Already have an account? Log in'
    final returnToLogin = find.text('Already have an account? Log in');
    expect(returnToLogin, findsOneWidget);
    await tester.tap(returnToLogin);
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });
}
