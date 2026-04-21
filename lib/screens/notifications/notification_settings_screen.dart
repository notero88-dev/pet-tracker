import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';

/// Notification settings screen
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
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final settings = provider.settings;

          return ListView(
            children: [
              // Event Types Section
              _buildSectionHeader('Tipos de Notificaciones'),
              _buildSwitchTile(
                title: 'Entrada a Zona',
                subtitle: 'Cuando tu mascota entra a una zona segura',
                icon: Icons.home,
                iconColor: Colors.green,
                value: settings.geofenceEnterEnabled,
                onChanged: (value) {
                  _updateSettings(
                    settings.copyWith(geofenceEnterEnabled: value),
                  );
                },
              ),
              _buildSwitchTile(
                title: 'Salida de Zona',
                subtitle: 'Cuando tu mascota sale de una zona segura',
                icon: Icons.warning,
                iconColor: Colors.red,
                value: settings.geofenceExitEnabled,
                onChanged: (value) {
                  _updateSettings(
                    settings.copyWith(geofenceExitEnabled: value),
                  );
                },
              ),
              _buildSwitchTile(
                title: 'Batería Baja',
                subtitle: 'Cuando el dispositivo tiene batería baja',
                icon: Icons.battery_alert,
                iconColor: Colors.orange,
                value: settings.batteryLowEnabled,
                onChanged: (value) {
                  _updateSettings(
                    settings.copyWith(batteryLowEnabled: value),
                  );
                },
              ),
              _buildSwitchTile(
                title: 'Dispositivo Desconectado',
                subtitle: 'Cuando el GPS pierde conexión',
                icon: Icons.signal_wifi_off,
                iconColor: Colors.grey,
                value: settings.deviceOfflineEnabled,
                onChanged: (value) {
                  _updateSettings(
                    settings.copyWith(deviceOfflineEnabled: value),
                  );
                },
              ),
              _buildSwitchTile(
                title: 'Dispositivo Conectado',
                subtitle: 'Cuando el GPS se conecta',
                icon: Icons.wifi,
                iconColor: Colors.green,
                value: settings.deviceOnlineEnabled,
                onChanged: (value) {
                  _updateSettings(
                    settings.copyWith(deviceOnlineEnabled: value),
                  );
                },
              ),
              _buildSwitchTile(
                title: 'Alerta de Velocidad',
                subtitle: 'Cuando la mascota se mueve muy rápido',
                icon: Icons.speed,
                iconColor: Colors.orange,
                value: settings.speedAlertEnabled,
                onChanged: (value) {
                  _updateSettings(
                    settings.copyWith(speedAlertEnabled: value),
                  );
                },
              ),

              const Divider(height: 32),

              // Alert Preferences Section
              _buildSectionHeader('Preferencias de Alerta'),
              _buildSwitchTile(
                title: 'Sonido',
                subtitle: 'Reproducir sonido al recibir notificaciones',
                icon: Icons.volume_up,
                iconColor: Colors.blue,
                value: settings.soundEnabled,
                onChanged: (value) {
                  _updateSettings(settings.copyWith(soundEnabled: value));
                },
              ),
              _buildSwitchTile(
                title: 'Vibración',
                subtitle: 'Vibrar al recibir notificaciones',
                icon: Icons.vibration,
                iconColor: Colors.purple,
                value: settings.vibrationEnabled,
                onChanged: (value) {
                  _updateSettings(settings.copyWith(vibrationEnabled: value));
                },
              ),

              const Divider(height: 32),

              // Do Not Disturb Section
              _buildSectionHeader('No Molestar'),
              _buildSwitchTile(
                title: 'Modo No Molestar',
                subtitle: settings.dndEnabled
                    ? 'Activo ${_formatDndSchedule(settings)}'
                    : 'Silenciar notificaciones en horario específico',
                icon: Icons.do_not_disturb_on,
                iconColor: Colors.indigo,
                value: settings.dndEnabled,
                onChanged: (value) {
                  _updateSettings(settings.copyWith(dndEnabled: value));
                },
              ),

              if (settings.dndEnabled) ...[
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Hora de Inicio'),
                  subtitle: Text(
                    settings.dndStart != null
                        ? _formatTime(settings.dndStart!)
                        : 'No configurado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(
                    context,
                    'Hora de Inicio',
                    settings.dndStart ?? const TimeOfDay(hour: 22, minute: 0),
                    (time) {
                      _updateSettings(settings.copyWith(dndStart: time));
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Hora de Fin'),
                  subtitle: Text(
                    settings.dndEnd != null
                        ? _formatTime(settings.dndEnd!)
                        : 'No configurado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(
                    context,
                    'Hora de Fin',
                    settings.dndEnd ?? const TimeOfDay(hour: 7, minute: 0),
                    (time) {
                      _updateSettings(settings.copyWith(dndEnd: time));
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Días Activos'),
                  subtitle: Text(_formatDndDays(settings.dndDays)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectDays(context, settings),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Las alertas de alta prioridad (salida de zona, batería crítica) seguirán llegando.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  void _updateSettings(NotificationSettings newSettings) {
    Provider.of<NotificationProvider>(context, listen: false)
        .updateSettings(newSettings);
  }

  Future<void> _selectTime(
    BuildContext context,
    String title,
    TimeOfDay initialTime,
    ValueChanged<TimeOfDay> onSelected,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (time != null) {
      onSelected(time);
    }
  }

  Future<void> _selectDays(
    BuildContext context,
    NotificationSettings settings,
  ) async {
    final selectedDays = Set<int>.from(settings.dndDays);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Días Activos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final day in [
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
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedDays.add(day.$1);
                        } else {
                          selectedDays.remove(day.$1);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateSettings(settings.copyWith(dndDays: selectedDays));
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDndSchedule(NotificationSettings settings) {
    if (settings.dndStart == null || settings.dndEnd == null) {
      return '';
    }
    return '${_formatTime(settings.dndStart!)} - ${_formatTime(settings.dndEnd!)}';
  }

  String _formatDndDays(Set<int> days) {
    if (days.length == 7) {
      return 'Todos los días';
    }

    final dayNames = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mié',
      4: 'Jue',
      5: 'Vie',
      6: 'Sáb',
      7: 'Dom',
    };

    final sortedDays = days.toList()..sort();
    return sortedDays.map((d) => dayNames[d]).join(', ');
  }
}
