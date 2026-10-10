import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';

/// Password Recovery Screen for Doctors and Clinic Staff.
/// Discloses that live automated password reset requires Firebase Authentication configuration.
class ForgotPasswordScreen extends StatefulWidget {
  final AuthService authService;
  final String initialIdentifier;

  ForgotPasswordScreen({
    super.key,
    AuthService? authService,
    this.initialIdentifier = '',
  }) : authService = authService ?? LocalDemoAuthService.instance;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;

  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _isError = false;
    });

    final result = await widget.authService.sendPasswordReset(
      _identifierController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _statusMessage = result.message;
      _isError = !result.isSuccess;
    });
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
              title: 'Password Recovery',
              subtitle: 'Doctor Account Access',
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
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Security Shield Icon
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLightMint,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  size: 32,
                                  color: AppColors.primaryDarkGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Reset Healthcare Account Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textNavyPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),

                            const Text(
                              'Enter your registered medical email or mobile number to receive account recovery instructions.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textNavyMuted,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),

                            AuthTextField(
                              label: 'Registered Clinical Email or Mobile',
                              hintText: 'e.g. dr.sharma@gmail.com or 9876543210',
                              controller: _identifierController,
                              prefixIcon: Icons.badge_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your registered email or mobile number.';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 18),

                            // Status / Feedback Box
                            if (_statusMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isError
                                      ? AppColors.statusAmber.withValues(alpha: 0.12)
                                      : AppColors.primaryLightMint,
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                  border: Border.all(
                                    color: _isError
                                        ? AppColors.statusAmber.withValues(alpha: 0.5)
                                        : AppColors.primaryGreen,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _isError ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: _isError ? AppColors.statusAmber : AppColors.primaryDarkGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isError ? 'Notice' : 'Recovery Dispatched',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _isError ? AppColors.textNavyPrimary : AppColors.primaryDarkGreen,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _statusMessage!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textNavySecondary,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Submit Button
                            PrimaryButton(
                              text: _isLoading ? 'Checking Dispatch Route...' : 'Send Password Recovery Link',
                              icon: Icons.send_rounded,
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _handlePasswordReset,
                            ),
                            const SizedBox(height: 14),

                            SecondaryButton(
                              text: 'Return to Sign In',
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(height: 16),

                            // Hospital IT Helpdesk memo
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMutedLight,
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                              ),
                              child: const Text(
                                'Rural Clinic Tip: In clinical environments without internet access, contact your District Health Officer (DHO) or Hospital IT Coordinator for on-site credential provisioning.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textNavyMuted,
                                  fontStyle: FontStyle.italic,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
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
