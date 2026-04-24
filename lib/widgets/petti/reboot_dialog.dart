// Reboot confirmation dialog + in-screen success/error toast.
//
// Shown from DeviceSettingsScreen's "Zona peligrosa" section.

import 'package:flutter/material.dart';
import '../../utils/petti_theme.dart';

class PettiRebootDialog extends StatelessWidget {
  final String petName;

  const PettiRebootDialog({super.key, required this.petName});

  /// Show the dialog and return `true` if the user confirmed reboot.
  static Future<bool?> show(BuildContext context, {required String petName}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: PettiColors.midnight.withValues(alpha: 0.45),
      builder: (_) => PettiRebootDialog(petName: petName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(PettiSpacing.s5),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: PettiShadows.elevation2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: Column(
                  children: [
                    // Power icon in alert-soft circle
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: PettiColors.alertSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.power_settings_new_rounded,
                        size: 22,
                        color: PettiColors.alert,
                      ),
                    ),
                    const SizedBox(height: PettiSpacing.s3 + 2),
                    Text(
                      '¿Reiniciar el tracker de $petName?',
                      style: PettiText.h4().copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: PettiSpacing.s2),
                    Text(
                      'Estará desconectado cerca de 2 minutos. $petName debe '
                      'estar en un lugar seguro.',
                      style: PettiText.body().copyWith(fontSize: 13.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Cancel / Confirm buttons, iOS-style side-by-side
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: PettiColors.borderLight, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: PettiColors.borderLight,
                                width: 1,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancelar',
                            style: PettiText.body().copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: PettiColors.midnight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: Text(
                            'Reiniciar',
                            style: PettiText.body().copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: PettiColors.alert,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Toast — green success / red error slide-up pill at the bottom of the screen.
// -----------------------------------------------------------------------------

enum PettiToastKind { success, error }

class PettiToast extends StatelessWidget {
  final PettiToastKind kind;
  final String message;
  final VoidCallback? onRetry;

  const PettiToast({
    super.key,
    required this.kind,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bg = kind == PettiToastKind.success
        ? PettiColors.sabana
        : PettiColors.alert;
    final icon = kind == PettiToastKind.success
        ? Icons.check_rounded
        : Icons.error_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PettiSpacing.s4,
        vertical: PettiSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: PettiShadows.elevation2,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: PettiText.body().copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: PettiSpacing.s2),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Reintentar',
                style: PettiText.bodyStrong().copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Helper: show a snack-bar-style toast from anywhere with a context.
  static void show(
    BuildContext context, {
    required PettiToastKind kind,
    required String message,
    VoidCallback? onRetry,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: Duration(seconds: kind == PettiToastKind.error ? 6 : 3),
        margin: const EdgeInsets.fromLTRB(
          PettiSpacing.s4,
          0,
          PettiSpacing.s4,
          PettiSpacing.s5,
        ),
        behavior: SnackBarBehavior.floating,
        content: PettiToast(
          kind: kind,
          message: message,
          onRetry: onRetry,
        ),
      ),
    );
  }
}
