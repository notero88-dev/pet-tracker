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
      Provider.of<SubscriptionProvider>(context, listen: false).initialize();
    });
  }

  Future<void> _initializeTraccar() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final traccarProvider =
        Provider.of<TraccarProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    if (userId == null) return;

    try {
      final userProfile = await FirestoreService().getUserProfile(userId);
      if (userProfile == null) return;
      final email = userProfile['traccarEmail'] as String?;
      final password = userProfile['traccarPassword'] as String?;
      if (email == null || password == null) {
        debugPrint(
            '[PettiMainTabs] user has no traccar credentials yet — empty state');
        return;
      }
      final success = await traccarProvider.connect(email, password);
      if (success) {
        await traccarProvider.refreshDevices();
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
