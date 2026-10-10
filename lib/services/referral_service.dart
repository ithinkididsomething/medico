import '../models/enums.dart';
import '../models/patient.dart';
import '../models/referral.dart';
import '../models/referral_status_history.dart';
import '../repositories/hospital_repository.dart';
import '../repositories/patient_repository.dart';
import '../repositories/referral_repository.dart';
import 'assessment_service.dart';
import 'hospital_matching_service.dart';

/// Service abstraction for the complete clinical referral workflow.
abstract class ReferralService {
  Future<Referral> generateReferral({
    required Patient patient,
    required String referringClinic,
    required double clinicLatitude,
    required double clinicLongitude,
  });

  Future<Referral> updateReferralStatus({
    required String referralId,
    required ReferralStatus newStatus,
    required String note,
  });

  Future<List<Referral>> getReferrals({ReferralStatus? filterByStatus});

  Future<Referral?> getReferralById(String referralId);
}

/// Core implementation coordinating clinical assessment, hospital matching,
/// data persistence, and audit trail logging.
class DefaultReferralService implements ReferralService {
  final AssessmentService assessmentService;
  final HospitalMatchingService matchingService;
  final HospitalRepository hospitalRepository;
  final ReferralRepository referralRepository;
  final PatientRepository patientRepository;

  const DefaultReferralService({
    required this.assessmentService,
    required this.matchingService,
    required this.hospitalRepository,
    required this.referralRepository,
    required this.patientRepository,
  });

  @override
  Future<Referral> generateReferral({
    required Patient patient,
    required String referringClinic,
    required double clinicLatitude,
    required double clinicLongitude,
  }) async {
    // 1. Run clinical decision-support assessment
    final assessment = assessmentService.evaluate(patient);

    // 2. Fetch available hospitals and run matching algorithm
    final availableHospitals = await hospitalRepository.getAllHospitals();
    final matchResults = matchingService.matchHospitals(
      patient: patient,
      assessment: assessment,
      availableHospitals: availableHospitals,
      clinicLatitude: clinicLatitude,
      clinicLongitude: clinicLongitude,
    );

    final topMatch = matchResults.isNotEmpty ? matchResults.first : null;
    final alternatives = matchResults.length > 1
        ? matchResults.skip(1).take(3).map((m) => m.hospital).toList()
        : const <dynamic>[];

    final now = DateTime.now();
    final referralId = 'REF-${now.millisecondsSinceEpoch.toString().substring(5)}';

    final initialNote = assessment.isRedFlag
        ? 'Urgent triage alert: ${assessment.clinicalRationale.join(" ")}'
        : 'Routine clinical transfer recommendation generated.';

    final referral = Referral(
      referralId: referralId,
      patient: patient,
      urgencyLevel: assessment.urgencyLevel,
      referralReason: assessment.clinicalRationale.join(' '),
      requiredSpecialty: assessment.requiredSpecialty,
      requiredFacilities: assessment.requiredFacilities,
      recommendedHospital: topMatch?.hospital,
      alternativeHospitals: List.from(alternatives),
      estimatedDistance: topMatch?.distanceKm,
      estimatedTravelTime: topMatch?.travelTime,
      recommendationScore: topMatch?.matchScore,
      status: ReferralStatus.pending,
      statusHistory: [
        ReferralStatusHistory(
          status: ReferralStatus.pending,
          timestamp: now,
          note: initialNote,
        ),
      ],
      createdAt: now,
      updatedAt: now,
      referringClinic: referringClinic,
    );

    // 3. Persist patient and referral
    await patientRepository.savePatient(patient);
    await referralRepository.saveReferral(referral);

    return referral;
  }

  @override
  Future<Referral> updateReferralStatus({
    required String referralId,
    required ReferralStatus newStatus,
    required String note,
  }) async {
    final updated = await referralRepository.updateStatus(
      referralId,
      newStatus,
      note,
    );

    if (updated == null) {
      throw StateError('Referral with ID "$referralId" not found in repository.');
    }

    return updated;
  }

  @override
  Future<List<Referral>> getReferrals({ReferralStatus? filterByStatus}) async {
    if (filterByStatus != null) {
      return referralRepository.getReferralsByStatus(filterByStatus);
    }
    return referralRepository.getAllReferrals();
  }

  @override
  Future<Referral?> getReferralById(String referralId) async {
    return referralRepository.getReferralById(referralId);
  }
}
