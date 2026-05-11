// Throwaway diagnostic screen for Plan #2 Phase A.
// Verifies that com.apple.developer.networking.HotspotConfiguration
// is correctly provisioned end-to-end on a physical iPhone before
// we wire phone-side home-zone setup into the onboarding flow.
//
// What it does:
//   1. Requests location permission (BSSID is gated behind it on iOS).
//   2. Reads current WiFi SSID + BSSID via network_info_plus.
//   3. Reads current GPS via the `location` package.
//   4. Displays all three with a refresh button.
//
// Success criteria: on a physical iPhone connected to home WiFi,
// SSID + BSSID + lat/lng all populate with real values (not <unknown>
// or zeros). If BSSID is null/"02:00:00:00:00:00" — the iOS privacy
// placeholder for "BSSID hidden" — entitlement or location auth is
// missing.
//
// DELETE THIS FILE once Phase B is wired (the real onboarding step
// will replace it). Intentionally not added to any persistent route
// — navigate from the temporary debug tile in settings_screen.dart.
//
// Plan: docs/plans/2026-05-11-phone-side-home-zone.md

import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:network_info_plus/network_info_plus.dart';

class WifiProbeScreen extends StatefulWidget {
  const WifiProbeScreen({super.key});

  @override
  State<WifiProbeScreen> createState() => _WifiProbeScreenState();
}

class _WifiProbeScreenState extends State<WifiProbeScreen> {
  final _info = NetworkInfo();
  final _location = loc.Location();

  bool _busy = false;
  String? _error;
  // Results
  String? _ssid;
  String? _bssid;
  String? _ip;
  double? _lat;
  double? _lng;
  double? _accuracy;
  String? _locStatus;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // ----- location permission -----
      var perm = await _location.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        perm = await _location.requestPermission();
      }
      _locStatus = perm.toString();
      if (perm != loc.PermissionStatus.granted &&
          perm != loc.PermissionStatus.grantedLimited) {
        setState(() {
          _busy = false;
          _error =
              'Location permission denied — BSSID will read as null on iOS.';
        });
        return;
      }

      final serviceOn = await _location.serviceEnabled();
      if (!serviceOn) {
        final r = await _location.requestService();
        if (!r) {
          setState(() {
            _busy = false;
            _error = 'Location services are off at the OS level.';
          });
          return;
        }
      }

      // ----- read WiFi info -----
      _ssid = await _info.getWifiName(); // returns with quotes on iOS
      _bssid = await _info.getWifiBSSID();
      _ip = await _info.getWifiIP();

      // ----- read GPS -----
      final fix = await _location.getLocation();
      _lat = fix.latitude;
      _lng = fix.longitude;
      _accuracy = fix.accuracy;
    } catch (e, st) {
      _error = 'Probe error: $e\n$st';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi + GPS probe (debug)'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Phase A diagnostic — confirms HotspotConfiguration '
              'entitlement + location auth are correctly provisioned. '
              'See plans/2026-05-11-phone-side-home-zone.md.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _row('Location permission', _locStatus ?? '—'),
            const Divider(),
            _row('WiFi SSID', _ssid ?? '(null)'),
            _row(
              'WiFi BSSID',
              _bssid == null
                  ? '(null — entitlement/permission missing?)'
                  : _bssid == '02:00:00:00:00:00'
                  ? '(02:00:00:00:00:00 — iOS placeholder; '
                        'entitlement OR location auth missing)'
                  : _bssid!,
            ),
            _row('WiFi IP', _ip ?? '(null)'),
            const Divider(),
            _row('GPS lat', _lat?.toStringAsFixed(7) ?? '—'),
            _row('GPS lng', _lng?.toStringAsFixed(7) ?? '—'),
            _row(
              'GPS accuracy',
              _accuracy != null ? '${_accuracy!.toStringAsFixed(1)} m' : '—',
            ),
            const SizedBox(height: 24),
            _interpretation(),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    ),
  );

  Widget _interpretation() {
    if (_busy || _error != null) return const SizedBox.shrink();
    final ok =
        _ssid != null &&
        _bssid != null &&
        _bssid != '02:00:00:00:00:00' &&
        _lat != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        ok
            ? '✓ Phase A entitlement working. SSID + BSSID + GPS all '
                  'populated. Ready to wire into onboarding (Phase B).'
            : '⚠ Phase A not yet working. Likely missing: '
                  '(a) Hotspot Configuration capability not enabled on '
                  'the App ID in Apple Developer Portal, OR '
                  '(b) provisioning profile not regenerated after '
                  'adding the entitlement, OR '
                  '(c) location permission not granted at runtime.',
        style: TextStyle(
          color: ok ? Colors.green.shade900 : Colors.amber.shade900,
        ),
      ),
    );
  }
}
