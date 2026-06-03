// Welcome / splash — Variation A "Barrio dorado" (design handoff 2026-05-20).
//
// Visual contract (matches /tmp/besti-design/.../app.jsx VariantSunny 1:1):
//   - Amber vertical gradient #F2BD5E → #E8A33D → #D88E1F
//   - Full-bleed BarrioMap SVG (assets/illustrations/welcome_barrio.svg)
//     covers the whole screen with rolling horizon ellipses, route trail,
//     houses, trees, ghost pins.
//   - "• BIENVENIDO A BESTI •" small label at the top, midnight @55%.
//   - Hero pin (the app icon, transparent-bg variant) heroed near the top
//     with a strong drop shadow.
//   - "Besti" wordmark (Nunito ExtraBold, 64pt, #1A2332) + tagline anchored
//     at the bottom of the screen.
//
// Behavioral contract (unchanged from the legacy splash):
//   - 2-second hold while we resolve auth state.
//   - Routes to PettiMainTabsScreen if signed in, otherwise LoginScreen.
//   - pushReplacement so back-swipe doesn't return to the welcome.
//
// The old "marigold flat bg + paw icon + spinner" layout has been retired.
// See /tmp/besti-design/petti-first-design-app-v1/chats/chat4.md for the
// design conversation and the user's final landing on Variation A.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'main/petti_main_tabs_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Subtle fade-in for the hero pin — the rest of the illustration appears
  // immediately so the screen feels alive on the very first paint.
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Design tokens lifted directly from the React handoff so future tweaks
  // are a 1-line change. NOT exposed via PettiColors because they're
  // intentionally specific to this one screen (the rest of the app uses
  // marigold/cream, not this 3-stop amber gradient).
  static const _navy = Color(0xFF0F1B2E);
  static const _wordmarkNavy = Color(0xFF1A2332);
  static const _gradTop = Color(0xFFF2BD5E);
  static const _gradMid = Color(0xFFE8A33D);
  static const _gradBottom = Color(0xFFD88E1F);

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
        builder: (_) =>
            isLoggedIn ? const PettiMainTabsScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background uses the same amber gradient even outside SafeArea so the
      // status-bar / home-indicator areas blend in.
      backgroundColor: _gradMid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.6, 1.0],
            colors: [_gradTop, _gradMid, _gradBottom],
          ),
        ),
        child: Stack(
          children: [
            // Full-bleed barrio illustration. xMidYMid slice on the SVG +
            // BoxFit.cover on flutter_svg means the centre of the SVG stays
            // anchored even when the device is taller than 874pt.
            Positioned.fill(
              child: SvgPicture.asset(
                'assets/illustrations/welcome_barrio.svg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),

            // Top label — sits inside SafeArea so the notch never overlaps.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    '•   BIENVENIDO A MY BESTI   •',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.5,
                      color: _navy.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),

            // Hero pin — sits above the BarrioMap's shadow ellipse.
            // The SVG places its drop-shadow at y=338 in a 874pt viewBox →
            // ~38.7% from the top. We align via fractional offset so the pin
            // hovers right over that shadow regardless of device aspect.
            Align(
              alignment: const Alignment(0.0, -0.45),
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * _logoScale.value,
                    child: child,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  // Transparent-bg pin so the amber gradient shows through
                  // around it (this is the same asset Android uses as its
                  // adaptive-icon foreground).
                  child: Image.asset(
                    'assets/icons/besti_icon_foreground.png',
                    width: 168,
                    height: 168,
                  ),
                ),
              ),
            ),

            // Wordmark + tagline anchored to the bottom of the canvas
            // (matches the handoff's marginTop:auto layout).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 64pt Nunito ExtraBold — the chat's final landing was
                      // "make it bolder" → weight 800, letterSpacing -2.6.
                      Text(
                        'My Besti',
                        style: GoogleFonts.nunito(
                          fontSize: 64,
                          height: 0.95,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2.6,
                          color: _wordmarkNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 280,
                        child: Text(
                          'Tu mascota, siempre cerca.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: _navy.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ],
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
