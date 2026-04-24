// DeviceSettingsScreen — Petti-branded settings for a single MT710 tracker.
//
// Matches the React prototype at
//   Downloads/Petti - First design App V1/src/settings-screen.jsx
//
// States handled:
//   configured   — everything normal; mode picker + Home Zone + info
//   unconfigured — Home Zone empty state, rest normal
//   offline      — orange banner at top, controls disabled
//
// Wired to device_commands_api.dart. Every backend call surfaces via
// PettiToast (success/error) with a retry affordance.

import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../services/device_commands_api.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_primitives.dart';
import '../../widgets/petti/mode_picker.dart';
import '../../widgets/petti/zona_segura_card.dart';
import '../../widgets/petti/reboot_dialog.dart';
import 'zona_segura_wizard.dart';

class DeviceSettingsScreen extends StatefulWidget {
  final Device device;
  final String petName;
  final String? petPhotoUrl;

  /// Whether the Home Zone (DEF) has been configured previously. Passed in
  /// from the caller; we don't query the device to infer this because the
  /// RCONF,4 readback is a full command round-trip.
  final bool homeZoneConfigured;

  /// Used to decide what state to show on first paint. Updated in real time
  /// by a lightweight /online probe on screen focus.
  final bool isOnline;

  /// Timestamp of last known position, for the header "Visto por última vez".
  final DateTime? lastSeen;

  /// 0–100, bucketed to 20/40/60/80/100 by the time we store it.
  final int batteryPercent;

  final DeviceCommandsApi? api;

  const DeviceSettingsScreen({
    super.key,
    required this.device,
    required this.petName,
    this.petPhotoUrl,
    this.homeZoneConfigured = false,
    this.isOnline = true,
    this.lastSeen,
    this.batteryPercent = 80,
    this.api,
  });

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  late final DeviceCommandsApi _api = widget.api ?? DeviceCommandsApi();

  PettiMode _mode = PettiMode.home;
  int _interval = 30;
  bool _dirty = false;
  bool _savingMode = false;
  bool _rebootInFlight = false;

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  bool get _offline => !widget.isOnline;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _saveMode() async {
    setState(() => _savingMode = true);

    final result = await _api.setMode(
      imei: widget.device.uniqueId,
      mode: _pettiToApiMode(_mode),
      intervalSeconds: _mode == PettiMode.realtime || _mode == PettiMode.home
          ? _interval
          : null,
      intervalHours: _mode == PettiMode.deepSleep ? _interval : null,
    );

    if (!mounted) return;
    setState(() => _savingMode = false);

    if (result is DeviceCommandOk) {
      setState(() => _dirty = false);
      PettiToast.show(
        context,
        kind: PettiToastKind.success,
        message: 'Modo actualizado',
      );
    } else if (result is DeviceCommandError) {
      PettiToast.show(
        context,
        kind: PettiToastKind.error,
        message: _friendlyError(result, 'No pudimos actualizar el modo.'),
        onRetry: _saveMode,
      );
    }
  }

  Future<void> _openZonaWizard() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ZonaSeguraWizardScreen(
          device: widget.device,
          petName: widget.petName,
          api: _api,
        ),
      ),
    );
    if (result == true && mounted) {
      // The wizard already shows its own success screen; no toast needed here.
      setState(() {});
    }
  }

  Future<void> _confirmReboot() async {
    final confirmed = await PettiRebootDialog.show(
      context,
      petName: widget.petName,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rebootInFlight = true);
    final result = await _api.reboot(imei: widget.device.uniqueId);
    if (!mounted) return;
    setState(() => _rebootInFlight = false);

    if (result is DeviceCommandOk) {
      PettiToast.show(
        context,
        kind: PettiToastKind.success,
        message: 'Reiniciando el tracker…',
      );
    } else if (result is DeviceCommandError) {
      PettiToast.show(
        context,
        kind: PettiToastKind.error,
        message: _friendlyError(result, 'No pudimos reiniciar el tracker.'),
        onRetry: _confirmReboot,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 40),
              children: [
                _header(),
                const SizedBox(height: 18),
                _deviceHeaderCard(),
                if (_offline) _offlineBanner(),
                const PettiSectionHeader('Modo de rastreo'),
                _modeCard(),
                const PettiSectionHeader('Zona segura'),
                _zonaSeguraCard(),
                const PettiSectionHeader('Información del dispositivo'),
                _deviceInfoCard(),
                _dangerZone(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Header ---

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s2,
        PettiSpacing.s5,
        0,
      ),
      child: Row(
        children: [
          _circleIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'AJUSTES',
                style: PettiText.meta().copyWith(letterSpacing: 0.96),
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: PettiColors.borderLight)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: PettiColors.midnight, size: 18),
        ),
      ),
    );
  }

  // --- Pet/device header card ---

  Widget _deviceHeaderCard() {
    final lastSeenText = widget.lastSeen == null
        ? 'Sin datos recientes'
        : _relativeTimeEs(widget.lastSeen!);

    return PettiCard(
      padding: const EdgeInsets.all(PettiSpacing.s4 + 2),
      child: Column(
        children: [
          Row(
            children: [
              PettiPetAvatar(initial: widget.petName.substring(0, 1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.petName, style: PettiText.h2()),
                    const SizedBox(height: 4),
                    Text(
                      'Visto por última vez $lastSeenText',
                      style: PettiText.label().copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PettiSpacing.s4),
          Container(
            height: 1,
            color: PettiColors.borderLight,
          ),
          const SizedBox(height: PettiSpacing.s3 + 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PettiStatusPill(
                kind: _offline ? PettiStatus.offline : PettiStatus.online,
                label: _offline
                    ? 'Desconectado $lastSeenText'
                    : 'En línea · el pulso activo',
              ),
              PettiBatteryBadge(percentBucket: widget.batteryPercent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offlineBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s4,
        PettiSpacing.s4,
        PettiSpacing.s4,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PettiColors.duskSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PettiColors.duskRose.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: PettiColors.duskRose,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'El tracker de ${widget.petName} está desconectado',
                    style: PettiText.bodyStrong().copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'No podemos aplicar cambios hasta que se reconecte. '
                    'Asegúrate de que esté encendido.',
                    style: PettiText.body().copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Mode card ---

  Widget _modeCard() {
    return PettiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PettiModePicker(
            selected: _mode,
            disabled: _offline,
            onChanged: (m) {
              setState(() {
                _mode = m;
                _dirty = true;
                // Clamp interval to presets for the new mode.
                final presets = kPettiIntervalPresets[m]!;
                if (!presets.any((p) => p.value == _interval)) {
                  _interval = presets.length > 1
                      ? presets[1].value
                      : presets.first.value;
                }
              });
            },
          ),
          const SizedBox(height: PettiSpacing.s3 + 2),
          PettiIntervalStepper(
            mode: _mode,
            value: _interval,
            disabled: _offline,
            onChanged: (v) => setState(() {
              _interval = v;
              _dirty = true;
            }),
          ),
          const SizedBox(height: PettiSpacing.s3 + 2),
          PettiBatteryEstimateCard(mode: _mode, interval: _interval),
          const SizedBox(height: PettiSpacing.s3 + 2),
          PettiCta(
            label: _savingMode
                ? 'Enviando a tu dispositivo…'
                : 'Guardar cambios',
            loading: _savingMode,
            onPressed: (_offline || !_dirty || _savingMode) ? null : _saveMode,
          ),
        ],
      ),
    );
  }

  // --- Zona Segura card ---

  Widget _zonaSeguraCard() {
    return PettiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PettiRadii.md),
        child: widget.homeZoneConfigured
            ? PettiZonaSeguraConfigured(
                radiusLabel: '100 m',
                networkCount: 3,
                configuredOn: '3 abr',
                onUpdate: _openZonaWizard,
              )
            : PettiZonaSeguraEmpty(onConfigure: _openZonaWizard),
      ),
    );
  }

  // --- Device info card ---

  Widget _deviceInfoCard() {
    final lastSyncText = widget.lastSeen == null
        ? '—'
        : _relativeTimeEs(widget.lastSeen!);

    return PettiCard(
      padding: const EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
      child: Column(
        children: [
          PettiListRow(
            label: 'IMEI',
            value: widget.device.uniqueId,
            mono: true,
          ),
          PettiListRow(label: 'Nombre', value: widget.device.name),
          const PettiListRow(label: 'Modelo', value: 'MT710'),
          const PettiListRow(label: 'Firmware', value: 'v2.4.1', mono: true),
          PettiListRow(
            label: 'Última sincronización',
            value: lastSyncText,
            last: true,
          ),
        ],
      ),
    );
  }

  // --- Danger zone ---

  Widget _dangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PettiSectionHeader(
          'Zona peligrosa',
          color: PettiColors.alert.withValues(alpha: 0.8),
        ),
        PettiCard(
          color: PettiColors.alertSoft,
          border: Border.all(
            color: PettiColors.alert.withValues(alpha: 0.18),
            width: 1,
          ),
          shadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: PettiSpacing.s3),
                child: Text(
                  'Reiniciar enviará una señal al tracker. Estará desconectado '
                  'cerca de 2 minutos.',
                  style: PettiText.body().copyWith(fontSize: 13),
                ),
              ),
              PettiCta(
                label: 'Reiniciar dispositivo',
                variant: PettiCtaVariant.danger,
                icon: const Icon(Icons.power_settings_new_rounded),
                loading: _rebootInFlight,
                onPressed: _offline || _rebootInFlight ? null : _confirmReboot,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  TrackingMode _pettiToApiMode(PettiMode m) {
    switch (m) {
      case PettiMode.realtime:
        return TrackingMode.realtime;
      case PettiMode.home:
        return TrackingMode.home;
      case PettiMode.deepSleep:
        return TrackingMode.deepSleep;
    }
  }

  String _friendlyError(DeviceCommandError e, String fallback) {
    if (e.isOffline) return 'Tu tracker está desconectado. Intenta en unos minutos.';
    if (e.isTimeout) return 'El tracker no respondió a tiempo. Intenta de nuevo.';
    if (e.isRejectedByDevice) return 'El tracker rechazó el comando.';
    return fallback;
  }

  String _relativeTimeEs(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 30) return 'hace unos segundos';
    if (diff.inMinutes < 1) return 'hace ${diff.inSeconds} s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }
}
