import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../providers/traccar_provider.dart';
import '../utils/constants.dart';

/// Bottom sheet with device commands
class DeviceCommandsSheet extends StatelessWidget {
  final Device device;

  const DeviceCommandsSheet({
    super.key,
    required this.device,
  });

  static Future<void> show(BuildContext context, Device device) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeviceCommandsSheet(device: device),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D6A4F).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_remote,
                    color: Color(0xFF2D6A4F),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comandos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Controla tu dispositivo GPS',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Command: Request Position Now
            _buildCommandButton(
              context: context,
              icon: Icons.my_location,
              title: 'Ubicar Ahora',
              subtitle: 'Solicita la posición GPS actual',
              color: const Color(0xFF2D6A4F),
              onTap: () => _requestPositionNow(context),
            ),
            const SizedBox(height: 12),

            // Command: Live Mode
            _buildCommandButton(
              context: context,
              icon: Icons.play_circle,
              title: 'Modo LIVE (10 seg)',
              subtitle: 'Actualizaciones cada 10 segundos',
              color: Colors.red,
              onTap: () => _setLiveMode(context),
            ),
            const SizedBox(height: 12),

            // Command: Normal Mode
            _buildCommandButton(
              context: context,
              icon: Icons.timer,
              title: 'Modo Normal (5 min)',
              subtitle: 'Actualizaciones cada 5 minutos',
              color: Colors.blue,
              onTap: () => _setNormalMode(context),
            ),
            const SizedBox(height: 12),

            // Command: Battery Saver
            _buildCommandButton(
              context: context,
              icon: Icons.battery_saver,
              title: 'Modo Ahorro (30 min)',
              subtitle: 'Actualizaciones cada 30 minutos',
              color: Colors.orange,
              onTap: () => _setBatterySaverMode(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPositionNow(BuildContext context) async {
    Navigator.pop(context);
    
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Solicitando ubicación...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await traccar.requestPositionNow(device.traccarId!);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Comando enviado. La ubicación llegará en unos segundos.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setLiveMode(BuildContext context) async {
    await _setUpdateInterval(
      context,
      AppConstants.liveUpdateIntervalSeconds,
      'Modo LIVE activado (10 seg)',
    );
  }

  Future<void> _setNormalMode(BuildContext context) async {
    await _setUpdateInterval(
      context,
      AppConstants.normalUpdateIntervalSeconds,
      'Modo Normal activado (5 min)',
    );
  }

  Future<void> _setBatterySaverMode(BuildContext context) async {
    await _setUpdateInterval(
      context,
      1800, // 30 minutes
      'Modo Ahorro activado (30 min)',
    );
  }

  Future<void> _setUpdateInterval(
    BuildContext context,
    int seconds,
    String successMessage,
  ) async {
    Navigator.pop(context);

    final traccar = Provider.of<TraccarProvider>(context, listen: false);

    try {
      await traccar.setUpdateInterval(device.traccarId!, seconds);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $successMessage'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
