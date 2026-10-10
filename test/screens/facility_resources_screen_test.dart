import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/navigation/app_navigation.dart';
import 'package:smart_referral/repositories/facility_resource_repository.dart';
import 'package:smart_referral/screens/resources/facility_resources_screen.dart';

void main() {
  setUp(() async {
    // Prime the repository cache so widget tests render immediately without network delays
    await FacilityResourceRepository.instance.getFacilityResources('indore_hospital_001');
  });

  group('Facility Resources & Infrastructure Management Widget Tests', () {
    testWidgets('Criteria 1 & 2: Navigation contains dedicated Facility Resources tab at Index 4', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationScreen(initialIndex: 4),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that navigation label and bar shows Facility Resources
      expect(find.text('Facility Resources'), findsWidgets);
      expect(find.byType(FacilityResourcesScreen), findsOneWidget);
    });

    testWidgets('Criteria 2 & 14: FacilityResourcesScreen renders all 6 management tabs and facility selector', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacilityResourcesScreen(initialFacilityId: 'indore_hospital_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Facility Selector Bar
      expect(find.text('Facility Infrastructure Management'), findsOneWidget);
      expect(find.text('Admin Authorized'), findsOneWidget);

      // Verify all 6 tabs are present in TabBar
      expect(find.text('Profile & Support'), findsOneWidget);
      expect(find.text('Equipment & Tech'), findsOneWidget);
      expect(find.text('Departments & Services'), findsOneWidget);
      expect(find.text('Staff & Personnel'), findsOneWidget);
      expect(find.text('Beds & Capacity'), findsOneWidget);
      expect(find.text('Verification & Audit'), findsOneWidget);
    });

    testWidgets('Section 7: Departments & Services tab displays clinical departments and filters', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacilityResourcesScreen(initialFacilityId: 'indore_hospital_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Departments & Services' tab
      await tester.tap(find.text('Departments & Services'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify header and action button
      expect(find.text('Clinical Departments & Services'), findsOneWidget);
      expect(find.text('Add Department'), findsOneWidget);
      expect(find.text('24/7 Emergency Active'), findsOneWidget);
      expect(find.text('Fully Operational Only'), findsOneWidget);

      // Verify clinical department cards rendered
      expect(find.textContaining('Emergency'), findsWidgets);
    });

    testWidgets('Section 4 & 6: Equipment & Tech tab shows search, category chips, and inventory items', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacilityResourcesScreen(initialFacilityId: 'indore_hospital_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Equipment & Tech' tab
      await tester.tap(find.text('Equipment & Tech'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Add Equipment'), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Section 8: Staff & Personnel tab renders staff roster and credentials', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacilityResourcesScreen(initialFacilityId: 'indore_hospital_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Staff & Personnel' tab
      await tester.tap(find.text('Staff & Personnel'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Clinical & Technical Personnel'), findsOneWidget);
      expect(find.text('Add Staff'), findsOneWidget);
    });

    testWidgets('Section 9: Beds & Capacity tab renders operational bed distribution and update action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacilityResourcesScreen(initialFacilityId: 'indore_hospital_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Beds & Capacity' tab
      await tester.tap(find.text('Beds & Capacity'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Operational Bed & Unit Capacity'), findsOneWidget);
      expect(find.text('Update Bed Census'), findsOneWidget);
    });

    testWidgets('Section 11: Verification & Audit tab renders audit trail', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacilityResourcesScreen(initialFacilityId: 'indore_hospital_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Verification & Audit' tab
      await tester.tap(find.text('Verification & Audit'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Audit & Quality Verification Trail'), findsOneWidget);
    });
  });
}
