// SubscriptionProvider — single source of truth for the user's
// subscription state in the app UI.
//
// Owns:
//   1. A `status` enum the UI reads to decide whether to render the
//      paywall, the trial banner, the active state, etc.
//   2. A `Subscription` model with trial-end-date / next-renewal-date
//      fields the Cuenta tab renders.
//   3. The bridge between Flutter's `in_app_purchase` package (which
//      handles the StoreKit / Play Billing sheets) and our own
//      `/verify-purchase` backend endpoint.
//
// Lifecycle:
//   - `initialize()` is called once from PettiMainTabsScreen.initState
//     after the user is signed in. Wires the in_app_purchase purchase
//     stream + does an initial `/me` fetch.
//   - `startPurchase()` is called from the paywall's CTA button.
//     Kicks off the IAP sheet via `InAppPurchase.instance.buyNonConsumable()`.
//   - On a successful purchase event, the stream listener calls
//     `_verifyAndRefresh()` which POSTs `/verify-purchase` + flips
//     `status` to the new value.
//
// Threading: all state mutations call `notifyListeners()`. The IAP
// stream events arrive on the main isolate.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/subscription_api.dart';

/// Status enum the UI gates on. Maps 1:1 to the backend's `status`
/// column values, plus `unknown` for "we haven't fetched yet".
enum SubscriptionStatus {
  /// Initial state on app launch, before initialize() resolves.
  unknown,

  /// User has no subscription row server-side, OR all their rows are
  /// in terminal states. Paywall should fire.
  none,

  /// In the 30-day free trial. Same access as active.
  inTrial,

  /// Paid + renewing on schedule.
  active,

  /// Apple/Google grace period (payment failed, retrying). We still
  /// grant access during this window so a user fixing their card
  /// mid-month isn't kicked out.
  billingIssue,

  /// Trial or paid period ended without renewal. Full paywall fires.
  expired,

  /// Apple/Google refunded. Full paywall.
  refunded,
}

SubscriptionStatus _statusFromString(String s) {
  switch (s) {
    case 'in_trial':
      return SubscriptionStatus.inTrial;
    case 'active':
      return SubscriptionStatus.active;
    case 'billing_issue':
      return SubscriptionStatus.billingIssue;
    case 'expired':
      return SubscriptionStatus.expired;
    case 'refunded':
    case 'cancelled':
      // Backend distinguishes refunded vs cancelled for analytics, but
      // for the app's gating logic both mean "paywall." Folding into
      // refunded keeps the enum smaller.
      return SubscriptionStatus.refunded;
    default:
      // Unknown string from the backend → fall back to `unknown`, NOT
      // `none`. `none` triggers the full-screen paywall takeover;
      // mapping a brand-new backend status (e.g. a future `paused` or
      // `suspended` introduced in v2) to `none` would silently lock
      // paying users out the day the new status starts showing up in
      // /me responses. `unknown` keeps the prior state in
      // refreshFromBackend's catch path and lets the next legitimate
      // refresh recover.
      // ignore: avoid_print
      assert(() {
        debugPrint(
          'SubscriptionProvider: unknown subscription status "$s" — treating as unknown',
        );
        return true;
      }());
      return SubscriptionStatus.unknown;
  }
}

/// The v1 monthly SKU — must match what's in App Store Connect AND
/// the backend's `PRODUCT_PRICE_COP` key (currently 'monthly_v1').
const String kMonthlyProductId = 'monthly_v1';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({SubscriptionApi? api, InAppPurchase? iap})
      : _api = api ?? SubscriptionApi(),
        _iap = iap ?? InAppPurchase.instance;

  final SubscriptionApi _api;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _isInitialized = false;

  /// Safety timer for startPurchase(). If StoreKit / Play Billing
  /// drops the purchase event (network blip during the sheet, app
  /// backgrounded mid-sheet, etc.) the purchaseStream listener may
  /// never fire and `_isPurchaseInFlight` would otherwise stay true
  /// indefinitely — the CTA button stays a permanent spinner with
  /// no recovery short of force-quitting the app. The timer ensures
  /// the flag is cleared after `_purchaseSafetyTimeout` so the user
  /// can retry / restore. Cancelled on any terminal stream event.
  Timer? _purchaseSafetyTimer;
  static const Duration _purchaseSafetyTimeout = Duration(seconds: 60);

  // ── Public state ─────────────────────────────────────────────────

  SubscriptionStatus _status = SubscriptionStatus.unknown;
  SubscriptionStatus get status => _status;

  Subscription? _subscription;
  Subscription? get subscription => _subscription;

  /// The IAP product (loaded from the store) we'll offer on the
  /// paywall. Holds price string + display title + description.
  ProductDetails? _product;
  ProductDetails? get product => _product;

  /// True while a backend or store call is in flight. The paywall
  /// disables the CTA button when true.
  bool _isPurchaseInFlight = false;
  bool get isPurchaseInFlight => _isPurchaseInFlight;

  /// Last error message, surfaced via SnackBar by the paywall.
  String? _lastError;
  String? get lastError => _lastError;

  /// True once `initialize()` has resolved (succeeded or failed).
  /// Used by the splash / route gating to avoid showing the wrong
  /// screen during the brief window before /me returns.
  bool get isInitialized => _isInitialized;

  // ── Initialization ───────────────────────────────────────────────

  /// Wire the purchase stream + do an initial /me fetch. Safe to
  /// call multiple times — the second call is a no-op.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Subscribe to purchase events from the store. The stream
    // fires on:
    //   - new purchases the user initiated via startPurchase()
    //   - restored purchases on cold launch (StoreKit replays past
    //     subscriptions automatically on iOS; Android needs an
    //     explicit restorePurchases() call)
    //   - state changes (subscription renewed in background, etc.)
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) {
        if (kDebugMode) debugPrint('SubscriptionProvider: purchaseStream error: $e');
      },
    );

    // 2. Initial /me fetch. Errors are swallowed (and surfaced via
    // status=unknown → paywall fires defensively).
    await refreshFromBackend();

    // 3. Best-effort product load so the paywall can show the real
    // price string from the store ("US$7.50/month" etc.) instead of
    // a hardcoded constant.
    unawaited(fetchProducts());
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _purchaseSafetyTimer?.cancel();
    super.dispose();
  }

  /// Called from the root WidgetsBindingObserver on
  /// AppLifecycleState.resumed. If the user backgrounded the app
  /// mid-purchase (a common way to silently break the IAP stream),
  /// clear the in-flight flag so the paywall can be tapped again
  /// and re-pull the canonical /me state. A purchase that actually
  /// completed in the meantime will land on the stream listener
  /// either way — _onPurchaseUpdates doesn't gate on
  /// _isPurchaseInFlight to run.
  void handleAppResumed() {
    if (_isPurchaseInFlight) {
      _purchaseSafetyTimer?.cancel();
      _isPurchaseInFlight = false;
      notifyListeners();
    }
    // Always pull canonical state on resume — the IAP webhook may
    // have landed while the app was backgrounded.
    unawaited(refreshFromBackend());
  }

  // ── Public actions ───────────────────────────────────────────────

  /// Re-fetch the canonical state from our backend. Called on cold
  /// launch + after the IAP sheet dismisses + whenever we suspect
  /// drift (e.g. after a foreground/background cycle).
  Future<void> refreshFromBackend() async {
    try {
      final sub = await _api.getMe();
      _subscription = sub;
      _status = sub == null
          ? SubscriptionStatus.none
          : _statusFromString(sub.status);
      _lastError = null;
    } catch (e) {
      // Network blip, expired creds, etc. We keep the previous
      // status so a transient backend failure doesn't briefly show
      // the paywall to a paying user.
      if (kDebugMode) debugPrint('SubscriptionProvider: /me failed: $e');
    }
    notifyListeners();
  }

  /// Fetch product metadata from the store so the paywall renders the
  /// real localized price string. No-op on failure (paywall falls
  /// back to a constant).
  Future<void> fetchProducts() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        if (kDebugMode) debugPrint('SubscriptionProvider: IAP not available on this device');
        return;
      }
      final resp = await _iap.queryProductDetails({kMonthlyProductId});
      if (resp.notFoundIDs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'SubscriptionProvider: product not found in store: ${resp.notFoundIDs}',
          );
        }
      }
      if (resp.productDetails.isNotEmpty) {
        _product = resp.productDetails.first;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionProvider: fetchProducts failed: $e');
    }
  }

  /// Triggers the IAP sheet. Returns when the sheet dismisses (the
  /// actual purchase result lands on the purchaseStream listener).
  Future<void> startPurchase() async {
    final product = _product;
    if (product == null) {
      _lastError = 'Producto no disponible. Reintenta en unos segundos.';
      notifyListeners();
      return;
    }
    _isPurchaseInFlight = true;
    _lastError = null;
    // Start the safety timer BEFORE we await — if the await itself
    // hangs we still get the auto-clear. Reset on every call so a
    // user tapping retry after a stale state gets a fresh 60s window.
    _purchaseSafetyTimer?.cancel();
    _purchaseSafetyTimer = Timer(_purchaseSafetyTimeout, _onPurchaseSafetyTimeout);
    notifyListeners();
    try {
      final param = PurchaseParam(productDetails: product);
      // buyNonConsumable is correct for subscriptions in this package
      // (despite the name) — consumables are for one-time-use items
      // like virtual coins. Subscriptions + non-consumables both use
      // buyNonConsumable; the store sheet shows the right copy based
      // on the product type registered in App Store Connect.
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _lastError = 'No pudimos iniciar la compra: $e';
      _isPurchaseInFlight = false;
      _purchaseSafetyTimer?.cancel();
      _purchaseSafetyTimer = null;
      notifyListeners();
    }
  }

  /// Fires when the safety timer elapses without any terminal stream
  /// event. Conservatively clears the in-flight flag and surfaces an
  /// actionable message. A purchase that actually completes later
  /// will still process correctly via _onPurchaseUpdates — we don't
  /// gate that path on _isPurchaseInFlight.
  void _onPurchaseSafetyTimeout() {
    if (!_isPurchaseInFlight) return; // already resolved cleanly
    _isPurchaseInFlight = false;
    _lastError = 'No pudimos completar la compra. Reintenta o usa '
        '"Restaurar compra" si ya pagaste.';
    if (kDebugMode) {
      debugPrint('SubscriptionProvider: purchase safety timeout fired');
    }
    notifyListeners();
  }

  /// User tapped "Restaurar compra" on the paywall. Useful for users
  /// who reinstalled the app or are on a fresh device with the same
  /// Apple ID.
  Future<void> restorePurchases() async {
    _isPurchaseInFlight = true;
    _lastError = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      // Restored purchases arrive on the purchaseStream listener
      // (with status=restored). When all are processed we re-fetch
      // /me to get the canonical state.
      await Future<void>.delayed(const Duration(seconds: 2));
      await refreshFromBackend();
    } catch (e) {
      _lastError = 'No pudimos restaurar: $e';
    } finally {
      _isPurchaseInFlight = false;
      notifyListeners();
    }
  }

  // ── Internal — purchase stream handler ───────────────────────────

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // User is interacting with the sheet. Nothing to do.
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // The crucial path: verify with our backend.
          await _verifyAndRefresh(purchase);
          // ALWAYS call completePurchase, even after restored events.
          // Failing to do so means iOS will keep replaying this
          // purchase on every cold launch.
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _isPurchaseInFlight = false;
          _purchaseSafetyTimer?.cancel();
          _purchaseSafetyTimer = null;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _lastError = purchase.error?.message ?? 'Error desconocido durante la compra';
          _isPurchaseInFlight = false;
          _purchaseSafetyTimer?.cancel();
          _purchaseSafetyTimer = null;
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          // User dismissed the sheet without buying. No error UI.
          _lastError = null;
          _isPurchaseInFlight = false;
          _purchaseSafetyTimer?.cancel();
          _purchaseSafetyTimer = null;
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          notifyListeners();
          break;
      }
    }
  }

  /// Retry schedule for the iOS verify-purchase call. The Apple
  /// transaction stays in `pendingCompletePurchase` until we call
  /// `_iap.completePurchase`, so retrying the backend call is safe —
  /// the worst that happens is the user sees "Reintentando…" for a
  /// few extra seconds while we recover from a 5xx blip. After the
  /// last attempt fails we fall back to a /me refresh in case the
  /// ASSN webhook already landed.
  static const List<Duration> _verifyRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  Future<void> _verifyAndRefresh(PurchaseDetails purchase) async {
    // For iOS StoreKit 2, `serverVerificationData` is the signed
    // transaction JWT — exactly what our backend's
    // appleReceiptVerifier expects. For older StoreKit 1 + Android
    // this is a different format (raw receipt blob / purchase
    // token JSON) which our backend doesn't currently understand.
    // v1 = iOS-only; Phase C+ wires Android.
    final provider = _platformProvider();
    if (provider == 'google_play') {
      // Defensive: the backend returns 501 for google_play in v1.
      // Refresh /me after a delay in case the RTDN webhook already
      // landed and grew the row. The paywall UI now hides the Android
      // CTA outright (see paywall_screen.dart), so this branch is a
      // belt-and-suspenders guard for any orphaned restored purchase.
      if (kDebugMode) {
        debugPrint('SubscriptionProvider: google_play verify not implemented in v1');
      }
      await Future<void>.delayed(const Duration(seconds: 3));
      await refreshFromBackend();
      return;
    }

    // iOS: try the verify call up to 4 times (1 initial + 3 retries).
    // Surface "Reintentando…" copy between attempts so a paying user
    // sees progress instead of an apparent freeze on a transient 5xx.
    final maxAttempts = 1 + _verifyRetryDelays.length;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final updated = await _api.verifyPurchase(
          provider: provider,
          productId: purchase.productID,
          signedTransactionInfo:
              purchase.verificationData.serverVerificationData,
        );
        _subscription = updated;
        _status = _statusFromString(updated.status);
        _lastError = null;
        return;
      } catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint(
            'SubscriptionProvider: verifyPurchase attempt ${attempt + 1}/$maxAttempts failed: $e',
          );
        }
        if (attempt < _verifyRetryDelays.length) {
          _lastError = 'Reintentando verificación…';
          notifyListeners();
          await Future<void>.delayed(_verifyRetryDelays[attempt]);
        }
      }
    }

    // All attempts exhausted. Surface the support message and fall
    // back to /me — the ASSN webhook may have written the row in the
    // meantime, which gets us out of the bad state without user
    // intervention.
    _lastError = 'No pudimos verificar la compra con el servidor. '
        'Si te cobraron, escríbenos a soporte.';
    if (kDebugMode) {
      debugPrint('SubscriptionProvider: verifyPurchase exhausted: $lastError');
    }
    await refreshFromBackend();
  }

  String _platformProvider() {
    // The package's `purchase.productID` doesn't tell us the platform
    // directly; check via defaultTargetPlatform.
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'apple_iap';
      case TargetPlatform.android:
        return 'google_play';
      default:
        return 'apple_iap';
    }
  }
}
