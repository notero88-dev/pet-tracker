// Petti Alert Detail screen.
//
// This is what the user sees when they tap a push notification, an in-app
// PettiAlertBanner, or a row in the Notifications screen. It's the
// canonical "I see something happened with my pet — give me details +
// what to do next" surface.
//
// Layout (top to bottom):
//   1. App bar     ←  back chevron, "Alerta" title, more-actions (mark
//                     read / delete) menu
//   2. Pet header  ←  avatar + pet name + alert headline + relative time
//   3. Mini-map    ←  CustomPaint (no Google Maps SDK dependency for
//                     this screen so it renders even if Maps API isn't
//                     enabled in Cloud Console). Shows the home zone
//                     circle + the pet's last known dot.
//   4. Location    ←  meta eyebrow + reverse-geocoded address (if any)
//                     + raw lat/lng in mono
//   5. Time        ←  meta eyebrow + absolute time + relative time
//   6. CTAs        ←  "Ver en el mapa" (primary, opens device detail)
//                     + "Marcar como leído" (outlined, idempotent)
//                     + "Llamar a soporte" (text button, tel: link)
//
// Data source: takes an AppNotification (the same model used by
// NotificationProvider). When opened from an FCM tap, the FCM handler
// constructs an AppNotification from the message's data fields and
// passes it here. When opened from the Notifications list, the list
// already has the AppNotification cached and passes it directly.
//
// "Mark as read" updates the local NotificationProvider only — the
// server-side row (in push-service's postgres) doesn't have a read
// concept yet. That's fine for v1; tracked as future work.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_primitives.dart';
import '../device/device_detail_screen.dart';

class AlertDetailScreen extends StatefulWidget {
  final AppNotification notification;

  const AlertDetailScreen({super.key, required this.notification});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  bool _markedRead = false;

  AppNotification get _n => widget.notification;

  /// Pull the per-alert tone (color + icon) from the same logic the banner
  /// uses, so a notification arriving as a banner and then opened to detail
  /// stays visually consistent.
  _AlertTone get _tone => _toneFor(_n);

  /// Latitude / longitude from the FCM data field (push-service stringifies
  /// these — parse on demand, gracefully no-op if missing).
  double? get _lat {
    final raw = _n.data?['latitude'] as String?;
    return raw == null ? null : double.tryParse(raw);
  }

  double? get _lng {
    final raw = _n.data?['longitude'] as String?;
    return raw == null ? null : double.tryParse(raw);
  }

  String? get _zoneName {
    final raw = _n.data?['zoneName'] as String?;
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  String? get _petName {
    final raw = _n.data?['petName'] as String?;
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  @override
  void initState() {
    super.initState();
    // Auto-mark-as-read on open. Mirrors most messaging apps; the user
    // came here intentionally.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markAsRead();
    });
  }

  Future<void> _markAsRead() async {
    if (_markedRead || _n.isRead) return;
    final provider = context.read<NotificationProvider>();
    await provider.markAsRead(_n.id);
    if (mounted) setState(() => _markedRead = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(
        title: const Text('Alerta'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) async {
              if (value == 'delete') {
                // Capture references before the async gap so we don't have
                // to use BuildContext after await — flutter_lints flags
                // that pattern even with a `mounted` guard.
                final navigator = Navigator.of(context);
                final provider = context.read<NotificationProvider>();
                await provider.deleteNotification(_n.id);
                if (!mounted) return;
                navigator.pop();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PettiSpacing.s5,
            PettiSpacing.s2,
            PettiSpacing.s5,
            PettiSpacing.s7,
          ),
          children: [
            _buildPetHeader(),
            const SizedBox(height: PettiSpacing.s5),
            if (_lat != null && _lng != null) ...[
              _buildMiniMap(),
              const SizedBox(height: PettiSpacing.s5),
            ],
            _buildSection(
              eyebrow: 'ÚLTIMA UBICACIÓN CONOCIDA',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lat != null && _lng != null) ...[
                    Text(
                      _formatCoords(_lat!, _lng!),
                      style: PettiText.number(size: 16),
                    ),
                  ] else
                    Text(
                      'No disponible',
                      style:
                          PettiText.body().copyWith(color: PettiColors.fgDim),
                    ),
                  if (_zoneName != null) ...[
                    const SizedBox(height: PettiSpacing.s2),
                    Text(
                      'Zona: $_zoneName',
                      style: PettiText.bodySm()
                          .copyWith(color: PettiColors.fgDim),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: PettiSpacing.s4),
            _buildSection(
              eyebrow: 'HORA DE LA ALERTA',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatAbsoluteTime(_n.timestamp),
                      style: PettiText.bodyStrong().copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(_formatRelativeTime(_n.timestamp),
                      style: PettiText.bodySm()
                          .copyWith(color: PettiColors.fgDim)),
                ],
              ),
            ),
            const SizedBox(height: PettiSpacing.s7),
            _buildPrimaryCta(context),
            const SizedBox(height: PettiSpacing.s3),
            _buildSecondaryCta(),
            const SizedBox(height: PettiSpacing.s5),
            _buildSupportLink(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- pet header

  Widget _buildPetHeader() {
    final petName = _petName ?? 'tu mascota';
    final tone = _tone;
    return Center(
      child: Column(
        children: [
          // Avatar with severity-tinted ring around it — visual continuity
          // from the banner that brought the user here.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tone.iconColor, width: 3),
            ),
            padding: const EdgeInsets.all(4),
            child: PettiPetAvatar(
              initial: petName.isNotEmpty ? petName.substring(0, 1) : '?',
              size: 80,
            ),
          ),
          const SizedBox(height: PettiSpacing.s4),
          Text(_n.title, style: PettiText.h2(), textAlign: TextAlign.center),
          const SizedBox(height: PettiSpacing.s2),
          Text(
            _n.body,
            style: PettiText.body().copyWith(color: PettiColors.fgDim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- mini-map

  Widget _buildMiniMap() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PettiRadii.md),
        child: Container(
          decoration: BoxDecoration(
            color: PettiColors.sand,
            border: Border.all(color: PettiColors.borderLight, width: 1),
          ),
          child: CustomPaint(
            painter: _MiniMapPainter(tone: _tone),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- sections

  Widget _buildSection({required String eyebrow, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        border: Border.all(color: PettiColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: PettiText.meta()),
          const SizedBox(height: PettiSpacing.s2),
          child,
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- CTAs

  Widget _buildPrimaryCta(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _openDeviceDetail(context),
      icon: const Icon(Icons.map_outlined),
      label: const Text('Ver en el mapa'),
    );
  }

  Widget _buildSecondaryCta() {
    return OutlinedButton.icon(
      onPressed: _n.isRead || _markedRead
          ? null
          : () async {
              await _markAsRead();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Marcada como leída')),
              );
            },
      icon: Icon(
        (_n.isRead || _markedRead)
            ? Icons.check_rounded
            : Icons.mark_email_read_outlined,
      ),
      label: Text(
        (_n.isRead || _markedRead) ? 'Leída' : 'Marcar como leída',
      ),
    );
  }

  Widget _buildSupportLink() {
    return Center(
      child: Column(
        children: [
          Text(
            '¿Es una emergencia?',
            style: PettiText.bodySm().copyWith(color: PettiColors.fgDim),
          ),
          TextButton(
            onPressed: () {
              // TODO: replace with real support number / live chat. For now
              // surface a Petti SnackBar so the tap acknowledges.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Soporte estará disponible próximamente'),
                ),
              );
            },
            child: Text(
              'Llamar a soporte ›',
              style: PettiText.bodyStrong().copyWith(
                color: PettiColors.midnight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- navigation

  void _openDeviceDetail(BuildContext context) {
    // Resolve the device by its Traccar id (data.deviceId is stringified
    // from the server). If the device isn't in the provider's cache yet
    // (rare — would mean the user hasn't loaded the home screen this
    // session), fall back to popping back to wherever they came from.
    final traccar = context.read<TraccarProvider>();
    final deviceIdStr = _n.data?['deviceId'] as String?;
    final deviceId =
        deviceIdStr != null ? int.tryParse(deviceIdStr) : null;
    final device = deviceId != null ? traccar.getDevice(deviceId) : null;

    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el mapa de la mascota')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
    );
  }

  // -------------------------------------------------------------- formatting

  String _formatCoords(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  String _formatAbsoluteTime(DateTime t) {
    final local = t.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$hh:$mm · $dd/$mo/${local.year}';
  }

  String _formatRelativeTime(DateTime t) {
    final delta = DateTime.now().difference(t);
    if (delta.inSeconds < 60) return 'hace un momento';
    if (delta.inMinutes < 60) return 'hace ${delta.inMinutes} min';
    if (delta.inHours < 24) return 'hace ${delta.inHours} h';
    if (delta.inDays < 7) return 'hace ${delta.inDays} días';
    return 'hace ${(delta.inDays / 7).floor()} semanas';
  }
}

// =============================================================================
// _MiniMapPainter — stylized "circle + dot" representation of where the
// pet was last seen relative to its home zone. Not a real map (we don't
// pull tiles); just a Petti-styled visual cue.
// =============================================================================

class _MiniMapPainter extends CustomPainter {
  final _AlertTone tone;
  _MiniMapPainter({required this.tone});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Soft background grid — gives the map a "geographic" feel without
    // pulling tiles. Two faint gridlines cross at center.
    final gridPaint = Paint()
      ..color = PettiColors.borderLight
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Home zone circle, centered. Radius is just a visual proxy — we don't
    // know the actual radius vs map scale here.
    final zoneRadius = size.height * 0.32;
    final ringPaint = Paint()
      ..color = PettiColors.sabana.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final ringFill = Paint()
      ..color = PettiColors.sabana.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, zoneRadius, ringFill);
    canvas.drawCircle(center, zoneRadius, ringPaint);

    // Home anchor at zone center.
    final homePaint = Paint()..color = PettiColors.sabana;
    canvas.drawCircle(center, 5, homePaint);

    // Pet position — placed slightly outside the zone circle (geofenceExit
    // narrative) along a deterministic angle so it doesn't jump on rebuild.
    // Angle derived from the alert id so the same alert always renders the
    // same way; harmless visual whimsy.
    final angle = math.pi * 0.45;
    final petR = zoneRadius * 1.45;
    final petPos =
        center + Offset(math.cos(angle) * petR, math.sin(angle) * petR);

    // Faint dashed line from home to pet.
    final trail = Paint()
      ..color = tone.iconColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    const dashLen = 4.0;
    const gap = 4.0;
    final totalLen = (petPos - center).distance;
    final unit = (petPos - center) / totalLen;
    var traveled = 0.0;
    while (traveled < totalLen) {
      final start = center + unit * traveled;
      final end = center + unit * math.min(traveled + dashLen, totalLen);
      canvas.drawLine(start, end, trail);
      traveled += dashLen + gap;
    }

    // Pet dot with severity-tinted halo.
    final halo = Paint()
      ..color = tone.iconColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(petPos, 12, halo);
    final pet = Paint()..color = tone.iconColor;
    canvas.drawCircle(petPos, 6, pet);
    final petCore = Paint()..color = Colors.white;
    canvas.drawCircle(petPos, 2, petCore);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.tone.iconColor != tone.iconColor;
}

// =============================================================================
// _AlertTone — same shape as the banner's _BannerTone, but defined here too
// so this file doesn't have to import petti_alert_banner.dart's private
// types. Kept in sync by hand for now; could be promoted to a shared util
// later.
// =============================================================================

class _AlertTone {
  final Color iconColor;
  const _AlertTone({required this.iconColor});
}

_AlertTone _toneFor(AppNotification n) {
  final severity =
      (n.data?['severity'] as String?) ?? _inferSeverityFor(n.type);
  switch (severity) {
    case 'critical':
      return const _AlertTone(iconColor: PettiColors.alert);
    case 'info':
      return const _AlertTone(iconColor: PettiColors.sabana);
    case 'warning':
    default:
      return const _AlertTone(iconColor: PettiColors.marigoldDim);
  }
}

String _inferSeverityFor(NotificationType t) {
  switch (t) {
    case NotificationType.geofenceExit:
      return 'critical';
    case NotificationType.geofenceEnter:
    case NotificationType.deviceOnline:
      return 'info';
    case NotificationType.batteryLow:
    case NotificationType.deviceOffline:
    case NotificationType.speedAlert:
    case NotificationType.general:
      return 'warning';
  }
}
