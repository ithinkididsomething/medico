import 'enums.dart';
import 'hospital.dart';
import 'indore_hospital_dataset.dart';
import 'patient.dart';
import 'referral.dart';
import 'referral_status_history.dart';

/// Realistic synthetic dataset for prototyping and verifying clinical decision-support logic.
///
/// ============================================================================
/// NOTICE: ALL DATA IN THIS FILE IS STRICTLY SYNTHETIC AND SIMULATED.
/// DO NOT USE AS REAL PATIENT RECORDS OR REAL-TIME HOSPITAL AVAILABILITY.
/// ============================================================================
class MockClinicalData {
  MockClinicalData._();

  static const String datasetDisclaimer =
      'SYNTHETIC / SIMULATED CLINICAL DATASET — INDORE REGIONAL HEALTH NETWORK';

  // --- Synthetic Hospitals (Indore Regional Healthcare Dataset) ---

  static final Hospital hospitalDistrictGeneral = IndoreHospitalDataset.facility02.copyWith(
    hospitalId: 'indore_hospital_002',
    name: 'Bhandari Hospital and Research Centre (Civil Referral Wing)',
    specialties: const [
      'Cardiology',
      'Neurology',
      'Gastroenterology',
      'Orthopaedics',
      'Urology',
      'Pulmonology',
      'ENT',
      'Ophthalmology',
      'Dermatology',
      'Dental',
      'Obstetrics & Gynecology',
      'Paediatrics',
      'General Surgery',
    ],
    diagnosticFacilities: const [
      'Full Pathology Lab',
      '24/7 Blood Bank',
      '16-Slice CT Scanner',
      'Digital X-Ray',
      'Ultrasound / Sonography',
    ],
    treatmentCapabilities: const [
      'Emergency Cesarean Section (C-Section)',
      'Orthopedic Fracture Fixation',
      'Laparoscopic Surgery',
      'ICU Mechanical Ventilation',
      'Blood Transfusion',
    ],
    tags: const [
      'Multi-Specialty',
      'District Referral Hospital',
      '24/7 Emergency',
      'ICU',
      'Blood Bank',
      'Obstetrics & Gynae',
      'Pediatrics',
    ],
  );

  static final Hospital hospitalTalukCommunity = IndoreHospitalDataset.chcDepalpur.copyWith(
    hospitalId: 'indore_healthcare_026',
    name: 'Community Health Centre (CHC), Depalpur',
    emergencyCare: true,
    specialties: const [
      'General Medicine',
      'Basic Obstetrics',
      'Pediatrics',
    ],
    diagnosticFacilities: const [
      'Basic Clinical Lab',
      'Digital X-Ray',
      'Ultrasound / Sonography',
    ],
    treatmentCapabilities: const [
      'Normal Vaginal Delivery',
      'Trauma First-Aid Stabilization',
      'IV Rehydration',
    ],
    tags: const [
      'Government',
      'CHC',
      'Community Health Centre',
      'Rural Triage',
      'Emergency First-Aid',
    ],
  );

  static final Hospital hospitalRegionalApex = IndoreHospitalDataset.saimsHospital.copyWith(
    hospitalId: 'indore_hospital_003',
    name: 'Sri Aurobindo Institute of Medical Sciences (SAIMS Apex Center)',
    specialties: const [
      'General Medicine',
      'General Surgery',
      'Obstetrics & Gynecology',
      'Pediatrics',
      'Neonatology (NICU)',
      'Orthopedics & Trauma Surgery',
      'Cardiology',
      'Cardiothoracic Surgery',
      'Neurology',
      'Neurosurgery',
      'Nephrology',
      'Oncology',
    ],
    diagnosticFacilities: const [
      'Full Pathology & Histology Lab',
      '24/7 Blood Bank & Component Separation',
      '128-Slice CT Scanner',
      '3T MRI',
      'Digital X-Ray',
      'Cath Lab',
      'Echocardiography',
      'Advanced Ultrasound',
    ],
    treatmentCapabilities: const [
      'Level 1 Polytrauma Resuscitation',
      'Craniotomy & Neurotrauma Surgery',
      'Percutaneous Coronary Intervention (PCI)',
      'Emergency Cesarean Section (C-Section)',
      'NICU / PICU Neonatal & Pediatric Intensive Care',
      'Hemodialysis',
      'ICU Mechanical Ventilation',
      'Blood Transfusion',
    ],
    tags: const [
      'Medical College & Hospital',
      'Apex Tertiary Care',
      'Level-1 Trauma',
      '24/7 Emergency',
      'ICU',
      'Blood Bank',
      'Neuro & Cardiac',
    ],
  );

  static final Hospital hospitalMaternalChild = IndoreHospitalDataset.facility18.copyWith(
    hospitalId: 'indore_hospital_018',
    name: 'Charak Hospital (Maternal & Child Health Wing)',
    specialties: const [
      'Obstetrics & Gynecology',
      'Pediatrics',
      'Neonatology (NICU)',
      'General Medicine',
    ],
    diagnosticFacilities: const [
      'Maternal-Fetal Ultrasound',
      'Pathology Lab',
      'Digital X-Ray',
      '24/7 Blood Bank',
    ],
    treatmentCapabilities: const [
      'Emergency Cesarean Section (C-Section)',
      'High-Risk Pregnancy Stabilization',
      'Neonatal Resuscitation',
      'NICU Incubator Care',
      'Normal Vaginal Delivery',
      'Blood Transfusion',
    ],
    tags: const [
      'Multi-Specialty',
      'Maternal & Child Health',
      '24/7 Emergency',
      'ICU',
      'NICU',
      'Obstetrics',
    ],
  );

  static final Hospital hospitalMetroTrauma = IndoreHospitalDataset.facility17.copyWith(
    hospitalId: 'indore_hospital_017',
    name: 'V One Hospital (Metro Trauma Center)',
    specialties: const [
      'Orthopedics & Trauma Surgery',
      'Emergency Medicine',
      'General Surgery',
      'Neurosurgery',
    ],
    diagnosticFacilities: const [
      '16-Slice CT Scanner',
      'Digital X-Ray',
      'Pathology Lab',
      '24/7 Blood Bank',
    ],
    treatmentCapabilities: const [
      'Orthopedic Fracture Fixation',
      'Polytrauma Resuscitation & Surgery',
      'ICU Mechanical Ventilation',
      'Blood Transfusion',
    ],
    tags: const [
      'Multi-Specialty',
      'Orthopedics & Spine',
      'Trauma Care',
      '24/7 Emergency',
      'ICU',
      'Blood Bank',
    ],
  );

  static final Hospital hospitalGreenValley = IndoreHospitalDataset.facility12.copyWith(
    hospitalId: 'indore_healthcare_027',
    name: 'Essence Dispensary (Rural Outpatient Clinic)',
    emergencyCare: false,
    icuAvailable: false,
    specialties: const ['General Medicine'],
    diagnosticFacilities: const ['Basic Clinical Lab'],
    treatmentCapabilities: const ['Outpatient Care'],
    tags: const [
      'Dispensary',
      'Outpatient',
      'Rural Clinic',
    ],
  );

  static final Hospital hospitalCityHeart = IndoreHospitalDataset.facility05.copyWith(
    hospitalId: 'indore_hospital_005',
    name: 'CARE CHL Hospitals (Heart & Vascular Center)',
    tags: const [
      'Super Speciality',
      'Cath Lab / Cardiac',
      '24/7 Emergency',
      'ICU',
      'Trauma Care',
      'Blood Bank',
    ],
  );

  static final Hospital hospitalSunriseDiverting = IndoreHospitalDataset.facility02.copyWith(
    hospitalId: 'indore_hospital_002_div',
    name: 'Bhandari Hospital (Emergency Diverting)',
    operatingStatus: 'Diverting',
    availability: IndoreHospitalDataset.facility02.availability?.copyWith(
      operatingStatus: 'Diverting',
    ),
    tags: const [
      'Multi-Specialty',
      'Diverting',
      'Emergency Care',
    ],
  );

  static final Hospital hospitalHighlandMission = IndoreHospitalDataset.chcSanwer.copyWith(
    hospitalId: 'indore_healthcare_035',
    name: 'Community Health Centre (CHC), Sanwer',
    tags: const [
      'Government',
      'CHC',
      'Community Health Centre',
      '30 Beds',
      'Rural Triage',
    ],
  );

  /// All 45 Indore facilities loaded directly from the synthetic Indore healthcare registry.
  static List<Hospital> get sampleHospitals => [
        hospitalTalukCommunity,
        hospitalDistrictGeneral,
        hospitalRegionalApex,
        hospitalMaternalChild,
        hospitalMetroTrauma,
        hospitalGreenValley,
        hospitalCityHeart,
        hospitalSunriseDiverting,
        hospitalHighlandMission,
        ...IndoreHospitalDataset.allFacilities.where((h) =>
            h.hospitalId != hospitalTalukCommunity.hospitalId &&
            h.hospitalId != hospitalDistrictGeneral.hospitalId &&
            h.hospitalId != hospitalRegionalApex.hospitalId &&
            h.hospitalId != hospitalMetroTrauma.hospitalId &&
            h.hospitalId != hospitalMaternalChild.hospitalId &&
            h.hospitalId != hospitalGreenValley.hospitalId &&
            h.hospitalId != hospitalCityHeart.hospitalId &&
            h.hospitalId != hospitalHighlandMission.hospitalId),
      ];

  // --- Synthetic Patients ---

  static final Patient patientPostpartumHemorrhage = Patient(
    patientId: 'PAT-SIM-101',
    age: 26,
    sex: Sex.female,
    mainComplaint: 'Heavy vaginal bleeding after home delivery (PPH)',
    symptoms: const [
      'Excessive postpartum hemorrhage',
      'Dizziness and pale conjunctiva',
      'Cold clammy peripheries',
    ],
    injuryOrIllnessDetails:
      'Delivered 3 hours ago at home. Placenta delivered, continuous heavy bleeding noted upon clinic arrival.',
    clinicalFindings:
      'Uterine atony palpable. Markedly pale, capillary refill time > 3 seconds.',
    heartRate: 126,
    systolicBP: 84,
    diastolicBP: 52,
    respiratoryRate: 24,
    oxygenSaturation: 93.0,
    temperature: 36.6,
    requiredSpecialty: 'Obstetrics & Gynecology',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  );

  static final Patient patientPediatricPneumonia = Patient(
    patientId: 'PAT-SIM-102',
    age: 3,
    sex: Sex.male,
    mainComplaint: 'Severe breathing difficulty and high fever',
    symptoms: const [
      'Chest in-drawing',
      'Stridor and wheezing',
      'Lethargy and poor oral intake',
    ],
    injuryOrIllnessDetails:
      'Cough and fever for 4 days, acutely worsened over the past 12 hours with grunting respiration.',
    clinicalFindings:
      'Severe subcostal retractions, nasal flaring, bilateral coarse crackles.',
    heartRate: 154,
    systolicBP: 92,
    diastolicBP: 58,
    respiratoryRate: 50,
    oxygenSaturation: 88.0,
    temperature: 39.4,
    requiredSpecialty: 'Pediatrics',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  );

  static final Patient patientCompoundFracture = Patient(
    patientId: 'PAT-SIM-103',
    age: 34,
    sex: Sex.male,
    mainComplaint: 'Severe open leg injury following road collision',
    symptoms: const [
      'Open deformity of lower right leg',
      'Active wound bleeding',
      'Severe pain and inability to bear weight',
    ],
    injuryOrIllnessDetails:
      'Motorcycle skid against rural culvert 1 hour ago. Bone fragment visibly protruding.',
    clinicalFindings:
      'Compound Gustilo-Anderson Grade II fracture of right tibia-fibula. Distal pedal pulse intact.',
    heartRate: 98,
    systolicBP: 122,
    diastolicBP: 78,
    respiratoryRate: 18,
    oxygenSaturation: 98.0,
    temperature: 36.8,
    requiredSpecialty: 'Orthopedics & Trauma Surgery',
    createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
  );

  static final Patient patientAcuteCoronary = Patient(
    patientId: 'PAT-SIM-104',
    age: 60,
    sex: Sex.male,
    mainComplaint: 'Crushing central chest pain radiating to left jaw',
    symptoms: const [
      'Retrosternal pressure lasting > 45 mins',
      'Diaphoresis (heavy sweating)',
      'Shortness of breath',
    ],
    injuryOrIllnessDetails:
      'Sudden onset while working in farm field. No relief with rest. History of untreated hypertension.',
    clinicalFindings:
      'Anxious, pale, sweaty. S1/S2 present, no murmurs. ECG shows ST elevation in leads II, III, aVF.',
    heartRate: 90,
    systolicBP: 172,
    diastolicBP: 104,
    respiratoryRate: 22,
    oxygenSaturation: 94.0,
    temperature: 36.9,
    requiredSpecialty: 'Cardiology',
    createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
  );

  static final Patient patientMildViralInfection = Patient(
    patientId: 'PAT-SIM-105',
    age: 20,
    sex: Sex.female,
    mainComplaint: 'Mild dry cough, runny nose, and low-grade fatigue',
    symptoms: const [
      'Rhinorrhea',
      'Throat tickle',
      'Normal appetite',
    ],
    injuryOrIllnessDetails: 'Symptoms for 2 days. No respiratory distress or danger signs.',
    clinicalFindings: 'Mild pharyngeal erythema. Lungs clear to auscultation bilaterally.',
    heartRate: 74,
    systolicBP: 116,
    diastolicBP: 76,
    respiratoryRate: 16,
    oxygenSaturation: 99.0,
    temperature: 37.1,
    requiredSpecialty: 'General Medicine',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  );

  static List<Patient> get samplePatients => [
        patientPostpartumHemorrhage,
        patientPediatricPneumonia,
        patientCompoundFracture,
        patientAcuteCoronary,
        patientMildViralInfection,
      ];

  // --- Synthetic Pre-generated Referral ---

  static final Referral sampleEmergencyReferral = Referral(
    referralId: 'REF-SIM-901',
    patient: patientAcuteCoronary,
    urgencyLevel: UrgencyLevel.emergency,
    referralReason:
      'Acute ST-elevation myocardial infarction (STEMI) requiring immediate primary PCI and cardiac ICU admission.',
    requiredSpecialty: 'Cardiology',
    requiredFacilities: const ['24/7 Cath Lab', 'Cardiac ICU', 'Emergency Resuscitation'],
    recommendedHospital: hospitalCityHeart,
    alternativeHospitals: [hospitalRegionalApex, hospitalDistrictGeneral],
    estimatedDistance: 31.2,
    estimatedTravelTime: const Duration(minutes: 42),
    recommendationScore: 96.0,
    status: ReferralStatus.transferred,
    statusHistory: [
      ReferralStatusHistory(
        status: ReferralStatus.pending,
        timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
        note: 'Acute coronary emergency triage recorded at rural clinic.',
      ),
      ReferralStatusHistory(
        status: ReferralStatus.referred,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        note: 'Direct emergency transfer order transmitted to City Heart cath lab.',
      ),
      ReferralStatusHistory(
        status: ReferralStatus.accepted,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        note: 'City Heart on-call interventional cardiologist accepted transfer.',
      ),
      ReferralStatusHistory(
        status: ReferralStatus.transferred,
        timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
        note: 'Patient departed in Advanced Cardiac Life Support ambulance with continuous ECG telemetry.',
      ),
    ],
    createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 18)),
    referringClinic: 'Primary Health Center Sector 4',
  );
}
