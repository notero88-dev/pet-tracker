// QR Scanner — Petti restyle.
//
// Camera viewfinder with a square cutout where the user aligns the QR
// code on the back of the GPS collar. Corner markers in Marigold so they
// pop against any background. Instructions in a warm Midnight card with
// Petti type. "Ingresar IMEI manualmente" affordance opens a Petti dialog.
//
// One-shot scan: detected → validate → navigate. Manual entry is the
// fallback when the QR is dirty / damaged.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/petti_theme.dart';
import 'pet_profile_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Translucent app bar so the camera preview shows through to the top.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Escanear collar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Linterna',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleBarcode,
          ),
          CustomPaint(painter: _ScannerOverlayPainter()),
          Positioned(
            bottom: PettiSpacing.s7,
            left: PettiSpacing.s5,
            right: PettiSpacing.s5,
            child: Container(
              padding: const EdgeInsets.all(PettiSpacing.s5),
              decoration: BoxDecoration(
                color: PettiColors.midnight.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(PettiRadii.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                  const SizedBox(height: PettiSpacing.s3),
                  Text(
                    'Apunta al código QR',
                    style: PettiText.h3().copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PettiSpacing.s2),
                  Text(
                    'El código está en la parte trasera del collar GPS.',
                    style: PettiText.body().copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PettiSpacing.s4),
                  TextButton.icon(
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.keyboard_outlined,
                        color: Colors.white),
                    label: Text(
                      'Ingresar IMEI manualmente',
                      style: PettiText.bodyStrong().copyWith(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- callbacks

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    if (_isValidIMEI(code)) {
      _navigateToPetProfile(_normalizeImei(code));
    } else {
      _showInvalidCodeDialog(code);
      setState(() => _isProcessing = false);
    }
  }

  bool _isValidIMEI(String code) {
    final cleaned = code.replaceAll(RegExp(r'\D'), '');
    return cleaned.length == 15;
  }

  String _normalizeImei(String code) =>
      code.replaceAll(RegExp(r'\D'), '');

  void _navigateToPetProfile(String imei) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PetProfileScreen(imei: imei)),
    );
  }

  // ----------------------------------------------------------- dialogs

  void _showInvalidCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Código no válido'),
        content: Text(
          'El código escaneado no parece un IMEI válido.\n\n'
          'Código: $code\n\n'
          'El IMEI debe tener 15 dígitos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ingresar IMEI'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 15,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'IMEI (15 dígitos)',
            hintText: '862407061373209',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final imei = controller.text.trim();
              if (_isValidIMEI(imei)) {
                Navigator.pop(dialogContext);
                _navigateToPetProfile(_normalizeImei(imei));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('IMEI inválido. Debe tener 15 dígitos.'),
                  ),
                );
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _ScannerOverlayPainter — dim everything outside a centered rounded square
// (the cutout window) and draw Marigold L-shaped corner markers.
// =============================================================================

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dim full-screen tint with the cutout punched out via even-odd fill rule.
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final cutoutSize = size.width * 0.7;
    final cutoutLeft = (size.width - cutoutSize) / 2;
    final cutoutTop = (size.height - cutoutSize) / 2;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize),
          const Radius.circular(PettiRadii.md),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, dimPaint);

    // Marigold L-shaped corner markers — bright enough to read against any
    // camera content the user points at.
    const markerLength = 32.0;
    const markerWidth = 4.0;
    final markerPaint = Paint()
      ..color = PettiColors.marigold
      ..style = PaintingStyle.stroke
      ..strokeWidth = markerWidth
      ..strokeCap = StrokeCap.round;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx, y), markerPaint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy), markerPaint);
    }

    corner(cutoutLeft, cutoutTop, markerLength, markerLength);
    corner(cutoutLeft + cutoutSize, cutoutTop, -markerLength, markerLength);
    corner(cutoutLeft, cutoutTop + cutoutSize, markerLength, -markerLength);
    corner(cutoutLeft + cutoutSize, cutoutTop + cutoutSize, -markerLength,
        -markerLength);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
