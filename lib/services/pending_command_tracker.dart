import 'dart:async';
import 'package:flutter/foundation.dart';

/// One in-flight or recently-resolved command, observed by the UI.
@immutable
class PendingCommand {
  /// Stable id used for keyed list entries / dismissal.
  final String id;

  /// Human label for the user, e.g. "Reiniciar PetTrack".
  final String label;

  /// IMEI the command targets — useful when we eventually support
  /// multiple devices per account.
  final String imei;

  /// When the user fired it.
  final DateTime startedAt;

  /// Current resolution. Null while in flight.
  final PendingCommandStatus? status;

  /// Optional human-readable error when [status] is failed/expired.
  final String? errorDetail;

  const PendingCommand({
    required this.id,
    required this.label,
    required this.imei,
    required this.startedAt,
    this.status,
    this.errorDetail,
  });

  PendingCommand copyWith({
    PendingCommandStatus? status,
    String? errorDetail,
  }) =>
      PendingCommand(
        id: id,
        label: label,
        imei: imei,
        startedAt: startedAt,
        status: status ?? this.status,
        errorDetail: errorDetail ?? this.errorDetail,
      );

  bool get isInFlight => status == null;
  bool get isResolved => status != null;
}

enum PendingCommandStatus {
  /// HTTP 200 — command landed on the device.
  delivered,

  /// HTTP 408 — queue TTL elapsed without device wake.
  expired,

  /// HTTP 504 — timed out.
  timedOut,

  /// HTTP 502 — device explicitly rejected.
  rejected,

  /// 503 / network / other. Caller can retry.
  failed,
}

extension PendingCommandStatusLabel on PendingCommandStatus {
  /// Spanish-language label for the banner UI.
  String get label {
    switch (this) {
      case PendingCommandStatus.delivered:
        return 'Aplicada';
      case PendingCommandStatus.expired:
        return 'Tu PetTrack no se despertó a tiempo';
      case PendingCommandStatus.timedOut:
        return 'Tu PetTrack tardó demasiado en responder';
      case PendingCommandStatus.rejected:
        return 'Tu PetTrack rechazó la orden';
      case PendingCommandStatus.failed:
        return 'No pudimos aplicar la orden';
    }
  }
}

/// Observable in-memory store of in-flight + recently-resolved commands.
///
/// The wizard / device-settings screens call [start], [resolve], [fail]
/// as they run. The banner widget listens via [stream] and renders.
///
/// Not persisted — if the app restarts mid-flight the banner clears,
/// which is acceptable: the underlying server-side queue (`?queue=true`)
/// continues delivering and the eventual FCM "command applied" can
/// surface success in another way later. This service is purely for
/// surfacing "in this app session" intent.
class PendingCommandTracker {
  final List<PendingCommand> _all = [];
  final StreamController<List<PendingCommand>> _ctrl =
      StreamController.broadcast();

  /// Auto-clear resolved commands after this delay so the banner doesn't
  /// linger forever on a successful apply.
  static const Duration _autoClearAfter = Duration(seconds: 6);

  /// Snapshot of current entries (in-flight + recently-resolved).
  List<PendingCommand> get all => List.unmodifiable(_all);

  /// Subset that's still in flight (UI typically prioritizes these).
  List<PendingCommand> get inFlight =>
      _all.where((c) => c.isInFlight).toList();

  Stream<List<PendingCommand>> get stream => _ctrl.stream;

  /// Begin tracking a new command. Returns the id so the caller can
  /// resolve/fail it later.
  String start({
    required String label,
    required String imei,
    DateTime? now,
  }) {
    final id = 'cmd_${DateTime.now().microsecondsSinceEpoch}_${_all.length}';
    _all.add(PendingCommand(
      id: id,
      label: label,
      imei: imei,
      startedAt: now ?? DateTime.now(),
    ));
    _emit();
    return id;
  }

  /// Mark the command resolved with the given status. Auto-clears after
  /// [_autoClearAfter] for non-failure outcomes.
  void resolve(String id, PendingCommandStatus status, {String? errorDetail}) {
    final idx = _all.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    _all[idx] = _all[idx].copyWith(status: status, errorDetail: errorDetail);
    _emit();

    // Auto-clear successes; leave failures up so the user sees them.
    if (status == PendingCommandStatus.delivered) {
      Timer(_autoClearAfter, () => dismiss(id));
    }
  }

  /// Remove a command from the store (banner dismissal).
  void dismiss(String id) {
    final removed = _all.length;
    _all.removeWhere((c) => c.id == id);
    if (_all.length != removed) _emit();
  }

  /// Remove all resolved commands (e.g. user taps "clear" on the banner).
  void dismissResolved() {
    _all.removeWhere((c) => c.isResolved);
    _emit();
  }

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_all));
  }

  void dispose() {
    _ctrl.close();
  }
}
