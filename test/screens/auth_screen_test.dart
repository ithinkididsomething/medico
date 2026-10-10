import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/app.dart';
import 'package:smart_referral/models/user_profile.dart';
import 'package:smart_referral/screens/auth/forgot_password_screen.dart';
import 'package:smart_referral/screens/auth/login_screen.dart';
import 'package:smart_referral/screens/auth/registration_screen.dart';
import 'package:smart_referral/services/auth_service.dart';

void main() {
  late LocalDemoAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authService = LocalDemoAuthService();
  });

  group('Doctor Healthcare Authentication Tests', () {
    Widget buildLoginApp({VoidCallback? onLoginSuccess}) {
      return MaterialApp(
        home: LoginScreen(
          authService: authService,
          onLoginSuccess: onLoginSuccess,
        ),
      );
    }

    testWidgets('1. Login screen renders clinical branding, disclaimer and doctor login fields without demo mode text or clinic staff option',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // App name & tagline
      expect(find.text('MEDICO'), findsOneWidget);
      expect(find.text('"The right care. The right hospital. At the right time."'), findsOneWidget);
      expect(find.text('Secure access for healthcare professionals.'), findsOneWidget);

      // Verifies no demo mode banner
      expect(find.textContaining('DEMO MODE'), findsNothing);

      // Verifies no clinic staff option
      expect(find.text('Clinic Staff'), findsNothing);

      // Doctor input fields
      expect(find.text('Registered Medical Email or Mobile'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // Medical disclaimer at bottom
      expect(
        find.textContaining('MEDICO is a clinical decision-support tool'),
        findsOneWidget,
      );
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
    });

    testWidgets('2. Doctor login field accepts personal email and mobile number format',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // Personal email without hospital domain
      await tester.enterText(textFields.at(0), 'dr.sharma@gmail.com');
      expect(find.text('dr.sharma@gmail.com'), findsOneWidget);

      // 10-digit mobile number
      await tester.enterText(textFields.at(0), '9876543210');
      expect(find.text('9876543210'), findsOneWidget);
    });

    testWidgets('3. Empty form validation displays inline error messages',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // Tap Sign In button without entering credentials
      final signInButton = find.text('Sign In');
      expect(signInButton, findsOneWidget);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Validation errors shown inline
      expect(find.text('Please enter registered email or mobile number.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('4. Invalid email format and short password trigger specific validation errors',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // Identifier field
      await tester.enterText(textFields.at(0), 'invalid-email@');
      // Password field
      await tester.enterText(textFields.at(1), '123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid clinical email address.'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
    });

    testWidgets('5. Password obscure toggle toggles visibility',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // Find password visibility toggle icon button
      final toggleIcon = find.byTooltip('Show password');
      expect(toggleIcon, findsOneWidget);

      await tester.tap(toggleIcon);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('6. Quick Sign In logs in successfully and triggers success callback',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool loginSucceeded = false;
      await tester.pumpWidget(buildLoginApp(onLoginSuccess: () {
        loginSucceeded = true;
      }));
      await tester.pumpAndSettle();

      final quickButton = find.text('Quick Sign In (Dr. Parth Saxena)');
      expect(quickButton, findsOneWidget);

      await tester.tap(quickButton);
      await tester.pump(); // Start async login
      await tester.pump(const Duration(milliseconds: 600)); // Advance delayed timer
      await tester.pumpAndSettle();

      expect(loginSucceeded, isTrue);
      expect(authService.currentUser?.fullName, contains('Parth Saxena'));
      expect(authService.currentUser?.role, UserRole.doctor);
    });

    testWidgets('7. Navigation to Registration Screen allows Doctor credential submission without clinic staff option',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // Tap Create Account
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // On Registration Screen
      expect(find.text('Account Registration'), findsOneWidget);
      expect(find.text('Doctor Full Name'), findsOneWidget);
      expect(find.text('Medical Registration Number'), findsOneWidget);
      expect(find.textContaining('Doctor Credentialing Notice'), findsOneWidget);

      // Verifies no clinic staff option
      expect(find.text('Clinic Staff'), findsNothing);
    });

    testWidgets('8. Registration validates matching passwords and confirms pending verification status',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      // Fill in doctor details with personal email
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Dr. Anil Mehta');
      await tester.enterText(textFields.at(1), 'KMC-77889');
      await tester.enterText(textFields.at(2), 'Taluk General Hospital');
      await tester.enterText(textFields.at(3), 'dr.anil@gmail.com');
      await tester.enterText(textFields.at(4), '9845123456');
      await tester.enterText(textFields.at(5), 'pass1234');
      await tester.enterText(textFields.at(6), 'mismatchedPass');

      // Submit
      await tester.tap(find.text('Register Doctor Account'));
      await tester.pumpAndSettle();

      // Confirm password error shown
      expect(find.text('Passwords do not match.'), findsOneWidget);

      // Fix confirm password
      await tester.enterText(textFields.at(6), 'pass1234');
      await tester.tap(find.text('Register Doctor Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Explicit verification dialog without demo/prototype text
      expect(find.text('Registration Submitted'), findsOneWidget);
      expect(find.textContaining('Pending Credential Verification'), findsOneWidget);
      expect(find.text('Continue to Application'), findsOneWidget);
    });

    testWidgets('9. Forgot Password screen dispatches recovery request without demo text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Password Recovery'), findsOneWidget);

      // Enter personal doctor email
      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, 'dr.sharma@gmail.com');

      // Tap Send
      await tester.tap(find.text('Send Password Recovery Link'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Discloses notice without demo mode wording
      expect(find.text('Notice'), findsOneWidget);
      expect(find.textContaining('demo mode'), findsNothing);
    });

    testWidgets('10. App launches at LoginScreen when startAtLogin is true and handles tablet layout cleanly',
        (WidgetTester tester) async {
      // Simulate tablet screen width
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        SmartReferralApp(
          startAtLogin: true,
          authService: authService,
        ),
      );
      await tester.pumpAndSettle();

      // Tablet two-column layout renders branding and features
      expect(find.text('MEDICO'), findsOneWidget);
      expect(find.text('Clinician Decision-Support Gateway'), findsOneWidget);
      expect(find.text('Offline-First Local Health Post Synchronization'), findsOneWidget);
      expect(find.text('Quick Sign In (Dr. Parth Saxena)'), findsOneWidget);
      expect(find.textContaining('DEMO MODE'), findsNothing);
    });
  });
}
