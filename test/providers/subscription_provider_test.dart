// Regression suite for the cross-account state-carryover bug (2026-06-01).
//
// Symptom reported by Nico: creating a brand-new account (without
// force-quitting the app) showed the *previous* account's pets and a
// "paid subscription". Root cause: app-scoped providers are never reset
// on sign-out. For SubscriptionProvider specifically, a process-global
// `_isInitialized` flag made `initialize()` a permanent no-op after the
// first account, so /me was NEVER re-fetched for subsequent accounts —
// the second account inherited the first account's status and skipped the
// paywall.
//
// These tests pin the fixed contract:
//   - initialize(uid:) fetches /me for the signed-in user
//   - re-init for the same uid stays a no-op (no wasteful double-fetch)
//   - reset() returns to `unknown` and re-enables a fresh fetch
//   - switching uid re-fetches even without an explicit reset (defense in
//     depth against a sign-out path that forgets to call reset())

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pettrack_app/providers/subscription_provider.dart';
import 'package:pettrack_app/services/subscription_api.dart';

/// Fake API whose `/me` response is scriptable per-call. Counts getMe()
/// hits so we can assert that switching accounts triggers a fresh check.
class _FakeSubscriptionApi extends SubscriptionApi {
  Subscription? meResult;
  int getMeCalls = 0;

  @override
  Future<Subscription?> getMe() async {
    getMeCalls++;
    return meResult;
  }
}

/// Minimal InAppPurchase fake — only the surface initialize() touches
/// (purchaseStream + isAvailable). Everything else routes through
/// noSuchMethod and is never exercised by these tests.
class _FakeInAppPurchase implements InAppPurchase {
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Subscription _activeSubscription() => const Subscription(
      id: 'sub_active',
      status: 'active',
      planType: 'monthly',
      priceCop: 19900,
      provider: 'apple_iap',
      autoRenew: true,
    );

void main() {
  late _FakeSubscriptionApi api;
  late _FakeInAppPurchase iap;
  late SubscriptionProvider provider;

  setUp(() {
    api = _FakeSubscriptionApi();
    iap = _FakeInAppPurchase();
    provider = SubscriptionProvider(api: api, iap: iap);
  });

  test('initialize() fetches /me once and reflects an active subscription',
      () async {
    api.meResult = _activeSubscription();
    await provider.initialize(uid: 'userA');

    expect(provider.status, SubscriptionStatus.active);
    expect(api.getMeCalls, 1);
  });

  test('re-initialize for the SAME uid is a no-op (no duplicate fetch)',
      () async {
    api.meResult = _activeSubscription();
    await provider.initialize(uid: 'userA');
    await provider.initialize(uid: 'userA');

    expect(api.getMeCalls, 1);
  });

  test('reset() clears status to unknown and allows re-initialization',
      () async {
    api.meResult = _activeSubscription();
    await provider.initialize(uid: 'userA');
    expect(provider.status, SubscriptionStatus.active);

    provider.reset();
    expect(provider.status, SubscriptionStatus.unknown);

    // New account (no server-side subscription) must resolve to `none` so
    // the paywall fires — the previous account's `active` must NOT survive.
    api.meResult = null;
    await provider.initialize(uid: 'userB');

    expect(api.getMeCalls, 2);
    expect(provider.status, SubscriptionStatus.none);
  });

  test(
      'switching uid re-fetches even WITHOUT an explicit reset '
      '(defense in depth against a missed sign-out reset)', () async {
    api.meResult = _activeSubscription();
    await provider.initialize(uid: 'userA');
    expect(provider.status, SubscriptionStatus.active);

    // Same app session, different account, no reset() called.
    api.meResult = null;
    await provider.initialize(uid: 'userB');

    expect(api.getMeCalls, 2);
    expect(provider.status, SubscriptionStatus.none);
  });
}
