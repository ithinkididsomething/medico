import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_referral/models/mock_data.dart';
import 'package:smart_referral/repositories/hospital_repository.dart';
import 'package:smart_referral/screens/hospital/hospital_details_screen.dart';
import 'package:smart_referral/screens/hospital/hospital_directory_screen.dart';
import 'package:smart_referral/screens/hospital/hospital_map_view.dart';
import 'package:smart_referral/services/location_service.dart';
import 'package:smart_referral/services/routing_service.dart';
import 'package:smart_referral/widgets/hospital_card.dart';

void main() {
  late HospitalRepository hospitalRepo;
  late LocationService locationService;
  late RoutingService routingService;

  setUp(() {
    hospitalRepo = MockHospitalRepository();
    locationService = DefaultLocationService();
    locationService.setManualClinicLocation(ClinicLocation.defaultSector4PHC);
    locationService.updatePermissionState(LocationPermissionState.granted);
    routingService = const SimulatedRoutingService();
  });

  group('LocationService & RoutingService Unit Tests', () {
    test('1. LocationService manages permission states and manual clinic presets', () {
      expect(locationService.permissionState, equals(LocationPermissionState.granted));
      expect(locationService.currentClinicLocation.name, equals('Primary Health Center Sector 4'));

      // Simulate permission denied
      locationService.updatePermissionState(LocationPermissionState.denied);
      expect(locationService.permissionState, equals(LocationPermissionState.denied));

      // Simulate location unavailable
      locationService.updatePermissionState(LocationPermissionState.unavailable);
      expect(locationService.permissionState, equals(LocationPermissionState.unavailable));

      // Set manual clinic preset
      locationService.setManualClinicLocation(ClinicLocation.subCenterBettadasanapura);
      expect(locationService.permissionState, equals(LocationPermissionState.manual));
      expect(locationService.currentClinicLocation.name, equals('Sub-Center Bettadasanapura'));
      expect(locationService.currentClinicLocation.latitude, equals(12.8350));
      expect(locationService.currentClinicLocation.longitude, equals(77.6200));
    });

    test('2. RoutingService calculates distance with clear simulated labeling and no fabricated traffic', () async {
      final origin = const LatLng(12.9716, 77.5946);
      final dest = const LatLng(12.9850, 77.5800);

      final route = await routingService.calculateRoute(
        origin: origin,
        destination: dest,
        isEmergency: false,
      );

      expect(route.distanceKm, greaterThan(0.0));
      expect(route.estimatedTravelTime.inMinutes, greaterThan(0));
      expect(route.isSimulated, isTrue);
      expect(route.sourceLabel, contains('Simulated Rural Transit Estimate'));
      expect(route.disclaimer, contains('Live traffic is NOT monitored'));
      expect(route.waypoints, isNotEmpty);
    });
  });

  group('HospitalRepository Filtering Unit Tests', () {
    test('3. Search and filter by specialty, emergency, and ICU', () async {
      final all = await hospitalRepo.getAllHospitals();
      expect(all.length, greaterThanOrEqualTo(8));

      // Filter by Obstetrics
      final obgyn = await hospitalRepo.searchHospitals(specialty: 'Obstetrics');
      expect(obgyn.every((h) => h.hasSpecialty('Obstetrics')), isTrue);

      // Filter by Emergency
      final emergency = await hospitalRepo.searchHospitals(emergencyCareOnly: true);
      expect(emergency.every((h) => h.emergencyCare), isTrue);

      // Filter by ICU
      final icu = await hospitalRepo.searchHospitals(icuAvailableOnly: true);
      expect(icu.every((h) => h.icuAvailable && (h.availability?.icuBedsAvailable ?? 0) > 0), isTrue);
    });
  });

  group('Hospital Directory & Map Widget Tests', () {
    Widget buildDirectoryScreen() {
      return MaterialApp(
        home: HospitalDirectoryScreen(
          repository: hospitalRepo,
          locationService: locationService,
        ),
      );
    }

    testWidgets('4. Renders searchable list with hospital cards and quick filters', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDirectoryScreen());
      await tester.pumpAndSettle();

      // Verify Header & Location bar
      expect(find.text('Hospital Directory'), findsOneWidget);
      expect(find.textContaining('Primary Health Center Sector 4'), findsOneWidget);

      // Verify Quick Filter chips
      expect(find.text('24/7 Emergency'), findsWidgets);
      expect(find.text('ICU Available'), findsWidgets);
      expect(find.text('Free Beds Only'), findsOneWidget);

      // Verify Hospital Cards are displayed
      expect(find.byType(HospitalCard), findsWidgets);
      await tester.scrollUntilVisible(
        find.text(MockClinicalData.hospitalDistrictGeneral.name),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(MockClinicalData.hospitalDistrictGeneral.name), findsOneWidget);
    });

    testWidgets('5. Can switch between List View and OpenStreetMap View', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDirectoryScreen());
      await tester.pumpAndSettle();

      // Tap OpenStreetMap segment
      await tester.tap(find.text('OpenStreetMap'));
      await tester.pumpAndSettle();

      // Verify Map View is rendered with simulated disclaimer
      expect(find.byType(HospitalMapView), findsOneWidget);
      expect(find.textContaining('Simulated Transit Estimates (Offline)'), findsOneWidget);
      expect(find.text('Clinic'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Alternatives'), findsOneWidget);

      // Switch back to List View
      await tester.tap(find.text('List View'));
      await tester.pumpAndSettle();
      expect(find.byType(HospitalCard), findsWidgets);
    });

    testWidgets('6. ClinicLocationDialog allows manual clinic entry and preset changes', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDirectoryScreen());
      await tester.pumpAndSettle();

      // Tap Change location button
      final changeBtn = find.text('Change');
      expect(changeBtn, findsOneWidget);
      await tester.tap(changeBtn);
      await tester.pumpAndSettle();

      // Verify ClinicLocationDialog is open
      expect(find.text('Clinic Location & GPS Settings'), findsOneWidget);
      expect(find.textContaining('Select Rural Clinic Preset:'), findsOneWidget);

      // Select preset Bettadasanapura
      final bettadasanapuraTile = find.text('Sub-Center Bettadasanapura');
      expect(bettadasanapuraTile, findsWidgets);
      await tester.tap(bettadasanapuraTile.first);
      await tester.pumpAndSettle();

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Location bar should now show Bettadasanapura
      expect(find.textContaining('Sub-Center Bettadasanapura'), findsWidgets);
    });

    testWidgets('7. HospitalDetailsScreen displays complete capabilities and explains facility limitations',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Test with Taluk Community Sub-District Hospital (No ICU, basic diagnostics)
      final hospitalWithLimits = MockClinicalData.hospitalTalukCommunity;

      await tester.pumpWidget(
        MaterialApp(
          home: HospitalDetailsScreen(
            hospital: hospitalWithLimits,
            clinicLocation: ClinicLocation.defaultSector4PHC,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Details Screen sections
      expect(find.text(hospitalWithLimits.name), findsWidgets);
      expect(find.text('Facility Capabilities & Operational Limits'), findsOneWidget);

      // Verify Transit logistics with simulated labeling
      expect(find.text('Transfer Logistics & Distance'), findsOneWidget);
      expect(find.textContaining('Rural Transit Estimate'), findsWidgets);

      // Verify Explicit Limitations Section
      expect(find.text('Facility Limitations & Constraints'), findsOneWidget);
      expect(find.textContaining('No Intensive Care Unit (ICU)'), findsOneWidget);

      // Verify Emergency & ICU Capabilities
      expect(find.text('Emergency & Critical Care'), findsOneWidget);
      expect(find.text('24/7 Emergency Care'), findsOneWidget);

      // Verify Bed Capacity
      expect(find.text('Bed Capacity & Occupancy'), findsOneWidget);

      // Verify Clinical Specialties
      expect(find.text('Clinical Specialties'), findsOneWidget);
    });
  });
}
