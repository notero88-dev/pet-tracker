// Settings — Petti restyle.
//
// Section-grouped list of settings entries. Functionality unchanged from the
// legacy version; the visible swaps are:
//   - Cloud background instead of grey
//   - Section eyebrows use PettiText.meta() (uppercase, tight tracking) instead
//     of bold green headers
//   - Outlined icons throughout for consistency with rest of Petti
//   - Destructive button (Desvincular) uses PettiColors.alert, not Colors.red
//   - Sections separated by visual gap rather than full-width Divider — fits
//     the Petti card-stack feel
//
// Most ListTile + Dialog visuals come for free from PettiTheme.lightTheme.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/device.dart';
import '../../utils/petti_theme.dart';
import 'pet_profile_screen.dart';
import 'user_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  final Device? device;

  const SettingsScreen({super.key, this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          _section('Cuenta'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mi perfil'),
            subtitle: const Text('Editar nombre, foto y contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UserProfileScreen(),
              ),
            ),
          ),
          if (device != null)
            ListTile(
              leading: const Icon(Icons.pets_outlined),
              title: const Text('Perfil de mascota'),
              subtitle: const Text('Información de tu mascota'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetProfileScreen(device: device!),
                ),
              ),
            ),

          _section('Dispositivo'),
          if (device != null) ...[
            ListTile(
              leading: const Icon(Icons.gps_fixed_outlined),
              title: const Text('Mi dispositivo GPS'),
              subtitle: Text(device!.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDeviceInfo(context, device!),
            ),
            ListTile(
              leading: const Icon(Icons.link_off_outlined),
              title: const Text('Desvincular dispositivo'),
              subtitle: const Text('Remover dispositivo de tu cuenta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmUnlinkDevice(context, device!),
            ),
          ] else
            const ListTile(
              leading: Icon(Icons.gps_off_outlined),
              title: Text('Sin dispositivo'),
              subtitle: Text('Agrega un dispositivo GPS para comenzar'),
            ),

          _section('Preferencias'),
          ListTile(
            leading: const Icon(Icons.translate_outlined),
            title: const Text('Idioma'),
            subtitle: const Text('Español'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Solo español disponible en esta versión'),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.straighten_outlined),
            title: const Text('Unidades'),
            subtitle: const Text('Kilómetros, metros'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showUnitsDialog(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Modo oscuro'),
            subtitle: const Text('Tema oscuro para la aplicación'),
            value: false,
            onChanged: (_) => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Modo oscuro disponible próximamente'),
              ),
            ),
          ),

          _section('Soporte'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Centro de ayuda'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHelp(context),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contactar soporte'),
            subtitle: const Text('soporte@pettrack.co'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _contactSupport,
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('WhatsApp soporte'),
            subtitle: const Text('+57 300 123 4567'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _contactWhatsApp,
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Reportar un problema'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _reportBug(context),
          ),

          _section('Acerca de'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versión'),
            subtitle: Text('1.0.0 (Build 1)'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de privacidad'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl('https://pettrack.co/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Términos y condiciones'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl('https://pettrack.co/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Licencias de código abierto'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicenses(context),
          ),

          const SizedBox(height: PettiSpacing.s7),
        ],
      ),
    );
  }

  /// Petti section eyebrow — uppercase, tight tracking.
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

  // ---------------------------------------------------------------- dialogs

  void _showDeviceInfo(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Información del dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Nombre', device.name),
            const SizedBox(height: PettiSpacing.s3),
            _infoRow('IMEI', device.uniqueId),
            const SizedBox(height: PettiSpacing.s3),
            _infoRow('Estado', device.statusText),
            const SizedBox(height: PettiSpacing.s3),
            _infoRow(
              'Última actualización',
              device.lastUpdate != null
                  ? _formatDate(device.lastUpdate!)
                  : 'Nunca',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ',
            style: PettiText.bodyStrong().copyWith(fontSize: 14)),
        Expanded(
          child: Text(value,
              style: PettiText.body().copyWith(fontSize: 14)),
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
      return 'hace ${diff.inDays}d';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  void _confirmUnlinkDevice(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desvincular dispositivo'),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // TODO: implement device unlinking on the backend
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dispositivo desvinculado')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PettiColors.alert,
              foregroundColor: Colors.white,
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unidades de medida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Métrico (km, m)'),
              value: 'metric',
              groupValue: 'metric',
              activeColor: PettiColors.marigold,
              onChanged: (_) {},
            ),
            RadioListTile<String>(
              title: const Text('Imperial (mi, ft)'),
              value: 'imperial',
              groupValue: 'metric',
              activeColor: PettiColors.marigold,
              onChanged: (_) => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Solo sistema métrico disponible'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
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
        builder: (_) => Scaffold(
          backgroundColor: PettiColors.cloud,
          appBar: AppBar(title: const Text('Centro de ayuda')),
          body: ListView(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            children: const [
              _FaqItem(
                question: '¿Cómo configuro mi dispositivo GPS?',
                answer:
                    'Escanea el código QR en la parte trasera del dispositivo o ingresa el IMEI manualmente desde la pantalla de inicio.',
              ),
              _FaqItem(
                question: '¿Qué hago si no recibo señal GPS?',
                answer:
                    'Asegúrate de que el dispositivo esté al aire libre con vista clara al cielo. La primera señal puede tardar 2-5 minutos.',
              ),
              _FaqItem(
                question: '¿Cuántas zonas seguras puedo crear?',
                answer:
                    'Puedes crear hasta 3 zonas seguras por mascota en la versión actual.',
              ),
              _FaqItem(
                question: '¿Cómo cambio el intervalo de actualización?',
                answer:
                    'Desde la pantalla del mapa, abre los ajustes del dispositivo (⚙️) y selecciona el modo de rastreo: tiempo real, hogar o sueño profundo.',
              ),
              _FaqItem(
                question: '¿Qué hago si la batería está baja?',
                answer:
                    'Recarga el dispositivo usando el cable USB incluido. La carga completa toma aproximadamente 2 horas.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contactSupport() async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'soporte@pettrack.co',
      query: 'subject=Soporte PetTrack',
    );
    _openUrl(emailUri.toString());
  }

  Future<void> _contactWhatsApp() async {
    final whatsappUri = Uri.parse(
      'https://wa.me/573001234567?text=Hola, necesito ayuda con PetTrack',
    );
    _openUrl(whatsappUri.toString());
  }

  void _reportBug(BuildContext context) {
    final controller = TextEditingController();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: PettiColors.cloud,
          appBar: AppBar(title: const Text('Reportar problema')),
          body: Padding(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cuéntanos qué pasó',
                  style: PettiText.h3(),
                ),
                const SizedBox(height: PettiSpacing.s2),
                Text(
                  'Mientras más detalle nos des, más rápido podemos arreglarlo.',
                  style: PettiText.body().copyWith(color: PettiColors.fgDim),
                ),
                const SizedBox(height: PettiSpacing.s4),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Describe el problema en detalle…',
                  ),
                  maxLines: 8,
                ),
                const SizedBox(height: PettiSpacing.s5),
                Builder(builder: (innerCtx) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.pop(innerCtx);
                      ScaffoldMessenger.of(innerCtx).showSnackBar(
                        const SnackBar(
                          content: Text('Reporte enviado. Gracias.'),
                        ),
                      );
                    },
                    child: const Text('Enviar reporte'),
                  );
                }),
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

/// Petti FAQ row — collapsed-by-default expansion tile.
class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PettiSpacing.s2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        border: Border.all(color: PettiColors.borderLight, width: 1),
      ),
      child: Theme(
        // Disable the default underline divider on ExpansionTile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s4,
            vertical: PettiSpacing.s1,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            PettiSpacing.s4,
            0,
            PettiSpacing.s4,
            PettiSpacing.s4,
          ),
          title: Text(
            question,
            style: PettiText.bodyStrong().copyWith(fontSize: 15),
          ),
          iconColor: PettiColors.midnight,
          collapsedIconColor: PettiColors.fgDim,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: PettiText.body().copyWith(color: PettiColors.fgDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
