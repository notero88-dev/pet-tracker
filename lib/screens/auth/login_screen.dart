import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/petti_theme.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import '../home/home_screen.dart';

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
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error al iniciar sesión'),
        ),
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
                        'o',
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

                // Sign-up CTA as outlined button — secondary action visually,
                // primary in importance for first-time users.
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
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
