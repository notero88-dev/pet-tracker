import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../providers/auth_provider.dart';
import '../../utils/petti_theme.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import '../main/petti_main_tabs_screen.dart';

/// Login — Petti style.
///
/// Layout: top app-bar-less screen with a soft brand wash at the top, the
/// PetTrack wordmark, then the form on Cloud surface. Mirrors the Petti
/// onboarding pattern: warm, branded, but the form itself is clean and
/// product-y rather than ad-y.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PettiMainTabsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error al iniciar sesión'),
        ),
      );
    }
  }

  /// Trigger the Google OAuth flow + navigate on success. Cancellation
  /// (auth.signInWithGoogle returns false with no errorMessage) is silent —
  /// the user closed the picker, no need to surface a snackbar for that.
  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PettiMainTabsScreen()),
      );
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!)),
      );
    }
  }

  /// Same shape as Google sign-in: silent abort on cancel, snackbar
  /// on real errors, navigate to home on success.
  Future<void> _handleAppleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithApple();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PettiMainTabsScreen()),
      );
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s5,
            vertical: PettiSpacing.s5,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: PettiSpacing.s6),

                // Brand mark — squircle in marigold with paw, evokes the
                // launcher icon. Doubles as the visual anchor for the form.
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: PettiColors.marigold,
                      borderRadius: BorderRadius.circular(PettiRadii.lg),
                      boxShadow: PettiShadows.elevation1,
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 48,
                      color: PettiColors.midnight,
                    ),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s5),

                // Wordmark + tagline.
                Text(
                  'Bienvenido',
                  style: PettiText.h1(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PettiSpacing.s2),
                Text(
                  'Inicia sesión para ver dónde está tu mascota',
                  style: PettiText.body().copyWith(color: PettiColors.fgDim),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PettiSpacing.s6),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'tu@correo.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu correo';
                    }
                    if (!value.contains('@')) {
                      return 'Correo inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PettiSpacing.s2),

                // Forgot password — right-aligned, no full-width emphasis.
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResetPasswordScreen(),
                      ),
                    ),
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: PettiText.bodySm().copyWith(
                        color: PettiColors.midnight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s5),

                // Primary CTA. Full width, Marigold per ElevatedButtonTheme.
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleLogin,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                  PettiColors.midnight),
                            ),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s5),

                // Divider with a soft "o" in the middle — common pattern,
                // hints that future sign-in methods (Apple/Google) belong
                // below if/when we add them.
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: PettiColors.fog, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: PettiSpacing.s3),
                      child: Text(
                        'o continúa con',
                        style: PettiText.label().copyWith(
                          color: PettiColors.fgDim,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(color: PettiColors.fog, thickness: 1)),
                  ],
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Sign in with Google.
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => OutlinedButton.icon(
                    onPressed:
                        auth.isLoading ? null : _handleGoogleSignIn,
                    icon: const _GoogleGlyph(size: 18),
                    label: const Text('Continuar con Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PettiColors.midnight,
                      side: BorderSide(
                          color: PettiColors.borderLight, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(0),
                    ),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s2),

                // Sign in with Apple. Required by App Store Review rule 4.8
                // because we offer Google SSO. Uses the package's pre-built
                // button so we satisfy Apple's brand-guideline constraints
                // (typeface, padding, logo size) automatically.
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => SignInWithAppleButton(
                    onPressed:
                        auth.isLoading ? () {} : _handleAppleSignIn,
                    text: 'Continuar con Apple',
                    style: SignInWithAppleButtonStyle.black,
                    height: 48,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Sign-up CTA as outlined button — secondary action visually,
                // primary in importance for first-time users.
                OutlinedButton(
                  // pushReplacement swaps Login↔Register without stacking;
                  // pairs with RegisterScreen's "Inicia sesión".
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ),
                  ),
                  child: const Text('Crear una cuenta'),
                ),

                const SizedBox(height: PettiSpacing.s7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Google "G" glyph approximating the brand mark — drawn with CustomPaint
/// so we don't need an asset file. Four colored quadrants meeting at the
/// center, then a white inset that creates the trailing horizontal stroke
/// of the G. Close enough to be recognizable; replace with the official
/// SVG if marketing wants pixel-perfect.
class _GoogleGlyph extends StatelessWidget {
  final double size;
  const _GoogleGlyph({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  // Google brand colors.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = size.width * 0.22;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // 4 colored arcs around the ring.
    final rect = Rect.fromCircle(center: c, radius: radius - stroke / 2);
    void arc(double startDeg, double sweepDeg, Color color) {
      ringPaint.color = color;
      canvas.drawArc(
        rect,
        startDeg * 3.1415926 / 180,
        sweepDeg * 3.1415926 / 180,
        false,
        ringPaint,
      );
    }

    arc(-50, 100, _blue); // right side, blue
    arc(50, 90, _green); // bottom-right, green
    arc(140, 80, _yellow); // bottom-left, yellow
    arc(220, 80, _red); // top, red

    // Horizontal "leg" that turns the C into a G.
    final legPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    final legRect = Rect.fromLTWH(
      c.dx,
      c.dy - stroke / 2,
      radius - stroke / 2 + 1,
      stroke,
    );
    canvas.drawRect(legRect, legPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleGlyphPainter oldDelegate) => false;
}
