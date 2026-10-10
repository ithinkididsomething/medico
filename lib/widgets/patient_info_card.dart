import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/patient.dart';
import 'app_card.dart';

/// Card summarizing patient presentation, demographics, and vital signs
/// with visual callouts for abnormal triage thresholds.
class PatientInfoCard extends StatelessWidget {
  final Patient patient;
  final Widget? trailingBadge;
  final VoidCallback? onTap;

  const PatientInfoCard({
    super.key,
    required this.patient,
    this.trailingBadge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Patient ${patient.patientId}, Age ${patient.age}, Sex ${patient.sex.displayName}. Complaint: ${patient.mainComplaint}',
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Patient ID, Age, Sex, & Optional Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryLightMint,
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.patientId,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textNavyPrimary,
                        ),
                      ),
                      Text(
                        '${patient.age} yrs • ${patient.sex.displayName} • ${patient.requiredSpecialty}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textNavyMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailingBadge,
              ],
            ),

            const SizedBox(height: AppConstants.spacingSm + 4),

            // Chief Complaint
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm + 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceMutedLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    size: 16,
                    color: AppColors.secondarySlateTeal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient.mainComplaint,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textNavyPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacingMd),

            // Vitals Grid / Wrap
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildVitalChip(
                  label: 'BP',
                  value: patient.formattedBloodPressure,
                  isAbnormal: patient.systolicBP != null && (patient.systolicBP! < 90 || patient.systolicBP! > 160),
                ),
                _buildVitalChip(
                  label: 'HR',
                  value: patient.heartRate != null ? '${patient.heartRate} bpm' : 'N/A',
                  isAbnormal: patient.heartRate != null && (patient.heartRate! < 50 || patient.heartRate! > 120),
                ),
                _buildVitalChip(
                  label: 'SpO2',
                  value: patient.oxygenSaturation != null ? '${patient.oxygenSaturation!.toStringAsFixed(0)}%' : 'N/A',
                  isAbnormal: patient.oxygenSaturation != null && patient.oxygenSaturation! < 92.0,
                ),
                _buildVitalChip(
                  label: 'RR',
                  value: patient.respiratoryRate != null ? '${patient.respiratoryRate}/min' : 'N/A',
                  isAbnormal: patient.respiratoryRate != null && (patient.respiratoryRate! < 12 || patient.respiratoryRate! > 28),
                ),
                _buildVitalChip(
                  label: 'Temp',
                  value: patient.temperature != null ? '${patient.temperature!.toStringAsFixed(1)}°C' : 'N/A',
                  isAbnormal: patient.temperature != null && (patient.temperature! < 35.5 || patient.temperature! > 38.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalChip({
    required String label,
    required String value,
    required bool isAbnormal,
  }) {
    final bgColor = isAbnormal ? AppColors.statusRedBg : AppColors.surfaceLight;
    final borderColor = isAbnormal ? AppColors.statusRed : AppColors.borderLight;
    final textColor = isAbnormal ? AppColors.statusRed : AppColors.textNavyPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isAbnormal ? AppColors.statusRed : AppColors.textNavyMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
