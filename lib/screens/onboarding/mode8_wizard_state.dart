/// State machine for the Mode 8 onboarding wizard.
///
/// Linear progression — no skipping, no branching. The wizard advances
/// state-by-state through four backend command calls and a final
/// server-side Traccar geofence creation, halting in [error] on any
/// failure for retry/cancel from the UI.
///
/// The matching backend sequence is documented at
/// docs/superpowers/plans/2026-04-29-mode8-flutter-wizard.md
enum Mode8WizardState {
  /// Initial state, before user taps "Configurar zona de casa".
  idle,

  /// Calling /devices/:imei/scan — UI shows "Detectando redes WiFi…".
  scanning,

  /// Calling /devices/:imei/access-points — UI shows "Memorizando tu casa…".
  settingMacs,

  /// Calling /devices/:imei/geo-fence — UI shows "Dibujando tu zona de casa…".
  settingHomeZone,

  /// Calling /devices/:imei/mode (type=home) — UI shows
  /// "Activando ahorro de batería…".
  enteringMode8,

  /// Creating server-side Traccar geofence — UI shows
  /// "Guardando en el servidor…". Runs after device-side success so a
  /// failure here doesn't leave a phantom geofence pointing at a
  /// half-configured device.
  creatingTraccarGeofence,

  /// All steps succeeded — UI shows the success dialog.
  success,

  /// A step returned an error — UI shows error message + retry button.
  error,
}

extension Mode8WizardStateLabel on Mode8WizardState {
  /// Spanish-language label used in the in-flight progress UI.
  String get label {
    switch (this) {
      case Mode8WizardState.idle:
        return '';
      case Mode8WizardState.scanning:
        return 'Detectando redes WiFi…';
      case Mode8WizardState.settingMacs:
        return 'Memorizando tu casa…';
      case Mode8WizardState.settingHomeZone:
        return 'Dibujando tu zona de casa…';
      case Mode8WizardState.enteringMode8:
        return 'Activando ahorro de batería…';
      case Mode8WizardState.creatingTraccarGeofence:
        return 'Guardando en el servidor…';
      case Mode8WizardState.success:
        return '¡Listo!';
      case Mode8WizardState.error:
        return 'Algo salió mal';
    }
  }

  /// 0..1 progress for a linear progress bar.
  double get progress {
    switch (this) {
      case Mode8WizardState.idle:
        return 0.0;
      case Mode8WizardState.scanning:
        return 0.16;
      case Mode8WizardState.settingMacs:
        return 0.33;
      case Mode8WizardState.settingHomeZone:
        return 0.5;
      case Mode8WizardState.enteringMode8:
        return 0.66;
      case Mode8WizardState.creatingTraccarGeofence:
        return 0.83;
      case Mode8WizardState.success:
        return 1.0;
      case Mode8WizardState.error:
        return 0.0;
    }
  }

  /// True while the wizard is mid-flight (any step in progress).
  bool get isInFlight =>
      this != Mode8WizardState.idle &&
      this != Mode8WizardState.success &&
      this != Mode8WizardState.error;
}
