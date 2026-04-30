// A4.2 — "Apunta al código en la base"
//
// Live camera with Marigold-corner scanning frame and an animated
// scan-line. Captures a QR from the device's bottom face. Falls back
// to A4.3 manual IMEI entry on the secondary action.
//
// Source: design package screens-a4.jsx::A4_QrScan + the existing
// integration with `mobile_scanner` already used in the legacy
// qr_scanner_screen.dart.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A4QrScanScreen extends StatefulWidget {
  /// Called with the scanned IMEI string. Caller is responsible for
  /// validation (15 digits) and navigation to A4.4.
  final ValueChanged<String> onCodeFound;

  /// Switches to A4.3 manual IMEI entry.
  final VoidCallback onManualEntry;

  const A4QrScanScreen({
    super.key,
    required this.onCodeFound,
    required this.onManualEntry,
  });

  @override
  State<A4QrScanScreen> createState() => _A4QrScanScreenState();
}

class _A4QrScanScreenState extends State<A4QrScanScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _consumed = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_consumed) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code == null) return;
    _consumed = true;
    widget.onCodeFound(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // === Camera (full bleed) ====================================
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
          ),
          // Subtle warm gradient over the camera so the dark theme
          // tokens remain consistent — dimmed cream wash bottom-half.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  PettiColors.midnight.withValues(alpha: 0.65),
                  PettiColors.midnight.withValues(alpha: 0.25),
                  PettiColors.midnight.withValues(alpha: 0.85),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          // === Scan-frame overlay ====================================
          const Center(child: _ScanFrame()),
          // === Top chrome — header + caption ==========================
          SafeArea(
            child: Column(
              children: [
                const PettiStepHeader(step: 2, total: 4),
                const SizedBox(height: PettiSpacing.s5),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: PettiSpacing.s5),
                  child: const PettiScreenHeading(
                    kicker: 'Paso 2 · escanear',
                    title: 'Apunta al código en la base.',
                    ledeText:
                        'Está debajo de la base de carga. Acércalo, lo vamos a leer solo.',
                  ),
                ),
                const Spacer(),
                PettiCtaDock(
                  primaryLabel: 'Buscando…',
                  primaryLoading: true,
                  loadingLabel: 'Buscando…',
                  secondaryLabel: 'Ingresar IMEI manualmente',
                  onSecondary: widget.onManualEntry,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatefulWidget {
  const _ScanFrame();

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          // 4 corner brackets in Marigold.
          for (final corner in const [
            (Alignment.topLeft, true, true, false, false),
            (Alignment.topRight, true, false, false, true),
            (Alignment.bottomLeft, false, true, true, false),
            (Alignment.bottomRight, false, false, true, true),
          ])
            Align(
              alignment: corner.$1,
              child: _Bracket(
                top: corner.$2,
                left: corner.$3,
                bottom: corner.$4,
                right: corner.$5,
              ),
            ),
          // Animated scan-line.
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value; // 0 → 1 → 0
              return Positioned(
                left: 14,
                right: 14,
                top: 14 + (240 - 28) * t,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        PettiColors.marigold.withValues(alpha: 0),
                        PettiColors.marigold,
                        PettiColors.marigold.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PettiColors.marigold.withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  final bool top;
  final bool left;
  final bool bottom;
  final bool right;

  const _Bracket({
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: PettiColors.marigold, width: 2.5);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          left: left ? side : BorderSide.none,
          bottom: bottom ? side : BorderSide.none,
          right: right ? side : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(18) : Radius.zero,
          topRight: top && right ? const Radius.circular(18) : Radius.zero,
          bottomLeft:
              bottom && left ? const Radius.circular(18) : Radius.zero,
          bottomRight:
              bottom && right ? const Radius.circular(18) : Radius.zero,
        ),
      ),
    );
  }
}
