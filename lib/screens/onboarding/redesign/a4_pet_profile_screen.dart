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
// Captures pet name + species + an OPTIONAL photo before the device gets
// provisioned. The photo is optional — tapping the avatar opens a
// camera/gallery sheet, but the user can skip it and add one later from
// the pet's profile. (Photo added 2026-06-11.)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

enum PetSpecies { dog, cat }

class A4PetProfileScreen extends StatefulWidget {
  /// Submitted with the entered name, chosen species, and the optional
  /// local photo file (null when the user skipped it). The caller
  /// uploads the file + persists the resulting URL after provisioning.
  final void Function(String petName, PetSpecies species, File? photo) onSubmit;

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
  final _picker = ImagePicker();
  PetSpecies _species = PetSpecies.dog;
  bool _isValid = false;
  File? _photo;

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
    widget.onSubmit(_nameController.text.trim(), _species, _photo);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _photo = File(image.path));
      }
    } catch (_) {
      // Permission denied / no camera / cancelled — silently no-op,
      // the photo stays optional.
    }
  }

  void _showPhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PettiColors.midnight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PettiSpacing.s3),
            _PhotoSheetOption(
              icon: Icons.photo_camera_outlined,
              label: 'Tomar foto',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            _PhotoSheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Elegir de la galería',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photo != null)
              _PhotoSheetOption(
                icon: Icons.delete_outline,
                label: 'Quitar foto',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  setState(() => _photo = null);
                },
              ),
            const SizedBox(height: PettiSpacing.s3),
          ],
        ),
      ),
    );
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
                    kicker: 'Tu mascota',
                    title: '¿Quién es tu mascota?',
                    lede: Text(
                      'Su nombre, una foto (opcional) y si es perrito o gatito.',
                      style: PettiText.lead().copyWith(
                        color: PettiColors.fgOnDarkDim,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s5),
                  // Photo picker — tappable circular avatar, centered.
                  Center(
                    child: GestureDetector(
                      onTap: _showPhotoSheet,
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFAF7F2)
                                  .withValues(alpha: 0.06),
                              border: Border.all(
                                color: _photo != null
                                    ? PettiColors.marigold
                                    : PettiColors.fgOnDarkHairline,
                                width: _photo != null ? 2 : 1,
                              ),
                              image: _photo != null
                                  ? DecorationImage(
                                      image: FileImage(_photo!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _photo == null
                                ? Icon(
                                    Icons.pets_rounded,
                                    size: 34,
                                    color: PettiColors.fgOnDarkDim,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: PettiColors.marigold,
                                border: Border.all(
                                  color: PettiColors.midnight,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: PettiColors.midnight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s2),
                  Center(
                    child: TextButton(
                      onPressed: _showPhotoSheet,
                      child: Text(
                        _photo != null ? 'Cambiar foto' : 'Agregar foto',
                        style: PettiText.bodySm().copyWith(
                          color: PettiColors.marigold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s4),
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

class _PhotoSheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoSheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: PettiColors.fgOnDark),
      title: Text(
        label,
        style: PettiText.bodyStrong().copyWith(color: PettiColors.fgOnDark),
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
