// Onboarding step — pet profile setup. Petti restyle.
//
// User just provisioned a device, lands here to give the pet a name and
// type plus a photo. On Continuar we call provisioning-api, link the
// Firebase user, and navigate to FirstPositionScreen.
//
// Layout: hero panel (Marigold-soft square w/ paw) → tagline → photo
// picker (Marigold ring) → form fields → IMEI display in a Sand pill →
// Marigold continue button.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/petti_theme.dart';
import 'first_position_screen.dart';

class PetProfileScreen extends StatefulWidget {
  final String imei;

  const PetProfileScreen({super.key, required this.imei});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _petNameController = TextEditingController();
  final _deviceNameController = TextEditingController();

  String _petType = 'dog';
  File? _petPhoto;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _deviceNameController.text = 'GPS-${widget.imei.substring(9, 15)}';
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(title: const Text('Tu mascota')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PettiSpacing.s5),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: PettiSpacing.s2),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: PettiColors.marigoldSoft,
                    borderRadius: BorderRadius.circular(PettiRadii.lg),
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 44,
                    color: PettiColors.marigold,
                  ),
                ),
              ),
              const SizedBox(height: PettiSpacing.s4),
              Text('¡Casi listo!',
                  style: PettiText.h1(), textAlign: TextAlign.center),
              const SizedBox(height: PettiSpacing.s2),
              Text(
                'Cuéntanos sobre tu mascota para personalizar la experiencia.',
                style:
                    PettiText.body().copyWith(color: PettiColors.fgDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PettiSpacing.s6),

              Center(child: _buildPhotoPicker()),
              const SizedBox(height: PettiSpacing.s6),

              TextFormField(
                controller: _petNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de tu mascota *',
                  hintText: 'Ej: Buddy',
                  prefixIcon: Icon(Icons.pets_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre de tu mascota';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PettiSpacing.s4),

              DropdownButtonFormField<String>(
                value: _petType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de mascota *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'dog', child: Text('🐕  Perro')),
                  DropdownMenuItem(value: 'cat', child: Text('🐈  Gato')),
                  DropdownMenuItem(value: 'other', child: Text('🐾  Otro')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _petType = value);
                },
              ),
              const SizedBox(height: PettiSpacing.s4),

              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del dispositivo',
                  hintText: 'Ej: GPS-Buddy',
                  prefixIcon: Icon(Icons.gps_fixed_outlined),
                  helperText: 'Identificador interno del rastreador',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un nombre para el dispositivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PettiSpacing.s3),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PettiSpacing.s3,
                  vertical: PettiSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: PettiColors.sand,
                  borderRadius: BorderRadius.circular(PettiRadii.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag_outlined,
                        size: 18, color: PettiColors.fgDim),
                    const SizedBox(width: PettiSpacing.s2),
                    Text('IMEI:',
                        style: PettiText.label()
                            .copyWith(color: PettiColors.fgDim)),
                    const SizedBox(width: PettiSpacing.s2),
                    Expanded(
                      child: Text(
                        widget.imei,
                        style:
                            PettiText.number(size: 13, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: PettiSpacing.s6),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
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
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: PettiColors.marigoldSoft,
          shape: BoxShape.circle,
          border: Border.all(color: PettiColors.marigold, width: 2),
        ),
        child: _petPhoto != null
            ? ClipOval(
                child: Image.file(_petPhoto!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                    color: PettiColors.midnight,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agregar foto',
                    style: PettiText.label().copyWith(
                      color: PettiColors.midnight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
      setState(() => _petPhoto = File(image.path));
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final traccarProvider =
        Provider.of<TraccarProvider>(context, listen: false);

    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      _showError('Error de autenticación. Inicia sesión nuevamente.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userEmail = authProvider.currentUser?.email;
      if (userEmail == null) {
        _showError('Error: no se pudo obtener el correo del usuario');
        setState(() => _isLoading = false);
        return;
      }

      final device = await traccarProvider.provisionDevice(
        imei: widget.imei,
        deviceName: _deviceNameController.text.trim(),
        userId: userId,
        userEmail: userEmail,
        petName: _petNameController.text.trim(),
        petType: _petType,
      );

      if (device == null) {
        _showError(traccarProvider.errorMessage ??
            'Error al aprovisionar dispositivo');
        setState(() => _isLoading = false);
        return;
      }

      final firestoreService = FirestoreService();
      // TODO: upload pet photo to Firebase Storage first.
      String? photoUrl;

      await firestoreService.createPet(
        name: _petNameController.text.trim(),
        type: _petType,
        traccarDeviceId: device.traccarId,
        deviceImei: widget.imei,
        photoUrl: photoUrl,
      );

      final credentials = traccarProvider.getLastProvisionedCredentials();
      if (credentials != null) {
        await firestoreService.updateUserProfile(userId, {
          'traccarEmail': credentials['email'],
          'traccarPassword': credentials['password'], // TODO: encrypt
        });
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FirstPositionScreen(
            device: device,
            petName: _petNameController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      _showError('Error inesperado: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
