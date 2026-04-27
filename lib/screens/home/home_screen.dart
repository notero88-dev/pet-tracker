import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_primitives.dart';
import '../onboarding/qr_scanner_screen.dart';
import '../device/device_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/settings_screen.dart';

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
        title: Text('Petti', style: PettiText.h2()),
        actions: [
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
              '¡Bienvenido a Petti!',
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
          // Section header — quiet "Tus mascotas" eyebrow above the cards.
          Padding(
            padding: const EdgeInsets.only(
              left: PettiSpacing.s2,
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
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
    final int? battery = position?.batteryLevel;

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
                            kind: isOnline
                                ? PettiStatus.online
                                : PettiStatus.offline,
                            label: isOnline ? 'En línea' : 'Sin señal',
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
}
