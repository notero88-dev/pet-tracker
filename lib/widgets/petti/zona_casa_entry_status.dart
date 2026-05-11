// ZonaCasaEntryStatus — stateful wrapper around ZonaCasaEntryCard that
// reads the device's latest home-setup intent from the backend and
// switches between the configured / unconfigured variants automatically.
//
// Used in Settings > Modo de ahorro. On first build:
//   1. Query GET /devices/<imei>/home-setup/latest.
//   2. If response is null OR status is failed/cancelled/superseded:
//      render unconfigured.
//   3. Otherwise (configured / reconciling / pending / soft_confirmed):
//      render configured with the SSID from the intent.
//
// When the user taps and returns from the wizard, this widget refetches
// — so a fresh save flips it to the configured state without a full
// app restart.

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../screens/device/home_zone_setup_wizard.dart';
import '../../services/provisioning_api.dart';
import 'zona_casa_entry_card.dart';

class ZonaCasaEntryStatus extends StatefulWidget {
  final Device device;
  final String petName;

  /// Optional API client override for tests.
  final ProvisioningApi? api;

  const ZonaCasaEntryStatus({
    super.key,
    required this.device,
    required this.petName,
    this.api,
  });

  @override
  State<ZonaCasaEntryStatus> createState() => _ZonaCasaEntryStatusState();
}

class _ZonaCasaEntryStatusState extends State<ZonaCasaEntryStatus> {
  HomeSetupIntent? _latest;
  bool _loading = true;

  /// Statuses we treat as "configured" for the entry-card UX. Anything
  /// that means "the user successfully saved a home zone and the
  /// runner is either done or still working on flushing to the device"
  /// counts as configured for display.
  ///
  /// Excludes terminal failure states (failed/cancelled/superseded) —
  /// those should bring the user back to the unconfigured CTA so they
  /// can retry.
  static const _configuredStatuses = {
    'configured',
    'verified',
    'reconciling',
    'soft_confirmed',
    'pending',
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final api = widget.api ?? ProvisioningApi();
      final intent = await api.getLatestHomeSetupIntent(
        imei: widget.device.uniqueId,
      );
      if (!mounted) return;
      setState(() {
        _latest = intent;
        _loading = false;
      });
    } catch (_) {
      // Quiet failure mode — if the lookup errors we fall back to the
      // unconfigured CTA. The user can still tap to (re-)run setup.
      if (!mounted) return;
      setState(() {
        _latest = null;
        _loading = false;
      });
    }
  }

  Future<void> _openWizard() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HomeZoneSetupWizard(
          device: widget.device,
          petName: widget.petName,
        ),
      ),
    );
    // Wizard pops with no value either way. Refetch unconditionally to
    // pick up any newly-created intent (or status change on an existing
    // one).
    if (mounted) {
      await _fetch();
    }
    // Avoid lint about unused param.
    if (result == null) return;
  }

  bool get _isConfigured {
    final s = _latest?.status;
    return s != null && _configuredStatuses.contains(s);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _LoadingSkeleton();
    }
    return ZonaCasaEntryCard(
      onTap: _openWizard,
      configured: _isConfigured,
      ssid: _latest?.homeSsid,
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    // Match the unconfigured card's footprint so the layout doesn't
    // jump when the real card slots in.
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
