import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/petti_theme.dart';

/// Reset password — Petti style.
///
/// Two states: form (single email field + Marigold CTA) and success
/// (Sabana-green confirmation + back button). Both states are intentionally
/// minimal since this is a one-shot recovery flow.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success =
        await authProvider.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(authProvider.errorMessage ?? 'Error al enviar el correo'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s5,
            vertical: PettiSpacing.s4,
          ),
          child: _emailSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: PettiSpacing.s5),

          // Icon panel — soft marigold square holding the lock-reset glyph.
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PettiColors.marigoldSoft,
                borderRadius: BorderRadius.circular(PettiRadii.md),
              ),
              child: const Icon(
                Icons.lock_reset_outlined,
                size: 40,
                color: PettiColors.midnight,
              ),
            ),
          ),
          const SizedBox(height: PettiSpacing.s5),

          Text(
            '¿Olvidaste tu contraseña?',
            style: PettiText.h2(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PettiSpacing.s2),
          Text(
            'Ingresa tu correo y te enviaremos un enlace para restablecerla.',
            style: PettiText.body().copyWith(color: PettiColors.fgDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PettiSpacing.s6),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _handleResetPassword(),
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
          const SizedBox(height: PettiSpacing.s5),

          Consumer<AuthProvider>(
            builder: (context, auth, _) => ElevatedButton(
              onPressed: auth.isLoading ? null : _handleResetPassword,
              child: auth.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(PettiColors.midnight),
                      ),
                    )
                  : const Text('Enviar enlace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sabana-green check circle for success — follows Petti convention
        // that "safe / OK" states use the Sabana token rather than Marigold.
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: PettiColors.sabanaSoft,
              borderRadius: BorderRadius.circular(PettiRadii.lg),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: PettiColors.sabana,
            ),
          ),
        ),
        const SizedBox(height: PettiSpacing.s5),

        Text(
          '¡Correo enviado!',
          style: PettiText.h1(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PettiSpacing.s4),
        Text(
          'Enviamos un enlace de recuperación a',
          style: PettiText.body().copyWith(color: PettiColors.fgDim),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PettiSpacing.s2),
        Text(
          _emailController.text,
          style: PettiText.bodyStrong().copyWith(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PettiSpacing.s4),
        Text(
          'Revisa tu bandeja de entrada y sigue las instrucciones.',
          style: PettiText.bodySm().copyWith(color: PettiColors.fgDim),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PettiSpacing.s7),

        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }
}
