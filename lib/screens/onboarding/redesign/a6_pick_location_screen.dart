// A6.1 — "¿Dónde es casa?"
//
// Drag-the-map interaction with a fixed center pin. Top floating
// search/address sheet, bottom status sheet showing "PIN CENTRADO".
// Source: design package screens-a6.jsx::A6_PickLocation.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A6PickLocationScreen extends StatefulWidget {
  /// Where the map should start centered. Typically the device's first
  /// GPS fix from A5.2.
  final LatLng initialPosition;

  /// Optional human-readable address to seed the top sheet.
  final String? initialAddress;

  /// Called with the chosen home center when the user taps "Aquí es".
  final ValueChanged<LatLng> onConfirm;

  /// "Buscar otra dirección" — caller routes to a future search screen.
  final VoidCallback? onSearch;

  /// Back-chevron tap.
  final VoidCallback? onBack;

  const A6PickLocationScreen({
    super.key,
    required this.initialPosition,
    this.initialAddress,
    required this.onConfirm,
    this.onSearch,
    this.onBack,
  });

  @override
  State<A6PickLocationScreen> createState() => _A6PickLocationScreenState();
}

class _A6PickLocationScreenState extends State<A6PickLocationScreen> {
  GoogleMapController? _mapCtrl;
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition;
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: Stack(
        children: [
          // === Draggable map ==========================================
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 17,
            ),
            onMapCreated: (c) => setState(() => _mapCtrl = c),
            onCameraMove: (cam) => setState(() => _center = cam.target),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          // Soft scrim so glass sheets read.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      PettiColors.midnight.withValues(alpha: 0.35),
                      Colors.transparent,
                      PettiColors.midnight.withValues(alpha: 0.45),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          // === Center pin =============================================
          IgnorePointer(child: const Center(child: _CenterPin())),
          // === Top header + address sheet ============================
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PettiStepHeader(
                  step: 4,
                  total: 4,
                  onBack: widget.onBack,
                ),
                const SizedBox(height: PettiSpacing.s2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: PettiSpacing.s3),
                  child: _AddressSheet(
                    addressLabel: widget.initialAddress,
                    onTap: widget.onSearch,
                  ),
                ),
              ],
            ),
          ),
          // === Bottom status sheet + CTA ==============================
          Positioned(
            left: PettiSpacing.s3,
            right: PettiSpacing.s3,
            bottom: 100,
            child: const _PinCenteredSheet(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PettiCtaDock(
              primaryLabel: 'Aquí es',
              onPrimary: () => widget.onConfirm(_center),
              secondaryLabel:
                  widget.onSearch == null ? null : 'Buscar otra dirección',
              onSecondary: widget.onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: PettiSpacing.s3, vertical: 6),
          decoration: BoxDecoration(
            color: PettiColors.midnight,
            borderRadius: BorderRadius.circular(PettiRadii.pill),
            border: Border.all(
              color: PettiColors.marigold.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            'casa',
            style: PettiText.number(size: 12).copyWith(
              color: PettiColors.fgOnDark,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: PettiSpacing.s2),
        SizedBox(
          width: 36,
          height: 46,
          child: CustomPaint(painter: _PinPainter()),
        ),
        const SizedBox(height: 2),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: PettiColors.midnight,
            shape: BoxShape.circle,
            border: Border.all(color: PettiColors.marigold, width: 2),
          ),
        ),
      ],
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PettiColors.marigold;
    final stroke = Paint()
      ..color = PettiColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Tear-drop shape.
    final path = Path()
      ..moveTo(18, 2)
      ..cubicTo(9.7, 2, 3, 8.7, 3, 17)
      ..cubicTo(3, 28, 18, 44, 18, 44)
      ..cubicTo(18, 44, 33, 28, 33, 17)
      ..cubicTo(33, 8.7, 26.3, 2, 18, 2)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, stroke);
    // Inner dot.
    canvas.drawCircle(const Offset(18, 17), 5, Paint()..color = PettiColors.midnight);
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}

class _AddressSheet extends StatelessWidget {
  final String? addressLabel;
  final VoidCallback? onTap;

  const _AddressSheet({this.addressLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PettiRadii.md + 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(PettiSpacing.s4),
          decoration: BoxDecoration(
            color: const Color(0xFF111A2B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(PettiRadii.md + 2),
            border:
                Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PASO 1 DE 3 · UBICACIÓN',
                style: PettiText.meta().copyWith(
                  color: PettiColors.marigold,
                  fontSize: 11,
                  letterSpacing: 0.08 * 11,
                ),
              ),
              const SizedBox(height: PettiSpacing.s2),
              Text(
                '¿Dónde es casa?',
                style: PettiText.h2().copyWith(
                  color: PettiColors.fgOnDark,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: PettiSpacing.s3 + 2),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: PettiSpacing.s3 + 2,
                      vertical: PettiSpacing.s3),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFAF7F2).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
                    border: Border.all(
                        color: const Color(0xFFFAF7F2)
                            .withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          color: PettiColors.fgOnDarkDim, size: 18),
                      const SizedBox(width: PettiSpacing.s2 + 2),
                      Expanded(
                        child: Text(
                          addressLabel ?? 'Buscar dirección',
                          style: PettiText.body().copyWith(
                            color: PettiColors.fgOnDark,
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
        ),
      ),
    );
  }
}

class _PinCenteredSheet extends StatelessWidget {
  const _PinCenteredSheet();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PettiRadii.lg - 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(PettiSpacing.s4 + 2),
          decoration: BoxDecoration(
            color: const Color(0xFF111A2B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(PettiRadii.lg - 2),
            border:
                Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: PettiColors.sabana,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: PettiSpacing.s2 + 2),
                  Text(
                    'PIN CENTRADO',
                    style: PettiText.meta().copyWith(
                      color: PettiColors.sabana,
                      fontSize: 11,
                      letterSpacing: 0.08 * 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PettiSpacing.s2 - 2),
              Text(
                'Mueve el mapa hasta que el pin caiga justo donde duerme tu peludo.',
                style: PettiText.bodySm().copyWith(
                  color: PettiColors.fgOnDarkDim,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
