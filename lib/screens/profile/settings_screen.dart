import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_profile_screen.dart';
import 'pet_profile_screen.dart';
import '../../models/device.dart';

/// Main settings screen
class SettingsScreen extends StatelessWidget {
  final Device? device;

  const SettingsScreen({super.key, this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader('Cuenta'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Mi Perfil'),
            subtitle: const Text('Editar nombre, foto y contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserProfileScreen(),
                ),
              );
            },
          ),

          if (device != null)
            ListTile(
              leading: const Icon(Icons.pets),
              title: const Text('Perfil de Mascota'),
              subtitle: const Text('Información de tu mascota'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PetProfileScreen(device: device!),
                  ),
                );
              },
            ),

          const Divider(),

          // Device section
          _buildSectionHeader('Dispositivo'),
          if (device != null) ...[
            ListTile(
              leading: const Icon(Icons.gps_fixed),
              title: const Text('Mi Dispositivo GPS'),
              subtitle: Text(device!.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDeviceInfo(context, device!),
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Desvincular Dispositivo'),
              subtitle: const Text('Remover dispositivo de tu cuenta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmUnlinkDevice(context, device!),
            ),
          ] else ...[
            const ListTile(
              leading: Icon(Icons.gps_off),
              title: Text('Sin Dispositivo'),
              subtitle: Text('Agrega un dispositivo GPS para comenzar'),
            ),
          ],

          const Divider(),

          // App preferences
          _buildSectionHeader('Preferencias'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Idioma'),
            subtitle: const Text('Español'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Solo español disponible en esta versión'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Unidades'),
            subtitle: const Text('Kilómetros, metros'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showUnitsDialog(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Modo Oscuro'),
            subtitle: const Text('Tema oscuro para la aplicación'),
            value: false,
            onChanged: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modo oscuro disponible próximamente'),
                ),
              );
            },
          ),

          const Divider(),

          // Support section
          _buildSectionHeader('Soporte'),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Centro de Ayuda'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHelp(context),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Contactar Soporte'),
            subtitle: const Text('soporte@pettrack.co'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _contactSupport(),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('WhatsApp Soporte'),
            subtitle: const Text('+57 300 1234567'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _contactWhatsApp(),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Reportar un Problema'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _reportBug(context),
          ),

          const Divider(),

          // About section
          _buildSectionHeader('Acerca de'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Versión'),
            subtitle: Text('1.0.0 (Build 1)'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Política de Privacidad'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl('https://pettrack.co/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Términos y Condiciones'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl('https://pettrack.co/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Licencias de Código Abierto'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicenses(context),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D6A4F),
        ),
      ),
    );
  }

  void _showDeviceInfo(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del Dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Nombre', device.name),
            const SizedBox(height: 12),
            _buildInfoRow('IMEI', device.uniqueId),
            const SizedBox(height: 12),
            _buildInfoRow('Estado', device.statusText),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Última actualización',
              device.lastUpdate != null
                  ? _formatDate(device.lastUpdate!)
                  : 'Nunca',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays < 1) {
      return 'Hoy ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d atrás';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _confirmUnlinkDevice(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular Dispositivo'),
        content: Text(
          '¿Estás seguro de desvincular "${device.name}"?\n\n'
          'Perderás acceso a:\n'
          '• Ubicación en tiempo real\n'
          '• Historial de posiciones\n'
          '• Zonas seguras\n'
          '• Notificaciones',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement device unlinking
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dispositivo desvinculado'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
  }

  void _showUnitsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unidades de Medida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Métrico (km, m)'),
              value: 'metric',
              groupValue: 'metric',
              onChanged: (value) {},
            ),
            RadioListTile<String>(
              title: const Text('Imperial (mi, ft)'),
              value: 'imperial',
              groupValue: 'metric',
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solo sistema métrico disponible'),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Centro de Ayuda')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFaqItem(
                '¿Cómo configuro mi dispositivo GPS?',
                'Escanea el código QR en la parte trasera del dispositivo o ingresa el IMEI manualmente desde la pantalla de inicio.',
              ),
              _buildFaqItem(
                '¿Qué hago si no recibo señal GPS?',
                'Asegúrate de que el dispositivo esté al aire libre con vista clara al cielo. La primera señal puede tardar 2-5 minutos.',
              ),
              _buildFaqItem(
                '¿Cuántas zonas seguras puedo crear?',
                'Puedes crear hasta 3 zonas seguras por mascota en la versión actual.',
              ),
              _buildFaqItem(
                '¿Cómo cambio el intervalo de actualización?',
                'Desde la pantalla del mapa, toca el botón de comandos (⚙️) y selecciona el intervalo deseado: LIVE (10s), Normal (5min) o Ahorro (30min).',
              ),
              _buildFaqItem(
                '¿Qué hago si la batería está baja?',
                'Recarga el dispositivo usando el cable USB incluido. La carga completa toma aproximadamente 2 horas.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(answer),
        ),
      ],
    );
  }

  Future<void> _contactSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'soporte@pettrack.co',
      query: 'subject=Soporte PetTrack',
    );
    _openUrl(emailUri.toString());
  }

  Future<void> _contactWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/573001234567?text=Hola, necesito ayuda con PetTrack',
    );
    _openUrl(whatsappUri.toString());
  }

  void _reportBug(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Reportar Problema')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Describe el problema que encontraste:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Describe el problema en detalle...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte enviado. Gracias!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Enviar Reporte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'PetTrack',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 PetTrack Colombia',
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
