import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/doctor_profile_data.dart';
import '../../services/doctor_profile_service.dart';
import '../../widgets/primary_button.dart';

/// Modal dialog for editing the currently logged-in doctor's profile
/// with robust client-side form validation.
class EditDoctorProfileDialog extends StatefulWidget {
  final DoctorProfileData currentProfile;

  const EditDoctorProfileDialog({
    super.key,
    required this.currentProfile,
  });

  static Future<bool?> show(BuildContext context, DoctorProfileData profile) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditDoctorProfileDialog(currentProfile: profile),
    );
  }

  @override
  State<EditDoctorProfileDialog> createState() => _EditDoctorProfileDialogState();
}

class _EditDoctorProfileDialogState extends State<EditDoctorProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _qualificationsController;
  late final TextEditingController _specializationController;
  late final TextEditingController _regNumberController;
  late final TextEditingController _councilController;
  late final TextEditingController _facilityController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _designationController;
  late final TextEditingController _emergencyContactController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.currentProfile;
    _nameController = TextEditingController(text: p.fullName);
    _qualificationsController = TextEditingController(text: p.qualifications);
    _specializationController = TextEditingController(text: p.specialization);
    _regNumberController = TextEditingController(text: p.medicalRegNumber);
    _councilController = TextEditingController(text: p.councilName);
    _facilityController = TextEditingController(text: p.clinicOrHospital);
    _emailController = TextEditingController(text: p.email);
    _phoneController = TextEditingController(text: p.phoneNumber);
    _designationController = TextEditingController(text: p.designation);
    _emergencyContactController = TextEditingController(text: p.emergencyContact);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qualificationsController.dispose();
    _specializationController.dispose();
    _regNumberController.dispose();
    _councilController.dispose();
    _facilityController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = widget.currentProfile.copyWith(
        fullName: _nameController.text.trim(),
        qualifications: _qualificationsController.text.trim(),
        specialization: _specializationController.text.trim(),
        medicalRegNumber: _regNumberController.text.trim().toUpperCase(),
        councilName: _councilController.text.trim(),
        clinicOrHospital: _facilityController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phoneNumber: _phoneController.text.trim(),
        designation: _designationController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim(),
      );

      await DoctorProfileService.instance.updateProfile(updated);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primaryLightMint,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Doctor Profile',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textNavyPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update credentials & practice details (Stored locally offline)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textNavyMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textNavyMuted),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Personal & Identity Details'),
                      const SizedBox(height: 10),

                      // Full Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Doctor Full Name *',
                          hintText: 'e.g. Dr. Parth Saxena',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Doctor full name is required.';
                          }
                          if (v.length < 3) {
                            return 'Name must be at least 3 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Current Designation
                      TextFormField(
                        controller: _designationController,
                        decoration: const InputDecoration(
                          labelText: 'Designation / Title *',
                          hintText: 'e.g. Senior Medical Officer & Triage Lead',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'Designation is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Medical Credentials & Qualifications'),
                      const SizedBox(height: 10),

                      // Qualifications
                      TextFormField(
                        controller: _qualificationsController,
                        decoration: const InputDecoration(
                          labelText: 'Medical Qualifications *',
                          hintText: 'e.g. MBBS, MD (General Medicine)',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Medical qualifications are required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Specialization
                      TextFormField(
                        controller: _specializationController,
                        decoration: const InputDecoration(
                          labelText: 'Specialization / Field *',
                          hintText: 'e.g. General Medicine & Emergency Triage',
                          prefixIcon: Icon(Icons.medical_services_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Specialization is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Registration Number
                      TextFormField(
                        controller: _regNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Medical Council Registration Number *',
                          hintText: 'e.g. MP-MED-2018-09428 or KMC-48291-B',
                          prefixIcon: Icon(Icons.verified_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Registration number is required.';
                          }
                          if (v.length < 4) {
                            return 'Registration number must be at least 4 alphanumeric characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Council Name
                      TextFormField(
                        controller: _councilController,
                        decoration: const InputDecoration(
                          labelText: 'State Medical Council *',
                          hintText: 'e.g. Madhya Pradesh Medical Council (NMC)',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'Council name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Affiliated Facility & Practice Base'),
                      const SizedBox(height: 10),

                      // Clinic / Hospital
                      TextFormField(
                        controller: _facilityController,
                        decoration: const InputDecoration(
                          labelText: 'Affiliated Clinic / Hospital *',
                          hintText: 'e.g. Primary Health Centre Sector 4',
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Affiliated hospital or clinic is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Contact Details'),
                      const SizedBox(height: 10),

                      // Official Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Official Email Address *',
                          hintText: 'e.g. dr.parth.saxena@gmail.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Email address is required.';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Primary Contact Mobile *',
                          hintText: 'e.g. 9876543210 or +91 98765 43210',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                          if (digits.isEmpty) {
                            return 'Mobile number is required.';
                          }
                          if (digits.length < 10) {
                            return 'Please enter a valid 10-digit mobile number.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Emergency On-Call Desk
                      TextFormField(
                        controller: _emergencyContactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Facility Emergency / Desk Contact',
                          hintText: 'e.g. +91 731 245 9901',
                          prefixIcon: Icon(Icons.phone_in_talk_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    text: _isSaving ? 'Saving Changes...' : 'Save Profile',
                    width: 160,
                    icon: _isSaving ? null : Icons.check_circle_outline_rounded,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textNavyPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
