import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/disease_acuity.dart';
import '../../models/enums.dart';
import '../../models/mock_data.dart';
import '../../models/patient.dart';
import '../../services/assessment_service.dart';
import '../../services/condition_specific_ranking_service.dart';
import '../../services/hospital_matching_service.dart';
import '../../services/location_service.dart';
import '../../widgets/widgets.dart';
import 'assessment_result_screen.dart';
import '../emergency/emergency_quick_referral_screen.dart';
import '../../models/facility_resource.dart';
import '../../models/indore_hospital_dataset.dart';
import '../../models/symptom_analysis.dart';
import '../../repositories/facility_resource_repository.dart';

/// Patient Assessment form for rural health workers.
/// Captures patient information, symptoms, vitals, referral needs, and local clinic resources.
class PatientAssessmentScreen extends StatefulWidget {
  final AssessmentService assessmentService;
  final Patient? initialPatient;
  final bool showAppHeader;

  /// Global notifier allowing external screens (e.g. observation saved or referral dispatched)
  /// to request clearing the current assessment form.
  static final ValueNotifier<int> formResetNotifier = ValueNotifier<int>(0);

  /// Triggers a form reset across active assessment screen instances.
  static void requestFormReset() {
    formResetNotifier.value++;
  }

  const PatientAssessmentScreen({
    super.key,
    this.assessmentService = const RuleBasedAssessmentService(),
    this.initialPatient,
    this.showAppHeader = true,
  });

  @override
  State<PatientAssessmentScreen> createState() => _PatientAssessmentScreenState();
}

class _PatientAssessmentScreenState extends State<PatientAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Section 1: Patient Information
  late final TextEditingController _patientIdController;
  late final TextEditingController _ageController;
  Sex _selectedSex = Sex.female;
  late final TextEditingController _mainComplaintController;

  // Gemini AI & Offline Symptom Analysis
  late final TextEditingController _presentationDescriptionController;
  final Set<String> _selectedCustomTags = {};
  SymptomAnalysisResult? _currentSymptomAnalysis;

  // Section 2: Symptoms and Condition
  final Set<String> _selectedSymptoms = {};
  late final TextEditingController _customSymptomController;
  late final TextEditingController _injuryDetailsController;
  late final TextEditingController _clinicalFindingsController;

  // Section 3: Vital Signs
  late final TextEditingController _heartRateController;
  late final TextEditingController _systolicBPController;
  late final TextEditingController _diastolicBPController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenSaturationController;
  late final TextEditingController _temperatureController;

  // Section 4: Referral Information
  PatientConditionCategory _selectedConditionCategory = PatientConditionCategory.stableMedicalCase;
  String _selectedSpecialty = 'General Medicine';
  final Set<String> _selectedDiagnostics = {};
  final Set<String> _selectedTreatments = {};

  // Section 5: Clinic Resources Available
  bool _hasBasicDiagnostics = true;
  bool _hasEmergencyCapability = true;
  bool _hasSpecialistAvailability = false;
  bool _hasIcuSupport = false;
  FacilityCompleteResources? _preloadedFacilityResources;

  Future<void> _preloadFacilityInfrastructure() async {
    try {
      final curLoc = DefaultLocationService().currentClinicLocation;
      String matchedId = 'indore_healthcare_041';
      for (final f in IndoreHospitalDataset.allFacilities) {
        final fName = f.name.toLowerCase();
        final curName = curLoc.name.toLowerCase();
        if (fName.contains(curName.split(' ').first) || curName.contains(fName.split(' ').first)) {
          matchedId = f.hospitalId;
          break;
        }
      }
      final resources = await FacilityResourceRepository.instance.getFacilityResources(matchedId);
      if (mounted) {
        setState(() {
          _preloadedFacilityResources = resources;
          _hasBasicDiagnostics = resources.inventory.any((i) =>
              (i.category == ResourceCategory.diagnosticAndImaging ||
                  i.category == ResourceCategory.laboratoryAndPathology) &&
              i.isOperational);
          _hasEmergencyCapability = resources.emergencyCare ||
              resources.inventory.any((i) => i.category == ResourceCategory.emergencyAndTrauma && i.isOperational);
          _hasSpecialistAvailability = resources.staff.any((s) => s.staffRole == 'doctor' && s.isCurrentlyPractising);
          _hasIcuSupport = resources.icuAvailable ||
              resources.capacity.any((c) => c.category == 'icu_beds' && c.availableCapacity > 0);
        });
      }
    } catch (_) {}
  }

  // Disease Acuity Protocol Filter (0 = All, 4 = L4 Emergency, 3 = L3 Urgent, 2 = L2 Clinic/PHC, 1 = L1 Home Care)
  int _selectedAcuityFilter = 0;

  // Common quick-pick symptoms in rural clinic settings
  static const List<String> _commonSymptoms = [
    'Excessive postpartum hemorrhage',
    'Breathing difficulty',
    'Chest in-drawing',
    'Crushing chest pain',
    'Open fracture / limb trauma',
    'High fever',
    'Lethargy / Unconsciousness',
    'Convulsions / Seizures',
    'Severe dehydration',
    'Acute abdominal pain',
    'Active bleeding',
    'Persistent vomiting',
  ];

  static const List<String> _specialtyOptions = [
    'General Medicine',
    'Obstetrics & Gynecology',
    'Pediatrics',
    'Orthopedics & Trauma Surgery',
    'Cardiology',
    'General Surgery',
    'Neurosurgery',
    'Neonatology (NICU)',
  ];

  static const List<String> _diagnosticOptions = [
    'Basic Clinical Lab',
    '24/7 Blood Bank',
    'Digital X-Ray',
    'Ultrasound',
    '16-Slice CT Scanner',
    'Full Pathology Lab',
  ];

  static const List<String> _treatmentOptions = [
    'Normal Vaginal Delivery',
    'Emergency Cesarean Section (C-Section)',
    'Orthopedic Fracture Fixation',
    'ICU Mechanical Ventilation',
    'Blood Transfusion',
    'Polytrauma Resuscitation',
    'IV Rehydration',
  ];

  @override
  void initState() {
    super.initState();
    PatientAssessmentScreen.formResetNotifier.addListener(_onFormResetRequested);
    _preloadFacilityInfrastructure();
    final p = widget.initialPatient;

    final defaultId = 'PAT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _patientIdController = TextEditingController(text: p?.patientId ?? defaultId);
    _ageController = TextEditingController(text: p != null ? p.age.toString() : '');
    _selectedSex = p?.sex ?? Sex.female;
    _mainComplaintController = TextEditingController(text: p?.mainComplaint ?? '');
    _presentationDescriptionController = TextEditingController(
      text: p != null
          ? (p.clinicalFindings.isNotEmpty
              ? p.clinicalFindings
              : (p.injuryOrIllnessDetails.isNotEmpty ? p.injuryOrIllnessDetails : p.mainComplaint))
          : '',
    );

    if (p != null) {
      _selectedSymptoms.addAll(p.symptoms);
    }
    _customSymptomController = TextEditingController();
    _injuryDetailsController = TextEditingController(text: p?.injuryOrIllnessDetails ?? '');
    _clinicalFindingsController = TextEditingController(text: p?.clinicalFindings ?? '');

    _heartRateController = TextEditingController(text: p?.heartRate?.toString() ?? '');
    _systolicBPController = TextEditingController(text: p?.systolicBP?.toString() ?? '');
    _diastolicBPController = TextEditingController(text: p?.diastolicBP?.toString() ?? '');
    _respiratoryRateController = TextEditingController(text: p?.respiratoryRate?.toString() ?? '');
    _oxygenSaturationController = TextEditingController(text: p?.oxygenSaturation?.toString() ?? '');
    _temperatureController = TextEditingController(text: p?.temperature?.toString() ?? '');

    _selectedSpecialty = p?.requiredSpecialty ?? 'General Medicine';
    if (p?.conditionCategory != null) {
      _selectedConditionCategory = p!.conditionCategory!;
    }
  }

  @override
  void dispose() {
    PatientAssessmentScreen.formResetNotifier.removeListener(_onFormResetRequested);
    _patientIdController.dispose();
    _ageController.dispose();
    _mainComplaintController.dispose();
    _presentationDescriptionController.dispose();
    _customSymptomController.dispose();
    _injuryDetailsController.dispose();
    _clinicalFindingsController.dispose();
    _heartRateController.dispose();
    _systolicBPController.dispose();
    _diastolicBPController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  void _onFormResetRequested() {
    if (mounted) {
      _resetForm();
    }
  }

  /// Resets the assessment form to a clean slate with a fresh patient token.
  void _resetForm() {
    if (!mounted) return;
    _formKey.currentState?.reset();
    setState(() {
      final newId = 'PAT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _patientIdController.text = newId;
      _ageController.clear();
      _selectedSex = Sex.female;
      _mainComplaintController.clear();
      _presentationDescriptionController.clear();
      _selectedCustomTags.clear();
      _currentSymptomAnalysis = null;
      _selectedSymptoms.clear();
      _customSymptomController.clear();
      _injuryDetailsController.clear();
      _clinicalFindingsController.clear();
      _heartRateController.clear();
      _systolicBPController.clear();
      _diastolicBPController.clear();
      _respiratoryRateController.clear();
      _oxygenSaturationController.clear();
      _temperatureController.clear();
      _selectedSpecialty = 'General Medicine';
      _selectedConditionCategory = PatientConditionCategory.stableMedicalCase;
      _selectedDiagnostics.clear();
      _selectedTreatments.clear();
      _selectedAcuityFilter = 0;
    });
  }

  void _loadPreset(Patient preset) {
    setState(() {
      _patientIdController.text = preset.patientId;
      _ageController.text = preset.age.toString();
      _selectedSex = preset.sex;
      _mainComplaintController.text = preset.mainComplaint;
      _presentationDescriptionController.text = preset.clinicalFindings.isNotEmpty
          ? preset.clinicalFindings
          : (preset.injuryOrIllnessDetails.isNotEmpty ? preset.injuryOrIllnessDetails : preset.mainComplaint);
      _selectedCustomTags.clear();
      _currentSymptomAnalysis = null;

      _selectedSymptoms.clear();
      _selectedSymptoms.addAll(preset.symptoms);
      _injuryDetailsController.text = preset.injuryOrIllnessDetails;
      _clinicalFindingsController.text = preset.clinicalFindings;

      _heartRateController.text = preset.heartRate?.toString() ?? '';
      _systolicBPController.text = preset.systolicBP?.toString() ?? '';
      _diastolicBPController.text = preset.diastolicBP?.toString() ?? '';
      _respiratoryRateController.text = preset.respiratoryRate?.toString() ?? '';
      _oxygenSaturationController.text = preset.oxygenSaturation?.toString() ?? '';
      _temperatureController.text = preset.temperature?.toString() ?? '';

      _selectedSpecialty = preset.requiredSpecialty;

      if (preset.conditionCategory != null) {
        _selectedConditionCategory = preset.conditionCategory!;
      } else if (preset.patientId == 'PAT-SIM-101' || preset.mainComplaint.contains('PPH')) {
        _selectedConditionCategory = PatientConditionCategory.obstetricEmergency;
      } else if (preset.patientId == 'PAT-SIM-102') {
        _selectedConditionCategory = PatientConditionCategory.pediatricEmergency;
      } else if (preset.patientId == 'PAT-SIM-103') {
        _selectedConditionCategory = PatientConditionCategory.majorTrauma;
      } else if (preset.patientId == 'PAT-SIM-104') {
        _selectedConditionCategory = PatientConditionCategory.suspectedCardiacEmergency;
      } else {
        _selectedConditionCategory = PatientConditionCategory.stableMedicalCase;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded sample clinical presentation: ${preset.mainComplaint}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addCustomSymptom() {
    final text = _customSymptomController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _selectedSymptoms.add(text);
        _customSymptomController.clear();
      });
    }
  }

  List<String> get _displayedSymptoms {
    switch (_selectedAcuityFilter) {
      case 4:
        return DiseaseAcuityDataset.getConditionsForSeverity(4);
      case 3:
        return DiseaseAcuityDataset.getConditionsForSeverity(3);
      case 2:
        return DiseaseAcuityDataset.getConditionsForSeverity(2);
      case 1:
        return DiseaseAcuityDataset.getConditionsForSeverity(1);
      case -1:
        return DiseaseAcuityDataset.getAllConditions();
      case 0:
      default:
        return _commonSymptoms;
    }
  }

  void _toggleSymptom(String symptom, bool selected) {
    setState(() {
      if (selected) {
        _selectedSymptoms.add(symptom);
        final cat = DiseaseAcuityDataset.mapConditionToCategory(symptom);
        if (cat != PatientConditionCategory.stableMedicalCase) {
          _selectedConditionCategory = cat;
        }
        final spec = DiseaseAcuityDataset.deduceSpecialtyForCondition(symptom);
        if (spec != 'General Medicine') {
          _selectedSpecialty = spec;
        }
      } else {
        _selectedSymptoms.remove(symptom);
      }
    });
  }

  void _showDiseaseProtocolGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingMd),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLightMint,
                              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryGreen, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Disease Triage Acuity Matrix',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
                              ),
                              Text(
                                '4-Level Clinical Decision Support Protocol',
                                style: TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: DiseaseAcuityDataset.allLevels.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spacingMd),
                      itemBuilder: (context, index) {
                        final level = DiseaseAcuityDataset.allLevels[DiseaseAcuityDataset.allLevels.length - 1 - index];
                        return Container(
                          decoration: BoxDecoration(
                            color: level.backgroundColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            border: Border.all(color: level.color.withValues(alpha: 0.4), width: 1.2),
                          ),
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(level.icon, size: 18, color: level.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      level.level,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: level.color),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: level.color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Severity ${level.severity}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                level.recommendation,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textNavyPrimary),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.directions_run_rounded, size: 14, color: level.color),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Action: ${level.typicalAction}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: level.color),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Conditions & Symptoms:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavyMuted),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: level.examples.map((ex) {
                                  final isSel = _selectedSymptoms.contains(ex);
                                  return ActionChip(
                                    avatar: isSel ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                                    label: Text(ex),
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : AppColors.textNavyPrimary,
                                    ),
                                    backgroundColor: isSel ? level.color : Colors.white,
                                    side: BorderSide(color: level.color.withValues(alpha: 0.4)),
                                    onPressed: () {
                                      _toggleSymptom(ex, !isSel);
                                      Navigator.of(ctx).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          duration: const Duration(milliseconds: 1500),
                                          backgroundColor: level.color,
                                          content: Text('Added "$ex" to clinical assessment.'),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAcuityFilterChip(int severity, String label, [Color? color]) {
    final isSelected = _selectedAcuityFilter == severity;
    final activeColor = color ?? AppColors.primaryGreen;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: color != null
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textNavyPrimary,
      ),
      selectedColor: activeColor,
      backgroundColor: AppColors.surfaceLight,
      side: BorderSide(
        color: isSelected ? activeColor : AppColors.borderLight,
      ),
      onSelected: (_) {
        setState(() {
          _selectedAcuityFilter = severity;
        });
      },
    );
  }

  Widget _buildConditionDestinationRankingPreview() {
    final previewResult = const ClinicalHospitalMatchingService().evaluateRecommendations(
      patient: Patient(
        patientId: _patientIdController.text.trim().isEmpty ? 'PREVIEW-01' : _patientIdController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 30,
        sex: _selectedSex,
        mainComplaint: _mainComplaintController.text.trim().isEmpty ? 'Referral Candidate' : _mainComplaintController.text.trim(),
        symptoms: _selectedSymptoms.toList(),
        injuryOrIllnessDetails: _injuryDetailsController.text.trim(),
        clinicalFindings: _clinicalFindingsController.text.trim(),
        requiredSpecialty: _selectedSpecialty,
        createdAt: DateTime.now(),
        conditionCategory: _selectedConditionCategory,
      ),
      assessment: AssessmentResult(
        urgencyLevel: UrgencyLevel.urgent,
        recommendedAction: RecommendedAction.referralRecommended,
        clinicalRationale: const ['Preliminary destination ranking preview'],
        requiredSpecialty: _selectedSpecialty,
        requiredFacilities: _selectedDiagnostics.toList(),
        dangerSignsDetected: const [],
        isRedFlag: false,
        conditionCategory: _selectedConditionCategory,
      ),
      availableHospitals: MockClinicalData.sampleHospitals,
      clinicLatitude: DefaultLocationService().currentClinicLocation.latitude,
      clinicLongitude: DefaultLocationService().currentClinicLocation.longitude,
      conditionCategory: _selectedConditionCategory,
    );

    final topHospitals = previewResult.eligibleHospitals.take(3).toList();
    if (topHospitals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered_rounded, size: 14, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Live Condition Referral Ranking Preview',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDarkGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${previewResult.eligibleHospitals.length} eligible',
                style: const TextStyle(fontSize: 10, color: AppColors.textNavyMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...topHospitals.asMap().entries.map((entry) {
            final idx = entry.key;
            final m = entry.value;
            final isTop = idx == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isTop ? AppColors.primaryLightMint : AppColors.surfaceMutedLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${idx + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isTop ? AppColors.primaryDarkGreen : AppColors.textNavySecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.hospital.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textNavyPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${m.matchScore.round()}% • ~${m.travelTime.inMinutes}m',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondarySlateTeal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSymptomChip(String symptom, ThemeData theme) {
    final isSelected = _selectedSymptoms.contains(symptom);
    final level = DiseaseAcuityDataset.findLevelForCondition(symptom);
    final chipColor = level != null ? level.color : AppColors.primaryGreen;

    return FilterChip(
      selected: isSelected,
      showCheckmark: true,
      avatar: level != null
          ? Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : level.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'L${level.severity}',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? level.color : level.color,
                  ),
                ),
              ),
            )
          : null,
      label: Text(symptom),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.textWhite : AppColors.textNavyPrimary,
      ),
      selectedColor: chipColor,
      backgroundColor: AppColors.surfaceLight,
      side: BorderSide(
        color: isSelected
            ? chipColor
            : (level != null ? level.color.withValues(alpha: 0.3) : AppColors.borderLight),
      ),
      onSelected: (selected) => _toggleSymptom(symptom, selected),
    );
  }

  Future<void> _assessPatient() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusRed,
          content: Text('Please check highlighted required fields before assessing.'),
        ),
      );
      return;
    }

    if (_selectedSymptoms.isEmpty && _mainComplaintController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusRed,
          content: Text('Please record at least one symptom or main complaint.'),
        ),
      );
      return;
    }

    // 1. Build strongly typed Patient object
    final patient = Patient(
      patientId: _patientIdController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      sex: _selectedSex,
      mainComplaint: _mainComplaintController.text.trim(),
      symptoms: _selectedSymptoms.toList(),
      injuryOrIllnessDetails: _injuryDetailsController.text.trim(),
      clinicalFindings: _clinicalFindingsController.text.trim(),
      heartRate: int.tryParse(_heartRateController.text.trim()),
      systolicBP: int.tryParse(_systolicBPController.text.trim()),
      diastolicBP: int.tryParse(_diastolicBPController.text.trim()),
      respiratoryRate: int.tryParse(_respiratoryRateController.text.trim()),
      oxygenSaturation: double.tryParse(_oxygenSaturationController.text.trim()),
      temperature: double.tryParse(_temperatureController.text.trim()),
      requiredSpecialty: _selectedSpecialty,
      createdAt: DateTime.now(),
      conditionCategory: _selectedConditionCategory,
    );

    // 2. Evaluate with AssessmentService
    final result = widget.assessmentService.evaluate(patient);

    // 3. Navigate to Assessment Result Screen
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (ctx) => AssessmentResultScreen(
          patient: patient,
          assessment: result,
          symptomAnalysis: _currentSymptomAnalysis,
          clinicResources: {
            'basicDiagnostics': _hasBasicDiagnostics,
            'emergencyCapability': _hasEmergencyCapability,
            'specialistAvailability': _hasSpecialistAvailability,
            'icuSupport': _hasIcuSupport,
          },
        ),
      ),
    );

    if (completed == true && mounted) {
      _resetForm();
    }
  }

  Widget _buildPresetMenu() {
    return PopupMenuButton<Patient>(
      tooltip: 'Load Sample Presentation',
      icon: const Icon(Icons.playlist_add_check_rounded),
      onSelected: _loadPreset,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: MockClinicalData.patientPostpartumHemorrhage,
          child: const Text('Preset: Obstetric PPH (Emergency)'),
        ),
        PopupMenuItem(
          value: MockClinicalData.patientPediatricPneumonia,
          child: const Text('Preset: Pediatric Pneumonia (Emergency)'),
        ),
        PopupMenuItem(
          value: MockClinicalData.patientCompoundFracture,
          child: const Text('Preset: Compound Fracture (Urgent)'),
        ),
        PopupMenuItem(
          value: MockClinicalData.patientMildViralInfection,
          child: const Text('Preset: Mild Cold (Routine)'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formBody = _buildFormBody(context);

    if (!widget.showAppHeader) {
      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: formBody,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // Header
              AppHeader(
                title: 'New Patient Assessment',
                subtitle: 'Structured Clinical Triage Protocol',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reset Form & New Patient',
                    onPressed: _resetForm,
                  ),
                  _buildPresetMenu(),
                ],
              ),

              // Scrollable Form Body
              Expanded(
                child: formBody,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormBody(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.showAppHeader) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sample Case Presets:',
                          style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDarkGreen,
                              ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _resetForm,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reset Form', style: TextStyle(fontSize: 12)),
                        ),
                        _buildPresetMenu(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
            ],
            // Disclaimer banner
            const DisclaimerCard(initiallyExpanded: false),

            const SizedBox(height: AppConstants.spacingSm),

            // 🚨 Emergency Bypass Action Banner
            Container(
              margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: const Color(0xFFF87171), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient Unstable or Deteriorating?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Bypass routine intake to dispatch 108 ambulance & alert hospital.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7F1D1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmergencyQuickReferralScreen(
                            initialComplaint: _mainComplaintController.text.trim().isNotEmpty
                                ? _mainComplaintController.text.trim()
                                : null,
                            patientName: _patientIdController.text.trim().isNotEmpty
                                ? _patientIdController.text.trim()
                                : null,
                            patientAge: int.tryParse(_ageController.text.trim()),
                            patientSex: _selectedSex.displayName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('EMERGENCY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // SECTION 1 — PATIENT INFORMATION
                        // ==========================================
                        const SectionHeader(
                          title: 'SECTION 1 — Patient Information',
                          subtitle: 'Demographics & identification',
                        ),
                        AppCard(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _patientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Patient Identifier / Token *',
                                  hintText: 'e.g. PAT-10492 or local clinic slip ID',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter a patient identifier';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppConstants.spacingMd),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _ageController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Age (Years) *',
                                        hintText: 'e.g. 28',
                                        prefixIcon: Icon(Icons.cake_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Enter age';
                                        }
                                        final n = int.tryParse(val.trim());
                                        if (n == null || n < 0 || n > 125) {
                                          return 'Valid age 0-125';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spacingMd),
                                  Expanded(
                                    flex: 4,
                                    child: DropdownButtonFormField<Sex>(
                                      key: ValueKey(_selectedSex),
                                      initialValue: _selectedSex,
                                      decoration: const InputDecoration(
                                        labelText: 'Sex *',
                                        prefixIcon: Icon(Icons.wc_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                      items: Sex.values.map((s) {
                                        return DropdownMenuItem(
                                          value: s,
                                          child: Text(s.displayName),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedSex = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppConstants.spacingMd),
                              TextFormField(
                                controller: _mainComplaintController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Main Complaint *',
                                  hintText: 'Primary presenting symptom and chief concern...',
                                  prefixIcon: Icon(Icons.record_voice_over_outlined),
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please describe the main complaint';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacingLg),

                        // ==========================================
                        // GEMINI AI & OFFLINE SYMPTOM ANALYSIS
                        // ==========================================
                        const SectionHeader(
                          title: 'CLINICAL AI & DECISION SUPPORT',
                          subtitle: 'Gemini symptom analysis, red-flag screening & custom tags',
                        ),
                        GeminiSymptomAnalysisCard(
                          freeTextController: _presentationDescriptionController,
                          systolicBPController: _systolicBPController,
                          diastolicBPController: _diastolicBPController,
                          heartRateController: _heartRateController,
                          respiratoryRateController: _respiratoryRateController,
                          oxygenSaturationController: _oxygenSaturationController,
                          temperatureController: _temperatureController,
                          mainComplaintController: _mainComplaintController,
                          injuryDetailsController: _injuryDetailsController,
                          clinicalFindingsController: _clinicalFindingsController,
                          patientId: _patientIdController.text.trim().isNotEmpty
                              ? _patientIdController.text.trim()
                              : 'PAT-UNSPECIFIED',
                          patientAge: int.tryParse(_ageController.text.trim()),
                          patientSex: _selectedSex.displayName,
                          selectedTags: _selectedCustomTags,
                          initialResult: _currentSymptomAnalysis,
                          onResultUpdated: (res) {
                            setState(() {
                              _currentSymptomAnalysis = res;
                            });
                          },
                          onApplyAnalysis: (res) {
                            setState(() {
                              _currentSymptomAnalysis = res;
                              // Auto-fill extracted vital signs in assessment form controllers
                              final vitals = res.extractedVitals;
                              if (vitals.oxygenSaturation != null && _oxygenSaturationController.text.trim().isEmpty) {
                                _oxygenSaturationController.text = vitals.oxygenSaturation!.toStringAsFixed(0);
                              }
                              if (vitals.systolicBP != null && _systolicBPController.text.trim().isEmpty) {
                                _systolicBPController.text = vitals.systolicBP!.toString();
                              }
                              if (vitals.diastolicBP != null && _diastolicBPController.text.trim().isEmpty) {
                                _diastolicBPController.text = vitals.diastolicBP!.toString();
                              }
                              if (vitals.heartRate != null && _heartRateController.text.trim().isEmpty) {
                                _heartRateController.text = vitals.heartRate!.toString();
                              }
                              if (vitals.respiratoryRate != null && _respiratoryRateController.text.trim().isEmpty) {
                                _respiratoryRateController.text = vitals.respiratoryRate!.toString();
                              }
                              if (vitals.temperature != null && _temperatureController.text.trim().isEmpty) {
                                _temperatureController.text = vitals.temperature!.toStringAsFixed(1);
                              }

                              // Discrete symptoms & condition mapping
                              for (final s in res.extractedSymptoms) {
                                _selectedSymptoms.add(s);
                                final cat = DiseaseAcuityDataset.mapConditionToCategory(s);
                                if (cat != PatientConditionCategory.stableMedicalCase) {
                                  _selectedConditionCategory = cat;
                                }
                                final spec = DiseaseAcuityDataset.deduceSpecialtyForCondition(s);
                                if (spec != 'General Medicine') {
                                  _selectedSpecialty = spec;
                                }
                              }

                              // Suggested tags without duplicates
                              for (final tag in res.suggestedTags) {
                                if (tag.trim().isNotEmpty && !_selectedCustomTags.contains(tag)) {
                                  _selectedCustomTags.add(tag);
                                }
                              }

                              // Clinical narrative notes
                              if (_mainComplaintController.text.trim().isEmpty && res.extractedSymptoms.isNotEmpty) {
                                _mainComplaintController.text = res.extractedSymptoms.first;
                              }
                              if (_injuryDetailsController.text.trim().isEmpty) {
                                final details = <String>[];
                                if (res.duration != 'Unknown') details.add('Duration: ${res.duration}');
                                if (res.onset != 'Unknown' && res.onset != 'unknown') details.add('Onset: ${res.onset}');
                                if (res.relevantHistory.isNotEmpty) details.add('History: ${res.relevantHistory.join(", ")}');
                                if (details.isNotEmpty) {
                                  _injuryDetailsController.text = details.join(' | ');
                                }
                              }
                              if (_clinicalFindingsController.text.trim().isEmpty && res.redFlags.isNotEmpty) {
                                _clinicalFindingsController.text = 'Warning signs: ${res.redFlags.join("; ")}';
                              }
                            });
                          },
                          onApplySymptoms: (extracted, suggestedTags, urgency, referral) {
                            setState(() {
                              // If current symptom analysis has extracted vitals, apply them too
                              if (_currentSymptomAnalysis != null) {
                                final vitals = _currentSymptomAnalysis!.extractedVitals;
                                if (vitals.oxygenSaturation != null && _oxygenSaturationController.text.trim().isEmpty) {
                                  _oxygenSaturationController.text = vitals.oxygenSaturation!.toStringAsFixed(0);
                                }
                                if (vitals.systolicBP != null && _systolicBPController.text.trim().isEmpty) {
                                  _systolicBPController.text = vitals.systolicBP!.toString();
                                }
                                if (vitals.diastolicBP != null && _diastolicBPController.text.trim().isEmpty) {
                                  _diastolicBPController.text = vitals.diastolicBP!.toString();
                                }
                                if (vitals.heartRate != null && _heartRateController.text.trim().isEmpty) {
                                  _heartRateController.text = vitals.heartRate!.toString();
                                }
                                if (vitals.respiratoryRate != null && _respiratoryRateController.text.trim().isEmpty) {
                                  _respiratoryRateController.text = vitals.respiratoryRate!.toString();
                                }
                                if (vitals.temperature != null && _temperatureController.text.trim().isEmpty) {
                                  _temperatureController.text = vitals.temperature!.toStringAsFixed(1);
                                }
                              }

                              for (final s in extracted) {
                                _selectedSymptoms.add(s);
                                final cat = DiseaseAcuityDataset.mapConditionToCategory(s);
                                if (cat != PatientConditionCategory.stableMedicalCase) {
                                  _selectedConditionCategory = cat;
                                }
                                final spec = DiseaseAcuityDataset.deduceSpecialtyForCondition(s);
                                if (spec != 'General Medicine') {
                                  _selectedSpecialty = spec;
                                }
                              }
                              for (final tag in suggestedTags) {
                                if (tag.trim().isNotEmpty && !_selectedCustomTags.contains(tag)) {
                                  _selectedCustomTags.add(tag);
                                }
                              }
                            });
                          },
                          onEmergencyTrigger: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EmergencyQuickReferralScreen(
                                  initialComplaint: _presentationDescriptionController.text.trim().isNotEmpty
                                      ? _presentationDescriptionController.text.trim()
                                      : _mainComplaintController.text.trim(),
                                  patientName: _patientIdController.text.trim().isNotEmpty
                                      ? _patientIdController.text.trim()
                                      : null,
                                  patientAge: int.tryParse(_ageController.text.trim()),
                                  patientSex: _selectedSex.displayName,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: AppConstants.spacingLg),

                        // ==========================================
                        // SECTION 2 — SYMPTOMS AND CONDITION
                        // ==========================================
                        const SectionHeader(
                          title: 'SECTION 2 — Symptoms & Condition',
                          subtitle: 'Danger signs, clinical history & physical exam',
                        ),
                        AppCard(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Select Presenting Symptoms:',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textNavyPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: AppColors.primaryGreen,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                                    label: const Text('Triage Acuity Guide', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    onPressed: _showDiseaseProtocolGuide,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildAcuityFilterChip(0, 'Common Symptoms (12)'),
                                    const SizedBox(width: 6),
                                    _buildAcuityFilterChip(4, 'Level 4: Emergency (11)', AppColors.statusRed),
                                    const SizedBox(width: 6),
                                    _buildAcuityFilterChip(3, 'Level 3: Urgent (8)', AppColors.statusAmber),
                                    const SizedBox(width: 6),
                                    _buildAcuityFilterChip(2, 'Level 2: Clinic / PHC (8)', AppColors.tealAccentDark),
                                    const SizedBox(width: 6),
                                    _buildAcuityFilterChip(1, 'Level 1: Home Care (5)', AppColors.statusGreen),
                                    const SizedBox(width: 6),
                                    _buildAcuityFilterChip(-1, 'All Diseases (32)'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _displayedSymptoms.map((symptom) {
                                  return _buildSymptomChip(symptom, theme);
                                }).toList(),
                              ),
                              const SizedBox(height: AppConstants.spacingMd),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customSymptomController,
                                      decoration: const InputDecoration(
                                        hintText: 'Add custom symptom/sign...',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      onSubmitted: (_) => _addCustomSymptom(),
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spacingSm),
                                  ElevatedButton(
                                    onPressed: _addCustomSymptom,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondarySlateTeal,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(60, 48),
                                    ),
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                              if (_selectedSymptoms.any((s) => !_commonSymptoms.contains(s))) ...[
                                const SizedBox(height: AppConstants.spacingSm),
                                Text(
                                  'Custom Clinical Symptoms Added:',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textNavyPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedSymptoms
                                      .where((s) => !_commonSymptoms.contains(s))
                                      .map((symptom) {
                                    return InputChip(
                                      label: Text(symptom),
                                      selected: true,
                                      selectedColor: AppColors.secondarySlateTeal,
                                      labelStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      deleteIconColor: Colors.white,
                                      onDeleted: () {
                                        setState(() => _selectedSymptoms.remove(symptom));
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: AppConstants.spacingMd),
                              TextFormField(
                                controller: _injuryDetailsController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Injury / Illness Details',
                                  hintText: 'Onset, timeline, trauma mechanism, past medical history...',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: AppConstants.spacingMd),
                              TextFormField(
                                controller: _clinicalFindingsController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Relevant Clinical Findings',
                                  hintText: 'Pallor, cyanosis, capillary refill time, conscious state, auscultation...',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacingLg),

                        // ==========================================
                        // SECTION 3 — VITAL SIGNS
                        // ==========================================
                        const SectionHeader(
                          title: 'SECTION 3 — Vital Signs',
                          subtitle: 'Objective clinical triage measurements',
                        ),
                        AppCard(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Blood Pressure (Systolic & Diastolic)
                              Text(
                                'Blood Pressure (mmHg):',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textNavyPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _systolicBPController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Systolic (SBP)',
                                        hintText: 'e.g. 120',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text('/', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _diastolicBPController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Diastolic (DBP)',
                                        hintText: 'e.g. 80',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppConstants.spacingMd),

                              // Heart Rate & Respiratory Rate
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _heartRateController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Heart Rate (bpm)',
                                        hintText: 'e.g. 82',
                                        prefixIcon: Icon(Icons.favorite_outline),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spacingMd),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _respiratoryRateController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Resp Rate (/min)',
                                        hintText: 'e.g. 18',
                                        prefixIcon: Icon(Icons.air_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppConstants.spacingMd),

                              // Oxygen Saturation & Temperature
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _oxygenSaturationController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'SpO2 (% Oxygen)',
                                        hintText: 'e.g. 98',
                                        prefixIcon: Icon(Icons.water_drop_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spacingMd),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _temperatureController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Temp (°C)',
                                        hintText: 'e.g. 37.0',
                                        prefixIcon: Icon(Icons.thermostat_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacingLg),

                        // ==========================================
                        // SECTION 4 — REFERRAL INFORMATION
                        // ==========================================
                        const SectionHeader(
                          title: 'SECTION 4 — Referral Information',
                          subtitle: 'Anticipated clinical specialty and hospital needs',
                        ),
                        AppCard(
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Clinical Condition Category Selector
                              DropdownButtonFormField<PatientConditionCategory>(
                                key: ValueKey(_selectedConditionCategory),
                                initialValue: _selectedConditionCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Suspected Condition Category (Clinician Confirmed) *',
                                  prefixIcon: Icon(Icons.emergency_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                isExpanded: true,
                                items: PatientConditionCategory.values.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Text(
                                      cat.displayName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedConditionCategory = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMutedLight,
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedConditionCategory.description,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textNavyPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Prioritization Rule: ${ConditionSpecificRankingService.getConfiguration(_selectedConditionCategory).summaryDescription}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.secondarySlateTeal,
                                      ),
                                    ),
                                    _buildConditionDestinationRankingPreview(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppConstants.spacingMd),

                              DropdownButtonFormField<String>(
                                key: ValueKey(_selectedSpecialty),
                                initialValue: _selectedSpecialty,
                                decoration: const InputDecoration(
                                  labelText: 'Required Medical Specialty *',
                                  prefixIcon: Icon(Icons.local_hospital_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                items: _specialtyOptions.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedSpecialty = val);
                                },
                              ),
                              const SizedBox(height: AppConstants.spacingMd),
                              Text(
                                'Required Diagnostic Facilities:',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textNavyPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _diagnosticOptions.map((diag) {
                                  final isSelected = _selectedDiagnostics.contains(diag);
                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(diag),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.textWhite : AppColors.textNavyPrimary,
                                    ),
                                    selectedColor: AppColors.secondarySlateTeal,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedDiagnostics.add(diag);
                                        } else {
                                          _selectedDiagnostics.remove(diag);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppConstants.spacingMd),
                              Text(
                                'Required Treatment Capabilities:',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textNavyPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _treatmentOptions.map((treat) {
                                  final isSelected = _selectedTreatments.contains(treat);
                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(treat),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.textWhite : AppColors.textNavyPrimary,
                                    ),
                                    selectedColor: AppColors.tealAccentDark,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedTreatments.add(treat);
                                        } else {
                                          _selectedTreatments.remove(treat);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacingLg),

                        // ==========================================
                        // SECTION 5 — CLINIC RESOURCES
                        // ==========================================
                        const SectionHeader(
                          title: 'SECTION 5 — Current Clinic Resources',
                          subtitle: 'Preloaded advance infrastructure and on-site capabilities',
                        ),
                        if (_preloadedFacilityResources != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_outlined, color: Color(0xFF15803D), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Verified Facility Infrastructure Preloaded (${_preloadedFacilityResources!.facilityName})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_preloadedFacilityResources!.inventory.where((i) => i.isOperational).length} operational devices, ${_preloadedFacilityResources!.staff.length} staff, ${_preloadedFacilityResources!.availableBeds} beds available. Maintained in advance via Facility Resources.',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('Basic Diagnostics', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: const Text('Rapid point-of-care tests, hemoglobinometer, urine strips', style: TextStyle(fontSize: 12)),
                                value: _hasBasicDiagnostics,
                                activeThumbColor: AppColors.primaryGreen,
                                activeTrackColor: AppColors.primaryLightMint,
                                onChanged: (val) => setState(() => _hasBasicDiagnostics = val),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                title: const Text('Emergency Stabilization Capability', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: const Text('Oxygen cylinder, IV resuscitation kits, basic airway', style: TextStyle(fontSize: 12)),
                                value: _hasEmergencyCapability,
                                activeThumbColor: AppColors.primaryGreen,
                                activeTrackColor: AppColors.primaryLightMint,
                                onChanged: (val) => setState(() => _hasEmergencyCapability = val),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                title: const Text('Specialist Doctor Available On-Site', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: const Text('Certified obstetrician, surgeon, or pediatrician present', style: TextStyle(fontSize: 12)),
                                value: _hasSpecialistAvailability,
                                activeThumbColor: AppColors.primaryGreen,
                                activeTrackColor: AppColors.primaryLightMint,
                                onChanged: (val) => setState(() => _hasSpecialistAvailability = val),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                title: const Text('ICU / Advanced Life Support Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: const Text('Continuous mechanical ventilator and intensive care beds', style: TextStyle(fontSize: 12)),
                                value: _hasIcuSupport,
                                activeThumbColor: AppColors.primaryGreen,
                                activeTrackColor: AppColors.primaryLightMint,
                                onChanged: (val) => setState(() => _hasIcuSupport = val),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacingXl),

                        // ==========================================
                        // BOTTOM ACTION: "Assess Patient"
                        // ==========================================
                        PrimaryButton(
                          text: 'Assess Patient',
                          icon: Icons.health_and_safety_outlined,
                          onPressed: _assessPatient,
                        ),

                        const SizedBox(height: AppConstants.spacingSm),

                        SecondaryButton(
                          text: 'Clear & New Patient',
                          icon: Icons.refresh_rounded,
                          onPressed: _resetForm,
                        ),

                        const SizedBox(height: AppConstants.spacingXxl),
                      ],
                    ),
                  ),
                );
  }
}
