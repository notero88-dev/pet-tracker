// PettiMainTabsScreen — the post-login root with a 4-tab bottom nav.
//
// Source: design bundle 2026-05-13 (`petti-first-design-app-v1/project/
// src/main-tabs.jsx`). The user's prompt was "haz un menú similar al de
// tractive con Mapa / Salud / Mascotas / Cuenta" + "en Cuenta modifica
// para que se vea más fácil la sección de Zona de casa (debe estar más
// arriba)". The original Flutter app had no bottom-tab navigation — it
// used a single HomeScreen with the ☰ menu icon opening Settings as a
// pushed route. This screen replaces that root.
//
// Tabs (left → right):
//   1. Mapa     → live map for the currently-selected pet
//                 (reuses DeviceDetailScreen)
//   2. Salud    → activity / health dashboard
//                 (reuses PetActivityScreen.live)
//   3. Mascotas → rich card list of pets, tap → device-detail
//                 (new MascotasTab)
//   4. Cuenta   → user profile + Zona de casa hero + Mascotas y
//                 dispositivos + Soporte + Legal (new CuentaTab)
//
// Design intent (from chat3.md): cream surface, marigold accents,
// 28px tab-bar icons with 3px marigold underline pill on active tab,
// blur backdrop, midnight on cloud text.
//
// We keep tab state alive across switches (IndexedStack) so the live
// map's Google Maps controller + the activity screen's lazy fetches
// don't reset every time the user toggles tabs.


import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/petti_theme.dart';
import '../paywall/paywall_screen.dart';
import 'cuenta_tab.dart';
import 'mapa_tab.dart';
import 'mascotas_tab.dart';
import 'salud_tab.dart';

class PettiMainTabsScreen extends StatefulWidget {
  final int initialIndex;
  const PettiMainTabsScreen({super.key, this.initialIndex = 0});

  @override
  State<PettiMainTabsScreen> createState() => _PettiMainTabsScreenState();
}

class _PettiMainTabsScreenState extends State<PettiMainTabsScreen> {
  late int _index = widget.initialIndex.clamp(0, 3);

  @override
  void initState() {
    super.initState();
    // 2026-05-13: TraccarProvider.connect() bootstrap moved here from
    // HomeScreen.initState. The old HomeScreen was the post-login root
    // and owned this responsibility; when we replaced it with this
    // tab scaffold the connect-on-mount path silently disappeared,
    // leaving `traccar.devices` empty even for fully-provisioned users
    // (the "Aún no hay mascotas" empty state on a working account).
    //
    // Reads credentials from Firestore (user profile doc — populated
    // by /provision and by manual recovery scripts) and fires a single
    // connect attempt. If credentials are missing or login fails, the
    // empty state in each tab handles it gracefully.
    //
    // Deferred to post-first-frame so the build()'s Consumer<TraccarProvider>
    // gets a render with the initial loading state before connect resolves.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTraccar();
      // 2026-05-25: SubscriptionProvider also boots from here —
      // single deferred-to-first-frame batch. It does its own /me
      // fetch + wires the in_app_purchase stream listener.
      //
      // 2026-06-01: pass the current uid so a second account in the same
      // app session forces a fresh /me fetch instead of inheriting the
      // first account's status (cross-account carryover bug).
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<SubscriptionProvider>(context, listen: false)
          .initialize(uid: auth.currentUser?.uid);
    });
  }

  Future<void> _initializeTraccar() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final traccarProvider =
        Provider.of<TraccarProvider>(context, listen: false);
    // Un-settle the loading state up front so the Mapa/Salud tabs render a
    // spinner — not the "Aún no hay mascotas" empty state — for the whole
    // bootstrap window (Firestore creds fetch + Traccar connect + device
    // load). completeInitialLoad() in the finally settles it again on
    // every exit path. See TraccarProvider.initialLoadComplete.
    traccarProvider.beginInitialLoad();
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      traccarProvider.completeInitialLoad();
      return;
    }

    try {
      final userProfile = await FirestoreService().getUserProfile(userId);
      if (userProfile == null) return;
      final email = userProfile['traccarEmail'] as String?;
      final password = userProfile['traccarPassword'] as String?;
      if (email == null || password == null) {
        debugPrint(
            '[PettiMainTabs] user has no traccar credentials yet — empty state');
        // Defense in depth (2026-06-01): TraccarProvider is app-scoped and
        // isn't torn down on sign-out, so it can still hold the PREVIOUS
        // account's devices. A brand-new account has no creds and would
        // otherwise render those stale devices as its own pets. Clear them.
        await traccarProvider.disconnect();
        return;
      }
      final success = await traccarProvider.connect(email, password);
      if (success) {
        await traccarProvider.refreshDevices();
      }
      // Devices (if any) are loaded now — settle the UI so Mapa draws the
      // map (or its genuine empty state) immediately, BEFORE the slower
      // Firestore pet reconciliation below. Otherwise the spinner lingers
      // through the reconcile round-trips even though the map is ready.
      traccarProvider.completeInitialLoad();
      if (success) {
        // 2026-05-25: reconcile Firestore pets against Traccar devices.
        // Handles the "user has a backend device but no Firestore pet
        // doc" case, which surfaces as Mascotas / Salud showing empty
        // even though Mapa renders a device. Causes:
        //   - Demo / review accounts seeded by setup-review-account.sh
        //     (the script creates Postgres + Traccar but skips Firestore).
        //   - Users who reinstall the app: pet_profile_screen.createPet()
        //     only fires during fresh provisioning; on a re-install
        //     after deletion the onboarding flow detects the
        //     pre-provisioned device and skips that step.
        //   - Manual admin tools / scripts that create Traccar devices.
        //
        // The reconciler is forward-only (device exists → ensure pet
        // exists); never deletes Firestore pets that no longer have a
        // matching device — they could be petless profiles the user
        // wants to keep.
        await _reconcileFirestorePets(traccarProvider);
      }
    } catch (e, stack) {
      // Network blip, expired creds, no device yet — each tab's empty
      // state handles the missing-devices case. We just log and move on.
      //
      // 2026-05-24: a permission-denied here once meant Firestore Security
      // Rules were broken (the default 30-day trial expired). See
      // `pettrack-backend/firebase/firestore.rules` for the deployed
      // rules + the deploy script in push-service/scripts/.
      //
      // Also report to Crashlytics as a NON-FATAL — fatal=false because
      // the app continues to function (just renders the empty Mapa); we
      // only want this to show up in the Firebase Console dashboard as
      // a recurring class of issue so we notice 50 users hitting
      // permission-denied before they email us. recordError attaches a
      // `reason` so we can filter by it in the Crashlytics UI.
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: '_initializeTraccar — failed to load Traccar credentials '
            'and/or connect to Traccar',
        fatal: false,
      );
      debugPrint('[PettiMainTabs] Traccar init failed: $e');
    } finally {
      // Safety net for the early-return paths (no profile / no creds) and
      // any error above: always settle the UI out of the loading state so
      // a tab never spins forever. Idempotent — a no-op if the happy path
      // already called it.
      traccarProvider.completeInitialLoad();
    }
  }

  /// Forward-only reconciler: ensures every Traccar device the user owns
  /// has a corresponding Firestore pet doc. Idempotent — only creates
  /// when no match exists for a given traccarDeviceId.
  ///
  /// Best-effort: any single device's failure is logged + recorded as a
  /// non-fatal in Crashlytics, but doesn't abort the loop for other
  /// devices. The app continues to function with the partial-state
  /// (whatever Firestore pets DID load).
  Future<void> _reconcileFirestorePets(TraccarProvider traccar) async {
    try {
      final firestore = FirestoreService();
      final existingPets = await firestore.getUserPets();
      final existingDeviceIds = existingPets
          .map((p) => p['traccarDeviceId'])
          .whereType<int>()
          .toSet();

      for (final device in traccar.devices) {
        final traccarId = device.traccarId;
        if (traccarId == null) continue;
        if (existingDeviceIds.contains(traccarId)) continue;

        // No Firestore pet for this device. Create a placeholder using
        // the Traccar device name as a sensible default. User can rename
        // later from Mascotas → este pet → Editar perfil. We default
        // type='dog' because that's the dominant species at v1 launch;
        // the user can change to 'cat' / other from the same edit screen.
        try {
          await firestore.createPet(
            name: device.name.isNotEmpty ? device.name : 'Mi mascota',
            type: 'dog',
            traccarDeviceId: traccarId,
            deviceImei: device.uniqueId,
          );
          debugPrint(
            '[PettiMainTabs] reconciled pet for device $traccarId '
            '(name=${device.name})',
          );
        } catch (e, stack) {
          FirebaseCrashlytics.instance.recordError(
            e,
            stack,
            reason: '_reconcileFirestorePets — createPet failed for '
                'device $traccarId (${device.uniqueId})',
            fatal: false,
          );
        }
      }
    } catch (e, stack) {
      // Lookup itself failed (network / permission). Log + move on —
      // the user still sees Mapa (devices loaded) but Mascotas / Salud
      // tabs may show stale state until next launch.
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: '_reconcileFirestorePets — getUserPets failed',
        fatal: false,
      );
      debugPrint('[PettiMainTabs] pet reconciliation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2026-05-25: full paywall takeover when the user has no live
    // subscription. Per the IAP plan's product decisions:
    //   - "Paywall after provisioning" → first-time users land in
    //     PettiMainTabsScreen with status=`none` and immediately see
    //     the paywall (no separate onboarding-paywall step needed)
    //   - "Full paywall — nothing works" for expired users → same
    //     treatment for `expired` / `refunded`
    //
    // `unknown` is the brief window before /me returns on cold launch.
    // We DELIBERATELY pass through to the normal tabs during this
    // window so returning subscribed users don't see a paywall flash
    // before /me confirms their status. The worst case (expired user
    // sees ~1s of tabs before paywall) is fine; the best case
    // (subscribed user) gets no flicker.
    final subStatus = context.watch<SubscriptionProvider>().status;
    // Same takeover on iOS + Android. The platform-specific
    // relaxation for Android-`none` was removed 2026-05-28 along with
    // the matching CTA block in PaywallScreen — Phase D of the
    // Android launch wired /verify-purchase + the Play Developer API,
    // so Play Billing is now shippable. Keeping the gate uniform
    // avoids a divergence where an Android user could indefinitely
    // skip paying while iOS users couldn't.
    if (subStatus == SubscriptionStatus.none
        || subStatus == SubscriptionStatus.expired
        || subStatus == SubscriptionStatus.refunded) {
      return const PaywallScreen();
    }

    return Scaffold(
      backgroundColor: PettiColors.cloud,
      // The tab content fills the full viewport — each tab manages its
      // own header / scroll padding so the bar can float over the content
      // (Mapa) or sit cleanly underneath it (the cream tabs).
      body: IndexedStack(
        index: _index,
        children: const [
          MapaTab(),
          SaludTab(),
          MascotasTab(),
          CuentaTab(),
        ],
      ),
      bottomNavigationBar: _PettiTabBar(
        active: _index,
        onChange: (i) => setState(() => _index = i),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Bottom tab bar — cream-on-cloud, marigold underline pill for selection.
//
// Visual spec (from main-tabs.jsx:17-61):
//   - background: rgba(250,247,242,0.92) + 20px backdrop blur
//   - border-top: 1px borderLight
//   - padding: 8px 8px 28px (extra bottom for iOS home indicator)
//   - active: marigoldDim text + 3px × 24px marigold pill at top
//   - inactive: trail (n500) text, weight 500
// Flutter doesn't expose backdrop-filter ergonomically inside the
// BottomAppBar slot, so we use solid cream — visually close enough.
// -----------------------------------------------------------------------------

class _PettiTabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onChange;
  const _PettiTabBar({required this.active, required this.onChange});

  static const _tabs = <_TabSpec>[
    _TabSpec(label: 'Mapa', icon: Icons.place_outlined, activeIcon: Icons.place),
    _TabSpec(
        label: 'Salud',
        icon: Icons.monitor_heart_outlined,
        activeIcon: Icons.monitor_heart),
    _TabSpec(label: 'Mascotas', icon: Icons.pets_outlined, activeIcon: Icons.pets),
    _TabSpec(label: 'Cuenta', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PettiColors.cloud,
        border: Border(top: BorderSide(color: PettiColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final sel = i == active;
              final spec = _tabs[i];
              return Expanded(
                child: InkResponse(
                  onTap: () => onChange(i),
                  radius: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 6,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          width: sel ? 24 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: PettiColors.marigold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          Icon(
                            sel ? spec.activeIcon : spec.icon,
                            size: 22,
                            color: sel
                                ? PettiColors.marigoldDim
                                : PettiColors.trail,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            spec.label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: -0.005 * 11,
                              color: sel
                                  ? PettiColors.marigoldDim
                                  : PettiColors.trail,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// Shared screen-header used by Salud / Mascotas / Cuenta tabs.
/// Mirrors the ScreenHeader component in main-tabs.jsx:64-87 —
/// 58px top padding, 28px Space Grotesk title, optional uppercase
/// eyebrow, optional right-aligned icon buttons.
class PettiTabScreenHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final List<Widget> trailing;
  const PettiTabScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.08 * 11,
                      color: PettiColors.trail,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: PettiColors.midnight,
                    letterSpacing: -0.03 * 28,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          if (trailing.isNotEmpty)
            Row(
              children: [
                for (var i = 0; i < trailing.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  trailing[i],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Round, white-on-cloud icon button used in the tab headers.
class PettiTabIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool badge;
  const PettiTabIconBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: PettiColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: PettiColors.midnight.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, size: 18, color: PettiColors.midnight)),
            if (badge)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: PettiColors.marigold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
