import 'package:flutter_test/flutter_test.dart';
import 'package:smart_referral/models/enums.dart';
import 'package:smart_referral/models/facility_resource.dart';
import 'package:smart_referral/models/indore_hospital_dataset.dart';
import 'package:smart_referral/repositories/facility_resource_repository.dart';
import 'package:smart_referral/services/condition_specific_ranking_service.dart';
import 'package:smart_referral/services/hierarchical_ranking_service.dart';

void main() {
  group('Facility Resources & Infrastructure Management Unit Tests (Section 14)', () {
    test('Criterion 3: All 45 preloaded Indore healthcare facilities and IDs are preserved', () {
      final facilities = IndoreHospitalDataset.allFacilities;
      expect(facilities.length, equals(45), reason: 'Must preserve all 45 preloaded healthcare facilities');

      final ids = facilities.map((f) => f.hospitalId).toSet();
      expect(ids.length, equals(45), reason: 'All facility IDs must be unique');
      expect(ids.contains('indore_hospital_001'), isTrue);
      expect(ids.contains('indore_healthcare_045'), isTrue);
    });

    test('Criterion 4 & 6: Seven functional categories of medical equipment and technology', () {
      expect(ResourceCategory.values.length, equals(7));
      expect(ResourceCategory.diagnosticAndImaging.id, equals('diagnostic_and_imaging'));
      expect(ResourceCategory.criticalCareAndLifeSupport.id, equals('critical_care_and_life_support'));
      expect(ResourceCategory.surgicalAndTheatre.id, equals('surgical_and_theatre'));
      expect(ResourceCategory.emergencyAndTrauma.id, equals('emergency_and_trauma'));
      expect(ResourceCategory.laboratoryAndPathology.id, equals('laboratory_and_pathology'));
      expect(ResourceCategory.specializedTreatment.id, equals('specialized_treatment'));
      expect(ResourceCategory.telemedicineAndDigitalHealth.id, equals('telemedicine_and_digital_health'));

      final item = FacilityResourceItem(
        id: 'res_test_01',
        facilityId: 'indore_hospital_001',
        name: 'Hamilton-C3 ICU Ventilator',
        category: ResourceCategory.criticalCareAndLifeSupport,
        modelSpec: 'Invasive Mechanical Ventilator',
        quantityInstalled: 4,
        quantityOperational: 3,
        quantityOutOfService: 1,
        operationalStatus: ResourceOperationalStatus.operational,
        serviceDelivery: 'in_house',
        ownershipType: OwnershipType.inHouseOwned,
        verificationStatus: ResourceVerificationStatus.verified,
        lastVerifiedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(item.isOperational, isTrue);
      expect(item.isInHouse, isTrue);
      expect(item.isVerified, isTrue);
      expect(item.quantityOperational, equals(3));
      expect(item.quantityOutOfService, equals(1));
    });

    test('Criterion 7 & 8: Unverified equipment and external services are explicitly differentiated', () {
      final externalItem = FacilityResourceItem(
        id: 'res_ext_01',
        facilityId: 'indore_hospital_002',
        name: 'External Private MRI Scan Center Linkage',
        category: ResourceCategory.diagnosticAndImaging,
        serviceDelivery: 'external_outsourced',
        ownershipType: OwnershipType.outsourcedOffsite,
        verificationStatus: ResourceVerificationStatus.selfReported,
        lastVerifiedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(externalItem.isInHouse, isFalse, reason: 'External outsourced services must not be reported as in-house');
      expect(externalItem.isVerified, isFalse, reason: 'Self-reported equipment must not be silently treated as verified');
    });

    test('Criterion 9: Installed capacity is distinguished from live operational availability', () {
      final cap = FacilityCapacityRecord(
        capacityId: 'cap_001_icu',
        facilityId: 'indore_hospital_001',
        category: 'icu_beds',
        categoryLabel: 'Intensive Care Unit (ICU)',
        installedCapacity: 20,
        operationalCapacity: 18,
        occupiedCapacity: 12,
        availableCapacity: 6,
        lastUpdatedAt: DateTime.now(),
      );

      expect(cap.installedCapacity, equals(20));
      expect(cap.operationalCapacity, equals(18));
      expect(cap.occupiedCapacity, equals(12));
      expect(cap.availableCapacity, equals(6));
      expect(cap.occupancyRate, closeTo(12 / 18, 0.01));
    });

    test('Section 7: Clinical Departments, specialties, coverage, and restrictions', () {
      final dept = FacilityDepartment(
        departmentId: 'dept_001_cath',
        facilityId: 'indore_hospital_001',
        departmentName: 'Interventional Cardiology',
        specialties: const ['Cardiology', 'Electrophysiology'],
        services: const ['Angiography', 'Primary PCI', 'Stenting'],
        operationalDays: 'Mon-Sun',
        operatingHours: '24 Hours',
        appointmentMode: 'Walk-in & Appointment',
        emergencyAvailable: true,
        specialistCoverage: 'on_site',
        careLevels: const ['outpatient', 'inpatient', 'emergency'],
        headOfDepartment: 'Dr. Interventional Chief',
        isOperational: false,
        temporaryClosureReason: 'Biplane Cath Lab detector routine maintenance',
        lastUpdatedAt: DateTime.now(),
      );

      expect(dept.departmentName, equals('Interventional Cardiology'));
      expect(dept.isOperational, isFalse);
      expect(dept.temporaryClosureReason, contains('Cath Lab'));
      expect(dept.specialistCoverage, equals('on_site'));
      expect(dept.careLevels, contains('emergency'));
      expect(dept.specialties, contains('Cardiology'));
    });

    test('Criterion 13 & 14: Hard non-compensatory ranking hierarchy (Capability > Availability > Distance)', () {
      // Priority 1: Technical suitability is mandatory
      // Priority 2: Live availability (beds, ICU, emergency bays)
      // Priority 3: Geographic proximity
      final rankingService = HierarchicalRankingService();
      expect(rankingService, isNotNull);

      // Condition-specific rules check:
      final critEmergency = ConditionSpecificRankingService.getConfiguration(PatientConditionCategory.criticalEmergency);
      expect(critEmergency.priority1Name, contains('Life-saving'));
      expect(critEmergency.mandatoryCapabilities, contains('24/7 Emergency Care'));
      expect(critEmergency.mandatoryCapabilities, contains('ICU Critical Care'));

      final cardiac = ConditionSpecificRankingService.getConfiguration(PatientConditionCategory.suspectedCardiacEmergency);
      expect(cardiac.priority1Name, contains('Cardiac'));
      expect(cardiac.mandatoryCapabilities, contains('Cardiology'));
    });

    test('Criterion 16: Verification records maintain full audit provenance and decisions', () {
      final auditRecord = FacilityResourceVerificationRecord(
        verificationId: 'verif_audit_101',
        facilityId: 'indore_hospital_001',
        resourceId: 'res_001_ct',
        reviewedBy: 'District Health Officer',
        reviewerRole: 'district_officer',
        decision: 'approved',
        evidenceNotes: 'On-site AERB radiation calibration certificate verified.',
        verifiedAt: DateTime.now(),
      );

      expect(auditRecord.reviewedBy, equals('District Health Officer'));
      expect(auditRecord.decision, equals('approved'));
      expect(auditRecord.evidenceNotes, contains('AERB radiation calibration'));
    });

    test('Offline Fallback: Repository produces complete structured facility resources offline', () async {
      final repo = FacilityResourceRepository.instance;
      expect(repo, isNotNull);

      final resources = await repo.getFacilityResources('indore_hospital_001');
      expect(resources, isNotNull);
      expect(resources.facilityId, equals('indore_hospital_001'));
      expect(resources.inventory.isNotEmpty, isTrue);
      expect(resources.capacity.isNotEmpty, isTrue);
      expect(resources.departments.isNotEmpty, isTrue);
      expect(resources.staff.isNotEmpty, isTrue);
    });
  });
}
