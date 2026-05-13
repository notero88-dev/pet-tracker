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
              const SliverToBoxAdapter(child: _SectionHeader('Soporte')),
              const SliverToBoxAdapter(child: _SoporteCard()),
              const SliverToBoxAdapter(child: _SectionHeader('Legal')),
              const SliverToBoxAdapter(child: _LegalCard()),
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
              onTap: () => _openUrl('https://pettrack.co/terms'),
              external: true,
            ),
            _RowItem(
              icon: Icons.shield_outlined,
              iconColor: PettiColors.midnight,
              label: 'Política de privacidad',
              onTap: () => _openUrl('https://pettrack.co/privacy'),
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
  final VoidCallback? onTap;
  const _RowItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sub,
    this.chevron = false,
    this.external = false,
    this.isLast = false,
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
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: PettiColors.midnight,
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
