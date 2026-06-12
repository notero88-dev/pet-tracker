import 'package:flutter/material.dart';

import '../../services/pending_command_tracker.dart';
import '../../utils/petti_theme.dart';

/// Persistent banner that surfaces in-flight and recently-resolved
/// device commands. Renders nothing when there are no entries.
///
/// Designed to be slotted at the top of any scaffolded screen via the
/// existing layout — it expands vertically to fit its content and
/// participates in normal layout flow.
class PettiPendingCommandsBanner extends StatelessWidget {
  final PendingCommandTracker tracker;

  const PettiPendingCommandsBanner({super.key, required this.tracker});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PendingCommand>>(
      stream: tracker.stream,
      initialData: tracker.all,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const [];
        if (all.isEmpty) return const SizedBox.shrink();
        return _BannerStack(commands: all, tracker: tracker);
      },
    );
  }
}

class _BannerStack extends StatelessWidget {
  final List<PendingCommand> commands;
  final PendingCommandTracker tracker;

  const _BannerStack({required this.commands, required this.tracker});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PettiSpacing.s4,
        vertical: PettiSpacing.s2,
      ),
      child: Column(
        children: [
          for (final cmd in commands)
            Padding(
              padding: const EdgeInsets.only(bottom: PettiSpacing.s2),
              child: _SingleBanner(
                command: cmd,
                onDismiss: () => tracker.dismiss(cmd.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SingleBanner extends StatelessWidget {
  final PendingCommand command;
  final VoidCallback onDismiss;

  const _SingleBanner({required this.command, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(command);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s3,
        PettiSpacing.s3,
        PettiSpacing.s2,
        PettiSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        border: Border.all(color: tone.border, width: 1),
        boxShadow: PettiShadows.elevation1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: tone.leading,
          ),
          const SizedBox(width: PettiSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  command.label,
                  style: PettiText.bodyStrong().copyWith(
                    color: PettiColors.midnight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _detailLine(command),
                  style: PettiText.bodySm()
                      .copyWith(color: PettiColors.fgDim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // In-flight commands can't be dismissed manually; resolved ones can.
          if (command.isResolved)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: PettiColors.fgDim,
              onPressed: onDismiss,
              tooltip: 'Descartar',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  String _detailLine(PendingCommand cmd) {
    if (cmd.isInFlight) {
      return 'Esperando a tu PetTrack…';
    }
    final base = cmd.status!.label;
    if (cmd.errorDetail != null && cmd.errorDetail!.isNotEmpty) {
      return '$base. ${cmd.errorDetail}';
    }
    return base;
  }

  _BannerTone _toneFor(PendingCommand cmd) {
    if (cmd.isInFlight) {
      return _BannerTone(
        background: PettiColors.cloud,
        border: PettiColors.fog,
        leading: const CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(PettiColors.midnight),
        ),
      );
    }
    switch (cmd.status!) {
      case PendingCommandStatus.delivered:
        return _BannerTone(
          background: PettiColors.sabanaSoft,
          border: PettiColors.sabana,
          leading: const Icon(Icons.check_rounded,
              color: PettiColors.sabana, size: 22),
        );
      case PendingCommandStatus.expired:
      case PendingCommandStatus.timedOut:
      case PendingCommandStatus.rejected:
      case PendingCommandStatus.failed:
        return _BannerTone(
          background: PettiColors.alertSoft,
          border: PettiColors.alert,
          leading: const Icon(Icons.error_outline_rounded,
              color: PettiColors.alert, size: 22),
        );
    }
  }
}

class _BannerTone {
  final Color background;
  final Color border;
  final Widget leading;
  const _BannerTone({
    required this.background,
    required this.border,
    required this.leading,
  });
}
