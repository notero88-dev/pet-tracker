// MascotasTab — rich pet-card list, the Mascotas tab of the bottom nav.
//
// Source: design bundle main-tabs.jsx:536-647 (MascotasScreen +
// PetRichCard + PillAction). Cards have:
//   - 56×56 gradient avatar with initial letter (Space Grotesk 22pt)
//   - Title row: pet name + breed/age + ⋯ menu
//   - Status row (above border-top): online/offline pill + battery badge
//   - Action row: 3 cream pills — Ubicación / Salud / Tracker
//
// Tapping the card body opens the pet's profile-edit screen. The three
// action pills go to: Mapa tab focused on this pet / Salud tab focused
// on this pet / device-settings for this pet's tracker.
//
// V1 limitations:
//   - Today the app supports 1 device. The grid still renders as a list
//     so multi-pet households slot in naturally when they arrive.
//   - "Acciones rápidas" pills currently only Ubicación (works) and
//     Tracker (works) — Salud routes to PetActivityScreen with the pet
//     selected. The pet-picker → tab navigation isn't yet wired across
//     tabs, so the pills do their best-effort fallback.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../providers/traccar_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/real_activity_builder.dart';
import '../../utils/petti_theme.dart';
import '../activity/pet_activity_screen.dart';
import '../activity/pet_avatar_palette.dart';
import '../device/device_detail_screen.dart';
import '../onboarding/redesign/onboarding_flow_controller.dart';
import '../profile/pet_profile_screen.dart';
import 'petti_main_tabs_screen.dart';

class MascotasTab extends StatefulWidget {
  const MascotasTab({super.key});

  @override
  State<MascotasTab> createState() => _MascotasTabState();
}

class _MascotasTabState extends State<MascotasTab> {
  List<Map<String, dynamic>>? _pets;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final pets = await FirestoreService().getUserPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pets = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TraccarProvider>(
      builder: (context, traccar, _) {
        return Container(
          color: PettiColors.cloud,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PettiTabScreenHeader(
                  title: 'Mascotas',
                  trailing: [
                    PettiTabIconBtn(
                      icon: Icons.add_rounded,
                      onTap: () => _addPet(context),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(
                    _subtitleText(traccar.devices.length),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: PettiColors.trail,
                      letterSpacing: -0.005 * 13,
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // After the pet cards, render the Add CTA.
                        if (index == _pets!.length) {
                          return _AddPetCard(onTap: () => _addPet(context));
                        }
                        final pet = _pets![index];
                        final device = _deviceForPet(pet, traccar.devices);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PetRichCard(
                            pet: pet,
                            device: device,
                            traccar: traccar,
                          ),
                        );
                      },
                      childCount: (_pets?.length ?? 0) + 1,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _subtitleText(int trackerCount) {
    final petCount = _pets?.length ?? 0;
    if (_loading) return 'Cargando...';
    if (petCount == 0) return 'Ninguna mascota todavía';
    final petLabel = petCount == 1 ? '1 mascota' : '$petCount mascotas';
    final trackerLabel =
        trackerCount == 1 ? '1 tracker activo' : '$trackerCount trackers activos';
    return '$petLabel · $trackerLabel';
  }

  Device? _deviceForPet(Map<String, dynamic> pet, List<Device> devices) {
    final traccarId = pet['traccarDeviceId'];
    if (traccarId is! int) return null;
    for (final d in devices) {
      if (d.traccarId == traccarId) return d;
    }
    return null;
  }

  Future<void> _addPet(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingFlowController()),
    );
    if (mounted) _loadPets();
  }
}

class _PetRichCard extends StatelessWidget {
  final Map<String, dynamic> pet;
  final Device? device;
  final TraccarProvider traccar;
  const _PetRichCard({
    required this.pet,
    required this.device,
    required this.traccar,
  });

  @override
  Widget build(BuildContext context) {
    final name = (pet['name'] as String?)?.trim() ?? 'Mascota';
    final breed = (pet['breed'] as String?)?.trim();
    final type = (pet['type'] as String?)?.trim() ?? '';
    final subtitle = _subtitleFor(type: type, breed: breed, weight: pet['weight']);
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final palette = petAvatarFor(name);

    final position = device != null && device!.traccarId != null
        ? traccar.getLastPosition(device!.requireTraccarId())
        : null;
    final bool isOnline = device?.isOnline ?? false;
    final int? battery = position?.batteryLevel;
    final locationLabel = isOnline
        ? 'En línea'
        : (device?.lastUpdate != null
            ? _relativeTimeEs(device!.lastUpdate as DateTime)
            : 'sin conexión');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PettiColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: PettiColors.midnight.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row — tap opens pet profile.
          InkWell(
            onTap: device != null ? () => _openProfile(context) : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  // Avatar — 56×56 squircle with gradient + initial.
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: palette,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PettiColors.midnight.withValues(alpha: 0.08),
                          offset: const Offset(0, -2),
                          blurRadius: 6,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: PettiColors.midnight,
                        letterSpacing: -0.02 * 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: PettiColors.midnight,
                            letterSpacing: -0.02 * 19,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: PettiColors.trail,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: PettiColors.trail,
                  ),
                ],
              ),
            ),
          ),
          // Status row (online/offline + battery)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: PettiColors.borderLight),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusPill(
                  online: isOnline,
                  label: locationLabel,
                ),
                if (battery != null) _BatteryBadge(percent: battery),
              ],
            ),
          ),
          // Action pills
          if (device != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _PillAction(
                      icon: Icons.place_outlined,
                      label: 'Ubicación',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceDetailScreen(device: device!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PillAction(
                      icon: Icons.monitor_heart_outlined,
                      label: 'Salud',
                      onTap: () => _openActivity(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PillAction(
                      icon: Icons.settings_outlined,
                      label: 'Tracker',
                      onTap: () => _openProfile(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    if (device == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetProfileScreen(device: device!),
      ),
    );
  }

  void _openActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetActivityScreen.live(
          initialPetId: pet['id'] as String?,
          loader: () => realActivitiesForUser(
            traccar: traccar,
            firestore: FirestoreService(),
          ),
        ),
      ),
    );
  }

  String _subtitleFor({
    required String type,
    required String? breed,
    required dynamic weight,
  }) {
    final lc = type.toLowerCase();
    final isCat = lc == 'cat' || lc == 'gato' || lc == 'felino';
    final typeEs = isCat ? 'Gato' : 'Perro';
    if (breed != null && breed.isNotEmpty) return '$typeEs · $breed';
    if (weight is num) return '$typeEs · ${weight.toStringAsFixed(1)} kg';
    return typeEs;
  }

  String _relativeTimeEs(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'hace unos segundos';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'hace $m ${m == 1 ? 'minuto' : 'minutos'}';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'hace $h ${h == 1 ? 'hora' : 'horas'}';
    }
    final d = diff.inDays;
    return 'hace $d ${d == 1 ? 'día' : 'días'}';
  }
}

// -----------------------------------------------------------------------------
// Status pill + battery badge + pill action — small primitives used by the
// rich card. Kept private to this file because the visual treatment is
// specific to this design; if they spread to another tab we'll lift them.
// -----------------------------------------------------------------------------

class _StatusPill extends StatelessWidget {
  final bool online;
  final String label;
  const _StatusPill({required this.online, required this.label});

  @override
  Widget build(BuildContext context) {
    final fg = online ? PettiColors.sabana : PettiColors.trail;
    final bg = online ? PettiColors.sabanaSoft : PettiColors.cloud;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PettiColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: -0.005 * 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  final int percent;
  const _BatteryBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    if (percent < 20) {
      icon = Icons.battery_alert_rounded;
      color = PettiColors.duskRose;
    } else if (percent < 40) {
      icon = Icons.battery_2_bar_rounded;
      color = PettiColors.marigoldDim;
    } else if (percent < 60) {
      icon = Icons.battery_3_bar_rounded;
      color = PettiColors.marigoldDim;
    } else if (percent < 80) {
      icon = Icons.battery_4_bar_rounded;
      color = PettiColors.sabana;
    } else {
      icon = Icons.battery_full_rounded;
      color = PettiColors.sabana;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$percent%',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PettiColors.cloud,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: PettiColors.midnight),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: PettiColors.midnight,
                  letterSpacing: -0.005 * 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPetCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPetCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: PettiColors.n300,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PettiColors.marigoldSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: PettiColors.marigoldDim,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agregar mascota',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: PettiColors.midnight,
                        letterSpacing: -0.015 * 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Empareja un Tracker o agrega un perfil sin dispositivo',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: PettiColors.trail,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: PettiColors.trail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
