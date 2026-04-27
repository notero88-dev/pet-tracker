// Petti foreground alert banner.
//
// When the app is in the foreground and an FCM push arrives, iOS actively
// suppresses the OS-level notification (intentionally — foreground apps
// are expected to surface their own UI). On Android the OS notification
// still fires, but it's much less effective when the user is already
// looking at the app. This widget is what we show instead: a Petti-styled
// card that slides down from the top of the screen, holds for a few
// seconds, and is tappable to open the AlertDetailScreen.
//
// The card itself is a stateless widget; the lifecycle (insert, animate,
// auto-dismiss, route on tap) lives in PettiAlertOverlay below, which
// uses Flutter's Overlay + OverlayEntry primitives so the banner floats
// above whatever screen is currently active without disturbing the route
// stack.
//
// Visual style varies by alert severity:
//   critical → alert-red soft fill, alert-red icon (e.g. geofenceExit, SOS)
//   warning  → marigold-soft fill, marigold-dim icon (e.g. lowBattery)
//   info     → sabana-soft fill, sabana icon (e.g. geofenceEnter, "back home")
//
// Severity comes from the FCM data field `severity`. See
// pettrack-backend/push-service/src/utils/templates.js for the source.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../utils/petti_theme.dart';

// =============================================================================
// PettiAlertBanner — the widget itself
// =============================================================================

class PettiAlertBanner extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const PettiAlertBanner({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _toneFor(notification);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        PettiSpacing.s4,
        media.padding.top + PettiSpacing.s2,
        PettiSpacing.s4,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(PettiRadii.md),
              border: Border.all(color: theme.borderColor, width: 1),
              boxShadow: PettiShadows.elevation2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.iconBg,
                    borderRadius: BorderRadius.circular(PettiRadii.sm),
                  ),
                  child: Icon(theme.icon, size: 22, color: theme.iconColor),
                ),
                const SizedBox(width: PettiSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: PettiText.bodyStrong()
                            .copyWith(fontSize: 15, color: theme.textColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        style: PettiText.bodySm()
                            .copyWith(color: theme.textColor.withValues(alpha: 0.85)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PettiSpacing.s2),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onDismiss,
                    child: Padding(
                      padding: const EdgeInsets.all(PettiSpacing.s2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _BannerTone — colors + icon picked from severity / type
// =============================================================================

class _BannerTone {
  final Color background;
  final Color borderColor;
  final Color iconBg;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
  const _BannerTone({
    required this.background,
    required this.borderColor,
    required this.iconBg,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}

_BannerTone _toneFor(AppNotification n) {
  // Pull severity from the FCM data field if present (push-service sends it).
  // Fall back to inferring from notification type.
  final severity = (n.data?['severity'] as String?) ?? _inferSeverity(n.type);

  switch (severity) {
    case 'critical':
      return _BannerTone(
        background: PettiColors.alertSoft,
        borderColor: PettiColors.alert.withValues(alpha: 0.3),
        iconBg: PettiColors.alert.withValues(alpha: 0.16),
        iconColor: PettiColors.alert,
        textColor: PettiColors.midnight,
        icon: _iconFor(n.type),
      );
    case 'info':
      return _BannerTone(
        background: PettiColors.sabanaSoft,
        borderColor: PettiColors.sabana.withValues(alpha: 0.3),
        iconBg: PettiColors.sabana.withValues(alpha: 0.18),
        iconColor: PettiColors.sabana,
        textColor: PettiColors.midnight,
        icon: _iconFor(n.type),
      );
    case 'warning':
    default:
      return _BannerTone(
        background: PettiColors.marigoldSoft,
        borderColor: PettiColors.marigold.withValues(alpha: 0.35),
        iconBg: PettiColors.marigold.withValues(alpha: 0.2),
        iconColor: PettiColors.marigoldDim,
        textColor: PettiColors.midnight,
        icon: _iconFor(n.type),
      );
  }
}

String _inferSeverity(NotificationType type) {
  switch (type) {
    case NotificationType.geofenceExit:
      return 'critical';
    case NotificationType.geofenceEnter:
    case NotificationType.deviceOnline:
      return 'info';
    case NotificationType.batteryLow:
    case NotificationType.deviceOffline:
    case NotificationType.speedAlert:
    case NotificationType.general:
      return 'warning';
  }
}

IconData _iconFor(NotificationType type) {
  switch (type) {
    case NotificationType.geofenceExit:
      return Icons.directions_run_rounded;
    case NotificationType.geofenceEnter:
      return Icons.home_rounded;
    case NotificationType.batteryLow:
      return Icons.battery_2_bar_rounded;
    case NotificationType.deviceOffline:
      return Icons.signal_wifi_off_rounded;
    case NotificationType.deviceOnline:
      return Icons.signal_wifi_4_bar_rounded;
    case NotificationType.speedAlert:
      return Icons.speed_rounded;
    case NotificationType.general:
      return Icons.notifications_rounded;
  }
}

// =============================================================================
// PettiAlertOverlay — controls the banner's lifecycle
//
// Usage from anywhere in the app (typically from FCM handlers):
//
//   PettiAlertOverlay.show(
//     notification: appNotification,
//     onTap: () => Navigator.push(... AlertDetailScreen ...),
//   );
//
// Internally:
//   - Inserts an OverlayEntry attached to the global navigator's overlay
//   - Drives a slide-down animation via a separate StatefulWidget
//   - Auto-dismisses after `holdDuration` (default 6s)
//   - Tapping calls onTap and dismisses
//   - Tapping the close icon dismisses without firing onTap
//   - If a second alert arrives while one is showing, the first is dismissed
//     immediately and the second slides in (no stacking)
// =============================================================================

class PettiAlertOverlay {
  static OverlayEntry? _currentEntry;
  static _PettiAlertBannerHostState? _currentState;

  /// Show a banner for `notification`. Tap fires `onTap` and dismisses.
  static void show({
    required BuildContext context,
    required AppNotification notification,
    required VoidCallback onTap,
    Duration holdDuration = const Duration(seconds: 6),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _showOnOverlay(
      overlay: overlay,
      notification: notification,
      onTap: onTap,
      holdDuration: holdDuration,
    );
  }

  /// Variant for callers that hold an OverlayState directly (e.g. FCM
  /// handlers using AppNavigator.navigatorKey.currentState!.overlay!).
  static void showOnOverlay({
    required OverlayState overlay,
    required AppNotification notification,
    required VoidCallback onTap,
    Duration holdDuration = const Duration(seconds: 6),
  }) =>
      _showOnOverlay(
        overlay: overlay,
        notification: notification,
        onTap: onTap,
        holdDuration: holdDuration,
      );

  static void _showOnOverlay({
    required OverlayState overlay,
    required AppNotification notification,
    required VoidCallback onTap,
    required Duration holdDuration,
  }) {
    // If a banner is currently showing, dismiss it before inserting the new
    // one so we don't stack indefinitely. Any auto-dismiss timer attached
    // to the previous banner is canceled by its dispose.
    _currentState?.dismiss();
    _currentEntry?.remove();
    _currentEntry = null;
    _currentState = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _PettiAlertBannerHost(
        notification: notification,
        holdDuration: holdDuration,
        onTap: () {
          // Fire the tap callback first so the user sees navigation start,
          // then animate out.
          onTap();
          _dismissCurrent();
        },
        onDismiss: _dismissCurrent,
        registerState: (state) => _currentState = state,
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _dismissCurrent() {
    _currentState?.dismiss();
    // The entry removes itself after the slide-out animation finishes via
    // _PettiAlertBannerHostState._removeEntry().
  }

  /// Internal — called from the host widget's animation completion callback.
  static void _removeEntry() {
    _currentEntry?.remove();
    _currentEntry = null;
    _currentState = null;
  }
}

// =============================================================================
// _PettiAlertBannerHost — handles slide-in / slide-out animation and the
// auto-dismiss timer. Internal — not exposed.
// =============================================================================

class _PettiAlertBannerHost extends StatefulWidget {
  final AppNotification notification;
  final Duration holdDuration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final void Function(_PettiAlertBannerHostState state) registerState;

  const _PettiAlertBannerHost({
    required this.notification,
    required this.holdDuration,
    required this.onTap,
    required this.onDismiss,
    required this.registerState,
  });

  @override
  State<_PettiAlertBannerHost> createState() => _PettiAlertBannerHostState();
}

class _PettiAlertBannerHostState extends State<_PettiAlertBannerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  Timer? _autoDismiss;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    widget.registerState(this);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();

    _autoDismiss = Timer(widget.holdDuration, dismiss);
  }

  /// Animate out and remove the OverlayEntry.
  void dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _autoDismiss?.cancel();
    _ctrl.reverse().then((_) {
      if (mounted) PettiAlertOverlay._removeEntry();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, child) {
        // Slide from -100% (above the screen) to 0% (resting position).
        return FractionalTranslation(
          translation: Offset(0, -1 + _slide.value),
          child: Opacity(opacity: _slide.value, child: child),
        );
      },
      child: SafeArea(
        bottom: false,
        // Position banner at the top of the screen — Align rather than
        // Positioned so it respects MediaQuery insets without absolute math.
        child: Align(
          alignment: Alignment.topCenter,
          child: PettiAlertBanner(
            notification: widget.notification,
            onTap: widget.onTap,
            onDismiss: widget.onDismiss,
          ),
        ),
      ),
    );
  }
}
