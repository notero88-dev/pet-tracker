// A5.2 — "Encontramos a tu Petti."
//
// First-GPS-fix moment. Real Google Map zoomed to the device position,
// floating Sabana toast at top, glass-blurred info sheet at bottom with
// 3-stat grid (precisión / satélites / batería) and a Marigold pulse-dot
// on the map. Source: design package screens-a5.jsx::A5_FirstFix.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A5FirstFixScreen extends StatefulWidget {
  /// Where the device just appeared.
  final LatLng position;

  /// Reverse-geocoded address. Pass null to suppress the address line.
  final String? addressLabel;

  /// GPS accuracy in meters.
  final double accuracyMeters;

  /// Number of satellites in view (10–14 typical urban).
  final int satellites;

  /// Device battery percentage.
  final int batteryPercent;

  /// "Definir zona segura" → caller advances into A6.1.
  final VoidCallback onDefineSafeZone;

  const A5FirstFixScreen({
    super.key,
    required this.position,
    this.addressLabel,
    required this.accuracyMeters,
    required this.satellites,
    required this.batteryPercent,
    required this.onDefineSafeZone,
  });

  @override
  State<A5FirstFixScreen> createState() => _A5FirstFixScreenState();
}

class _A5FirstFixScreenState extends State<A5FirstFixScreen> {
  GoogleMapController? _mapCtrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // === Map (full bleed) ========================================
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.position,
              zoom: 16,
            ),
            onMapCreated: (c) => setState(() => _mapCtrl = c),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Tinted dim wash so dark Petti chrome reads on top.
            // Real dark map style would replace this in production.
            circles: {
              Circle(
                circleId: const CircleId('first-fix-glow'),
                center: widget.position,
                radius: widget.accuracyMeters * 4,
                fillColor:
                    PettiColors.marigold.withValues(alpha: 0.18),
                strokeColor: PettiColors.marigold.withValues(alpha: 0.3),
                strokeWidth: 1,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('first-fix'),
                position: widget.position,
              ),
            },
          ),
          // Soft midnight scrim — just enough so the glass sheets read.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      PettiColors.midnight.withValues(alpha: 0.55),
                      PettiColors.midnight.withValues(alpha: 0.10),
                      PettiColors.midnight.withValues(alpha: 0.55),
                    ],
                    stops: const [0, 0.4, 1],
                  ),
                ),
              ),
            ),
          ),
          // === Top chrome ==============================================
          SafeArea(
            child: Column(
              children: [
                const PettiStepHeader(step: 3, total: 4),
                const SizedBox(height: PettiSpacing.s4),
                const _ReceivedToast(),
                const Spacer(),
              ],
            ),
          ),
          // === Bottom info sheet + CTA dock ============================
          Positioned(
            left: PettiSpacing.s3,
            right: PettiSpacing.s3,
            bottom: 100,
            child: _InfoSheet(
              accuracyMeters: widget.accuracyMeters,
              satellites: widget.satellites,
              batteryPercent: widget.batteryPercent,
              addressLabel: widget.addressLabel,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PettiCtaDock(
              primaryLabel: 'Definir zona segura',
              onPrimary: widget.onDefineSafeZone,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }
}

class _ReceivedToast extends StatelessWidget {
  const _ReceivedToast();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PettiRadii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: PettiSpacing.s4, vertical: PettiSpacing.s3 - 2),
          decoration: BoxDecoration(
            color: PettiColors.sabana.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(PettiRadii.pill),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_rounded,
                  color: PettiColors.fgOnDark, size: 14),
              const SizedBox(width: PettiSpacing.s2),
              Text(
                'Primera señal recibida',
                style: PettiText.bodyStrong().copyWith(
                  color: PettiColors.fgOnDark,
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

class _InfoSheet extends StatelessWidget {
  final double accuracyMeters;
  final int satellites;
  final int batteryPercent;
  final String? addressLabel;

  const _InfoSheet({
    required this.accuracyMeters,
    required this.satellites,
    required this.batteryPercent,
    this.addressLabel,
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
            color: const Color(0xFF111A2B).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(PettiRadii.lg - 2),
            border: Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AQUÍ ESTÁS',
                style: PettiText.meta().copyWith(
                  color: PettiColors.marigold,
                  fontSize: 11,
                  letterSpacing: 0.08 * 11,
                ),
              ),
              const SizedBox(height: PettiSpacing.s2 + 2),
              Text(
                'Encontramos a tu mascota.',
                style: PettiText.h2().copyWith(
                  color: PettiColors.fgOnDark,
                  fontSize: 24,
                ),
              ),
              if (addressLabel != null) ...[
                const SizedBox(height: PettiSpacing.s2),
                Text(
                  '${addressLabel!}. Precisión ${accuracyMeters.toStringAsFixed(1)} m.',
                  style: PettiText.bodySm().copyWith(
                    color: PettiColors.fgOnDarkDim,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: PettiSpacing.s3 + 2),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: accuracyMeters.toStringAsFixed(1),
                      unit: 'm',
                      label: 'precisión',
                    ),
                  ),
                  const SizedBox(width: PettiSpacing.s2),
                  Expanded(
                    child: _Stat(
                      value: '$satellites',
                      unit: '',
                      label: 'satélites',
                    ),
                  ),
                  const SizedBox(width: PettiSpacing.s2),
                  Expanded(
                    child: _Stat(
                      value: '$batteryPercent',
                      unit: '%',
                      label: 'batería',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  const _Stat({required this.value, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s3, vertical: PettiSpacing.s3 - 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
        border: Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: PettiText.number(size: 18).copyWith(
                    color: PettiColors.fgOnDark,
                    letterSpacing: -0.02 * 18,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: unit,
                    style: PettiText.bodySm().copyWith(
                      color: PettiColors.fgOnDarkFaint,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: PettiText.meta().copyWith(
              color: PettiColors.fgOnDarkFaint,
              fontSize: 9,
              letterSpacing: 0.05 * 9,
            ),
          ),
        ],
      ),
    );
  }
}
