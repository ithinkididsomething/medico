import 'package:flutter/material.dart';
import '../../core/animations/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../navigation/app_navigation.dart';

/// Premium animated splash screen for MEDICO.
///
/// Features:
/// - Smooth logo scale-up and fade-in
/// - Concentric pulsating life ripples around the medical emblem
/// - Gentle upward slide & fade for title and clinical tagline
/// - System status telemetry indicator
/// - Automatic smooth transition via [MedicoScaleFadeRoute]
/// - Tap to skip immediately
class SplashScreen extends StatefulWidget {
  final String nextRoute;
  final AuthService? authService;
  final Duration duration;
  final Widget? targetScreen;

  const SplashScreen({
    super.key,
    this.nextRoute = '/login',
    this.authService,
    this.targetScreen,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _ripple1;
  late final Animation<double> _ripple2;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _footerFade;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 1. Logo emergence (0.0 -> 0.45)
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // 2. Glowing pulse / concentric ripples (0.15 -> 0.75)
    _ripple1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _ripple2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Title & tagline entrance (0.35 -> 0.75)
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Footer telemetry & loader (0.65 -> 1.0)
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.95, curve: Curves.easeIn),
      ),
    );

    if (AppMotion.isTestEnvironment()) {
      _controller.value = 1.0;
    } else {
      _controller.forward().then((_) => _navigateToNext());
    }
  }

  void _navigateToNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    final target = widget.targetScreen ??
        (widget.nextRoute == '/dashboard'
            ? const MainNavigationScreen()
            : LoginScreen(authService: widget.authService));

    Navigator.of(context).pushReplacement(
      MedicoScaleFadeRoute(
        child: target,
        duration: AppMotion.durationMedium,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        onTap: _navigateToNext,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [
                      Color(0xFF0F172A),
                      Color(0xFF090E17),
                    ]
                  : const [
                      Color(0xFFF0FDF4), // Very soft mint white
                      Color(0xFFF8FAFC), // Slate clean surface
                    ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric Glowing Pulse Ripples behind Logo
                    _buildRipple(_ripple1.value, 160.0),
                    _buildRipple(_ripple2.value, 210.0),

                    // Center Content (Logo + Title + Tagline)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Emblem
                        Opacity(
                          opacity: _logoFade.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: _buildLogoBadge(isDark),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Animated Typography
                        Opacity(
                          opacity: _textFade.value,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'MEDICO',
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4.0,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textNavyPrimary,
                                      ),
                                    ),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(left: 6, bottom: 12),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Clinical Referral Decision-Support System',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : AppColors.secondarySlateTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Bottom Telemetry & Status Indicator
                    Positioned(
                      bottom: 32,
                      child: Opacity(
                        opacity: _footerFade.value,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Indore Metropolitan Grid • v2.4 Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : AppColors.textNavySecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 140,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: _controller.value,
                                  minHeight: 2.5,
                                  backgroundColor: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRipple(double progress, double maxDiameter) {
    if (progress <= 0.0) return const SizedBox.shrink();

    final currentDiameter = 80.0 + (maxDiameter - 80.0) * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.45;

    return Container(
      width: currentDiameter,
      height: currentDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: opacity),
          width: 2.0,
        ),
      ),
    );
  }

  Widget _buildLogoBadge(bool isDark) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.local_hospital_rounded,
          color: Colors.white,
          size: 54,
        ),
      ),
    );
  }
}
