// A4.3 — Manual IMEI fallback
//
// Segmented 15-digit input shown as Space Grotesk tabular figures with
// a blinking cursor and live "N de 15 dígitos" progress. Dark theme.
// Fallback when the QR scan fails or the QR is illegible. Source:
// design package screens-a4.jsx::A4_ManualImei.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A4ManualImeiScreen extends StatefulWidget {
  /// Called with a confirmed 15-digit IMEI when the user taps Continuar.
  final ValueChanged<String> onSubmit;

  /// "Volver al escáner".
  final VoidCallback onBackToScanner;

  const A4ManualImeiScreen({
    super.key,
    required this.onSubmit,
    required this.onBackToScanner,
  });

  @override
  State<A4ManualImeiScreen> createState() => _A4ManualImeiScreenState();
}

class _A4ManualImeiScreenState extends State<A4ManualImeiScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus so the OS keyboard appears immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _value => _controller.text;
  bool get _isComplete => _value.length == 15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      // 2026-05-12: was `false` to keep the segmented input visually stable
      // when the keyboard rose. Trade-off was wrong — with the iOS numeric
      // keyboard up, the bottom CTA dock ("Continuar") rendered BELOW the
      // keyboard's top edge and was unreachable, blocking the user from
      // completing the manual-IMEI flow. (Observed dogfood 2026-05-12: the
      // user typed 15 digits but could not advance, and the iOS number pad
      // has no built-in "Done" key.) `true` lets the Scaffold shrink the
      // body so the CTA stays above the keyboard. The segmented display
      // shifts up a few pixels — acceptable UX cost for the unblock.
      resizeToAvoidBottomInset: true,
      // Tap anywhere outside the input to dismiss the keyboard. Doubles as
      // an escape hatch on the off-chance the OS keyboard ever covers the
      // CTA again (e.g. third-party keyboard with taller bar).
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
        child: Column(
          children: [
            PettiStepHeader(step: 2, total: 4, onBack: widget.onBackToScanner),
            const SizedBox(height: PettiSpacing.s4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PettiScreenHeading(
                    kicker: 'Modo manual',
                    title: 'Escribe el IMEI.',
                    ledeText:
                        'Lo encuentras impreso en la base, debajo del código QR. Son 15 dígitos.',
                  ),
                  const SizedBox(height: PettiSpacing.s6),
                  // === Segmented input ====================================
                  Text(
                    'IMEI',
                    style: PettiText.meta().copyWith(
                      color: PettiColors.fgOnDarkFaint,
                      fontSize: 11,
                      letterSpacing: 0.06 * 11,
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s2),
                  GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    child: _SegmentedDisplay(value: _value),
                  ),
                  const SizedBox(height: PettiSpacing.s2),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _value.isEmpty
                              ? const Color(0xFFFAF7F2).withValues(alpha: 0.08)
                              : PettiColors.sabanaSoft,
                        ),
                        child: _value.isEmpty
                            ? null
                            : const Icon(Icons.check_rounded,
                                color: PettiColors.sabana, size: 10),
                      ),
                      const SizedBox(width: PettiSpacing.s2),
                      Text(
                        '${_value.length} de 15 dígitos',
                        style: PettiText.bodySm().copyWith(
                          color: PettiColors.fgOnDarkFaint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PettiSpacing.s5),
                  // === Help card ==========================================
                  const _HelpCard(),
                ],
              ),
            ),
            const Spacer(),
            PettiCtaDock(
              primaryLabel: 'Continuar',
              onPrimary: _isComplete ? () => widget.onSubmit(_value) : null,
              secondaryLabel: 'Volver al escáner',
              onSecondary: widget.onBackToScanner,
            ),
          ],
        ),
      ),
      ), // GestureDetector
      // Hidden numeric input bound to the focus node so the OS keyboard
      // drives the segmented display via setState.
      bottomSheet: Offstage(
        offstage: true,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }
}

class _SegmentedDisplay extends StatefulWidget {
  final String value;
  const _SegmentedDisplay({required this.value});

  @override
  State<_SegmentedDisplay> createState() => _SegmentedDisplayState();
}

class _SegmentedDisplayState extends State<_SegmentedDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final group1 = v.length >= 6 ? v.substring(0, 6) : v;
    final group2 = v.length >= 11 ? v.substring(6, 11) : (v.length > 6 ? v.substring(6) : '');
    final group3 = v.length > 11 ? v.substring(11) : '';
    final remaining = 15 - v.length;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s4, vertical: PettiSpacing.s4 + 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PettiRadii.md),
        border: Border.all(
          color: PettiColors.marigold.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          _digits(group1, opacity: 1.0),
          if (group2.isNotEmpty || group1.length == 6) const SizedBox(width: 6),
          if (group2.isNotEmpty) _digits(group2, opacity: 0.9),
          if (group3.isNotEmpty || (group1.length == 6 && group2.length == 5))
            const SizedBox(width: 6),
          if (group3.isNotEmpty) _digits(group3, opacity: 0.9, underline: true),
          // Animated cursor when there's room left.
          if (remaining > 0) ...[
            const SizedBox(width: 2),
            FadeTransition(
              opacity:
                  Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.5, 1, curve: Curves.linear),
              )),
              child: Container(
                width: 2,
                height: 22,
                color: PettiColors.marigold,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '_' * remaining,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 22,
                  letterSpacing: 0.03 * 22,
                  color: PettiColors.fgOnDarkFaint
                      .withValues(alpha: 0.4),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _digits(String s, {required double opacity, bool underline = false}) {
    return Text(
      s,
      style: TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.03 * 22,
        color: PettiColors.fgOnDark.withValues(alpha: opacity),
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: PettiColors.marigold.withValues(alpha: 0.6),
        decorationThickness: 2,
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: PettiColors.marigoldSoft,
        borderRadius: BorderRadius.circular(PettiRadii.md - 2),
        border: Border.all(
          color: PettiColors.marigold.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: PettiColors.marigold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: PettiColors.marigold,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: PettiSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Dónde está el IMEI?',
                  style: PettiText.bodyStrong().copyWith(
                    color: PettiColors.fgOnDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Voltea la base. Verás los números justo debajo del código.',
                  style: PettiText.bodySm().copyWith(
                    color: PettiColors.fgOnDarkDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
