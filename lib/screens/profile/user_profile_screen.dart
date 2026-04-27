// User profile edit — Petti restyle.
//
// Functionality unchanged: photo picker + name/phone fields + collapsible
// password section + save. Visual changes:
//   - Cloud background
//   - Avatar circle uses marigold-soft fill + midnight icon when empty,
//     marigold camera button overlay (matches the brand)
//   - Save button uses theme defaults (Marigold/Midnight)
//   - SnackBars no longer carry hard-coded green/red — the global Petti
//     theme renders them in Midnight on Cloud, which is more legible
//     anyway

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/petti_theme.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _profilePhoto;
  bool _isLoading = false;
  bool _isChangingPassword = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      // Phone is in Firestore (not yet wired)
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text('Guardar'),
          ),
          const SizedBox(width: PettiSpacing.s2),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PettiSpacing.s5),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: PettiSpacing.s2),
              _buildAvatar(),
              const SizedBox(height: PettiSpacing.s6),

              TextFormField(
                initialValue: user?.email ?? '',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email),
                  suffixIcon: Icon(Icons.lock_outline, size: 16),
                ),
              ),
              const SizedBox(height: PettiSpacing.s4),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  hintText: 'Ej: Juan Pérez',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa tu nombre';
                  }
                  if (value.trim().split(' ').length < 2) {
                    return 'Ingresa tu nombre completo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PettiSpacing.s4),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Ej: 3001234567',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: PettiSpacing.s6),

              OutlinedButton.icon(
                onPressed: () => setState(
                    () => _isChangingPassword = !_isChangingPassword),
                icon: Icon(
                  _isChangingPassword
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                label: const Text('Cambiar contraseña'),
              ),

              if (_isChangingPassword) ...[
                const SizedBox(height: PettiSpacing.s4),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: PettiSpacing.s4),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (_isChangingPassword &&
                        (value == null || value.length < 6)) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PettiSpacing.s4),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nueva contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (_isChangingPassword &&
                        value != _newPasswordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: PettiSpacing.s6),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                              PettiColors.midnight),
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _profilePhoto == null ? PettiColors.marigoldSoft : null,
              shape: BoxShape.circle,
              border: Border.all(color: PettiColors.borderLight, width: 1),
              image: _profilePhoto != null
                  ? DecorationImage(
                      image: FileImage(_profilePhoto!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _profilePhoto == null
                ? const Icon(
                    Icons.person_outline,
                    size: 60,
                    color: PettiColors.midnight,
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: PettiColors.marigold,
              shape: const CircleBorder(side: BorderSide(
                color: PettiColors.cloud,
                width: 2,
              )),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _pickPhoto,
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: PettiColors.midnight,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _profilePhoto = File(image.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // TODO: Update user profile in Firebase Auth + Firestore + Storage.
      await Future.delayed(const Duration(seconds: 1));

      if (_isChangingPassword &&
          _currentPasswordController.text.isNotEmpty) {
        // TODO: re-authenticate + change password
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
