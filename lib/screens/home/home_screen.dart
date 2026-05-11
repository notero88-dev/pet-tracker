import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_primitives.dart';
import '../onboarding/redesign/onboarding_flow_controller.dart';
import '../device/device_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/settings_screen.dart';
import '../activity/pet_activity_screen.dart';
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
          // Activity dashboard — Garmin-flavored daily stats. Live load:
          // the screen shows a loading skeleton, then renders metrics
          // computed from Traccar position history. Falls back to demo
          // data with a banner if the load fails.
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined),
            tooltip: 'Actividad',
            onPressed: () {
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
          ),
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
          PettiSpacing.s4,
          PettiSpacing.s4,
          // Bottom padding leaves room for the floating "Agregar mascota"
          // FAB so the last card never sits behind it.
          PettiSpacing.s8,
        ),
        children: [
          // Home-setup status banner — removed from home screen 2026-05-11
          // (Phase B v2 of plans/2026-05-11-phone-side-home-zone.md). The
          // banner was duplicating + contradicting the wizard's own
          // "Zona de casa guardada · se aplicará cuando se mueva" success
          // screen and the Settings entry card's configured variant.
          // Because the gateway now queues commands for up to 4h waiting
          // on the (offline) device, intents stay in 'reconciling' for
          // hours — the banner would stick around showing "Configurando..."
          // long after the user thought they were done.
          //
          // The widget file is left on disk in case we want a slimmer,
          // copy-corrected version later, but it's no longer wired here.
          // Section header — quiet "Tus mascotas" eyebrow above the cards.
          Padding(
            padding: const EdgeInsets.only(
              left: PettiSpacing.s2,
              top: PettiSpacing.s2,
              bottom: PettiSpacing.s3,
            ),
            child: Text(
              'TUS MASCOTAS',
              style: PettiText.meta(),
            ),
          ),
          ...traccar.devices.map(
              (device) => _PetCard(device: device, traccar: traccar)),
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

/// Single pet/device card. Tap → DeviceDetailScreen.
///
/// Layout: avatar + name + subtitle + battery + status chip in a horizontal
/// PettiCard. Sized for one-handed thumb tap.
class _PetCard extends StatelessWidget {
  final dynamic device; // Device — keeping dynamic to avoid coupling to model
  final TraccarProvider traccar;

  const _PetCard({required this.device, required this.traccar});

  @override
  Widget build(BuildContext context) {
    final position = traccar.getLastPosition(device.traccarId!);
    final bool isOnline = device.isOnline;
    final DateTime? lastUpdate = device.lastUpdate as DateTime?;
    final int? battery = position?.batteryLevel;

    // Status pill copy mirrors Traccar's "Activo hace 2 horas" pattern:
    // green "En línea" when fresh (<30 min), muted "Activo hace X" when we
    // have a known-but-stale lastUpdate, and a true "Sin señal" only when
    // the device has never reported. Distinguishing stale vs. never-seen
    // matters because the device commonly goes quiet on Mode 8 stationary
    // — that's not a signal failure, it's expected reporting behavior.
    final PettiStatus statusKind;
    final String statusLabel;
    if (isOnline) {
      statusKind = PettiStatus.online;
      statusLabel = 'En línea';
    } else if (lastUpdate != null) {
      statusKind = PettiStatus.warning;
      statusLabel = 'Activo ${_relativeTimeEs(lastUpdate)}';
    } else {
      statusKind = PettiStatus.offline;
      statusLabel = 'Sin señal';
    }

    // Bucket battery to nearest 20% for the Petti badge (which expects
    // 20/40/60/80/100 to keep visual states from being too noisy).
    int? bucket;
    if (battery != null) {
      bucket = ((battery / 20).round() * 20).clamp(20, 100);
    }

    final initial = (device.name as String).isNotEmpty
        ? (device.name as String).substring(0, 1)
        : '?';

    // PettiCard doesn't take onTap; wrap it in Material+InkWell so the tap
    // ripple respects the rounded corners and matches the rest of Petti's
    // touch feedback.
    return Padding(
      padding: const EdgeInsets.only(bottom: PettiSpacing.s3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeviceDetailScreen(device: device),
            ),
          ),
          child: PettiCard(
            // Override the default horizontal margin — we're already inside
            // a ListView with horizontal padding.
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(PettiSpacing.s4),
            child: Row(
              children: [
                PettiPetAvatar(initial: initial, size: 56),
                const SizedBox(width: PettiSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name as String,
                        style: PettiText.h4(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: PettiSpacing.s1),
                      Text(
                        position != null
                            ? (position.address ?? position.coordinatesText)
                            : 'Sin ubicación reciente',
                        style: PettiText.bodySm()
                            .copyWith(color: PettiColors.fgDim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: PettiSpacing.s2),
                      Row(
                        children: [
                          PettiStatusPill(
                            kind: statusKind,
                            label: statusLabel,
                          ),
                          if (bucket != null) ...[
                            const SizedBox(width: PettiSpacing.s2),
                            PettiBatteryBadge(percentBucket: bucket),
                          ],
                        ],
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
