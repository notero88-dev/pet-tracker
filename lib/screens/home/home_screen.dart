import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/petti_theme.dart';
import '../onboarding/redesign/onboarding_flow_controller.dart';
import '../device/device_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/settings_screen.dart';
import '../activity/pet_activity_screen.dart';
import '../activity/pet_avatar_palette.dart';
import '../../services/real_activity_builder.dart';

/// Home — the main daily-use screen.
///
/// Has three states: loading (Cloud + spinner), empty (paw illustration +
/// big "Add device" CTA), populated (list of pet cards). The populated
/// state uses Petti's PettiCard, PettiPetAvatar, PettiBatteryBadge, and
/// PettiStatusPill so it shares visual DNA with the device-detail screen
/// the user lands on after tapping a card.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeTraccar();
    _dedupePets();
  }

  /// One-shot cleanup on every launch. Deletes duplicate Firestore pet
  /// docs that point to the same traccarDeviceId, keeping the most-recent
  /// one. Idempotent — no-op when there are no duplicates. See
  /// FirestoreService.dedupePetsByDevice for the why.
  Future<void> _dedupePets() async {
    try {
      final n = await FirestoreService().dedupePetsByDevice();
      if (n > 0) {
        debugPrint('[home_screen] dedupePetsByDevice: removed $n duplicate(s)');
      }
    } catch (e) {
      debugPrint('[home_screen] dedupePetsByDevice failed: $e');
    }
  }

  Future<void> _initializeTraccar() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final traccarProvider =
        Provider.of<TraccarProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;

    if (userId == null) return;

    try {
      final firestoreService = FirestoreService();
      final userProfile = await firestoreService.getUserProfile(userId);

      if (userProfile != null &&
          userProfile['traccarEmail'] != null &&
          userProfile['traccarPassword'] != null) {
        final success = await traccarProvider.connect(
          userProfile['traccarEmail'],
          userProfile['traccarPassword'],
        );

        if (success) {
          await traccarProvider.refreshDevices();
        }
      }
    } catch (e) {
      // User hasn't provisioned a device yet — empty state will handle it.
      debugPrint('Error initializing Traccar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(
        title: Text('Besti', style: PettiText.h2()),
        actions: [
          // Activity icon moved out of the AppBar 2026-05-11 to match the
          // home screen redesign in plans/2026-05-11-… — entry is now the
          // dark "Ver actividad" CTA below the pet list.

          // Bell icon with optional unread badge.
          Consumer<NotificationProvider>(
            builder: (context, n, _) {
              final unread = n.unreadCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: PettiColors.alert,
                          borderRadius:
                              BorderRadius.circular(PettiRadii.pill),
                          border:
                              Border.all(color: PettiColors.cloud, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_outlined),
            tooltip: 'Configuración',
            onPressed: () {
              final traccar =
                  Provider.of<TraccarProvider>(context, listen: false);
              final device = traccar.devices.isNotEmpty
                  ? traccar.devices.first
                  : null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(device: device),
                ),
              );
            },
          ),
          const SizedBox(width: PettiSpacing.s2),
        ],
      ),
      body: Consumer<TraccarProvider>(
        builder: (context, traccar, _) {
          if (traccar.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (traccar.devices.isEmpty) {
            return _buildEmptyState();
          }
          return _buildDeviceList(traccar);
        },
      ),
      floatingActionButton: Consumer<TraccarProvider>(
        // Hide the FAB on empty state (the empty state has its own primary
        // CTA — two CTAs would compete and look confusing).
        builder: (context, traccar, _) {
          if (traccar.devices.isEmpty || traccar.isLoading) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: _navigateToScanner,
            backgroundColor: PettiColors.marigold,
            foregroundColor: PettiColors.midnight,
            icon: const Icon(Icons.add),
            label: Text(
              'Agregar mascota',
              style: PettiText.bodyStrong().copyWith(fontSize: 14),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PettiSpacing.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hero panel — soft marigold square with paw, big enough to
            // anchor the page but not so big it overpowers the CTA.
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: PettiColors.marigoldSoft,
                borderRadius: BorderRadius.circular(PettiRadii.lg),
              ),
              child: const Icon(
                Icons.pets,
                size: 72,
                color: PettiColors.marigold,
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),

            Text(
              '¡Bienvenido a Besti!',
              style: PettiText.h1(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PettiSpacing.s3),
            Text(
              'Agrega tu primer collar GPS para empezar a ver dónde anda tu mascota.',
              style: PettiText.body().copyWith(color: PettiColors.fgDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PettiSpacing.s6),

            // Primary CTA — full-width within the column padding.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToScanner,
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: const Text('Escanear collar GPS'),
              ),
            ),
            const SizedBox(height: PettiSpacing.s3),
            // Secondary CTA — manual IMEI entry path. Same screen accepts
            // both flows; the QR scanner screen has a "type IMEI manually"
            // affordance.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _navigateToScanner,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Ingresar IMEI manualmente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Device list
  // ---------------------------------------------------------------------

  Widget _buildDeviceList(TraccarProvider traccar) {
    return RefreshIndicator(
      onRefresh: () => traccar.refreshDevices(),
      color: PettiColors.marigold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PettiSpacing.s4,
          PettiSpacing.s2,
          PettiSpacing.s4,
          // Bottom padding leaves room for the floating "Agregar mascota"
          // FAB so the last card / CTA never sits behind it. PettiSpacing
          // tops out at s8 (64); we add a manual gap on top of s8 inside
          // a SizedBox below the CTA.
          PettiSpacing.s8,
        ),
        children: [
          // Headline section — matches the design bundle's home-screen
          // pattern (plans/2026-05-11-phone-side-home-zone.md, the
          // Pets + Activity Dashboard handoff). Replaces the previous
          // uppercase "TUS MASCOTAS" eyebrow.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PettiSpacing.s2,
              PettiSpacing.s2,
              PettiSpacing.s2,
              PettiSpacing.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus mascotas',
                  style: PettiText.h2().copyWith(
                    fontSize: 22,
                    height: 1.1,
                    letterSpacing: -0.55,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca una mascota para ver su ubicación.',
                  style: PettiText.body().copyWith(
                    fontSize: 13,
                    color: PettiColors.trail,
                  ),
                ),
              ],
            ),
          ),
          ...traccar.devices.map(
              (device) => _PetCard(device: device, traccar: traccar)),
          const SizedBox(height: PettiSpacing.s4),
          _VerActividadCta(),
          // Tail spacer so the FAB never overlaps the dark CTA.
          const SizedBox(height: PettiSpacing.s7),
        ],
      ),
    );
  }

  void _navigateToScanner() {
    // Cut over from legacy QRScannerScreen → redesigned A4/A6 flow on
    // 2026-05-03. The OnboardingFlowController owns the full A4 →
    // A4.5 → provision → A6 sequence including pet profile capture
    // and the Mode 8 wizard. See:
    //   docs/plans/2026-04-30-home-setup-reconciler.md
    //   lib/screens/onboarding/redesign/onboarding_flow_controller.dart
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingFlowController()),
    );
  }
}

/// Single pet/device card — design bundle's `PetCardSummary`.
///
/// Avatar gradient + name + (location · last sync OR "sin conexión" + last
/// sync). Tap → DeviceDetailScreen (which has the map). Removed the
/// PettiStatusPill + PettiBatteryBadge stack from the old card — battery /
/// status now surface in the device-detail screen the user lands on.
class _PetCard extends StatelessWidget {
  final dynamic device; // Device — keeping dynamic to avoid coupling to model
  final TraccarProvider traccar;

  const _PetCard({required this.device, required this.traccar});

  @override
  Widget build(BuildContext context) {
    final position = traccar.getLastPosition(device.traccarId!);
    final bool isOnline = device.isOnline;
    final DateTime? lastUpdate = device.lastUpdate as DateTime?;

    final lastSyncText = isOnline
        ? 'En línea'
        : (lastUpdate != null
            ? _relativeTimeEs(lastUpdate)
            : 'sin señal');

    // Location subtitle:
    //   online + position → "<address or coords> · <relative time>"
    //   offline           → "Sin conexión · <last seen>"
    final String subtitle;
    final IconData subtitleIcon;
    final Color subtitleIconColor;
    if (isOnline && position != null) {
      final loc = position.address?.isNotEmpty == true
          ? position.address!
          : position.coordinatesText;
      subtitle = '$loc · $lastSyncText';
      subtitleIcon = Icons.place;
      subtitleIconColor = PettiColors.marigoldDim;
    } else if (position != null) {
      // Offline but we have a last-known position.
      final loc = position.address?.isNotEmpty == true
          ? position.address!
          : position.coordinatesText;
      subtitle = '$loc · $lastSyncText';
      subtitleIcon = Icons.wifi_off_rounded;
      subtitleIconColor = PettiColors.trail;
    } else {
      subtitle = 'Sin conexión · $lastSyncText';
      subtitleIcon = Icons.wifi_off_rounded;
      subtitleIconColor = PettiColors.trail;
    }

    final initial = (device.name as String).isNotEmpty
        ? (device.name as String).substring(0, 1).toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: PettiSpacing.s3),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeviceDetailScreen(device: device),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: PettiColors.midnight.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _PetCircleAvatar(
                  name: device.name as String,
                  initial: initial,
                  isOnline: isOnline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name as String,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: PettiColors.midnight,
                          letterSpacing: -0.34,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            subtitleIcon,
                            size: 13,
                            color: subtitleIconColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                color: isOnline
                                    ? PettiColors.fg
                                    : PettiColors.trail,
                                letterSpacing: -0.0625,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: PettiColors.trail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Spanish relative-time formatter, mirrors Traccar's "hace 2 horas".
  /// Kept inline here (rather than shared) because the same formatter
  /// already lives in device_settings_screen.dart with the exact same
  /// breakpoints; the duplication is intentional until a third caller
  /// shows up and motivates lifting it into utils/.
  String _relativeTimeEs(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 30) return 'hace unos segundos';
    if (diff.inMinutes < 1) return 'hace ${diff.inSeconds} s';
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

/// Avatar — gradient circle + initial letter, with an online indicator
/// dot at the bottom-right. Color picked deterministically via
/// `petAvatarFor(name)` so the same pet always gets the same gradient.
class _PetCircleAvatar extends StatelessWidget {
  final String name;
  final String initial;
  final bool isOnline;
  static const double size = 48;

  const _PetCircleAvatar({
    required this.name,
    required this.initial,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final palette = petAvatarFor(name);
    final dotSize = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(14, 27, 44, 0.10),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
                color: PettiColors.midnight,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? PettiColors.sabana : PettiColors.trail,
                border: Border.all(color: PettiColors.cloud, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ver actividad" dark CTA — Garmin-style activity-screen entry, lives
/// below the pet list. Replaces the activity icon previously in the
/// AppBar.
class _VerActividadCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: PettiColors.midnight,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () {
          final traccar =
              Provider.of<TraccarProvider>(context, listen: false);
          final firestore = FirestoreService();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PetActivityScreen.live(
                loader: () => realActivitiesForUser(
                  traccar: traccar,
                  firestore: firestore,
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: PettiColors.midnight.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PettiColors.marigold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: PettiColors.marigold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ver actividad',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PettiColors.cloud,
                        letterSpacing: -0.225,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Paseos, pasos y frecuencia cardíaca',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: PettiColors.cloud.withValues(alpha: 0.6),
                        letterSpacing: -0.058,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: PettiColors.cloud.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
