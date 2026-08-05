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
import '../../services/firestore_service.dart';
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

  // Firestore pet doc backing this form. Null until _loadPet resolves,
  // or permanently null if this device has no pet doc (shouldn't happen
  // post-provision, but the screen must not lie about saving if it does).
  String? _petId;
  String? _existingPhotoUrl;
  bool _isLoadingPet = true;

  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Seed the name from the Traccar device only as a placeholder — it
    // reads "Joshi's Tracker", not the pet's name. _loadPet overwrites it
    // with the real value the user chose during onboarding.
    _petNameController = TextEditingController(text: widget.device.name);
    _breedController = TextEditingController();
    _weightController = TextEditingController();
    _notesController = TextEditingController();
    _loadPet();
  }

  /// Load the pet doc for this device so the form shows what the user
  /// actually saved. Until 2026-08-04 this was a TODO: every field
  /// rendered empty and the name showed the auto-generated device name,
  /// so the screen looked like it had lost the user's data.
  Future<void> _loadPet() async {
    try {
      final pets = await _firestore.getUserPets();
      final match = pets.firstWhere(
        (p) => p['traccarDeviceId'] == widget.device.traccarId,
        orElse: () => const <String, dynamic>{},
      );
      if (!mounted) return;
      if (match.isEmpty) {
        setState(() => _isLoadingPet = false);
        return;
      }
      setState(() {
        _petId = match['id'] as String?;
        final name = (match['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) _petNameController.text = name;
        _breedController.text = (match['breed'] as String?) ?? '';
        final weight = match['weight'];
        _weightController.text = weight == null ? '' : '$weight';
        _notesController.text = (match['notes'] as String?) ?? '';
        final type = match['type'] as String?;
        if (type == 'dog' || type == 'cat' || type == 'other') _petType = type!;
        _existingPhotoUrl = match['photoUrl'] as String?;
        _isLoadingPet = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPet = false);
    }
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
            onPressed: (_isLoading || _isLoadingPet) ? null : _saveProfile,
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
                initialValue: _petType,
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
                onPressed: (_isLoading || _isLoadingPet) ? null : _saveProfile,
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

    // No pet doc = nothing to write to. Say so instead of showing the
    // success toast; the old code claimed success unconditionally.
    if (_petId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos encontrar el perfil de tu mascota. '
              'Cierra y vuelve a abrir esta pantalla.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Photo first: if the upload fails we keep the previous URL rather
      // than clearing a photo the user already had.
      String? photoUrl = _existingPhotoUrl;
      if (_petPhoto != null) {
        final uploaded = await _firestore.uploadPetPhoto(_petPhoto!);
        if (uploaded != null) photoUrl = uploaded;
      }

      final weightText = _weightController.text.trim().replaceAll(',', '.');
      await _firestore.updatePet(_petId!, {
        'name': _petNameController.text.trim(),
        'type': _petType,
        'breed': _emptyToNull(_breedController.text),
        'weight': weightText.isEmpty ? null : double.tryParse(weightText),
        'notes': _emptyToNull(_notesController.text),
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      if (!mounted) return;
      setState(() => _existingPhotoUrl = photoUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil de mascota actualizado')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos guardar los cambios: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
