import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_referral/app.dart';
import 'package:smart_referral/models/doctor_profile_data.dart';
import 'package:smart_referral/navigation/app_navigation.dart';
import 'package:smart_referral/screens/more_screen.dart';
import 'package:smart_referral/screens/profile/doctor_profile_screen.dart';
import 'package:smart_referral/screens/profile/edit_doctor_profile_dialog.dart';
import 'package:smart_referral/services/doctor_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DoctorProfileService.instance.resetToDefaults();
  });

  group('DoctorProfileScreen Widget Tests', () {
    testWidgets('Displays all required doctor profile placeholder fields', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Doctor Name and Credentials
      expect(find.text('Dr. Parth Saxena'), findsOneWidget);
      expect(find.text('Doctor Profile'), findsOneWidget);
      expect(find.textContaining('MBBS, MD'), findsWidgets);
      expect(find.textContaining('General Medicine & Emergency Triage'), findsWidgets);
      expect(find.textContaining('MP-MED-2018-09428'), findsWidgets);
      expect(find.textContaining('Primary Health Centre Sector 4'), findsWidgets);
      expect(find.text('dr.parth.saxena@gmail.com'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);

      // Check Badges & Offline session note
      expect(find.text('Offline Session Active'), findsOneWidget);
      expect(find.text('Edit Doctor Profile'), findsOneWidget);
    });

    testWidgets('Tapping Edit Profile button opens EditDoctorProfileDialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Edit Doctor Profile button
      await tester.tap(find.text('Edit Doctor Profile'));
      await tester.pumpAndSettle();

      // Verify Dialog opened
      expect(find.byType(EditDoctorProfileDialog), findsOneWidget);
      expect(find.text('Edit Doctor Profile'), findsWidgets);
      expect(find.text('Save Profile'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Form validation enforces required fields and valid email/phone format', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EditDoctorProfileDialog(
            currentProfile: DoctorProfileData.defaultProfile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear full name
      final nameField = find.widgetWithText(TextFormField, 'Doctor Full Name *');
      await tester.enterText(nameField, '');

      // Enter invalid email
      final emailField = find.widgetWithText(TextFormField, 'Official Email Address *');
      await tester.enterText(emailField, 'invalid-email');

      // Click Save Profile
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      // Verify validation errors are shown
      expect(find.text('Doctor full name is required.'), findsOneWidget);
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('Successful edit saves and updates DoctorProfileScreen immediately', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open edit dialog
      await tester.tap(find.text('Edit Doctor Profile'));
      await tester.pumpAndSettle();

      // Update name to Dr. Parth S. Saxena
      final nameField = find.widgetWithText(TextFormField, 'Doctor Full Name *');
      await tester.enterText(nameField, 'Dr. Parth S. Saxena');

      // Save changes
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      // Verify dialog is closed and screen displays updated name
      expect(find.byType(EditDoctorProfileDialog), findsNothing);
      expect(find.text('Dr. Parth S. Saxena'), findsOneWidget);
      expect(find.text('Doctor profile updated successfully'), findsOneWidget);
    });
  });

  group('Doctor Profile Navigation Tests', () {
    testWidgets('MainNavigationScreen top bar action button navigates to DoctorProfileScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find top bar doctor profile button
      final doctorProfileBtn = find.text('Doctor Profile');
      expect(doctorProfileBtn, findsOneWidget);

      await tester.tap(doctorProfileBtn);
      await tester.pumpAndSettle();

      // Verify DoctorProfileScreen is shown
      expect(find.byType(DoctorProfileScreen), findsOneWidget);
      expect(find.text('Medical Qualifications & Credentials'), findsOneWidget);
    });

    testWidgets('MoreScreen Clinician Account card contains View Doctor Profile button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View Doctor Profile'), findsOneWidget);
      expect(find.text('Edit Profile Information'), findsOneWidget);

      await tester.ensureVisible(find.text('View Doctor Profile'));
      await tester.tap(find.text('View Doctor Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorProfileScreen), findsOneWidget);
    });

    testWidgets('DashboardScreen Doctor Greeting card is tappable and opens DoctorProfileScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const SmartReferralApp(),
      );
      await tester.pumpAndSettle();

      // Tap Doctor greeting card / Profile pill
      expect(find.text('Profile'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorProfileScreen), findsOneWidget);
      expect(find.text('Dr. Parth Saxena'), findsOneWidget);
    });
  });
}
