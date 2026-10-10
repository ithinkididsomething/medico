import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/emergency_referral.dart';
import '../../models/indore_hospital_dataset.dart';
import '../../repositories/emergency_referral_repository.dart';
import '../../services/emergency_referral_service.dart';
import 'emergency_referral_detail_screen.dart';

/// Ultra-fast emergency quick referral form.
/// Designed for rapid completion under critical pressure within seconds.
/// Guarantees that ambulance dispatch and referral persistence are never blocked
/// by optional clinical fields or network latency.
class EmergencyQuickReferralScreen extends StatefulWidget {
  final EmergencyCategory? initialCategory;
  final String? initialComplaint;
  final String? patientName;
  final int? patientAge;
  final String? patientSex;

  const EmergencyQuickReferralScreen({
    super.key,
    this.initialCategory,
    this.initialComplaint,
    this.patientName,
    this.patientAge,
    this.patientSex,
  });

  @override
  State<EmergencyQuickReferralScreen> createState() => _EmergencyQuickReferralScreenState();
}

class _EmergencyQuickReferralScreenState extends State<EmergencyQuickReferralScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _referralId;

  // Controllers
  late final TextEditingController _patientIdCtrl;
  late final TextEditingController _patientNameCtrl;
  late final TextEditingController _patientAgeCtrl;
  late final TextEditingController _complaintCtrl;
  late final TextEditingController _vitalsPulseCtrl;
  late final TextEditingController _vitalsSysCtrl;
  late final TextEditingController _vitalsDiaCtrl;
  late final TextEditingController _vitalsSpo2Ctrl;
  late final TextEditingController _vitalsRespCtrl;
  late final TextEditingController _vitalsTempCtrl;
  late final TextEditingController _firstAidCtrl;
  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _medsCtrl;
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _etaCtrl;
  late final TextEditingController _overrideReasonCtrl;

  // Sex options
  static const List<String> _sexOptions = ['Male', 'Female', 'Other', 'Unknown'];

  static String _normalizeSex(String? sex) {
    if (sex == null) return 'Unknown';
    final s = sex.trim().toLowerCase();
    if (s == 'male') return 'Male';
    if (s == 'female') return 'Female';
    if (s == 'other') return 'Other';
    return 'Unknown';
  }

  // State
  late EmergencyCategory _selectedCategory;
  String _selectedSex = 'Unknown';
  String _consciousnessLevel = 'Alert';
  AmbulanceDispatchStatus _ambulanceStatus = AmbulanceDispatchStatus.requested;
  final Set<String> _selectedRedFlags = {};
  bool _isSaving = false;

  // Hospital Recommendations
  List<EmergencyHospitalRecommendation> _recommendations = [];
  EmergencyHospitalRecommendation? _selectedRecommendation;
  bool _isOverridden = false;

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _referralId = 'ER-${timestamp.substring(timestamp.length - 6)}';

    _selectedCategory = widget.initialCategory ?? EmergencyCategory.stemiCardiac;
    _selectedSex = _normalizeSex(widget.patientSex);

    _patientIdCtrl = TextEditingController(text: 'PT-${timestamp.substring(timestamp.length - 4)}');
    _patientNameCtrl = TextEditingController(text: widget.patientName ?? '');
    _patientAgeCtrl = TextEditingController(
      text: widget.patientAge != null ? widget.patientAge.toString() : '',
    );
    _complaintCtrl = TextEditingController(
      text: widget.initialComplaint ?? _getDefaultComplaint(_selectedCategory),
    );
    _vitalsPulseCtrl = TextEditingController();
    _vitalsSysCtrl = TextEditingController();
    _vitalsDiaCtrl = TextEditingController();
    _vitalsSpo2Ctrl = TextEditingController();
    _vitalsRespCtrl = TextEditingController();
    _vitalsTempCtrl = TextEditingController();
    _firstAidCtrl = TextEditingController();
    _allergiesCtrl = TextEditingController();
    _medsCtrl = TextEditingController();
    _vehicleCtrl = TextEditingController();
    _etaCtrl = TextEditingController(text: '15');
    _overrideReasonCtrl = TextEditingController();

    _loadRecommendations();
  }

  @override
  void didUpdateWidget(covariant EmergencyQuickReferralScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientSex != widget.patientSex) {
      setState(() {
        _selectedSex = _normalizeSex(widget.patientSex);
      });
    }
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _patientNameCtrl.dispose();
    _patientAgeCtrl.dispose();
    _complaintCtrl.dispose();
    _vitalsPulseCtrl.dispose();
    _vitalsSysCtrl.dispose();
    _vitalsDiaCtrl.dispose();
    _vitalsSpo2Ctrl.dispose();
    _vitalsRespCtrl.dispose();
    _vitalsTempCtrl.dispose();
    _firstAidCtrl.dispose();
    _allergiesCtrl.dispose();
    _medsCtrl.dispose();
    _vehicleCtrl.dispose();
    _etaCtrl.dispose();
    _overrideReasonCtrl.dispose();
    super.dispose();
  }

  String _getDefaultComplaint(EmergencyCategory cat) {
    switch (cat) {
      case EmergencyCategory.stemiCardiac:
        return 'Crushing chest pain radiating to jaw and left arm, diaphoresis';
      case EmergencyCategory.acuteStroke:
        return 'Acute unilateral facial droop, arm weakness, and severe dysarthria';
      case EmergencyCategory.polytrauma:
        return 'High-velocity road trauma, multiple fractures, active blood loss';
      case EmergencyCategory.severeRespiratory:
        return 'Severe acute respiratory distress, stridor, unable to complete sentences';
      case EmergencyCategory.septicShock:
        return 'High fever, altered sensorium, profound hypotension, hypoperfusion';
      case EmergencyCategory.postpartumHemorrhage:
        return 'Excessive postpartum uterine bleeding, tachycardia, dizziness';
      case EmergencyCategory.pediatricEmergency:
        return 'Pediatric severe dehydration, lethargy, respiratory retraction';
      case EmergencyCategory.acuteAbdomen:
        return 'Acute board-like abdominal rigidity, guarding, severe peritoneal pain';
      case EmergencyCategory.generalEmergency:
        return 'Acute clinical deterioration requiring immediate resuscitation';
    }
  }

  void _loadRecommendations() {
    final list = EmergencyReferralService.rankHospitalsForEmergency(_selectedCategory);
    setState(() {
      _recommendations = list;
      if (!_isOverridden || _selectedRecommendation == null) {
        _selectedRecommendation = list.firstWhere(
          (r) => r.meetsMandatoryCapability,
          orElse: () => list.first,
        );
      }
    });
  }

  Future<void> _submitReferral() async {
    if (_isSaving) return;

    final complaint = _complaintCtrl.text.trim();
    if (complaint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least a brief presenting complaint.'),
          backgroundColor: AppColors.statusRed,
        ),
      );
      return;
    }

    final targetHospital = _selectedRecommendation?.hospital ?? IndoreHospitalDataset.facility01;

    setState(() => _isSaving = true);

    final ref = EmergencyReferral(
      referralId: _referralId,
      patientIdentifier: _patientIdCtrl.text.trim().isNotEmpty
          ? _patientIdCtrl.text.trim()
          : 'UNKNOWN_${DateTime.now().millisecondsSinceEpoch % 10000}',
      patientName: _patientNameCtrl.text.trim().isNotEmpty ? _patientNameCtrl.text.trim() : null,
      patientAge: int.tryParse(_patientAgeCtrl.text.trim()),
      patientSex: _selectedSex,
      presentingComplaint: complaint,
      emergencyCategory: _selectedCategory,
      redFlagSymptoms: _selectedRedFlags.toList(),
      symptomOnsetTime: 'Within last 60 minutes',
      vitalsPulse: int.tryParse(_vitalsPulseCtrl.text.trim()),
      vitalsBpSystolic: int.tryParse(_vitalsSysCtrl.text.trim()),
      vitalsBpDiastolic: int.tryParse(_vitalsDiaCtrl.text.trim()),
      vitalsSpo2: int.tryParse(_vitalsSpo2Ctrl.text.trim()),
      vitalsRespRate: int.tryParse(_vitalsRespCtrl.text.trim()),
      vitalsTemp: double.tryParse(_vitalsTempCtrl.text.trim()),
      consciousnessLevel: _consciousnessLevel,
      immediateTreatmentGiven: _firstAidCtrl.text.trim().isNotEmpty ? _firstAidCtrl.text.trim() : null,
      allergies: _allergiesCtrl.text.trim().isNotEmpty ? _allergiesCtrl.text.trim() : null,
      medicationsHistory: _medsCtrl.text.trim().isNotEmpty ? _medsCtrl.text.trim() : null,
      ambulanceStatus: _ambulanceStatus,
      ambulanceDispatchTime: _ambulanceStatus != AmbulanceDispatchStatus.notDispatched ? DateTime.now() : null,
      ambulanceVehicleNumber: _vehicleCtrl.text.trim().isNotEmpty ? _vehicleCtrl.text.trim() : null,
      ambulanceEtaMinutes: int.tryParse(_etaCtrl.text.trim()),
      referringClinicianId: 'DOC-IND-702',
      referringClinicianName: 'Dr. Parth Saxena',
      referringFacilityName: 'Sanwer Community Health Centre (CHC)',
      referringCallbackPhone: '+91 98260 12345',
      receivingFacilityId: targetHospital.hospitalId,
      receivingFacilityName: targetHospital.name,
      receivingDepartment: _selectedCategory.departmentTarget,
      recommendationOverrideReason: _isOverridden && _overrideReasonCtrl.text.trim().isNotEmpty
          ? _overrideReasonCtrl.text.trim()
          : null,
      currentVersion: 1,
      workflowStatus: EmergencyWorkflowStatus.emergencyCreated,
      deliveryStatus: EmergencyDeliveryStatus.notSent,
      responseStatus: ReceivingResponseStatus.noResponseYet,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final saved = await EmergencyReferralRepository.instance.createEmergencyReferral(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Emergency Referral ${saved.referralId} created successfully!'),
                ),
              ],
            ),
            backgroundColor: AppColors.statusGreen,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmergencyReferralDetailScreen(referralId: saved.referralId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally. Backend sync will continue in background ($e)'),
            backgroundColor: AppColors.statusAmber,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF991B1B), // Urgent Deep Crimson
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Quick Referral',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Ref: $_referralId • Rapid Triage',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Instant 108 Emergency Call Action
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => EmergencyReferralService.launchAmbulanceCall(),
              icon: const Icon(Icons.phone_in_talk, size: 16, color: Color(0xFF991B1B)),
              label: const Text(
                'DIAL 108',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF991B1B),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Safety Banner
            _buildSafetyBanner(),
            const SizedBox(height: 16),

            // 1. Ambulance Dispatch Control Section
            _buildAmbulanceDispatchCard(),
            const SizedBox(height: 16),

            // 2. Patient Demographics & Presenting Emergency
            _buildClinicalEmergencyCard(),
            const SizedBox(height: 16),

            // 3. Vitals & Conscious State (Optional / Rapid)
            _buildVitalsCard(),
            const SizedBox(height: 16),

            // 4. Pre-hospital First Aid & History
            _buildFirstAidCard(),
            const SizedBox(height: 16),

            // 5. 3-Pillar Destination Hospital Recommendation
            _buildDestinationHospitalCard(),
            const SizedBox(height: 24),

            // 6. Action Button
            _buildSubmitButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'PATIENT SAFETY RULE: Dispatch the ambulance immediately. '
              'Referral documentation, network sync, or incomplete details must NEVER delay urgent patient transport or treatment.',
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceDispatchCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.airport_shuttle, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambulance Dispatch Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Record real-time transport response',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Segmented Status Choices
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AmbulanceDispatchStatus.values.map((status) {
                final isSelected = _ambulanceStatus == status;
                Color activeColor;
                switch (status) {
                  case AmbulanceDispatchStatus.notDispatched:
                    activeColor = const Color(0xFF64748B);
                    break;
                  case AmbulanceDispatchStatus.requested:
                    activeColor = const Color(0xFFD97706);
                    break;
                  case AmbulanceDispatchStatus.enRouteScene:
                    activeColor = const Color(0xFF0284C7);
                    break;
                  case AmbulanceDispatchStatus.patientLoadedInTransit:
                    activeColor = const Color(0xFF16A34A);
                    break;
                  case AmbulanceDispatchStatus.arrived:
                    activeColor = const Color(0xFF0D7A68);
                    break;
                }

                return ChoiceChip(
                  label: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: activeColor,
                  backgroundColor: const Color(0xFFF1F5F9),
                  onSelected: (val) {
                    if (val) setState(() => _ambulanceStatus = status);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _vehicleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ambulance Reg / ID (Optional)',
                      hintText: 'e.g. MP-09-EM-1084',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _etaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ETA (Mins)',
                      hintText: '15',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalEmergencyCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.health_and_safety, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient & Emergency Condition',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Minimum essential clinical information',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Emergency Category Selection Dropdown
            DropdownButtonFormField<EmergencyCategory>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Emergency Condition Category *',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.medical_services, color: Color(0xFFDC2626)),
              ),
              items: EmergencyCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(
                    cat.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (cat) {
                if (cat != null) {
                  setState(() {
                    _selectedCategory = cat;
                    _complaintCtrl.text = _getDefaultComplaint(cat);
                  });
                  _loadRecommendations();
                }
              },
            ),
            const SizedBox(height: 12),

            // Patient Identifiers
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _patientIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Patient Identifier / ID *',
                      hintText: 'PT-1042',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _patientNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Patient Name (If known)',
                      hintText: 'e.g. Ramesh Verma',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _patientAgeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age (Yrs)',
                      hintText: '48',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _sexOptions.contains(_selectedSex) ? _selectedSex : 'Unknown',
                    decoration: const InputDecoration(
                      labelText: 'Sex',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _sexOptions.map((sex) {
                      return DropdownMenuItem<String>(
                        value: sex,
                        child: Text(sex),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedSex = v ?? 'Unknown'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Presenting Complaint
            TextField(
              controller: _complaintCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Presenting Complaint / Clinical Impression *',
                hintText: 'Describe acute symptoms and onset...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Red Flag Symptoms Chips
            const Text(
              'Red Flag Symptoms (Select all that apply):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'Crushing Chest Pain',
                'Loss of Consciousness',
                'Unilateral Weakness / Slurred Speech',
                'Cyanosis / Severe Dyspnea',
                'Severe Active Hemorrhage',
                'Hypotension / Weak Pulse',
                'Seizure Activity',
                'Rigid Abdomen',
              ].map((flag) {
                final isSelected = _selectedRedFlags.contains(flag);
                return FilterChip(
                  label: Text(
                    flag,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFDC2626),
                  backgroundColor: const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedRedFlags.add(flag);
                      } else {
                        _selectedRedFlags.remove(flag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.monitor_heart, color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vital Signs & Neurological Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'All vitals optional — can be recorded en route',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Vitals row 1: Pulse, BP Systolic/Diastolic
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vitalsPulseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pulse (bpm)',
                      hintText: '88',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _vitalsSysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'BP Sys',
                      hintText: '120',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _vitalsDiaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'BP Dia',
                      hintText: '80',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Vitals row 2: SpO2, Resp, Temp
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vitalsSpo2Ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'SpO2 (%)',
                      hintText: '96',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _vitalsRespCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Resp Rate (/m)',
                      hintText: '18',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _vitalsTempCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Temp (°C)',
                      hintText: '37.0',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // AVPU Consciousness scale
            const Text(
              'Consciousness Level (AVPU Scale):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['Alert', 'Voice', 'Pain', 'Unresponsive'].map((level) {
                final isSelected = _consciousnessLevel == level;
                return ChoiceChip(
                  label: Text(
                    level,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: level == 'Alert'
                      ? const Color(0xFF16A34A)
                      : (level == 'Unresponsive' ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  onSelected: (val) {
                    if (val) setState(() => _consciousnessLevel = level);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstAidCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.healing, color: Color(0xFF16A34A), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pre-hospital Care & Background',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Immediate treatment given before or during transit',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _firstAidCtrl,
              decoration: const InputDecoration(
                labelText: 'Immediate Treatment Administered',
                hintText: 'e.g. O2 4L/min, IV fluid bolus, Aspirin 300mg, wound dressing...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allergiesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Known Allergies',
                      hintText: 'e.g. Penicillin, NSAIDs (or NKDA)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _medsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Current Medications',
                      hintText: 'e.g. Metformin, Amlodipine',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationHospitalCard() {
    final top = _selectedRecommendation;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: top?.meetsMandatoryCapability == true ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: top?.meetsMandatoryCapability == true ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    color: top?.meetsMandatoryCapability == true ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Destination Hospital Recommendation',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'P1: Capability → P2: Availability → P3: Distance',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _showHospitalPickerModal,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),

            if (top != null) ...[
              Text(
                top.hospital.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                top.hospital.address,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),

              // 3-Pillar Capability Badges
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: top.meetsMandatoryCapability ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          top.meetsMandatoryCapability ? Icons.verified : Icons.warning_amber,
                          size: 14,
                          color: top.meetsMandatoryCapability ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          top.meetsMandatoryCapability
                              ? 'Capability: ${top.capabilityScore}% Matched'
                              : 'Lacks Required Capabilities',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: top.meetsMandatoryCapability ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '~${top.distanceKm.toStringAsFixed(1)} km (~${top.estimatedTransitMinutes}m transit)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Target: ${_selectedCategory.departmentTarget}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                'Clinical Rationale: ${top.matchRationale}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
              ),

              if (_isOverridden) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Selection Override',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _overrideReasonCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Reason for selecting this facility (e.g. proximity for airway control)...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showHospitalPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment, color: Color(0xFF0D7A68)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Select Receiving Facility (45 Facilities)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: _recommendations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final rec = _recommendations[index];
                      final isSelected = _selectedRecommendation?.hospital.hospitalId == rec.hospital.hospitalId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFE6F5F2),
                        leading: CircleAvatar(
                          backgroundColor: rec.meetsMandatoryCapability ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          child: Icon(
                            rec.meetsMandatoryCapability ? Icons.check : Icons.warning_amber,
                            color: rec.meetsMandatoryCapability ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          rec.hospital.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${rec.meetsMandatoryCapability ? "Fully Equipped" : "Inadequate for ${rec.meetsMandatoryCapability ? "" : _selectedCategory.name}"} • ~${rec.distanceKm.toStringAsFixed(1)} km (~${rec.estimatedTransitMinutes} mins)',
                          style: TextStyle(
                            fontSize: 12,
                            color: rec.meetsMandatoryCapability ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF0D7A68)) : null,
                        onTap: () {
                          setState(() {
                            _selectedRecommendation = rec;
                            _isOverridden = true;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _submitReferral,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626), // High-urgency crimson
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isSaving
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('SAVING & INITIATING DISPATCH...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flash_on, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'CREATE & DISPATCH REFERRAL',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
      ),
    );
  }
}
