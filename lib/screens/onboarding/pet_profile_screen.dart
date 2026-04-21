import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../services/firestore_service.dart';
import 'first_position_screen.dart';

/// Pet profile setup screen
class PetProfileScreen extends StatefulWidget {
  final String imei;

  const PetProfileScreen({
    super.key,
    required this.imei,
  });

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
    // Pre-fill device name with IMEI last 6 digits
    _deviceNameController.text = 'GPS-${widget.imei.substring(9, 15)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de tu Mascota'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(
                Icons.pets,
                size: 64,
                color: Color(0xFF2D6A4F),
              ),
              const SizedBox(height: 16),
              const Text(
                '¡Casi listo!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuéntanos sobre tu mascota para personalizar su experiencia',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Photo picker
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2D6A4F),
                        width: 2,
                      ),
                    ),
                    child: _petPhoto != null
                        ? ClipOval(
                            child: Image.file(
                              _petPhoto!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 32,
                                color: Color(0xFF2D6A4F),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Agregar foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Pet name
              TextFormField(
                controller: _petNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de tu mascota *',
                  hintText: 'Ej: Firulais',
                  prefixIcon: Icon(Icons.pets),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre de tu mascota';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Pet type
              DropdownButtonFormField<String>(
                value: _petType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de mascota *',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'dog', child: Text('🐕 Perro')),
                  DropdownMenuItem(value: 'cat', child: Text('🐈 Gato')),
                  DropdownMenuItem(value: 'other', child: Text('🐾 Otro')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _petType = value);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Device name
              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del dispositivo',
                  hintText: 'Ej: GPS-Firulais',
                  prefixIcon: Icon(Icons.gps_fixed),
                  border: OutlineInputBorder(),
                  helperText: 'Identificador interno del rastreador',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un nombre para el dispositivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // IMEI display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'IMEI:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.imei,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Continuar',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _petPhoto = File(image.path);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);

    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      _showError('Error de autenticación. Inicia sesión nuevamente.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get user email
      final userEmail = authProvider.currentUser?.email;
      if (userEmail == null) {
        _showError('Error: No se pudo obtener el correo del usuario');
        setState(() => _isLoading = false);
        return;
      }

      // Provision device
      final device = await traccarProvider.provisionDevice(
        imei: widget.imei,
        deviceName: _deviceNameController.text.trim(),
        userId: userId,
        userEmail: userEmail,
        petName: _petNameController.text.trim(),
        petType: _petType,
      );

      if (device == null) {
        _showError(traccarProvider.errorMessage ?? 'Error al aprovisionar dispositivo');
        setState(() => _isLoading = false);
        return;
      }

      // Save pet profile to Firestore
      final firestoreService = FirestoreService();
      
      // TODO: Upload pet photo to Firebase Storage first
      String? photoUrl;
      // if (_petPhoto != null) {
      //   photoUrl = await uploadPhoto(_petPhoto!);
      // }

      await firestoreService.createPet(
        name: _petNameController.text.trim(),
        type: _petType,
        traccarDeviceId: device.traccarId,
        deviceImei: widget.imei,
        photoUrl: photoUrl,
      );
      
      // Save Traccar credentials to Firestore for future logins
      final credentials = traccarProvider.getLastProvisionedCredentials();
      if (credentials != null) {
        await firestoreService.updateUserProfile(userId, {
          'traccarEmail': credentials['email'],
          'traccarPassword': credentials['password'], // TODO: Encrypt this!
        });
      }

      // Navigate to first position screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FirstPositionScreen(
              device: device,
              petName: _petNameController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Error inesperado: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }
}
