import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/petti_theme.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

/// Splash — first surface the user sees on app open.
///
/// Petti style: Marigold background (the brand color), Midnight paw mark,
/// Space Grotesk wordmark. Holds for 2s while we check auth, then routes to
/// home or login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _logoController.forward();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await authProvider.checkAuthStatus();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.marigold,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle radial brightening from upper-left — matches the icon's
            // pseudo-gradient and adds warmth to an otherwise flat brand color.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.6),
                    radius: 1.2,
                    colors: [
                      PettiColors.marigoldBright,
                      PettiColors.marigold,
                    ],
                  ),
                ),
              ),
            ),

            // Centered wordmark + paw.
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) => Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: 0.9 + 0.1 * _logoScale.value,
                        child: child,
                      ),
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 92,
                      color: PettiColors.midnight,
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s5),
                  Text(
                    'PetTrack',
                    style: PettiText.display().copyWith(
                      fontSize: 44,
                      color: PettiColors.midnight,
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s2),
                  Text(
                    'Tu mascota, siempre cerca',
                    style: PettiText.body().copyWith(
                      color: PettiColors.midnight.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Footer activity indicator + signature.
            Positioned(
              left: 0,
              right: 0,
              bottom: PettiSpacing.s7,
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        PettiColors.midnight.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s4),
                  Text(
                    'Hecho en Bogotá',
                    style: PettiText.meta().copyWith(
                      color: PettiColors.midnight.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
