import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../models/geofence.dart';
import '../../providers/traccar_provider.dart';
import 'geofence_create_screen.dart';

/// Geofence list screen for a device
class GeofenceListScreen extends StatefulWidget {
  final Device device;

  const GeofenceListScreen({
    super.key,
    required this.device,
  });

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen> {
  bool _isLoading = true;
  List<Geofence> _geofences = [];

  @override
  void initState() {
    super.initState();
    _loadGeofences();
  }

  Future<void> _loadGeofences() async {
    setState(() => _isLoading = true);
    
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    await traccar.loadGeofences();
    
    if (mounted) {
      setState(() {
        _geofences = traccar.getGeofencesForDevice(widget.device.traccarId!);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonas Seguras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGeofences,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _geofences.isEmpty
              ? _buildEmptyState()
              : _buildGeofenceList(),
      floatingActionButton: _geofences.length < 3
          ? FloatingActionButton.extended(
              onPressed: _createGeofence,
              icon: const Icon(Icons.add_location),
              label: const Text('Crear Zona'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 64,
                color: Color(0xFF2D6A4F),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin Zonas Seguras',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Crea zonas seguras para recibir alertas cuando ${widget.device.name} entre o salga.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createGeofence,
              icon: const Icon(Icons.add_location),
              label: const Text('Crear Primera Zona'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceList() {
    return Column(
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tienes ${_geofences.length} de 3 zonas creadas',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        // Geofence list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _geofences.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final geofence = _geofences[index];
              return _buildGeofenceCard(geofence);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGeofenceCard(Geofence geofence) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showGeofenceOptions(geofence),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(geofence.colorValue).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    geofence.typeIcon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      geofence.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Radio: ${geofence.radiusText}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: geofence.isActive ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          geofence.isActive ? 'Activa' : 'Inactiva',
                          style: TextStyle(
                            fontSize: 12,
                            color: geofence.isActive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createGeofence() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceCreateScreen(device: widget.device),
      ),
    ).then((_) => _loadGeofences());
  }

  void _showGeofenceOptions(Geofence geofence) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Ver en Mapa'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to map view with geofence highlighted
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vista de mapa disponible próximamente'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(context);
                _editGeofence(geofence);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(geofence);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editGeofence(Geofence geofence) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceCreateScreen(
          device: widget.device,
          editGeofence: geofence,
        ),
      ),
    ).then((_) => _loadGeofences());
  }

  void _confirmDelete(Geofence geofence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Zona'),
        content: Text(
          '¿Estás seguro de eliminar la zona "${geofence.name}"?\n\n'
          'No recibirás más alertas de esta zona.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGeofence(geofence);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGeofence(Geofence geofence) async {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    
    final success = await traccar.deleteGeofence(geofence.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zona "${geofence.name}" eliminada'),
          backgroundColor: Colors.green,
        ),
      );
      _loadGeofences();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${traccar.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
