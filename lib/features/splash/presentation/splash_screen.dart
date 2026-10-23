import 'package:flutter/material.dart';
import '../../../core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../business/providers/business_provider.dart';

import 'package:go_router/go_router.dart';

/// Branded splash screen shown only on cold app startup.
///
/// Animation sequence (~2s total):
/// 1. Logo starts at 0.8x scale, 0 opacity
/// 2. Fade in (0→1) over 600ms
/// 3. Scale up (0.8→1.0) over 800ms
/// 4. Hold for 400ms
/// 5. Fade transition to auth-determined route
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleUp;
  late final Animation<double> _fadeOut;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Logo entrance: 800ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeIn = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );

    _scaleUp = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    // Fade out: 400ms
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    // Small initial delay for smooth startup
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Play logo entrance
    await _logoController.forward();
    if (!mounted) return;

    // Hold
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Fade out
    await _fadeOutController.forward();
    if (!mounted) return;

    // Navigate
    _navigate();
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final authState = ref.read(authStateProvider);
    final user = authState.value;

    if (user == null) {
      context.go('/login');
    } else {
      final businessState = ref.read(currentBusinessProvider);
      final hasBusiness = businessState.value != null;
      context.go(hasBusiness ? '/dashboard' : '/business-setup');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.splashBg,
      body: FadeTransition(
        opacity: _fadeOut,
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: ScaleTransition(
              scale: _scaleUp,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  AppLogo(size: 120),
                  const SizedBox(height: 24),
                  // App name
                  Text(
                    'Multi Business Billing',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withAlpha(230),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage. Bill. Grow.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withAlpha(130),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
