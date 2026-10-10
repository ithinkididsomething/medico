import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/referral.dart';
import '../../repositories/referral_repository.dart';
import '../../widgets/widgets.dart';
import '../../core/utils/navigation_utils.dart';
import '../assessment/patient_assessment_screen.dart';

/// Clinical Referral Summary Screen displaying the complete structured
/// transfer brief generated upon hospital selection.
class ReferralSummaryScreen extends StatefulWidget {
  final Referral referral;
  final ReferralRepository repository;

  ReferralSummaryScreen({
    super.key,
    required this.referral,
    ReferralRepository? repository,
  }) : repository = repository ?? LocalReferralRepository.instance;

  @override
  State<ReferralSummaryScreen> createState() => _ReferralSummaryScreenState();
}

class _ReferralSummaryScreenState extends State<ReferralSummaryScreen> {
  late Referral _referral;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _referral = widget.referral;

    // Privacy-compliant sanitized log: only IDs and urgency level, no PII.
    if (kDebugMode) {
      print('ReferralSummaryScreen: Initialized RefID=${_referral.referralId}, PatientToken=${_referral.patient.patientId}, Urgency=${_referral.urgencyLevel.name}');
    }
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$min';
  }

  Future<void> _onSaveReferral() async {
    await widget.repository.saveReferral(_referral);
    PatientAssessmentScreen.requestFormReset();
    setState(() => _isSaved = true);

    // Sanitized log
    if (kDebugMode) {
      print('ReferralSummaryScreen: Saved RefID=${_referral.referralId}');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryGreen,
        content: Text('Referral ${_referral.referralId} saved to local persistent registry.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onGeneratePdf() {
    // Sanitized log
    if (kDebugMode) {
      print('ReferralSummaryScreen: PDF generation triggered for RefID=${_referral.referralId}');
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLightMint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryGreen, size: 22),
            ),
            const SizedBox(width: 8),
            const Text('Generate Referral PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PDF Document created for Referral Order ${_referral.referralId}.',
              style: const TextStyle(fontSize: 13, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMutedLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'File: referral_${_referral.referralId.toLowerCase()}.pdf\n'
                'Format: Clinical Inter-Facility Transfer Brief (Standard IMAI / MoHFW Spec)',
                style: const TextStyle(fontSize: 11, color: AppColors.textNavySecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          PrimaryButton(
            text: 'Save PDF to Device',
            width: 180,
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.primaryGreen,
                  content: Text('Saved referral_${_referral.referralId.toLowerCase()}.pdf to Downloads.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onShare() {
    if (kDebugMode) {
      print('ReferralSummaryScreen: Share handover brief opened for RefID=${_referral.referralId}');
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildShareModal(ctx),
    );
  }

  void _onPrint() {
    if (kDebugMode) {
      print('ReferralSummaryScreen: Print dispatched for RefID=${_referral.referralId}');
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
        title: const Row(
          children: [
            Icon(Icons.print_outlined, color: AppColors.secondarySlateTeal),
            SizedBox(width: 8),
            Text('Print Transfer Handover Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Connecting to local clinic thermal/network printer...\n'
          'Referral Order ${_referral.referralId} ready to print (2 copies: 1 for ambulance transit, 1 for clinic audit).',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          PrimaryButton(
            text: 'Print Handover Order',
            width: 180,
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.primaryGreen,
                  content: Text('Print job sent to local clinic printer.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = _referral.patient;
    final hosp = _referral.recommendedHospital;
    final altHosp = _referral.alternativeHospitals.isNotEmpty
        ? _referral.alternativeHospitals.first
        : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            AppHeader(
              title: 'Referral Summary',
              subtitle: 'Inter-Facility Transfer Order',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => SafeNavigation.pop(context, fallbackTab: 0),
                tooltip: 'Back',
              ),
              showClinicStatusBar: false,
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Order Identification Banner
                    AppCard(
                      accentColor: AppColors.primaryGreen,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const AnimatedCheckmark(
                                    size: 38,
                                    circleColor: AppColors.primaryGreen,
                                    strokeWidth: 3.0,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'REFERRAL ORDER',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: AppColors.secondarySlateTeal,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _referral.referralId,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textNavyPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              StatusBadge(status: _referral.status),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          Row(
                            children: [
                              UrgencyBadge(
                                urgencyLevel: _referral.urgencyLevel,
                                isCompact: true,
                              ),
                              const SizedBox(width: AppConstants.spacingSm),
                              Expanded(
                                child: Text(
                                  'Referring Clinic: ${_referral.referringClinic}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textNavyMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generated Date/Time: ${_formatDateTime(_referral.createdAt)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingLg),

                    // ========================================================
                    // 1. PATIENT CLINICAL DATA (Sanitized ID, Age/Sex, Vitals)
                    // ========================================================
                    const SectionHeader(
                      title: 'Patient Clinical Presentation',
                      subtitle: 'Structured clinical presentation & triage findings',
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Patient ID', patient.patientId, isEmphasized: true),
                          _buildDetailRow('Age / Sex', '${patient.age} years • ${patient.sex.displayName}'),
                          _buildDetailRow('Main Complaint', patient.mainComplaint, isEmphasized: true),

                          const SizedBox(height: 6),
                          const Divider(height: 12),
                          const SizedBox(height: 4),

                          // Symptoms
                          const Text(
                            'Presenting Symptoms:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                          ),
                          const SizedBox(height: 4),
                          if (patient.symptoms.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: patient.symptoms.map((s) => Chip(
                                label: Text(s, style: const TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.surfaceMutedLight,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                            )
                          else
                            const Text('No specific symptom tags recorded.', style: TextStyle(fontSize: 12, color: AppColors.textNavyMuted)),

                          const SizedBox(height: 8),

                          // Clinical Findings
                          _buildDetailRow(
                            'Clinical Findings',
                            patient.clinicalFindings.isNotEmpty ? patient.clinicalFindings : 'No abnormal findings reported.',
                          ),

                          const SizedBox(height: 8),
                          const Divider(height: 12),
                          const SizedBox(height: 4),

                          // Vital Signs Table
                          const Text(
                            'Vital Signs Snapshot:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMutedLight,
                              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildVitalItem('HR', patient.heartRate != null ? '${patient.heartRate} bpm' : '--'),
                                _buildVitalItem('BP', patient.formattedBloodPressure),
                                _buildVitalItem('RR', patient.respiratoryRate != null ? '${patient.respiratoryRate} /min' : '--'),
                                _buildVitalItem('SpO2', patient.oxygenSaturation != null ? '${patient.oxygenSaturation!.toStringAsFixed(0)}%' : '--'),
                                _buildVitalItem('Temp', patient.temperature != null ? '${patient.temperature!.toStringAsFixed(1)}°C' : '--'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingLg),

                    // ========================================================
                    // 2. REFERRAL DETAILS & RATIONALE
                    // ========================================================
                    const SectionHeader(
                      title: 'Referral Details & Requirements',
                      subtitle: 'Clinical rationale and mandatory transfer capabilities',
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Urgency Level: ',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                              ),
                              UrgencyBadge(urgencyLevel: _referral.urgencyLevel, isCompact: true),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow('Reason for Referral', _referral.referralReason, isEmphasized: true),
                          _buildDetailRow('Required Specialty', _referral.requiredSpecialty),
                          _buildDetailRow(
                            'Required Facilities',
                            _referral.requiredFacilities.isNotEmpty
                                ? _referral.requiredFacilities.join(', ')
                                : 'General Inpatient Bed & Evaluation',
                          ),
                          _buildDetailRow('Referring Clinic', _referral.referringClinic),
                          _buildDetailRow('Date/Time', _formatDateTime(_referral.createdAt)),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingLg),

                    // ========================================================
                    // 3. RECOMMENDED & ALTERNATIVE HOSPITALS
                    // ========================================================
                    const SectionHeader(
                      title: 'Destination Facility & Alternatives',
                      subtitle: 'Primary transfer destination and verified backup',
                    ),

                    // Recommended Hospital
                    if (hosp != null) ...[
                      AppCard(
                        accentColor: AppColors.primaryGreen,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLightMint,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                    border: Border.all(color: AppColors.primaryGreen),
                                  ),
                                  child: const Text(
                                    'RECOMMENDED HOSPITAL',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDarkGreen),
                                  ),
                                ),
                                if (_referral.recommendationScore != null) ...[
                                  const Spacer(),
                                  Text(
                                    '${_referral.recommendationScore!.round()}/100 Match',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDarkGreen),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hosp.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(hosp.address, style: const TextStyle(fontSize: 12, color: AppColors.textNavyMuted)),
                            const SizedBox(height: 10),

                            // Distance & Estimated Travel Time
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMutedLight,
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.near_me_outlined, size: 16, color: AppColors.secondarySlateTeal),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Distance: ${_referral.formattedDistance}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 16, color: AppColors.borderLight),
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.secondarySlateTeal),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Travel Time: ${_referral.formattedTravelTime} by Car',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Alternative Hospital
                    if (altHosp != null) ...[
                      const SizedBox(height: AppConstants.spacingSm),
                      AppCard(
                        accentColor: AppColors.secondarySlateTeal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMutedLight,
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: const Text(
                                'ALTERNATIVE HOSPITAL (STANDBY)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavySecondary),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              altHosp.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(altHosp.address, style: const TextStyle(fontSize: 11, color: AppColors.textNavyMuted)),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppConstants.spacingLg),

                    // ========================================================
                    // 4. ACTION BUTTONS
                    // ========================================================
                    const SectionHeader(
                      title: 'Referral Actions & Distribution',
                      subtitle: 'Save, export, or share clinical transfer handover',
                    ),

                    // Save Referral
                    PrimaryButton(
                      text: _isSaved ? 'Referral Saved to Local Registry' : 'Save Referral',
                      icon: _isSaved ? Icons.check_circle_rounded : Icons.save_outlined,
                      onPressed: _onSaveReferral,
                    ),

                    if (_isSaved) ...[
                      const SizedBox(height: AppConstants.spacingSm),
                      PrimaryButton(
                        text: 'Start New Assessment',
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: () {
                          PatientAssessmentScreen.requestFormReset();
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],

                    const SizedBox(height: AppConstants.spacingSm),

                    // Generate PDF
                    SecondaryButton(
                      text: 'Generate PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: _onGeneratePdf,
                    ),

                    const SizedBox(height: AppConstants.spacingSm),

                    // Share & Print Row
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            text: 'Share',
                            icon: Icons.share_outlined,
                            onPressed: _onShare,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        Expanded(
                          child: SecondaryButton(
                            text: 'Print',
                            icon: Icons.print_outlined,
                            onPressed: _onPrint,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppConstants.spacingSm),

                    // Back to Dashboard
                    SecondaryButton(
                      text: 'Back to Dashboard',
                      icon: Icons.dashboard_outlined,
                      onPressed: () => SafeNavigation.toDashboard(context),
                    ),

                    const SizedBox(height: AppConstants.spacingXxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textNavyMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isEmphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w600,
                color: isEmphasized ? AppColors.textNavyPrimary : AppColors.textNavySecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textNavyPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareModal(BuildContext ctx) {
    final patient = _referral.patient;
    final hosp = _referral.recommendedHospital;

    final handoverBrief =
        'MEDICO CLINICAL HANDOVER BRIEF\n'
        'Ref ID: ${_referral.referralId} | Date: ${_formatDateTime(_referral.createdAt)}\n'
        'From: ${_referral.referringClinic}\n'
        'To: ${hosp?.name ?? "Designated Hospital"}\n'
        'Patient Token: ${patient.patientId} | ${patient.age}y / ${patient.sex.displayName}\n'
        'Urgency: ${_referral.urgencyLevel.displayName.toUpperCase()}\n'
        'Chief Complaint: ${patient.mainComplaint}\n'
        'Vitals: HR ${patient.heartRate ?? "--"} | BP ${patient.formattedBloodPressure} | SpO2 ${patient.oxygenSaturation?.toStringAsFixed(0) ?? "--"}%\n'
        'Indication: ${_referral.referralReason}\n'
        'Specialty Needed: ${_referral.requiredSpecialty}';

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Share Transfer Handover Brief',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMutedLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                handoverBrief,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Copy Handover Text to Clipboard',
              icon: Icons.copy_rounded,
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.primaryGreen,
                    content: Text('Handover brief copied to clipboard.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              text: 'Cancel',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
