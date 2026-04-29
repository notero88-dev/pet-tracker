/// Outcome of a single backend command in the Mode 8 onboarding wizard.
///
/// Every HTTP status the provisioning-api returns when driving the
/// wizard is mapped to one of these typed cases so the UI never has to
/// parse strings or branch on raw status codes. The wizard is a linear
/// state machine — each step's outcome decides whether to advance,
/// retry, or surface a user-friendly error.
sealed class WizardStepResult {
  const WizardStepResult();
}

/// Backend returned `200 { success: true, reply: { payload } }`.
/// The payload is the device's raw REPLY string (e.g. `"AP,OK"`,
/// `"MODE,OK"`, or for SCAN a comma-separated list of MAC:RSSI pairs).
class WizardStepOk extends WizardStepResult {
  final String payload;
  const WizardStepOk(this.payload);
}

/// Backend returned `408 — queued command expired before device
/// reconnected`. The wizard should ask the user to physically wake
/// the device (motion / take outdoors) before retrying.
class WizardStepQueueExpired extends WizardStepResult {
  final int queueTtlMs;
  const WizardStepQueueExpired(this.queueTtlMs);
}

/// Backend returned `503 — device offline` and queueing wasn't enabled.
/// Defensive case; the wizard always passes `queue=true`, so this should
/// never happen in practice. If it does, we surface as a generic offline
/// message and let the user retry.
class WizardStepDeviceOffline extends WizardStepResult {
  const WizardStepDeviceOffline();
}

/// Backend returned `504 — gateway/device timed out`. The device
/// received the command write but didn't reply within the gateway's
/// timeout window. Single retry is reasonable.
class WizardStepTimedOut extends WizardStepResult {
  const WizardStepTimedOut();
}

/// Backend returned `502 — device explicitly rejected the command`
/// (e.g. `MODE,FS`, `AP,FS`). Halt the wizard.
class WizardStepDeviceRejected extends WizardStepResult {
  /// The device's failure payload, surfaced for diagnostic logging.
  final String payload;
  const WizardStepDeviceRejected(this.payload);
}

/// `400` validation error or any other unrecognized failure mode.
class WizardStepFailed extends WizardStepResult {
  final String error;
  final int? statusCode;
  const WizardStepFailed(this.error, {this.statusCode});
}
