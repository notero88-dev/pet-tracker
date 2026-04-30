// A6.2 — "¿Hasta dónde es casa?"
//
// Visual radius slider (50–500m). Sabana dashed circle on the map
// updates live; bottom glass sheet shows a 56px tabular numeric
// readout of the current radius. Source: design package
// screens-a6.jsx::A6_SetRadius.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A6SetRadiusScreen extends StatefulWidget {
  /// The home center chosen in A6.1.
  final LatLng homeCenter;

  /// Initial radius value (defaults to 120m to match the design).
  final double initialRadiusMeters;

  /// Called with the chosen radius (rounded to whole meters) when the
  /// user taps Continuar.
  final ValueChanged<int> onConfirm;

  /// "Volver al pin" → back to A6.1.
  final VoidCallback onBack;

  const A6SetRadiusScreen({
    super.key,
    required this.homeCenter,
    this.initialRadiusMeters = 120,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  State<A6SetRadiusScreen> createState() => _A6SetRadiusScreenState();
}

class _A6SetRadiusScreenState extends State<A6SetRadiusScreen> {
  GoogleMapController? _mapCtrl;
  late double _radius;

  static const double _min = 50;
  static const double _max = 500;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadiusMeters.clamp(_min, _max);
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
          // === Map with Sabana radius circle =========================
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.homeCenter,
              zoom: _zoomFor(_radius),
            ),
            onMapCreated: (c) => setState(() => _mapCtrl = c),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            circles: {
              Circle(
                circleId: const CircleId('home-radius'),
                center: widget.homeCenter,
                radius: _radius,
                fillColor: PettiColors.sabana.withValues(alpha: 0.18),
                strokeColor: PettiColors.sabana,
                strokeWidth: 2,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('home-center'),
                position: widget.homeCenter,
              ),
            },
          ),
          // === Top header =============================================
          SafeArea(
            child: PettiStepHeader(
              step: 4,
              total: 4,
              onBack: widget.onBack,
            ),
          ),
          // === Bottom radius control sheet ============================
          Positioned(
            left: PettiSpacing.s3,
            right: PettiSpacing.s3,
            bottom: 100,
            child: _RadiusSheet(
              radius: _radius,
              min: _min,
              max: _max,
              onChanged: (v) => setState(() {
                _radius = v;
                _mapCtrl?.animateCamera(
                  CameraUpdate.newLatLngZoom(widget.homeCenter, _zoomFor(v)),
                );
              }),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PettiCtaDock(
              primaryLabel: 'Continuar',
              onPrimary: () => widget.onConfirm(_radius.round()),
              secondaryLabel: 'Volver al pin',
              onSecondary: widget.onBack,
            ),
          ),
        ],
      ),
    );
  }

  /// Pick a sensible map zoom for the current radius so the circle
  /// stays comfortably framed while scrubbing.
  double _zoomFor(double radius) {
    // Inverse-log mapping: 50m → ~17.5, 500m → ~14.5.
    if (radius <= 80) return 17.5;
    if (radius <= 150) return 16.8;
    if (radius <= 250) return 16;
    if (radius <= 400) return 15.2;
    return 14.6;
  }
}

class _RadiusSheet extends StatelessWidget {
  final double radius;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _RadiusSheet({
    required this.radius,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PettiRadii.lg - 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(PettiSpacing.s5 - 2),
          decoration: BoxDecoration(
            color: const Color(0xFF111A2B).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(PettiRadii.lg - 2),
            border:
                Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PASO 2 DE 3 · RADIO',
                style: PettiText.meta().copyWith(
                  color: PettiColors.marigold,
                  fontSize: 11,
                  letterSpacing: 0.08 * 11,
                ),
              ),
              const SizedBox(height: PettiSpacing.s2),
              Text(
                '¿Hasta dónde es "casa"?',
                style: PettiText.h2().copyWith(
                  color: PettiColors.fgOnDark,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Incluye el patio, el jardín, donde se siente en casa. No exageres — más pequeño es más preciso.',
                style: PettiText.bodySm().copyWith(
                  color: PettiColors.fgOnDarkDim,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: PettiSpacing.s4 + 2),
              // Big numeric readout.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    radius.round().toString(),
                    style: PettiText.number(size: 56, weight: FontWeight.w700)
                        .copyWith(
                      color: PettiColors.fgOnDark,
                      letterSpacing: -0.04 * 56,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'metros',
                    style: PettiText.lead().copyWith(
                      color: PettiColors.fgOnDarkDim,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PettiSpacing.s4),
              // Slider.
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: PettiColors.marigold,
                  inactiveTrackColor:
                      const Color(0xFFFAF7F2).withValues(alpha: 0.08),
                  thumbColor: PettiColors.cloud,
                  overlayColor:
                      PettiColors.marigold.withValues(alpha: 0.2),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 11),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 22),
                ),
                child: Slider(
                  value: radius,
                  min: min,
                  max: max,
                  divisions: ((max - min) / 5).round(),
                  onChanged: onChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '50 m',
                      style: PettiText.number(size: 11)
                          .copyWith(color: PettiColors.fgOnDarkFaint),
                    ),
                    Text(
                      '500 m',
                      style: PettiText.number(size: 11)
                          .copyWith(color: PettiColors.fgOnDarkFaint),
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
