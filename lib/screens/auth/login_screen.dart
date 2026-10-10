import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../navigation/app_navigation.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import 'doctor_registration_screen.dart';
import 'forgot_password_screen.dart';
import 'registration_screen.dart';

/// Clinical Authentication Screen for Doctors and Medical Officers.
/// Designed for clinic and hospital decision-support environments.
class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onLoginSuccess;

  LoginScreen({
    super.key,
    AuthService? authService,
    this.onLoginSuccess,
  }) : authService = authService ?? LocalDemoAuthService.instance;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please enter registered email or mobile number.';
    }
    final isEmail = text.contains('@');
    if (isEmail) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(text)) {
        return 'Please enter a valid clinical email address.';
      }
    } else {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10) {
        return 'Please enter a valid 10-digit mobile number.';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Password is required.';
    }
    if (text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  Future<void> _handleSignIn({bool isQuickSignIn = false}) async {
    if (_isLoading) return; // Prevent duplicate submissions

    if (!isQuickSignIn) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final identifier = isQuickSignIn
        ? 'dr.parth.saxena@gmail.com'
        : _identifierController.text.trim();
    final password = isQuickSignIn ? 'Doctor@123' : _passwordController.text;

    final result = await widget.authService.signIn(
      identifier: identifier,
      password: password,
      role: UserRole.doctor,
      rememberMe: _rememberMe,
      isDemo: isQuickSignIn,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (ctx) => const MainNavigationScreen(),
            settings: const RouteSettings(name: '/dashboard'),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Authentication failed. Please verify credentials.';
      });
    }
  }

  void _showPolicyDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.secondarySlateTeal, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textNavySecondary),
          ),
        ),
        actions: [
          PrimaryButton(
            text: 'I Acknowledge',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideTablet = screenWidth >= 850;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: isWideTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  // Mobile layout: Compact single column scrollable
  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg, vertical: 20),
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildFormCard(),
              const SizedBox(height: 20),
              _buildMedicalDisclaimerAndFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // Tablet layout: Centered card or two-column split
  Widget _buildTabletLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 880),
          child: AppCard(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Branding, Clinical Value, Security Notice
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 32, top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isTabletLeft: true),
                        const SizedBox(height: 24),
                        _buildFeaturePills(),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F1E36), Color(0xFF133E4A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F1E36).withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'REGIONAL HEALTH NETWORK',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Indore Emergency Triage & Referral Gateway',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Connecting 45 empanelled medical facilities with real-time capacity and disease acuity protocols.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 440,
                  color: AppColors.borderLight,
                ),
                // Right Column: Login Form
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFormCard(isEmbeddedInTablet: true),
                        const SizedBox(height: 16),
                        _buildMedicalDisclaimerAndFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool isTabletLeft = false}) {
    return Column(
      crossAxisAlignment: isTabletLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Healthcare Shield Icon Badge
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryLightMint,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.primaryDarkGreen,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // App Name
        Text(
          'MEDICO',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textNavyPrimary,
            letterSpacing: 1.0,
          ),
          textAlign: isTabletLeft ? TextAlign.left : TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Tagline
        Text(
          '"The right care. The right hospital. At the right time."',
          style: const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: AppColors.secondarySlateTeal,
          ),
          textAlign: isTabletLeft ? TextAlign.left : TextAlign.center,
        ),
        const SizedBox(height: 6),

        // Subtitle
        Text(
          'Secure access for healthcare professionals.',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textNavyMuted,
          ),
          textAlign: isTabletLeft ? TextAlign.left : TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeaturePills() {
    return Column(
      children: [
        _buildFeatureItem(Icons.verified_user_outlined, 'Clinician Decision-Support Gateway'),
        const SizedBox(height: 10),
        _buildFeatureItem(Icons.offline_pin_outlined, 'Offline-First Local Health Post Synchronization'),
        const SizedBox(height: 10),
        _buildFeatureItem(Icons.local_hospital_outlined, 'Smart Referral Matching with Bed & ICU Telemetry'),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryLightMint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryDarkGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textNavySecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard({bool isEmbeddedInTablet = false}) {
    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error Message Display
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.statusRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusRed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Login Fields
          AuthTextField(
            label: 'Registered Medical Email or Mobile',
            hintText: 'e.g. dr.sharma@gmail.com or 9876543210',
            controller: _identifierController,
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateIdentifier,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),

          AuthTextField(
            label: 'Password',
            hintText: 'Enter your password',
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
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            ),
          ),
          const SizedBox(height: 8),

          // Remember Me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.primaryGreen,
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              setState(() => _rememberMe = val ?? false);
                            },
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() => _rememberMe = !_rememberMe);
                          },
                    child: const Text(
                      'Remember me',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textNavySecondary),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordScreen(
                              authService: widget.authService,
                              initialIdentifier: _identifierController.text.trim(),
                            ),
                          ),
                        );
                      },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondarySlateTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Sign In Button
          PrimaryButton(
            text: _isLoading ? 'Signing In...' : 'Sign In',
            icon: Icons.login_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () => _handleSignIn(),
          ),
          const SizedBox(height: 10),

          // Quick Access Button
          SecondaryButton(
            text: 'Quick Sign In (Dr. Parth Saxena)',
            icon: Icons.bolt_rounded,
            onPressed: _isLoading ? null : () => _handleSignIn(isQuickSignIn: true),
          ),
          const SizedBox(height: 12),

          // Register as a Doctor (Regulatory Onboarding) Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              foregroundColor: AppColors.primaryDarkGreen,
              backgroundColor: AppColors.primaryLightMint.withValues(alpha: 0.5),
              side: const BorderSide(color: AppColors.primaryGreen, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
            ),
            icon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.primaryGreen),
            label: const Text(
              'Register as a Doctor',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DoctorRegistrationScreen(
                          onRegistrationSuccess: widget.onLoginSuccess,
                        ),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 14),

          // Create Account Link (Existing User Flow)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              const Text(
                'New doctor or medical officer? ',
                style: TextStyle(fontSize: 12, color: AppColors.textNavySecondary),
              ),
              InkWell(
                onTap: _isLoading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RegistrationScreen(
                              authService: widget.authService,
                              onRegistered: () {
                                if (widget.onLoginSuccess != null) {
                                  widget.onLoginSuccess!();
                                } else {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (ctx) => const MainNavigationScreen(),
                                      settings: const RouteSettings(name: '/dashboard'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkGreen,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isEmbeddedInTablet) {
      return formContent;
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: formContent,
    );
  }

  Widget _buildMedicalDisclaimerAndFooter() {
    return Column(
      children: [
        const Text(
          'MEDICO is a clinical decision-support tool. It supports healthcare professionals and does not replace professional medical judgment.',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textNavyMuted,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildFooterLinks(),
      ],
    );
  }

  Widget _buildFooterLinks() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        InkWell(
          onTap: () => _showPolicyDialog(
            'Privacy Policy',
            'MEDICO operates in compliance with health data privacy guidelines. '
            'Patient identifying tokens are stored locally on-device and minimal clinical indicators are shared during referral dispatch. '
            'Protected Health Information (PHI) is encrypted and never sold or shared with non-authorized commercial entities.',
          ),
          child: const Text(
            'Privacy Policy',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyMuted),
          ),
        ),
        const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted)),
        InkWell(
          onTap: () => _showPolicyDialog(
            'Terms of Use',
            'MEDICO provides algorithmic matching and clinical referral triage guidance based on standard healthcare protocols (WHO IMAI). '
            'All triage suggestions and hospital match rankings must be corroborated by attending medical personnel prior to transit dispatch.',
          ),
          child: const Text(
            'Terms of Use',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyMuted),
          ),
        ),
        const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted)),
        Text(
          'Version ${AppConstants.appVersion}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textNavyMuted),
        ),
      ],
    );
  }
}
