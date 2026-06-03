import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../providers/auth_provider.dart';
import '../../utils/petti_theme.dart';
import '../main/petti_main_tabs_screen.dart';

/// Sign-up — Petti style.
///
/// Quieter than login (no big brand mark — the user is already in the app
/// at this point and just needs to fill the form). Inline section header,
/// then form, then Marigold CTA.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones'),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PettiMainTabsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error al registrarse'),
        ),
      );
    }
  }

  /// Same Google OAuth flow as the login screen — Firebase's
  /// `signInWithCredential` creates a new user OR signs into an existing
  /// one matched by email, so a single button serves both screens.
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

  /// Same Apple OAuth flow as the login screen — same Firebase contract.
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
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s5,
            vertical: PettiSpacing.s4,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bienvenido a My Besti', style: PettiText.h1()),
                const SizedBox(height: PettiSpacing.s2),
                Text(
                  'Crea tu cuenta para registrar tu mascota y empezar a verla en el mapa.',
                  style: PettiText.body().copyWith(color: PettiColors.fgDim),
                ),
                const SizedBox(height: PettiSpacing.s6),

                // Full name
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    hintText: 'Nicolás Otero',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu nombre';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'Ingresa tu nombre completo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newUsername],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'tu@correo.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu correo';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Correo inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Phone (optional)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    hintText: '+57 300 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo 6 caracteres',
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
                      return 'Por favor ingresa una contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Confirm password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleRegister(),
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirma tu contraseña';
                    }
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PettiSpacing.s5),

                // Terms checkbox — softer "card" container so the legal
                // sentence doesn't feel buried under the password field.
                InkWell(
                  onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                  borderRadius: BorderRadius.circular(PettiRadii.md),
                  child: Container(
                    padding: const EdgeInsets.all(PettiSpacing.s3),
                    decoration: BoxDecoration(
                      color: PettiColors.sand,
                      borderRadius: BorderRadius.circular(PettiRadii.md),
                      border: Border.all(
                        color: _acceptTerms
                            ? PettiColors.marigold
                            : PettiColors.borderLight,
                        width: _acceptTerms ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          activeColor: PettiColors.marigold,
                          checkColor: PettiColors.midnight,
                          onChanged: (v) =>
                              setState(() => _acceptTerms = v ?? false),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: PettiText.bodySm(),
                              children: [
                                const TextSpan(text: 'Acepto los '),
                                TextSpan(
                                  text: 'términos y condiciones',
                                  style: PettiText.bodySm().copyWith(
                                    color: PettiColors.midnight,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: ' de My Besti'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s5),

                // Primary CTA
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleRegister,
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
                        : const Text('Crear cuenta'),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s4),

                // Divider + Google sign-up shortcut. Same behavior as the
                // login screen — Google OAuth creates the Firebase user if
                // they're new, signs them in if they already exist.
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

                // Sign in with Apple. App Store Review 4.8 requires it on
                // any iOS app that offers third-party SSO.
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

                // Back to login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: PettiText.bodySm()
                          .copyWith(color: PettiColors.fgDim),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Inicia sesión',
                        style: PettiText.bodySm().copyWith(
                          color: PettiColors.midnight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PettiSpacing.s5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Google "G" glyph drawn with CustomPaint — same approach as the login
/// screen's helper. Replace with the official SVG asset if marketing
/// wants pixel-perfect.
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

    arc(-50, 100, _blue);
    arc(50, 90, _green);
    arc(140, 80, _yellow);
    arc(220, 80, _red);

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
