// PaywallScreen — the single in-app surface that asks the user to
// subscribe (or restore an existing subscription). Rendered after
// device provisioning if `subscriptionProvider.status` is `none`,
// and as a full-screen takeover whenever `status` is `expired` or
// `refunded`.
//
// Visual contract (per the plan, 2026-05-25):
//   - Hero: the Besti pin icon + "Activa tu Besti" headline
//   - Price line: "30 días gratis · luego ${monthly price}"
//   - Primary CTA: "Empezar prueba gratis" (marigold pill, full width)
//   - Secondary action: "Restaurar compra" (text link, midnight)
//   - Cream background, midnight text — reuses Petti primitives
//
// State coupling: reads from a Consumer<SubscriptionProvider>. The
// CTA disables itself while a purchase is in flight. After a
// successful purchase the provider's status flips, and any parent
// screen that gates on status (PettiMainTabsScreen, the onboarding
// controller) re-builds + dismisses the paywall.


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/subscription_provider.dart';
import '../../utils/constants.dart';
import '../../utils/petti_theme.dart';

class PaywallScreen extends StatelessWidget {
  /// When true, the screen renders with a "back" affordance and
  /// allows dismissal. Used when the paywall is pushed onto the
  /// onboarding stack as a deliberate step.
  ///
  /// When false (default), the screen is a takeover with no escape —
  /// used for `expired` users where we don't want them clicking
  /// "back" into a stale Mapa view.
  final bool allowDismiss;

  const PaywallScreen({super.key, this.allowDismiss = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, sub, _) => _PaywallBody(
            sub: sub,
            allowDismiss: allowDismiss,
          ),
        ),
      ),
    );
  }
}

class _PaywallBody extends StatefulWidget {
  final SubscriptionProvider sub;
  final bool allowDismiss;

  const _PaywallBody({required this.sub, required this.allowDismiss});

  @override
  State<_PaywallBody> createState() => _PaywallBodyState();
}

class _PaywallBodyState extends State<_PaywallBody> {
  String? _lastShownError;

  @override
  void didUpdateWidget(covariant _PaywallBody old) {
    super.didUpdateWidget(old);
    // Surface any new error from the provider as a snack. Tracked
    // via _lastShownError so we don't re-render the same one across
    // unrelated rebuilds.
    final err = widget.sub.lastError;
    if (err != null && err != _lastShownError) {
      _lastShownError = err;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    // Price string. Prefer the localized price from the store
    // (e.g. "COP $29,900.00 / month") so we don't have to keep
    // hardcoded copy in sync with App Store Connect. Fall back to a
    // constant if the store fetch hasn't resolved yet.
    final priceLabel = sub.product?.price
        ?? '${(AppConstants.monthlyPrice ~/ 1000)}.${(AppConstants.monthlyPrice % 1000).toString().padLeft(3, '0')} COP';

    return Stack(
      children: [
        // Decorative back arrow when dismissible (onboarding-flow case).
        if (widget.allowDismiss)
          Positioned(
            top: PettiSpacing.s2,
            left: PettiSpacing.s2,
            child: IconButton(
              icon: const Icon(Icons.close, color: PettiColors.midnight),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PettiSpacing.s5,
            PettiSpacing.s7,
            PettiSpacing.s5,
            PettiSpacing.s5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: PettiSpacing.s5),
              Center(
                child: Image.asset(
                  'assets/icons/besti_icon_foreground.png',
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(height: PettiSpacing.s5),
              Text(
                'Activa tu Besti',
                textAlign: TextAlign.center,
                style: PettiText.display().copyWith(
                  fontSize: 32,
                  color: PettiColors.midnight,
                ),
              ),
              const SizedBox(height: PettiSpacing.s2),
              Text(
                '30 días gratis · luego $priceLabel al mes',
                textAlign: TextAlign.center,
                style: PettiText.bodyStrong().copyWith(
                  fontSize: 16,
                  color: PettiColors.fgDim,
                ),
              ),
              const SizedBox(height: PettiSpacing.s6),
              _featureRow('Rastreo GPS en tiempo real con el modo En vivo'),
              _featureRow('Alertas si tu mascota sale de la zona segura'),
              _featureRow('Historial completo de paseos y actividad'),
              _featureRow('Cancela cuando quieras desde tu Apple ID'),
              const SizedBox(height: PettiSpacing.s7),
              // Same CTA on iOS + Android. The Android-specific "coming
              // soon" block was removed 2026-05-28 along with the
              // matching gate in petti_main_tabs_screen.dart — Phase D
              // of the Android launch wired Google verify-purchase +
              // the Play Developer API, so Play Billing is now a real
              // end-to-end path. SubscriptionProvider already branches
              // on platform under the hood (apple_iap vs google_play
              // provider strings) so the UI doesn't need to.
              ElevatedButton(
                  onPressed: sub.isPurchaseInFlight
                      ? null
                      : () => sub.startPurchase(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PettiColors.marigold,
                    foregroundColor: PettiColors.midnight,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PettiRadii.md),
                    ),
                  ),
                  child: sub.isPurchaseInFlight
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(PettiColors.midnight),
                          ),
                        )
                      : const Text('Empezar prueba gratis'),
                ),
                const SizedBox(height: PettiSpacing.s3),
                // Restore is intentionally tappable even while a
                // purchase is "in flight" — it's the natural recovery
                // path when a purchase event got dropped (StoreKit
                // glitch, network blip, app backgrounded mid-sheet).
                // Disabling it would leave the user with no way out
                // short of force-quitting. The safety timer +
                // handleAppResumed in SubscriptionProvider also help,
                // but restore is the most direct user-controlled
                // escape hatch.
                TextButton(
                  onPressed: () => sub.restorePurchases(),
                  child: const Text(
                    'Restaurar compra',
                    style: TextStyle(
                      color: PettiColors.midnight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: PettiSpacing.s2),
              // WhatsApp support — Apple-acceptable (Tractive / Fi / Whistle
              // all link external support from their paywalls). Pre-filled
              // message gives Nico context on the first message.
              TextButton.icon(
                onPressed: () async {
                  final uri = AppConstants.whatsAppSupportLink(
                    'Tengo dudas de la suscripción de My Besti',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: Color(0xFF25D366),
                ),
                label: Text(
                  '¿Tienes dudas? Escríbenos por WhatsApp',
                  style: PettiText.body().copyWith(
                    color: PettiColors.fgDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: PettiSpacing.s5),
              Text(
                'La suscripción se renueva automáticamente cada mes. '
                'Puedes cancelarla en cualquier momento desde Ajustes → '
                'Apple ID → Suscripciones, al menos 24 horas antes del '
                'siguiente cobro.',
                textAlign: TextAlign.center,
                style: PettiText.body().copyWith(
                  fontSize: 12,
                  color: PettiColors.fgDim,
                ),
              ),
              const SizedBox(height: PettiSpacing.s3),
              // ToS + Privacy links — Apple's App Review checklist
              // explicitly looks for these on the paywall when an app
              // sells subscriptions. Same URLs as the Cuenta → Legal
              // section so users see one canonical pair.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legalLink(
                    'Términos',
                    Uri.parse('https://mybesti.co/terms'),
                  ),
                  Text(
                    ' · ',
                    style: PettiText.body().copyWith(
                      fontSize: 12,
                      color: PettiColors.fgDim,
                    ),
                  ),
                  _legalLink(
                    'Privacidad',
                    Uri.parse('https://mybesti.co/privacy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legalLink(String label, Uri uri) {
    return GestureDetector(
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: PettiText.body().copyWith(
          fontSize: 12,
          color: PettiColors.midnight,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _featureRow(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: PettiSpacing.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: PettiColors.sabana, size: 22),
            const SizedBox(width: PettiSpacing.s3),
            Expanded(
              child: Text(
                text,
                style: PettiText.body().copyWith(
                  fontSize: 15,
                  color: PettiColors.midnight,
                ),
              ),
            ),
          ],
        ),
      );
}
