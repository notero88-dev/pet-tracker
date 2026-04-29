# Onboarding Redesign — Remaining 11 Screens

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 11 onboarding screens from "Petti Design System.zip" (Onboarding Canvas, 2026-04-29 delivery) that were not shipped with the foundation commit.

**Architecture:** Each screen becomes a single Flutter `StatelessWidget` (or `StatefulWidget` where animation requires it) under `lib/screens/onboarding/`. Composition pattern is uniform: `Scaffold(backgroundColor: PettiColors.midnight)` + `SafeArea` + `Stack` with `PettiStepHeader` at top, screen-specific hero in the middle, `PettiCtaDock` at the bottom. The four shared widgets shipped today (`PettiStepHeader`, `PettiScreenHeading`, `PettiCtaDock`, `PettiPuck`) are the building blocks; only screen-specific illustrations / map renders need new code.

**Tech Stack:** Flutter, the existing Petti tokens + the four onboarding widgets. No new dependencies.

**Out of scope for this plan:**
- Wiring the screens into the existing onboarding navigation flow (separate task — current onboarding flow exists in `splash_screen.dart` → `auth/...` → `pet_profile_screen.dart` → `qr_scanner_screen.dart` → `first_position_screen.dart` → `setup_geofence_screen.dart`; the new design implies a different sequencing that the next plan will address).
- Real Lottie / Rive animations for the pulse rings — design says CSS keyframes; we'll start static and add `AnimationController` only where the absence of motion is most jarring (A5.1 Despertando).
- Map provider work — the design's stylized SVG basemap is decorative; in production the real Google Maps tiles take over. Where the design shows a stylized map, our screens use `GoogleMap` with the existing app dark map style.

---

## File Structure

**Files to create:**
- `lib/screens/onboarding/redesign/a4_intro_screen.dart` — A4.1 "Saca tu Petti"
- `lib/screens/onboarding/redesign/a4_qr_scan_screen.dart` — A4.2 (replaces existing `qr_scanner_screen.dart`'s look)
- `lib/screens/onboarding/redesign/a4_manual_imei_screen.dart` — A4.3 manual entry fallback
- `lib/screens/onboarding/redesign/a4_paired_screen.dart` — A4.4 success
- `lib/screens/onboarding/redesign/a5_searching_screen.dart` — A5.1 GPS searching with checklist
- `lib/screens/onboarding/redesign/a5_first_fix_screen.dart` — A5.2 map appears, glass sheet (replaces `first_position_screen.dart` look)
- `lib/screens/onboarding/redesign/a5_taking_longer_screen.dart` — A5.3 empathetic edge state
- `lib/screens/onboarding/redesign/a6_pick_location_screen.dart` — A6.1 map + address sheet
- `lib/screens/onboarding/redesign/a6_set_radius_screen.dart` — A6.2 radius slider
- `lib/screens/onboarding/redesign/a6_queued_screen.dart` — A6.4 queued empathetic edge
- `lib/screens/onboarding/redesign/a6_done_screen.dart` — A6.5 success card

**Files to modify (rewire):**
- `lib/screens/onboarding/setup_geofence_screen.dart` — currently combines pin + radius + Mode 8 hero in one screen; the design splits into 3 (A6.1, A6.2, A6.3). The Mode 8 hero overlay we just added stays; the pin/radius become separate steps.
- `lib/screens/onboarding/qr_scanner_screen.dart` — inherits A4.2 visual treatment.
- `lib/screens/onboarding/first_position_screen.dart` — inherits A5.1/A5.2/A5.3 visual treatment.

**Files NOT to touch:**
- `lib/widgets/petti/*.dart` (shipped with foundation commit; reuse as-is)
- `lib/utils/petti_theme.dart` (tokens cover everything the design needs)

---

## Reference: design package layout (already in `/tmp/petti_design/`)

| File | Provides |
|---|---|
| `screens-a4.jsx` | A4.1–A4.4 React/JSX source (translate to Flutter) |
| `screens-a5.jsx` | A5.1–A5.3 React/JSX source |
| `screens-a6.jsx` | A6.1–A6.5 React/JSX source |
| `screens-shared.jsx` | PhoneShell / StepHeader / ScreenHeading / CtaDock / PettiPuck — already translated to Flutter widgets in the foundation commit |
| `tokens.css` | All design tokens — already mapped to PettiColors / PettiText / PettiSpacing / PettiMotion |
| `assets/logo-mark.svg` | Petti pulse mark (paw inside ring) — needed for A4.1 brand moment |

When in doubt about exact pixel values / colors, the JSX is the source of truth. PettiColors / PettiSpacing are already aligned to the same hex values.

---

## Tasks

### Task 1 · A4.1 Intro — "Saca tu Petti de la caja"

**Files:**
- Create: `lib/screens/onboarding/redesign/a4_intro_screen.dart`

- [ ] **Step 1: Create the screen scaffold**

```dart
// lib/screens/onboarding/redesign/a4_intro_screen.dart
import 'package:flutter/material.dart';
import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_puck.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A4IntroScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback? onNotYet;

  const A4IntroScreen({super.key, required this.onContinue, this.onNotYet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: SafeArea(
        child: Column(
          children: [
            const PettiStepHeader(step: 1, total: 4, showBack: false),
            const Expanded(
              child: Center(child: PettiPuck(size: 220)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: PettiScreenHeading(
                kicker: 'Paso 1 · emparejar',
                title: 'Saca tu Petti de la caja.',
                ledeText:
                    'Lo vas a sostener cerca del teléfono. Tenlo a la mano — esto toma menos de un minuto.',
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),
            PettiCtaDock(
              primaryLabel: 'Lo tengo',
              onPrimary: onContinue,
              secondaryLabel: 'Mi Petti aún no llega',
              onSecondary: onNotYet,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: flutter analyze — expected: clean**

Run: `cd app && flutter analyze lib/screens/onboarding/redesign/a4_intro_screen.dart`

- [ ] **Step 3: commit**

```bash
git add app/lib/screens/onboarding/redesign/a4_intro_screen.dart
git commit -m "onboarding: A4.1 intro screen — Saca tu Petti"
```

---

### Task 2 · A4.2 QR scan

**Files:**
- Create: `lib/screens/onboarding/redesign/a4_qr_scan_screen.dart`

The design shows a styled scanner overlay with Marigold corner brackets and an animated scan-line. The existing `qr_scanner_screen.dart` already integrates `mobile_scanner`; this task wraps that camera surface in the new visual chrome.

- [ ] **Step 1: Build the visual frame** (corner brackets + animated scan-line) as a standalone widget `_QrFrame` inside the screen file, sized 240×240, using Marigold strokes per the design. Use `AnimationController` for the scan-line oscillation (1.6s ease, infinite).

- [ ] **Step 2: Wrap a `MobileScanner` (already a dependency in pubspec.yaml) inside the frame**, with the dark gradient background per the design.

- [ ] **Step 3: Wire `PettiStepHeader(step: 2, total: 4)` + screen heading "Apunta al código en la base." + `PettiCtaDock` with primary "Buscando…" disabled-loading and secondary "Ingresar IMEI manualmente"**.

- [ ] **Step 4: Test** — verify scanner triggers `onCodeFound` callback when a QR is detected.

- [ ] **Step 5: Commit**

---

### Task 3 · A4.3 Manual IMEI fallback

**Files:**
- Create: `lib/screens/onboarding/redesign/a4_manual_imei_screen.dart`

15-digit segmented IMEI input with live validation. The design shows segmented groups of `6 + 5 + 4` digits, an animated cursor, and a checkmark with "N de 15 dígitos" progress.

- [ ] **Step 1: Build a `_SegmentedImeiInput` widget** that takes a controller and renders the entered digits in three font groups (6-5-4 split) with the remaining slots as dim placeholders. Use `Space Grotesk` tabular figures per the design.

- [ ] **Step 2: Validation pill** — show Sabana checkmark + "N de 15 dígitos" once input is non-empty; show empty state otherwise.

- [ ] **Step 3: "¿Dónde está el IMEI?" help card** — Marigold-tinted, with hint copy from the design.

- [ ] **Step 4: Wire into `Scaffold` + step header + CTA dock** (primary "Continuar" disabled until 15 digits, secondary "Volver al escáner").

- [ ] **Step 5: Commit**

---

### Task 4 · A4.4 Paired success

**Files:**
- Create: `lib/screens/onboarding/redesign/a4_paired_screen.dart`

Sabana ring-burst around a checkmark, hardware/battery stat grid, "Continuar".

- [ ] **Step 1: `_SuccessBurst` widget** — 80px Sabana circle with white check, surrounded by 3 concentric Sabana-tinted rings at decreasing opacity. Mirror the same pattern used in `_SabanaHomeHero` from the foundation commit.

- [ ] **Step 2: Heading + IMEI display** — show identifier in Space Grotesk tabular figures, firmware version, "todo en orden".

- [ ] **Step 3: Two-column stat grid** — "Hardware: OK" / "Batería: 94%" cards, dark surface with hairline border per design tokens.

- [ ] **Step 4: Commit**

---

### Task 5 · A5.1 Despertando (GPS searching)

**Files:**
- Create: `lib/screens/onboarding/redesign/a5_searching_screen.dart`

Marigold pulse rings (3 layers) + checklist of (cellular / GPS / first fix) with done/active/pending states. **First screen requiring real animation** — pulse rings should expand+fade infinitely.

- [ ] **Step 1: `_PulseRings` widget** — `AnimationController` cycling 1.8s with 3 staggered rings expanding from 80px to ~240px while fading from 0.5 to 0 opacity. Marigold borders.

- [ ] **Step 2: `_StepChecklist` widget** — vertical list of 3 items (cellular, GPS, first-fix), reuses the same status-dot logic as `PettiWizardTimeline` but doesn't have a connector line. The active row's "EN CURSO" pill applies.

- [ ] **Step 3: Soft hint at bottom** — italic "Si está cerca de una ventana o al aire libre, encuentra señal más rápido." in `fgOnDarkFaint`.

- [ ] **Step 4: Commit**

---

### Task 6 · A5.2 First fix

**Files:**
- Create: `lib/screens/onboarding/redesign/a5_first_fix_screen.dart`

Map background + Sabana toast at top + glass info sheet at bottom. Uses real `GoogleMap` with the existing dark map style.

- [ ] **Step 1: Map surface** — `GoogleMap` widget with `cameraTargetBounds` zoomed to first-fix position. Custom marker = Marigold `PulseDot` (already exists? — check `lib/widgets/petti/`; if not, create one as a pulsing `Container`).

- [ ] **Step 2: Top toast** — pill-shaped Sabana-with-blur `Container` floating ~120px from top, "Primera señal recibida".

- [ ] **Step 3: Bottom glass sheet** — `BackdropFilter(blur: 24)` over Midnight 82% alpha, kicker "Aquí estás" / hero "Encontramos a tu Petti." / lede with address + precision / 3-stat grid (precisión, satélites, batería).

- [ ] **Step 4: CTA dock** — primary "Definir zona segura".

- [ ] **Step 5: Commit**

---

### Task 7 · A5.3 Taking longer (edge state)

**Files:**
- Create: `lib/screens/onboarding/redesign/a5_taking_longer_screen.dart`

Same structure as A5.1 but **Dusk Rose** instead of Marigold and a softer copy tone. Two tip cards with emoji glyphs (window / balcony).

- [ ] **Step 1: `_PulseRings` reused with `accentColor` param** — bump foundation widget to take a color so it can render in Dusk Rose for this screen. Update the widget added in Task 5 to accept `accent: PettiColors.duskRose`.

- [ ] **Step 2: `PettiScreenHeading` with `kickerColor: PettiColors.duskRose`** — already supported by the foundation widget.

- [ ] **Step 3: Two `_Tip` cards** — Dusk Rose-tinted background with emoji + bold title + lede.

- [ ] **Step 4: CTA dock** — primary "Seguir esperando", secondary "Lo intento más tarde".

- [ ] **Step 5: Commit**

---

### Task 8 · A6.1 Pick location

**Files:**
- Create: `lib/screens/onboarding/redesign/a6_pick_location_screen.dart`

Drag-the-map interaction with floating top search/address sheet and bottom action sheet.

- [ ] **Step 1: `GoogleMap` with `onCameraMove`** — track `_center` as the map drags; render a fixed center pin (Marigold pin SVG matching the design).

- [ ] **Step 2: Top address sheet** — kicker "Paso 1 de 3 · ubicación" / heading "¿Dónde es casa?" / search input with magnifier icon and current geocoded address. (Geocoding can be a `TODO` for now — show the LatLng as text.)

- [ ] **Step 3: Bottom status sheet** — small green dot + "PIN CENTRADO" + lede "Mueve el mapa hasta que el pin caiga justo donde duerme tu peludo."

- [ ] **Step 4: CTA dock** — primary "Aquí es", secondary "Buscar otra dirección".

- [ ] **Step 5: Commit**

---

### Task 9 · A6.2 Set radius

**Files:**
- Create: `lib/screens/onboarding/redesign/a6_set_radius_screen.dart`

Visual radius slider with 56px tabular numeric display.

- [ ] **Step 1: `GoogleMap` with `Circle` overlay** — Sabana fill at 0.18 alpha, Sabana stroke 2px dashed, center dot. Bind to `_radius` state.

- [ ] **Step 2: Bottom radius control sheet** — kicker / heading / large numeric "120 metros" / Marigold slider (50–500 range, 38% filled track at default 120) / "50 m / 500 m" min-max labels.

- [ ] **Step 3: CTA dock** — primary "Continuar", secondary "Volver al pin".

- [ ] **Step 4: Commit**

---

### Task 10 · A6.4 Queued (edge state)

**Files:**
- Create: `lib/screens/onboarding/redesign/a6_queued_screen.dart`

Empathetic state shown when the wizard's `?queue=true` returned 408 (or when device went offline mid-wizard). Dusk Rose moon-icon hero + status card showing "3 de 5 pasos completos".

- [ ] **Step 1: `_QueuedHero` widget** — square-rounded 70px container with Dusk Rose icon (the `moon_outlined` Material icon is close enough to the design's "Z" sleep glyph).

- [ ] **Step 2: `PettiScreenHeading`** — kicker "Tu Petti está dormido" / title "Lo despertaremos cuando se mueva." / lede / `kickerColor: PettiColors.duskRose`.

- [ ] **Step 3: Status card** — Dusk Rose-tinted, "EN COLA · 3 de 5 pasos completos" header, lede paragraph.

- [ ] **Step 4: CTA dock** — primary "Entendido", secondary "¿Cómo despierto a mi Petti?".

- [ ] **Step 5: Wire into `_failWizard` in setup_geofence_screen.dart** — when `WizardStepResult is WizardStepQueueExpired`, replace the SnackBar with a `Navigator.pushReplacement` to this screen.

- [ ] **Step 6: Commit**

---

### Task 11 · A6.5 Done (zona segura active)

**Files:**
- Create: `lib/screens/onboarding/redesign/a6_done_screen.dart`

Mini map preview of the geofence + Sabana checkmark kicker + summary card.

- [ ] **Step 1: `_MiniMap` widget** — fixed 220px height, rounded 22px, shows `GoogleMap` with `Circle` overlay matching the wizard's selected radius.

- [ ] **Step 2: Sabana kicker badge** — circle with checkmark + "ZONA SEGURA ACTIVA" text, all in Sabana.

- [ ] **Step 3: Hero "Pipo está en casa." + lede** — the title comes from `widget.petName`, not hardcoded.

- [ ] **Step 4: Detail row** — "CASA · CHAPINERO" + "Radio 120 m · alertas activadas" + chevron-right for tappable detail.

- [ ] **Step 5: CTA dock** — primary "Ver el mapa" → `HomeScreen`, secondary "Definir otra zona" → A6.1.

- [ ] **Step 6: Replace the current `_showSuccess()` AlertDialog in setup_geofence_screen.dart** with `Navigator.pushAndRemoveUntil` to this screen.

- [ ] **Step 7: Commit**

---

### Task 12 · Wire screens into the onboarding navigation flow

**Files:**
- Modify: `lib/screens/auth/register_screen.dart` (or wherever first-onboarding-step is currently launched)
- Modify: `lib/screens/onboarding/qr_scanner_screen.dart` (replace look)
- Modify: `lib/screens/onboarding/first_position_screen.dart` (replace look)
- Modify: `lib/screens/onboarding/setup_geofence_screen.dart` (split into A6.1 / A6.2 / A6.3 hero from this commit / A6.5)

Sequencing:

```
register/login → A4.1 → A4.2 (or A4.3 fallback) → A4.4 → A5.1 (→ A5.3 if slow) → A5.2 → A6.1 → A6.2 → A6.3 (already shipped) → A6.5 (or A6.4 on failure)
```

- [ ] **Step 1: Build a single `OnboardingFlow` controller** that owns the linear sequence, hands each screen a `onContinue` callback that pushes the next route.

- [ ] **Step 2: Migration** — replace direct screen references in the existing flow with the new ones, one screen at a time.

- [ ] **Step 3: End-to-end smoke test** — fresh APK install on emulator, walk through the entire onboarding from register to A6.5 with the live device.

- [ ] **Step 4: Update PLAN.md §13 Sessions log** with the rollout date + any issues observed.

- [ ] **Step 5: Final commit**

---

## Self-Review Notes

**Spec coverage:** Every screen in `Onboarding Canvas.html` has a task here.

**Placeholder scan:** The two animation tasks (A5.1 pulse rings, A4.2 scan line) have explicit `AnimationController` references. No "TBD" or "implement later".

**Type consistency:** `Mode8WizardState`, `PettiTimelineEntry`, `PettiTimelineStatus` are all imports from already-shipped files — no new types needed for this plan.

**Open question for the next session:** Does the original `register_screen.dart` already cover what the design implies should sit before A4.1, or does the design imply a new pre-pairing welcome screen we need to design?

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-04-29-onboarding-redesign.md`. Two execution options:

**1. Subagent-Driven** — fresh subagent per task, review between tasks. Recommended given each task is well-isolated.

**2. Inline Execution** — execute tasks in the current session using executing-plans, batch with checkpoints.

Which approach?
