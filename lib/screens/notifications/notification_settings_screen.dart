// Notification settings — Petti restyle.
//
// Lots of switches grouped into sections. Functionality preserved exactly
// from the legacy version. Visual changes:
//   - Cloud background, Petti meta-style section eyebrows (same as
//     SettingsScreen for consistency)
//   - Each switch's icon panel uses the Petti tone (alert/warning/info)
//     matching what the FCMService banner / AlertDetail screen show, so
//     toggling an alert type here visually previews how it'll appear
//   - DND info banner uses Marigold-soft instead of amber-yellow
//   - Outlined icon variants throughout

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../utils/petti_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(title: const Text('Notificaciones')),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          final settings = provider.settings;

          return ListView(
            children: [
              _section('Tipos de alerta'),
              _switchTile(
                title: 'Llegada a Zona Segura',
                subtitle: 'Cuando tu mascota vuelve a una zona configurada',
                icon: Icons.home_outlined,
                tone: _info,
                value: settings.geofenceEnterEnabled,
                onChanged: (v) => _update(
                    settings.copyWith(geofenceEnterEnabled: v)),
              ),
              _switchTile(
                title: 'Salida de Zona Segura',
                subtitle: 'Cuando tu mascota sale de una zona configurada',
                icon: Icons.directions_run_rounded,
                tone: _critical,
                value: settings.geofenceExitEnabled,
                onChanged: (v) => _update(
                    settings.copyWith(geofenceExitEnabled: v)),
              ),
              _switchTile(
                title: 'Batería baja',
                subtitle: 'Cuando el collar tiene poca batería',
                icon: Icons.battery_2_bar_rounded,
                tone: _warning,
                value: settings.batteryLowEnabled,
                onChanged: (v) =>
                    _update(settings.copyWith(batteryLowEnabled: v)),
              ),
              _switchTile(
                title: 'Sin señal',
                subtitle: 'Cuando perdemos contacto con el collar',
                icon: Icons.signal_wifi_off_rounded,
                tone: _warning,
                value: settings.deviceOfflineEnabled,
                onChanged: (v) =>
                    _update(settings.copyWith(deviceOfflineEnabled: v)),
              ),
              _switchTile(
                title: 'Reconexión',
                subtitle: 'Cuando el collar vuelve a tener señal',
                icon: Icons.signal_wifi_4_bar_rounded,
                tone: _info,
                value: settings.deviceOnlineEnabled,
                onChanged: (v) =>
                    _update(settings.copyWith(deviceOnlineEnabled: v)),
              ),
              _switchTile(
                title: 'Velocidad inusual',
                subtitle: 'Si tu mascota se mueve más rápido de lo normal',
                icon: Icons.speed_rounded,
                tone: _warning,
                value: settings.speedAlertEnabled,
                onChanged: (v) =>
                    _update(settings.copyWith(speedAlertEnabled: v)),
              ),

              _section('Sonido y vibración'),
              _switchTile(
                title: 'Sonido',
                subtitle: 'Reproducir sonido al recibir alertas',
                icon: Icons.volume_up_outlined,
                tone: _neutral,
                value: settings.soundEnabled,
                onChanged: (v) =>
                    _update(settings.copyWith(soundEnabled: v)),
              ),
              _switchTile(
                title: 'Vibración',
                subtitle: 'Vibrar al recibir alertas',
                icon: Icons.vibration_outlined,
                tone: _neutral,
                value: settings.vibrationEnabled,
                onChanged: (v) =>
                    _update(settings.copyWith(vibrationEnabled: v)),
              ),

              _section('No molestar'),
              _switchTile(
                title: 'Modo no molestar',
                subtitle: settings.dndEnabled
                    ? 'Activo ${_formatDndSchedule(settings)}'
                    : 'Silenciar alertas en horario específico',
                icon: Icons.do_not_disturb_on_outlined,
                tone: _neutral,
                value: settings.dndEnabled,
                onChanged: (v) =>
                    _update(settings.copyWith(dndEnabled: v)),
              ),

              if (settings.dndEnabled) ...[
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Hora de inicio'),
                  subtitle: Text(
                    settings.dndStart != null
                        ? _formatTime(settings.dndStart!)
                        : 'No configurado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(
                    context,
                    settings.dndStart ?? const TimeOfDay(hour: 22, minute: 0),
                    (time) => _update(settings.copyWith(dndStart: time)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Hora de fin'),
                  subtitle: Text(
                    settings.dndEnd != null
                        ? _formatTime(settings.dndEnd!)
                        : 'No configurado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(
                    context,
                    settings.dndEnd ?? const TimeOfDay(hour: 7, minute: 0),
                    (time) => _update(settings.copyWith(dndEnd: time)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Días activos'),
                  subtitle: Text(_formatDndDays(settings.dndDays)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectDays(context, settings),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PettiSpacing.s4,
                    PettiSpacing.s2,
                    PettiSpacing.s4,
                    0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(PettiSpacing.s3),
                    decoration: BoxDecoration(
                      color: PettiColors.marigoldSoft,
                      borderRadius: BorderRadius.circular(PettiRadii.sm),
                      border: Border.all(
                        color: PettiColors.marigold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: PettiColors.marigoldDim, size: 20),
                        const SizedBox(width: PettiSpacing.s3),
                        Expanded(
                          child: Text(
                            'Las alertas críticas (salida de zona, batería crítica) seguirán llegando aunque esté activo.',
                            style: PettiText.bodySm()
                                .copyWith(color: PettiColors.midnight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: PettiSpacing.s7),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- builders

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s2,
      ),
      child: Text(label.toUpperCase(), style: PettiText.meta()),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required _SwitchTone tone,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(PettiRadii.sm),
        ),
        child: Icon(icon, color: tone.fg, size: 20),
      ),
      title: Text(title, style: PettiText.bodyStrong().copyWith(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: PettiText.bodySm().copyWith(color: PettiColors.fgDim),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: PettiColors.marigold,
    );
  }

  void _update(NotificationSettings newSettings) {
    Provider.of<NotificationProvider>(context, listen: false)
        .updateSettings(newSettings);
  }

  // ---------------------------------------------------------------- pickers

  Future<void> _selectTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onSelected,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (time != null) onSelected(time);
  }

  Future<void> _selectDays(
    BuildContext context,
    NotificationSettings settings,
  ) async {
    final selectedDays = Set<int>.from(settings.dndDays);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setInnerState) => AlertDialog(
          title: const Text('Días activos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final day in const [
                  (1, 'Lunes'),
                  (2, 'Martes'),
                  (3, 'Miércoles'),
                  (4, 'Jueves'),
                  (5, 'Viernes'),
                  (6, 'Sábado'),
                  (7, 'Domingo'),
                ])
                  CheckboxListTile(
                    title: Text(day.$2),
                    value: selectedDays.contains(day.$1),
                    activeColor: PettiColors.marigold,
                    onChanged: (v) => setInnerState(() {
                      if (v == true) {
                        selectedDays.add(day.$1);
                      } else {
                        selectedDays.remove(day.$1);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _update(settings.copyWith(dndDays: selectedDays));
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- format

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDndSchedule(NotificationSettings settings) {
    if (settings.dndStart == null || settings.dndEnd == null) return '';
    return '${_formatTime(settings.dndStart!)} – ${_formatTime(settings.dndEnd!)}';
  }

  String _formatDndDays(Set<int> days) {
    if (days.length == 7) return 'Todos los días';
    const names = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mié',
      4: 'Jue',
      5: 'Vie',
      6: 'Sáb',
      7: 'Dom',
    };
    final sorted = days.toList()..sort();
    return sorted.map((d) => names[d]).join(', ');
  }
}

// =============================================================================
// _SwitchTone — same severity-based palette the alert banner uses.
// =============================================================================

class _SwitchTone {
  final Color bg;
  final Color fg;
  const _SwitchTone({required this.bg, required this.fg});
}

const _critical = _SwitchTone(
  bg: Color(0x24D7362C), // alertSoft, slightly stronger
  fg: PettiColors.alert,
);

final _warning = _SwitchTone(
  bg: PettiColors.marigoldSoft,
  fg: PettiColors.marigoldDim,
);

final _info = _SwitchTone(
  bg: PettiColors.sabanaSoft,
  fg: PettiColors.sabana,
);

const _neutral = _SwitchTone(
  bg: Color(0x140E1B2C), // midnight @ 8%
  fg: PettiColors.midnight,
);
