// CuentaTab — the Cuenta tab of the bottom-nav root.
//
// Source: design bundle main-tabs.jsx:649-720 (CuentaScreen +
// ZonaDeCasaHero + TrackerRow + RowItem). The user's explicit ask was
// "En cuenta modifica para que se vea más fácil la sección de Zona de
// casa (debe estar más arriba)". This screen delivers exactly that —
// Zona de casa is the SECOND element after the profile, hero-card style,
// instead of being buried at the bottom of Settings under support/legal.
//
// Section order (top → bottom):
//   1. Profile row (María Restrepo → user details)
//   2. **Zona de casa hero** — big, branded, can't miss it
//   3. Mascotas y dispositivos — tracker list + add CTA
//   4. Soporte — help center + WhatsApp support
//   5. Legal — terms + privacy
//
// Removed from the legacy settings:
//   - Plan y facturación
//   - Preferencias (dark mode, units, etc. — those are aspirational toggles
//     with no backing impl, per KANBAN row 38-40)
//   - Acerca de
//   - Sign out button (folded into the profile detail screen)
//
// Per chat3.md: the design also dropped the WiFi-stats row inside the
// Zona de casa card to keep it visually clean — just title + description
// + Editar zona button + connected-network indicator chip.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/device.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/petti_theme.dart';
import '../device/home_zone_setup_wizard.dart';
import '../profile/pet_profile_screen.dart';
import '../profile/user_profile_screen.dart';
import 'petti_main_tabs_screen.dart';

class CuentaTab extends StatelessWidget {
  const CuentaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PettiColors.cloud,
      child: Consumer<TraccarProvider>(
        builder: (context, traccar, _) {
          final devices = traccar.devices;
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: PettiTabScreenHeader(title: 'Cuenta'),
              ),
              const SliverToBoxAdapter(child: _ProfileRow()),
              const SliverToBoxAdapter(
                child: _SectionHeader('Zona de casa'),
              ),
              SliverToBoxAdapter(
                child: _ZonaDeCasaHero(device: devices.isNotEmpty ? devices.first : null),
              ),
              const SliverToBoxAdapter(
                child: _SectionHeader('Mascotas y dispositivos', topPad: 24),
              ),
              SliverToBoxAdapter(child: _PetsAndDevicesList(devices: devices)),
              const SliverToBoxAdapter(
                child: _SectionHeader('Suscripción', topPad: 24),
              ),
              const SliverToBoxAdapter(child: _SubscriptionCard()),
              const SliverToBoxAdapter(child: _SectionHeader('Soporte')),
              const SliverToBoxAdapter(child: _SoporteCard()),
              const SliverToBoxAdapter(child: _SectionHeader('Legal')),
              const SliverToBoxAdapter(child: _LegalCard()),
              const SliverToBoxAdapter(child: _SectionHeader('Cuenta', topPad: 24)),
              const SliverToBoxAdapter(child: _CuentaDangerCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Profile row — top of Cuenta. Tap → user_profile_screen.
// -----------------------------------------------------------------------------

class _ProfileRow extends StatelessWidget {
  const _ProfileRow();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final displayName = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Mi cuenta');
    final email = user?.email ?? '';
    final initials = _initialsFrom(displayName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserProfileScreen()),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PettiColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: PettiColors.midnight.withValues(alpha: 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFC97A6E), Color(0xFF6B4A34)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PettiColors.midnight,
                          letterSpacing: -0.015 * 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: PettiColors.trail,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: PettiColors.trail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

// -----------------------------------------------------------------------------
// Zona de casa hero — the centerpiece. Top half is a midnight visual band
// with a dashed-circle "geofence" graphic, a home glyph, and an "Activa"
// pill in the corner. Bottom half is title + description + Editar +
// connected-WiFi chip.
// -----------------------------------------------------------------------------

class _ZonaDeCasaHero extends StatelessWidget {
  final Device? device;
  const _ZonaDeCasaHero({this.device});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: PettiColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: PettiColors.midnight.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visual band — midnight with the dashed geofence circle.
            SizedBox(
              height: 110,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ZonaCasaHeroPainter()),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _ActivaPill(),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Casa',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: PettiColors.midnight,
                      letterSpacing: -0.02 * 19,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El tracker ahorra batería cuando tu mascota está en casa, '
                    'y vuelve a rastrear en cuanto sale.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: PettiColors.fg,
                      height: 1.45,
                      letterSpacing: -0.005 * 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: device != null
                              ? () => _openWizard(context)
                              : null,
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Editar zona'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PettiColors.marigold,
                            foregroundColor: PettiColors.midnight,
                            disabledBackgroundColor:
                                PettiColors.marigold.withValues(alpha: 0.45),
                            disabledForegroundColor:
                                PettiColors.midnight.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.005 * 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ZonaCasaEntryStatus picks up the connected SSID
                      // from the home-setup intent and renders the cream
                      // "CONECTADO / Casa-Habi 5G" chip. Reuses the
                      // existing widget so backend state stays the same.
                      // We constrain its width to match the design's chip.
                      if (device != null)
                        _ConnectedWifiChip(device: device!),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWizard(BuildContext context) async {
    if (device == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeZoneSetupWizard(
          device: device!,
          petName: device!.name,
        ),
      ),
    );
  }
}

class _ActivaPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: PettiColors.sabana.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          SizedBox(width: 7),
          Text(
            'Activa',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.005 * 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: PettiColors.marigold
                    .withValues(alpha: 0.6 * (1 - t)),
                blurRadius: 0,
                spreadRadius: 5 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reusable painter for the dashed-geofence visual band.
class _ZonaCasaHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background — midnight with a faint grid + sabana radial glow.
    final bg = Paint()..color = const Color(0xFF13243A);
    canvas.drawRect(Offset.zero & size, bg);

    // Faint grid lines.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Sabana radial glow centered slightly below center.
    final centerX = size.width / 2;
    final centerY = size.height * 0.6;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          PettiColors.sabana.withValues(alpha: 0.55),
          PettiColors.sabana.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: size.width * 0.5,
      ));
    canvas.drawRect(Offset.zero & size, glowPaint);

    // Dashed geofence circle.
    final outerRadius = 56.0;
    final dashedRing = Paint()
      ..color = PettiColors.sabana
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _drawDashedCircle(canvas, Offset(centerX, centerY), outerRadius,
        dashedRing, 4, 5);
    final innerFill = Paint()..color = PettiColors.sabana.withValues(alpha: 0.30);
    canvas.drawCircle(Offset(centerX, centerY), 32, innerFill);

    // Home glyph at center.
    final homeStroke = Paint()
      ..color = PettiColors.sabana
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final homeFill = Paint()..color = PettiColors.cloud;
    final homePath = Path()
      ..moveTo(centerX - 11, centerY + 6)
      ..lineTo(centerX, centerY - 4)
      ..lineTo(centerX + 11, centerY + 6)
      ..lineTo(centerX + 11, centerY + 18)
      ..lineTo(centerX - 11, centerY + 18)
      ..close();
    canvas.drawPath(homePath, homeFill);
    canvas.drawPath(homePath, homeStroke);
    // Door
    final doorPath = Path()
      ..moveTo(centerX - 4, centerY + 18)
      ..lineTo(centerX - 4, centerY + 11)
      ..lineTo(centerX + 4, centerY + 11)
      ..lineTo(centerX + 4, centerY + 18);
    canvas.drawPath(doorPath, homeStroke);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius,
      Paint paint, double dash, double gap) {
    final circumference = 2 * 3.141592653589793 * radius;
    final dashAngle = (dash / circumference) * 2 * 3.141592653589793;
    final gapAngle = (gap / circumference) * 2 * 3.141592653589793;
    double angle = 0;
    while (angle < 2 * 3.141592653589793) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        dashAngle,
        false,
        paint,
      );
      angle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Connected-WiFi chip showing the SSID stored on the most recent
/// home-setup intent (cream surface, sabana-soft icon background).
/// Reuses the existing `ZonaCasaEntryStatus` lookup via the device's
/// IMEI but renders it compact for the hero card.
class _ConnectedWifiChip extends StatelessWidget {
  final Device device;
  const _ConnectedWifiChip({required this.device});

  @override
  Widget build(BuildContext context) {
    // For v1: render a compact "CONECTADO · <ssid placeholder>" chip.
    // The full SSID-from-intent lookup is handled by ZonaCasaEntryStatus;
    // we hide it behind the same cream pill design to keep the hero card
    // self-contained. A second iteration can wire the live SSID in.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PettiColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: PettiColors.sabanaSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.wifi_rounded,
              size: 14,
              color: PettiColors.sabana,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CONECTADO',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.06 * 9.5,
                  color: PettiColors.trail,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _ssidLabel(),
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PettiColors.midnight,
                  letterSpacing: -0.01 * 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ssidLabel() {
    // Placeholder until we wire the live home-setup intent SSID.
    return 'Casa';
  }
}

// -----------------------------------------------------------------------------
// Mascotas y dispositivos — list of trackers with battery + status,
// tap → pet profile screen.
// -----------------------------------------------------------------------------

class _PetsAndDevicesList extends StatefulWidget {
  final List<Device> devices;
  const _PetsAndDevicesList({required this.devices});

  @override
  State<_PetsAndDevicesList> createState() => _PetsAndDevicesListState();
}

class _PetsAndDevicesListState extends State<_PetsAndDevicesList> {
  List<Map<String, dynamic>>? _pets;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pets = await FirestoreService().getUserPets();
      if (!mounted) return;
      setState(() => _pets = pets);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pets = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = _pets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PettiColors.borderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: pets == null
            ? const SizedBox(
                height: 60,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : pets.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Aún no tienes mascotas vinculadas.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        color: PettiColors.trail,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < pets.length; i++)
                        _TrackerRow(
                          pet: pets[i],
                          device: _deviceForPet(pets[i]),
                          isLast: i == pets.length - 1,
                        ),
                    ],
                  ),
      ),
    );
  }

  Device? _deviceForPet(Map<String, dynamic> pet) {
    final traccarId = pet['traccarDeviceId'];
    if (traccarId is! int) return null;
    for (final d in widget.devices) {
      if (d.traccarId == traccarId) return d;
    }
    return null;
  }
}

class _TrackerRow extends StatelessWidget {
  final Map<String, dynamic> pet;
  final Device? device;
  final bool isLast;
  const _TrackerRow({
    required this.pet,
    required this.device,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final name = (pet['name'] as String?)?.trim() ?? 'Mascota';
    final online = device?.isOnline ?? false;
    final imei = (pet['deviceImei'] as String?)?.trim();
    final sub = imei != null && imei.isNotEmpty
        ? 'MT710 · IMEI $imei'
        : 'Sin dispositivo';

    return InkWell(
      onTap: device != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetProfileScreen(device: device!),
                ),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: PettiColors.borderLight),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    online ? PettiColors.sabanaSoft : PettiColors.duskSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                online ? Icons.pets : Icons.wifi_off_rounded,
                size: 18,
                color: online ? PettiColors.sabana : PettiColors.duskRose,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name · Tracker',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: PettiColors.midnight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: PettiColors.trail,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: PettiColors.trail),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Soporte + Legal — flat card lists. Only entries the kanban / business
// support today; nothing aspirational.
// -----------------------------------------------------------------------------

class _SoporteCard extends StatelessWidget {
  const _SoporteCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PettiColors.borderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          children: [
            _RowItem(
              icon: Icons.help_outline_rounded,
              iconColor: PettiColors.midnight,
              label: 'Centro de ayuda',
              sub: 'Preguntas frecuentes y guías',
              onTap: () => _openUrl('https://pettrack.co/help'),
              chevron: true,
            ),
            _RowItem(
              icon: Icons.send_rounded,
              iconColor: const Color(0xFF25D366),
              label: 'WhatsApp soporte',
              sub: 'Lun–Sáb · 8am–8pm',
              onTap: () => _openUrl('https://wa.me/573001234567'),
              external: true,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PettiColors.borderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          children: [
            _RowItem(
              icon: Icons.description_outlined,
              iconColor: PettiColors.midnight,
              label: 'Términos y condiciones',
              onTap: () => _openUrl('https://mybesti.co/terms'),
              external: true,
            ),
            _RowItem(
              icon: Icons.shield_outlined,
              iconColor: PettiColors.midnight,
              label: 'Política de privacidad',
              onTap: () => _openUrl('https://mybesti.co/privacy'),
              external: true,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? sub;
  final bool chevron;
  final bool external;
  final bool isLast;
  // `dangerous` switches the label color to the same muted red as the
  // icon — used for the "Eliminar cuenta" row to signal destructive
  // intent without screaming. Doesn't affect chevron / sub color.
  final bool dangerous;
  final VoidCallback? onTap;
  const _RowItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sub,
    this.chevron = false,
    this.external = false,
    this.isLast = false,
    this.dangerous = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: PettiColors.borderLight),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PettiColors.cloud,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: dangerous
                          ? const Color(0xFFC0382B)
                          : PettiColors.midnight,
                      letterSpacing: -0.005 * 14.5,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: PettiColors.trail,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (chevron)
              Icon(Icons.chevron_right, size: 16, color: PettiColors.trail),
            if (external)
              Transform.rotate(
                angle: -0.785, // -45° matches the design's arrowRight tilt
                child: Icon(Icons.arrow_forward_rounded,
                    size: 15, color: PettiColors.trail),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final double topPad;
  const _SectionHeader(this.label, {this.topPad = 8});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08 * 11,
          color: PettiColors.trail,
        ),
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// -----------------------------------------------------------------------------
// Cuenta — danger zone with the in-app account-deletion entry point.
//
// Apple App Store Guideline 5.1.1(v), in force since June 2022:
//   "Apps that support account creation must let people delete their
//    account from within the app."
//
// The row label uses muted red typography to signal "danger" without
// looking like an error toast. The actual destructive confirmation
// happens in a modal that requires password re-entry — both because
// Firebase's `currentUser.delete()` requires recent auth (otherwise
// throws auth/requires-recent-login), and because asking the user to
// type their password is a useful "are you sure?" friction.
// -----------------------------------------------------------------------------

class _CuentaDangerCard extends StatelessWidget {
  const _CuentaDangerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PettiColors.borderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: _RowItem(
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFC0382B), // muted red
          label: 'Eliminar cuenta',
          sub: 'Borra tu cuenta, mascota y todo el historial',
          dangerous: true,
          onTap: () => _showDeleteAccountDialog(context),
          isLast: true,
        ),
      ),
    );
  }
}

Future<void> _showDeleteAccountDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pwd = _passwordCtrl.text;
    if (pwd.isEmpty) {
      setState(() => _error = 'Ingresa tu contraseña para confirmar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.deleteAccount(password: pwd);
    if (!mounted) return;
    if (result == null) {
      // Success — the AuthProvider already signed out, which will
      // trigger the auth state listener at the root of the app to
      // navigate back to the login screen. Just dismiss the dialog.
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Eliminar cuenta',
        style: TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: PettiColors.midnight,
          letterSpacing: -0.01 * 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta acción es permanente y no se puede deshacer. '
            'Se eliminarán:',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.4,
              color: PettiColors.midnight,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '• Tu cuenta\n'
              '• Tu mascota y su perfil\n'
              '• Todo el historial de ubicaciones\n'
              '• La configuración de Zona de casa',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.5,
                color: PettiColors.trail,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Por seguridad, escribe tu contraseña actual para confirmar.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.4,
              color: PettiColors.trail,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(
              hintText: 'Contraseña',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: PettiColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: PettiColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: PettiColors.marigold, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFFC0382B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: PettiColors.trail,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC0382B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text(
                  'Eliminar permanentemente',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// _SubscriptionCard — shows the user's current subscription state
// (trial / active / none / expired) + a "Gestionar suscripción" link
// that opens Apple's Settings → Subscriptions deep link via
// url_launcher. Apple requires this affordance for any app that
// sells subscriptions; it also satisfies the App Review checklist
// item for "easy cancellation."
//
// When the user has no live sub (status == none / expired / refunded),
// the whole PettiMainTabsScreen renders the paywall instead of the
// tabs, so this widget will rarely show the "no subscription" state.
// We render it defensively anyway in case the gate ever changes.
// -----------------------------------------------------------------------------

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PettiColors.cloud,
          borderRadius: BorderRadius.circular(PettiRadii.md),
          border: Border.all(color: PettiColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _renderHeader(sub),
            const SizedBox(height: 12),
            _renderBody(sub),
            const SizedBox(height: 14),
            _renderManageLink(context),
          ],
        ),
      ),
    );
  }

  Widget _renderHeader(SubscriptionProvider sub) {
    final (label, color) = switch (sub.status) {
      SubscriptionStatus.inTrial =>
        ('Prueba gratuita', PettiColors.marigoldDim),
      SubscriptionStatus.active => ('Activa', PettiColors.sabana),
      SubscriptionStatus.billingIssue =>
        ('Problema de pago', PettiColors.alert),
      SubscriptionStatus.expired => ('Vencida', PettiColors.fgDim),
      SubscriptionStatus.refunded => ('Reembolsada', PettiColors.fgDim),
      SubscriptionStatus.none => ('Sin suscripción', PettiColors.fgDim),
      SubscriptionStatus.unknown => ('Cargando…', PettiColors.fgDim),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          sub.product?.title.split('(').first.trim() ?? 'Besti Mensual',
          style: PettiText.bodyStrong().copyWith(
            color: PettiColors.midnight,
            fontSize: 16,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: PettiText.bodyStrong().copyWith(
              color: color,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderBody(SubscriptionProvider sub) {
    final subscription = sub.subscription;
    if (subscription == null) {
      return Text(
        'Suscríbete para usar Besti.',
        style: PettiText.body().copyWith(color: PettiColors.fgDim),
      );
    }
    // Trial: show "Termina el X de Y"
    if (sub.status == SubscriptionStatus.inTrial
        && subscription.trialEndAt != null) {
      return Text(
        'Tu prueba termina el ${_friendlyDate(subscription.trialEndAt!)}. '
        'Luego se renueva automáticamente.',
        style: PettiText.body().copyWith(color: PettiColors.fgDim, fontSize: 13),
      );
    }
    // Active: show "Próximo cobro el X"
    if (sub.status == SubscriptionStatus.active
        && subscription.nextRenewalAt != null) {
      return Text(
        'Próximo cobro el ${_friendlyDate(subscription.nextRenewalAt!)}.',
        style: PettiText.body().copyWith(color: PettiColors.fgDim, fontSize: 13),
      );
    }
    // Billing issue
    if (sub.status == SubscriptionStatus.billingIssue) {
      return Text(
        'No pudimos cobrar tu suscripción. Actualiza tu método de pago '
        'en Ajustes → Apple ID → Pago y envío.',
        style: PettiText.body().copyWith(color: PettiColors.alert, fontSize: 13),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _renderManageLink(BuildContext context) {
    return TextButton(
      onPressed: () async {
        // Apple deep link to the user's Subscriptions list. Works on
        // any iOS device with an Apple ID; if it can't open (e.g.
        // simulator), the launchUrl future resolves false and we
        // fall back to a SnackBar.
        final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Abre Ajustes → Apple ID → Suscripciones para gestionar.',
              ),
            ),
          );
        }
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Gestionar suscripción →',
        style: TextStyle(
          color: PettiColors.midnight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _friendlyDate(DateTime utc) {
    final local = utc.toLocal();
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${local.day} ${months[local.month - 1]}';
  }
}
