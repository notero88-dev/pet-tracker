// HomeSetupStatusBanner — surfaces the in-flight Phase 1 reconciler intent
// for a given device. Polls GET /devices/:imei/home-setup at 3s cadence
// while a non-terminal intent exists; renders nothing otherwise.
//
// Why this widget exists (Phase 1.1 plan-doc):
//   The Phase 1 inline runner is durable across app close + network blips,
//   so a user who started a home-setup wizard and then backgrounded the
//   app, lost signal, or killed the process should re-open the app and
//   see "we're still working on it" — not a silent reset to the empty
//   state. The banner is the surface that proves durability is real.
//
// State taxonomy mirrors the table in
//   pettrack-backend/docs/plans/2026-04-30-home-setup-reconciler.md.
//   Six visible states: Guardando, Configurando, Casi listo, Listo
//   (auto-dismiss 5s), Tomó más tiempo, Necesitamos tu ayuda. Plus
//   "No pudimos configurar" for hard-failed terminal.
//
// What this widget DOES NOT do (deferred):
//   - "Detalles" tap-through to a step-by-step view (Phase 1.2).
//   - Server-driven push notifications (Phase 2 — needs the Postgres
//     LISTEN/NOTIFY + WebSocket bridge).
//   - Per-device banner stacking when a user has multiple Pettis. v1
//     surfaces one banner per imei; the home screen renders one per
//     device card if it ever needs to.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/provisioning_api.dart';
import '../../utils/petti_theme.dart';

/// Polling cadence — matches setup_geofence_screen's in-screen poll, so
/// a user moving between the screen and home doesn't see two surfaces
/// updating out of sync.
const Duration _kPollInterval = Duration(seconds: 3);

/// How long the success state stays visible before auto-dismissing.
const Duration _kSuccessLinger = Duration(seconds: 5);

/// Threshold beyond which we transition from "Configurando" → "Tomó más
/// tiempo". 10 min matches the Phase 1 plan-doc's intermediate stall state.
const Duration _kSlowThreshold = Duration(minutes: 10);

/// Threshold beyond which we surface the "Necesitamos tu ayuda" copy.
/// Server-side stall detection at 30 min (Phase 2 spec); banner UX
/// matches.
const Duration _kStallThreshold = Duration(minutes: 30);

class HomeSetupStatusBanner extends StatefulWidget {
  final String imei;

  /// Optional ProvisioningApi injection for tests. Production callers
  /// should leave this null.
  final ProvisioningApi? api;

  const HomeSetupStatusBanner({
    super.key,
    required this.imei,
    this.api,
  });

  @override
  State<HomeSetupStatusBanner> createState() => _HomeSetupStatusBannerState();
}

class _HomeSetupStatusBannerState extends State<HomeSetupStatusBanner> {
  late final ProvisioningApi _api;
  HomeSetupIntent? _intent;
  Timer? _pollTimer;
  Timer? _dismissTimer;
  bool _dismissed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ProvisioningApi();
    _pollOnce(); // fire immediately so first frame has data
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _pollOnce());
  }

  @override
  void didUpdateWidget(covariant HomeSetupStatusBanner old) {
    super.didUpdateWidget(old);
    if (old.imei != widget.imei) {
      _resetForNewImei();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _resetForNewImei() {
    _pollTimer?.cancel();
    _dismissTimer?.cancel();
    setState(() {
      _intent = null;
      _dismissed = false;
      _loading = true;
    });
    _pollOnce();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (!mounted) return;
    try {
      // Cold start: no intentId in hand → use the active-lookup endpoint
      // (returns most-recent non-terminal intent for this IMEI, or null).
      // Once we know the intentId, switch to the by-id endpoint so the
      // banner can KEEP showing the row after it transitions to terminal
      // (lets the success state linger 5s; lets failed/cancelled stay on
      // screen until the user dismisses).
      final HomeSetupIntent? next;
      if (_intent == null) {
        next = await _api.getActiveHomeSetupIntent(imei: widget.imei);
      } else {
        next = await _api.getHomeSetupIntent(
          imei: widget.imei,
          intentId: _intent!.intentId,
        );
      }
      if (!mounted) return;
      setState(() {
        _intent = next;
        _loading = false;
      });
      _maybeStopPolling(next);
      _maybeArmAutoDismiss(next);
    } on HomeSetupApiException catch (_) {
      // Transient errors — leave the previous intent visible and try again
      // next tick. Phase 2 banner UX will surface "Esperando a que Petti
      // se conecte..." after a few consecutive failures.
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _maybeStopPolling(HomeSetupIntent? intent) {
    if (intent == null) {
      // No active intent. Keep polling at the same cadence so a fresh
      // POST elsewhere in the app (e.g. user starts a re-setup) gets
      // picked up without rebuilding the widget. This is cheap — 1
      // request per 3 seconds against a hot-path endpoint.
      return;
    }
    if (intent.isTerminal) {
      _pollTimer?.cancel();
    }
  }

  void _maybeArmAutoDismiss(HomeSetupIntent? intent) {
    if (intent?.isSuccess == true && _dismissTimer == null) {
      _dismissTimer = Timer(_kSuccessLinger, () {
        if (!mounted) return;
        setState(() => _dismissed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    if (_loading && _intent == null) return const SizedBox.shrink();
    if (_intent == null) return const SizedBox.shrink();

    final state = _resolveBannerState(_intent!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s4, PettiSpacing.s2, PettiSpacing.s4, 0,
      ),
      child: _BannerCard(state: state),
    );
  }
}

// ─── State derivation ───────────────────────────────────────────────────

class _BannerState {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showSpinner;

  _BannerState({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.foregroundColor,
    this.subtitle,
    this.showSpinner = false,
  });
}

_BannerState _resolveBannerState(HomeSetupIntent intent) {
  final elapsed = Duration(seconds: intent.elapsedSeconds);

  // Terminal states first.
  if (intent.isSuccess) {
    return _BannerState(
      title: '✓ Listo — Petti está protegido',
      icon: Icons.check_circle_rounded,
      accentColor: PettiColors.sabana,
      backgroundColor: PettiColors.sabanaSoft,
      foregroundColor: PettiColors.midnight,
    );
  }
  if (intent.status == 'failed') {
    return _BannerState(
      title: 'No pudimos configurar a Petti',
      subtitle: intent.lastError != null
          ? 'Toca para ver detalles'
          : 'Inténtalo de nuevo',
      icon: Icons.error_outline_rounded,
      accentColor: PettiColors.alert,
      backgroundColor: PettiColors.alertSoft,
      foregroundColor: PettiColors.midnight,
    );
  }
  if (intent.status == 'cancelled') {
    return _BannerState(
      title: 'Configuración cancelada',
      icon: Icons.cancel_outlined,
      accentColor: PettiColors.trail,
      backgroundColor: PettiColors.fog,
      foregroundColor: PettiColors.midnight,
    );
  }
  if (intent.status == 'superseded') {
    return _BannerState(
      title: 'Iniciaste otra configuración',
      icon: Icons.swap_horiz_rounded,
      accentColor: PettiColors.trail,
      backgroundColor: PettiColors.fog,
      foregroundColor: PettiColors.midnight,
    );
  }

  // Non-terminal — pick by elapsed and step.
  if (elapsed >= _kStallThreshold) {
    return _BannerState(
      title: 'Necesitamos tu ayuda',
      subtitle: 'Llevamos un rato y no logramos terminar.',
      icon: Icons.support_agent_rounded,
      accentColor: PettiColors.duskRose,
      backgroundColor: PettiColors.duskSoft,
      foregroundColor: PettiColors.midnight,
    );
  }
  if (elapsed >= _kSlowThreshold) {
    return _BannerState(
      title: 'Petti está tomando más tiempo del esperado',
      subtitle: 'Sigue intentando — te avisamos en cuanto termine.',
      icon: Icons.hourglass_top_rounded,
      accentColor: PettiColors.cafe,
      backgroundColor: PettiColors.cafeSoft,
      foregroundColor: PettiColors.midnight,
      showSpinner: true,
    );
  }
  if (intent.status == 'pending' && elapsed.inSeconds < 30) {
    return _BannerState(
      title: 'Guardando...',
      icon: Icons.cloud_upload_outlined,
      accentColor: PettiColors.marigold,
      backgroundColor: PettiColors.marigoldSoft,
      foregroundColor: PettiColors.midnight,
      showSpinner: true,
    );
  }
  if (intent.step == 'mode' || intent.status == 'soft_confirmed') {
    return _BannerState(
      title: 'Casi listo...',
      icon: Icons.bolt_rounded,
      accentColor: PettiColors.marigold,
      backgroundColor: PettiColors.marigoldSoft,
      foregroundColor: PettiColors.midnight,
      showSpinner: true,
    );
  }
  // Default: reconciling on scan / ap / geo, or pending past 30s.
  return _BannerState(
    title: 'Configurando a ${intent.petName ?? 'Petti'}...',
    icon: Icons.settings_remote_rounded,
    accentColor: PettiColors.marigold,
    backgroundColor: PettiColors.marigoldSoft,
    foregroundColor: PettiColors.midnight,
    showSpinner: true,
  );
}

// ─── Card ───────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final _BannerState state;

  const _BannerCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PettiMotion.std,
      curve: PettiMotion.ease,
      padding: const EdgeInsets.symmetric(
        horizontal: PettiSpacing.s3,
        vertical: PettiSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: state.backgroundColor,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        border: Border.all(
          color: state.accentColor.withValues(alpha: 0.24),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (state.showSpinner)
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(state.accentColor),
              ),
            )
          else
            Icon(state.icon, size: 22, color: state.accentColor),
          const SizedBox(width: PettiSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.title,
                  style: PettiText.bodyStrong().copyWith(
                    color: state.foregroundColor,
                    fontSize: 14,
                  ),
                ),
                if (state.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    state.subtitle!,
                    style: PettiText.bodyStrong().copyWith(
                      color: state.foregroundColor.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
