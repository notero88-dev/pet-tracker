// Notifications history — Petti style.
//
// Lists every alert the app has received, grouped by day with friendly
// section headers (HOY, AYER, ESTA SEMANA, "15 ABR"). Tap a row to open
// AlertDetailScreen (same screen FCM taps go to). Swipe-left to delete.
//
// Visual hierarchy:
//   - Unread row    white surface + Marigold accent stripe on the left
//                   + bold title + small Marigold dot on the right
//   - Read row      slightly muted (Sand background) + normal title weight
//
// Icon tone matches the alert banner / detail screen so a single alert
// looks consistent everywhere it's surfaced.
//
// The screen reads from NotificationProvider (the same one the FCM
// service writes to), so the list updates in real time as new pushes
// arrive. No separate fetch needed.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
import '../../utils/petti_theme.dart';
import '../alerts/alert_detail_screen.dart';
import 'notification_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationType? _filterType;

  // ---------------------------------------------------------------- spanish
  // Localized day-of-week + month-of-year labels. Keeping them inline rather
  // than pulling a heavy intl dep just for these two arrays.
  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _monthsShort = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          PopupMenuButton<NotificationType?>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filtrar',
            onSelected: (type) => setState(() => _filterType = type),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Todas')),
              ...NotificationType.values.map(
                (type) => PopupMenuItem(
                  value: type,
                  child: Text(type.displayName),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(width: PettiSpacing.s2),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = _filterType == null
              ? provider.notifications
              : provider.getNotificationsByType(_filterType!);

          if (all.isEmpty) return _buildEmptyState();

          // Sort newest-first then group by calendar day.
          final sorted = [...all]
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final groups = _groupByDay(sorted);

          return Column(
            children: [
              if (provider.unreadCount > 0) _buildUnreadBanner(provider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    PettiSpacing.s4,
                    PettiSpacing.s4,
                    PettiSpacing.s4,
                    // Bottom padding leaves room for the floating "Limpiar
                    // todo" CTA so the last row isn't hidden behind it.
                    PettiSpacing.s8,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final group = groups[i];
                    return _buildGroup(group, provider);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.notifications.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _confirmClearAll(provider),
            backgroundColor: PettiColors.midnight,
            foregroundColor: PettiColors.cloud,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(
              'Limpiar todo',
              style: PettiText.bodyStrong()
                  .copyWith(color: PettiColors.cloud, fontSize: 14),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------- empty state

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PettiSpacing.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: PettiColors.sabanaSoft,
                borderRadius: BorderRadius.circular(PettiRadii.lg),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 56,
                color: PettiColors.sabana,
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),
            Text(
              _filterType == null
                  ? 'Todo tranquilo'
                  : 'Sin alertas en este filtro',
              style: PettiText.h2(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PettiSpacing.s2),
            Text(
              _filterType == null
                  ? 'Cuando algo importante pase con tu mascota,\nlo verás aquí.'
                  : 'Prueba con otro filtro o quítalo para ver todas las alertas.',
              style: PettiText.body().copyWith(color: PettiColors.fgDim),
              textAlign: TextAlign.center,
            ),
            if (_filterType != null) ...[
              const SizedBox(height: PettiSpacing.s5),
              OutlinedButton(
                onPressed: () => setState(() => _filterType = null),
                child: const Text('Ver todas'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ unread banner

  Widget _buildUnreadBanner(NotificationProvider provider) {
    return Container(
      width: double.infinity,
      color: PettiColors.marigoldSoft,
      padding: const EdgeInsets.symmetric(
        horizontal: PettiSpacing.s4,
        vertical: PettiSpacing.s3,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: PettiColors.marigold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: PettiSpacing.s2),
          Text(
            '${provider.unreadCount} sin leer',
            style: PettiText.bodyStrong().copyWith(fontSize: 14),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => provider.markAllAsRead(),
            child: Text(
              'Marcar todas',
              style: PettiText.bodyStrong().copyWith(
                color: PettiColors.midnight,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------- grouping by day

  /// Bucket notifications by calendar day. Order preserved within bucket.
  List<_DayGroup> _groupByDay(List<AppNotification> sorted) {
    final groups = <_DayGroup>[];
    DateTime? currentKey;
    List<AppNotification>? currentList;

    for (final n in sorted) {
      final t = n.timestamp.toLocal();
      final key = DateTime(t.year, t.month, t.day);
      if (currentKey != key) {
        currentKey = key;
        currentList = <AppNotification>[];
        groups.add(_DayGroup(day: key, items: currentList));
      }
      currentList!.add(n);
    }
    return groups;
  }

  Widget _buildGroup(_DayGroup group, NotificationProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PettiSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: PettiSpacing.s2,
              bottom: PettiSpacing.s3,
            ),
            child: Text(_dayLabel(group.day), style: PettiText.meta()),
          ),
          ...group.items.map((n) => _buildNotificationRow(n, provider)),
        ],
      ),
    );
  }

  /// Friendly day label: HOY / AYER / weekday for last week / "15 ABR" / "15 ABR 2025"
  String _dayLabel(DateTime day) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final delta = start.difference(day).inDays;
    if (delta == 0) return 'HOY';
    if (delta == 1) return 'AYER';
    if (delta < 7) {
      // weekday is 1..7, _weekdays is 0-indexed for monday
      return _weekdays[day.weekday - 1].toUpperCase();
    }
    final monthShort = _monthsShort[day.month - 1];
    if (day.year == today.year) {
      return '${day.day} $monthShort';
    }
    return '${day.day} $monthShort ${day.year}';
  }

  // -------------------------------------------------- row card

  Widget _buildNotificationRow(
    AppNotification n,
    NotificationProvider provider,
  ) {
    final tone = _toneFor(n);
    final isUnread = !n.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: PettiSpacing.s2),
      child: Dismissible(
        key: ValueKey(n.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: PettiSpacing.s5),
          decoration: BoxDecoration(
            color: PettiColors.alertSoft,
            borderRadius: BorderRadius.circular(PettiRadii.md),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: PettiColors.alert,
          ),
        ),
        onDismissed: (_) {
          provider.deleteNotification(n.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notificación eliminada')),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(PettiRadii.md),
            onTap: () => _openDetail(n, provider),
            child: Container(
              decoration: BoxDecoration(
                color: isUnread ? Colors.white : PettiColors.sand,
                borderRadius: BorderRadius.circular(PettiRadii.md),
                border: Border.all(
                  color: isUnread
                      ? PettiColors.borderLightStrong
                      : PettiColors.borderLight,
                  width: 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Marigold accent stripe on the left edge for unread —
                    // a quiet visual cue without resorting to a colored
                    // background that would compete with the icon panel.
                    if (isUnread)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: PettiColors.marigold,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(PettiRadii.md),
                            bottomLeft: Radius.circular(PettiRadii.md),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(PettiSpacing.s4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon panel with severity tint.
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: tone.iconBg,
                                borderRadius:
                                    BorderRadius.circular(PettiRadii.sm),
                              ),
                              child: Icon(
                                _iconFor(n.type),
                                color: tone.iconColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: PettiSpacing.s3),
                            // Title + body + meta row.
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: PettiText.bodyStrong()
                                              .copyWith(
                                            fontSize: 15,
                                            fontWeight: isUnread
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(
                                          width: PettiSpacing.s2),
                                      Text(
                                        _shortTime(n.timestamp),
                                        style: PettiText.bodySm().copyWith(
                                          color: PettiColors.fgDim,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n.body,
                                    style: PettiText.bodySm()
                                        .copyWith(color: PettiColors.fgDim),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: PettiSpacing.s2),
                                  // Type chip — reusing the Petti pill pattern.
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: PettiSpacing.s2,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tone.iconBg,
                                      borderRadius: BorderRadius.circular(
                                          PettiRadii.pill),
                                    ),
                                    child: Text(
                                      n.type.displayName.toUpperCase(),
                                      style: PettiText.meta().copyWith(
                                        color: tone.iconColor,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------- helpers

  /// Short time-of-day for the row's right-aligned label. We don't show
  /// the date — that's already in the section header.
  String _shortTime(DateTime t) {
    final local = t.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _openDetail(AppNotification n, NotificationProvider provider) {
    if (!n.isRead) provider.markAsRead(n.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(notification: n),
      ),
    );
  }

  void _confirmClearAll(NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpiar notificaciones'),
        content: const Text(
          '¿Eliminar todas las notificaciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificaciones eliminadas')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PettiColors.alert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _DayGroup — internal value object for date-grouping
// =============================================================================

class _DayGroup {
  final DateTime day;
  final List<AppNotification> items;
  _DayGroup({required this.day, required this.items});
}

// =============================================================================
// _Tone — same severity → color logic the banner / detail screen use, kept
// here too so this file is self-contained. The three files share a hand-
// maintained convention; if a fourth screen needs it, promote to a shared
// helper in widgets/petti/.
// =============================================================================

class _Tone {
  final Color iconBg;
  final Color iconColor;
  const _Tone({required this.iconBg, required this.iconColor});
}

_Tone _toneFor(AppNotification n) {
  final severity =
      (n.data?['severity'] as String?) ?? _inferSeverityFor(n.type);
  switch (severity) {
    case 'critical':
      return _Tone(
        iconBg: PettiColors.alert.withValues(alpha: 0.14),
        iconColor: PettiColors.alert,
      );
    case 'info':
      return _Tone(
        iconBg: PettiColors.sabana.withValues(alpha: 0.16),
        iconColor: PettiColors.sabana,
      );
    case 'warning':
    default:
      return _Tone(
        iconBg: PettiColors.marigold.withValues(alpha: 0.18),
        iconColor: PettiColors.marigoldDim,
      );
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

IconData _iconFor(NotificationType type) {
  switch (type) {
    case NotificationType.geofenceExit:
      return Icons.directions_run_rounded;
    case NotificationType.geofenceEnter:
      return Icons.home_rounded;
    case NotificationType.batteryLow:
      return Icons.battery_2_bar_rounded;
    case NotificationType.deviceOffline:
      return Icons.signal_wifi_off_rounded;
    case NotificationType.deviceOnline:
      return Icons.signal_wifi_4_bar_rounded;
    case NotificationType.speedAlert:
      return Icons.speed_rounded;
    case NotificationType.general:
      return Icons.notifications_rounded;
  }
}
