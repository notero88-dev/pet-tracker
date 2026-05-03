// A4.5 — "¿Quién es tu Petti?"
//
// Captures pet name + species before the device gets provisioned in our
// backend. Sits between A4 Paired and the bridge to A6 Pick Location.
//
// Why pet profile lives in A4 not before:
//   - The user has already paired the device by now, so they're committed
//     enough to type a name.
//   - The Firebase Auth user is signed in; we have userId + email.
//   - Provisioning the device requires petName + petType; doing it before
//     A4 would require collecting these in some other screen we don't
//     have.
//
// This screen is deliberately minimal. Pet photo capture and breed are
// deferred to a later "edit profile" surface; gating onboarding on a
// camera permission grant is friction we don't need on day one.

import 'package:flutter/material.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

enum PetSpecies { dog, cat }

class A4PetProfileScreen extends StatefulWidget {
  /// Submitted with the entered name + chosen species.
  final void Function(String petName, PetSpecies species) onSubmit;

  /// Back to A4 Paired (rare; user changed their mind).
  final VoidCallback onBack;

  const A4PetProfileScreen({
    super.key,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<A4PetProfileScreen> createState() => _A4PetProfileScreenState();
}

class _A4PetProfileScreenState extends State<A4PetProfileScreen> {
  final _nameController = TextEditingController();
  PetSpecies _species = PetSpecies.dog;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _validate() {
    final next = _nameController.text.trim().isNotEmpty;
    if (next != _isValid) setState(() => _isValid = next);
  }

  void _submit() {
    if (!_isValid) return;
    widget.onSubmit(_nameController.text.trim(), _species);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PettiStepHeader(step: 4, total: 4),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: PettiSpacing.s4),
                  PettiScreenHeading(
                    kicker: 'Tu Petti',
                    title: '¿Quién es tu Petti?',
                    lede: Text(
                      'Solo el nombre y si es perrito o gatito.',
                      style: PettiText.lead().copyWith(
                        color: PettiColors.fgOnDarkDim,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s5),
                  // Name field
                  Text('NOMBRE',
                      style: PettiText.meta()
                          .copyWith(color: PettiColors.fgOnDarkDim)),
                  const SizedBox(height: PettiSpacing.s2),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: PettiText.bodyStrong()
                        .copyWith(color: PettiColors.fgOnDark, fontSize: 18),
                    cursorColor: PettiColors.marigold,
                    maxLength: 30,
                    decoration: InputDecoration(
                      hintText: 'Luna, Max, Lola…',
                      hintStyle: PettiText.bodyStrong().copyWith(
                        color: PettiColors.fgOnDarkFaint,
                        fontSize: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAF7F2).withValues(alpha: 0.04),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: PettiSpacing.s4,
                        vertical: PettiSpacing.s3,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
                        borderSide: BorderSide(
                          color: PettiColors.fgOnDarkHairline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
                        borderSide: const BorderSide(
                          color: PettiColors.marigold,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: PettiSpacing.s5),
                  // Species toggle
                  Text('TIPO',
                      style: PettiText.meta()
                          .copyWith(color: PettiColors.fgOnDarkDim)),
                  const SizedBox(height: PettiSpacing.s2),
                  Row(
                    children: [
                      Expanded(
                        child: _SpeciesChip(
                          label: 'Perrito',
                          icon: Icons.pets_rounded,
                          selected: _species == PetSpecies.dog,
                          onTap: () =>
                              setState(() => _species = PetSpecies.dog),
                        ),
                      ),
                      const SizedBox(width: PettiSpacing.s2),
                      Expanded(
                        child: _SpeciesChip(
                          label: 'Gatito',
                          icon: Icons.pets_outlined,
                          selected: _species == PetSpecies.cat,
                          onTap: () =>
                              setState(() => _species = PetSpecies.cat),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            PettiCtaDock(
              primaryLabel: 'Continuar',
              onPrimary: _isValid ? _submit : null,
              secondaryLabel: 'Volver',
              onSecondary: widget.onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SpeciesChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
      child: AnimatedContainer(
        duration: PettiMotion.micro,
        curve: PettiMotion.ease,
        padding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s4,
          vertical: PettiSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: selected
              ? PettiColors.marigold.withValues(alpha: 0.16)
              : const Color(0xFFFAF7F2).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
          border: Border.all(
            color: selected
                ? PettiColors.marigold
                : PettiColors.fgOnDarkHairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? PettiColors.marigold
                  : PettiColors.fgOnDarkDim,
            ),
            const SizedBox(width: PettiSpacing.s2),
            Text(
              label,
              style: PettiText.bodyStrong().copyWith(
                color: selected
                    ? PettiColors.fgOnDark
                    : PettiColors.fgOnDarkDim,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
