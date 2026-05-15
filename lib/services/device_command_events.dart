// device_command_events — process-wide pub/sub for command-completion
// events fired by the gateway → provisioning-api → FCM data-only push
// chain (shipped 2026-05-15 alongside the "En vivo Bad file descriptor"
// fix).
//
// Why a separate singleton instead of plumbing through ChangeNotifier or
// Provider:
//   * The FCMService fires these events from outside the widget tree
//     (top-level message handlers). A bare Stream avoids a chicken-and-
//     egg dependency on a BuildContext at message arrival.
//   * Screens that care about completion (DeviceDetailScreen for the En
//     vivo button today; future settings screens for mode flips) just
//     `.listen(...)` for the duration they're interested.
//   * The payload is tiny (~5 fields), short-lived, and doesn't belong
//     in NotificationProvider's persisted alert history — these are
//     silent system signals, not user-facing notifications.
//
// Lifecycle: the singleton lives for the process lifetime. Subscribers
// are responsible for cancelling their StreamSubscription on widget
// dispose; otherwise stale listeners pile up.

import 'dart:async';

/// A single command-completion event fired by the backend.
///
/// Shape mirrors the FCM data payload from the gateway → provisioning-api
/// callback chain (see pettrack-backend/provisioning-api/src/internalRoutes.js).
class CommandCompletedEvent {
  /// 15-digit IMEI of the device the command targeted.
  final String imei;

  /// Gateway-side command name, e.g. `'lock'`, `'modeHome'`, `'reboot'`.
  final String command;

  /// Gateway-assigned id from the original 202 response, useful for
  /// correlating with `WizardStepQueued.queueId`. May be null if the
  /// callback fired for a non-queued path (rare).
  final int? queueId;

  /// Terminal status from the gateway:
  ///   * `'acked'`        — device returned OK
  ///   * `'failed'`       — device returned FS (firmware refused)
  ///   * `'expired'`      — TTL elapsed without the device reconnecting
  ///   * `'timeout'`      — device received the command but never replied
  ///   * `'write_failed'` — socket write to the device threw
  ///   * `'evicted'`      — device disconnected mid-command
  final String status;

  /// Raw device REPLY payload (acked/failed) or null. Diagnostic-only.
  final String? payload;

  /// Server-side timestamp the event was generated.
  final DateTime firedAt;

  /// Pet's display name, populated by the backend lookup from
  /// customers JOIN pets WHERE pets.device_imei = imei. Empty string if
  /// the lookup found no pet. Used to render copy like "Petti está en
  /// modo En vivo".
  final String petName;

  const CommandCompletedEvent({
    required this.imei,
    required this.command,
    required this.status,
    required this.firedAt,
    required this.petName,
    this.queueId,
    this.payload,
  });

  /// True when the device confirmed the command.
  bool get isSuccess => status == 'acked';

  @override
  String toString() =>
      'CommandCompletedEvent(imei=$imei, command=$command, queueId=$queueId, '
      'status=$status)';
}

/// Process-wide singleton. Subscribers listen via [stream]; FCMService
/// (or any future emitter) calls [emit] when an event arrives.
class DeviceCommandEvents {
  DeviceCommandEvents._();
  static final DeviceCommandEvents instance = DeviceCommandEvents._();

  // Broadcast so multiple screens can listen concurrently without
  // stealing events from each other.
  final StreamController<CommandCompletedEvent> _controller =
      StreamController<CommandCompletedEvent>.broadcast();

  /// Subscribe to all command-completion events. Callers typically
  /// filter on [CommandCompletedEvent.imei] (and optionally [queueId]
  /// when correlating against a specific tap).
  Stream<CommandCompletedEvent> get stream => _controller.stream;

  /// Push an event to all current subscribers. No-op if the controller
  /// has been closed (shouldn't happen — the singleton lives for the
  /// process lifetime).
  void emit(CommandCompletedEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }
}
