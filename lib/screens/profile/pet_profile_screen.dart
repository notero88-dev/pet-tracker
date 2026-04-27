// Pet profile (post-onboarding edit) — Petti restyle.
//
// Form for editing pet name / type / breed / weight / notes plus a card
// showing the linked GPS device (read-only). Visual swap: Cloud bg,
// Marigold pet-photo ring (matches the Petti brand mark), section eyebrow
// in PettiText.meta, device card uses PettiCard, SnackBars use defaults.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/device.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_primitives.dart';

class PetProfileScreen extends StatefulWidget {
  final Device device;

  const PetProfileScreen({super.key, required this.device});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _petNameController;
  late TextEditingController _breedController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;

  String _petType = 'dog';
  File? _petPhoto;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _petNameController = TextEditingController(text: widget.device.name);
    _breedController = TextEditingController();
    _weightController = TextEditingController();
    _notesController = TextEditingController();
    // TODO: load pet data from Firestore.
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(
        title: const Text('Perfil de mascota'),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: PettiSpacing.s2),
              Center(child: _buildAvatar()),
              const SizedBox(height: PettiSpacing.s6),

              TextFormField(
                controller: _petNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
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
                  labelText: 'Tipo *',
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
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: 'Raza',
                  hintText: 'Ej: Labrador',
                  prefixIcon: Icon(Icons.format_list_bulleted_outlined),
                ),
              ),
              const SizedBox(height: PettiSpacing.s4),

              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Peso',
                  hintText: 'Ej: 15',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: PettiSpacing.s4),

              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText:
                      'Información adicional, comportamiento, salud, etc.',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),

              const SizedBox(height: PettiSpacing.s6),
              Padding(
                padding: const EdgeInsets.only(left: PettiSpacing.s2),
                child: Text('DISPOSITIVO GPS', style: PettiText.meta()),
              ),
              const SizedBox(height: PettiSpacing.s2),
              PettiCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(PettiSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.gps_fixed_outlined, 'Nombre',
                        widget.device.name),
                    const SizedBox(height: PettiSpacing.s3),
                    _infoRow(Icons.tag_outlined, 'IMEI',
                        widget.device.uniqueId),
                    const SizedBox(height: PettiSpacing.s3),
                    _infoRow(
                      widget.device.isOnline
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      'Estado',
                      widget.device.statusText,
                    ),
                  ],
                ),
              ),

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
              const SizedBox(height: PettiSpacing.s3),

              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Historial de actividad disponible próximamente',
                    ),
                  ),
                ),
                icon: const Icon(Icons.history_outlined),
                label: const Text('Ver historial de actividad'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: _petPhoto == null ? PettiColors.marigoldSoft : null,
              shape: BoxShape.circle,
              border: Border.all(color: PettiColors.marigold, width: 3),
            ),
            child: _petPhoto != null
                ? ClipOval(
                    child:
                        Image.file(_petPhoto!, fit: BoxFit.cover),
                  )
                : const Icon(
                    Icons.pets,
                    size: 64,
                    color: PettiColors.midnight,
                  ),
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
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: PettiColors.midnight,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PettiColors.fgDim),
        const SizedBox(width: PettiSpacing.s3),
        Text('$label:',
            style: PettiText.label().copyWith(color: PettiColors.fgDim)),
        const SizedBox(width: PettiSpacing.s2),
        Expanded(
          child: Text(
            value,
            style: PettiText.bodyStrong().copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // TODO: Save pet profile to Firestore + upload photo to Storage.
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil de mascota actualizado')),
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
