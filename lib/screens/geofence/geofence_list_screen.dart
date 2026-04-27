// Geofence list — Petti restyle.
//
// Shows the geofences linked to a device, plus an "Agregar zona" CTA when
// under the 3-zone limit. Tap a row → bottom sheet with View / Edit /
// Delete options.
//
// Uses Petti tokens throughout. The Zona Segura wizard creates one of
// these as part of onboarding (commit 4c07131); this screen is for
// managing additional zones afterward (e.g., "Trabajo", "Veterinario").

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/geofence.dart';
import '../../providers/traccar_provider.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_primitives.dart';
import 'geofence_create_screen.dart';

class GeofenceListScreen extends StatefulWidget {
  final Device device;

  const GeofenceListScreen({super.key, required this.device});

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
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(
        title: const Text('Zonas seguras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadGeofences,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _geofences.isEmpty
              ? _buildEmptyState()
              : _buildList(),
      floatingActionButton: _geofences.length < 3 && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _createGeofence,
              backgroundColor: PettiColors.marigold,
              foregroundColor: PettiColors.midnight,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(
                'Agregar zona',
                style:
                    PettiText.bodyStrong().copyWith(fontSize: 14),
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------- empty state

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PettiSpacing.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: PettiColors.sabanaSoft,
                borderRadius: BorderRadius.circular(PettiRadii.lg),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 56,
                color: PettiColors.sabana,
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),
            Text('Sin zonas seguras',
                style: PettiText.h2(), textAlign: TextAlign.center),
            const SizedBox(height: PettiSpacing.s2),
            Text(
              'Crea zonas seguras para recibir alertas cuando ${widget.device.name} entre o salga.',
              style: PettiText.body().copyWith(color: PettiColors.fgDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PettiSpacing.s6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createGeofence,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Crear primera zona'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- list

  Widget _buildList() {
    return Column(
      children: [
        // Quota banner — Sand surface, calm, informative.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s4,
            vertical: PettiSpacing.s3,
          ),
          color: PettiColors.sand,
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: PettiColors.fgDim),
              const SizedBox(width: PettiSpacing.s2),
              Expanded(
                child: Text(
                  'Tienes ${_geofences.length} de 3 zonas creadas',
                  style: PettiText.bodySm().copyWith(color: PettiColors.fgDim),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              PettiSpacing.s4,
              PettiSpacing.s4,
              PettiSpacing.s4,
              PettiSpacing.s8,
            ),
            itemCount: _geofences.length,
            itemBuilder: (context, index) {
              final g = _geofences[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: PettiSpacing.s2),
                child: _buildGeofenceCard(g),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGeofenceCard(Geofence g) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PettiRadii.md),
        onTap: () => _showGeofenceOptions(g),
        child: PettiCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(PettiSpacing.s4),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: PettiColors.marigoldSoft,
                  borderRadius: BorderRadius.circular(PettiRadii.sm),
                ),
                child: Center(
                  child: Text(g.typeIcon,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: PettiSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: PettiText.h4()),
                    const SizedBox(height: PettiSpacing.s1),
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked,
                            size: 14, color: PettiColors.fgDim),
                        const SizedBox(width: 4),
                        Text(
                          'Radio: ${g.radiusText}',
                          style: PettiText.bodySm()
                              .copyWith(color: PettiColors.fgDim),
                        ),
                      ],
                    ),
                    const SizedBox(height: PettiSpacing.s2),
                    PettiStatusPill(
                      kind: g.isActive
                          ? PettiStatus.online
                          : PettiStatus.offline,
                      label: g.isActive ? 'Activa' : 'Inactiva',
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: PettiColors.fgFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- actions

  void _createGeofence() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeofenceCreateScreen(device: widget.device),
      ),
    ).then((_) => _loadGeofences());
  }

  void _editGeofence(Geofence g) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeofenceCreateScreen(
          device: widget.device,
          editGeofence: g,
        ),
      ),
    ).then((_) => _loadGeofences());
  }

  void _showGeofenceOptions(Geofence g) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PettiColors.cloud,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PettiRadii.lg),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PettiSpacing.s2),
            // Pull handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: PettiColors.fog,
                borderRadius: BorderRadius.circular(PettiRadii.pill),
              ),
            ),
            const SizedBox(height: PettiSpacing.s3),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Ver en mapa'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vista de mapa disponible próximamente'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editGeofence(g);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: PettiColors.alert),
              title: Text(
                'Eliminar',
                style: PettiText.bodyStrong()
                    .copyWith(color: PettiColors.alert, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(g);
              },
            ),
            const SizedBox(height: PettiSpacing.s2),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Geofence g) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar zona'),
        content: Text(
          '¿Eliminar la zona "${g.name}"?\n\nNo recibirás más alertas de esta zona.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteGeofence(g);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PettiColors.alert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGeofence(Geofence g) async {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final success = await traccar.deleteGeofence(g.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Zona "${g.name}" eliminada'
            : 'Error: ${traccar.errorMessage}'),
      ),
    );
    if (success) _loadGeofences();
  }
}
