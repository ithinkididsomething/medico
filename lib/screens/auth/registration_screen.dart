import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import 'doctor_registration_screen.dart';

/// Clinical Registration Screen for Medical Practitioners and Doctors.
/// Captures verified medical credentials and facility affiliations with regulatory disclosures.
class RegistrationScreen extends StatefulWidget {
  final AuthService authService;
  final UserRole initialRole;
  final VoidCallback? onRegistered;

  RegistrationScreen({
    super.key,
    AuthService? authService,
    this.initialRole = UserRole.doctor,
    this.onRegistered,
  }) : authService = authService ?? LocalDemoAuthService.instance;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _medicalRegController = TextEditingController();
  final _affiliationController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _medicalRegController.dispose();
    _affiliationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? val, String fieldName) {
    if (val == null || val.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  String? _validateEmail(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(text)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePhone(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Mobile number is required.';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Enter a valid 10-digit mobile number.';
    }
    return null;
  }

  String? _validatePassword(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Password is required.';
    if (text.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String? _validateConfirmPassword(String? val) {
    if (val == null || val.isEmpty) return 'Please confirm password.';
    if (val != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _handleRegistration() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.authService.registerDoctor(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      medicalRegNumber: _medicalRegController.text.trim(),
      hospitalAffiliation: _affiliationController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          title: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: AppColors.statusAmber, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Registration Submitted',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account created for ${result.user?.fullName}.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textNavyPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Status: Pending Credential Verification\n\n'
                  'Your registration has been submitted. '
                  'Professional medical credentials will be validated against state medical council records.',
                  style: TextStyle(fontSize: 11, color: AppColors.textNavySecondary, height: 1.4),
                ),
              ),
            ],
          ),
          actions: [
            PrimaryButton(
              text: 'Continue to Application',
              onPressed: () {
                Navigator.of(ctx).pop();
                if (widget.onRegistered != null) {
                  widget.onRegistered!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Registration could not be completed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            AppHeader(
              title: 'Account Registration',
              subtitle: 'Doctor Credentialing & Registration',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back to Sign In',
              ),
              showClinicStatusBar: false,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Doctor Switch Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLightMint.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                border: Border.all(color: AppColors.primaryGreen, width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.badge_outlined, color: AppColors.primaryGreen, size: 22),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Doctor Regulatory Onboarding',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDarkGreen),
                                        ),
                                        Text(
                                          'Includes Council verification, document vault, and normalized scoring.',
                                          style: TextStyle(fontSize: 10.5, color: AppColors.textNavyMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      foregroundColor: AppColors.primaryDarkGreen,
                                      side: const BorderSide(color: AppColors.primaryGreen),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute<void>(
                                          builder: (_) => DoctorRegistrationScreen(
                                            onRegistrationSuccess: widget.onRegistered,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Doctor Form', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Credentialing Notice Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMutedLight,
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.verified_user_outlined, size: 18, color: AppColors.secondarySlateTeal),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Doctor Credentialing Notice: Registered medical qualifications are audited against state medical council records. Submitting this form registers an account in pending verification status.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textNavySecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Error Message
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.statusRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                  border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusRed),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Doctor Registration Fields
                            AuthTextField(
                              label: 'Doctor Full Name',
                              hintText: 'e.g. Dr. Ramesh Kumar',
                              controller: _fullNameController,
                              prefixIcon: Icons.person_outline_rounded,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => _validateRequired(v, 'Full name'),
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),

                            AuthTextField(
                              label: 'Medical Registration Number',
                              hintText: 'e.g. KMC-48291-B or NMC Reg ID',
                              controller: _medicalRegController,
                              prefixIcon: Icons.featured_play_list_outlined,
                              helperText: 'State Medical Council or National Medical Commission ID',
                              validator: (v) => _validateRequired(v, 'Medical registration number'),
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),

                            AuthTextField(
                              label: 'Hospital or Clinic Affiliation',
                              hintText: 'e.g. Taluk Community Clinic / PHC Sector 4',
                              controller: _affiliationController,
                              prefixIcon: Icons.local_hospital_outlined,
                              validator: (v) => _validateRequired(v, 'Hospital or clinic affiliation'),
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),

                            AuthTextField(
                              label: 'Registered Medical Email',
                              hintText: 'e.g. dr.sharma@gmail.com',
                              controller: _emailController,
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),

                            AuthTextField(
                              label: 'Official Mobile Number',
                              hintText: 'e.g. 9876543210 (10 digits)',
                              controller: _phoneController,
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: _validatePhone,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),

                            AuthTextField(
                              label: 'Create Account Password',
                              hintText: 'At least 6 characters',
                              controller: _passwordController,
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              validator: _validatePassword,
                              enabled: !_isLoading,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: AppColors.textNavyMuted,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                            AuthTextField(
                              label: 'Confirm Password',
                              hintText: 'Re-enter your password',
                              controller: _confirmPasswordController,
                              prefixIcon: Icons.lock_clock_outlined,
                              obscureText: _obscureConfirmPassword,
                              validator: _validateConfirmPassword,
                              enabled: !_isLoading,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: AppColors.textNavyMuted,
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Submit Button
                            PrimaryButton(
                              text: _isLoading
                                  ? 'Submitting Registration...'
                                  : 'Register Doctor Account',
                              icon: Icons.app_registration_rounded,
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _handleRegistration,
                            ),
                            const SizedBox(height: 12),

                            // Already have account
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Already registered? Return to Sign In',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondarySlateTeal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
