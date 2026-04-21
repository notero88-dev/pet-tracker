import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/traccar_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../onboarding/qr_scanner_screen.dart';
import '../device/device_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeTraccar();
  }

  Future<void> _initializeTraccar() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;

    if (userId == null) return;

    try {
      // Get Traccar credentials from Firestore
      final firestoreService = FirestoreService();
      final userProfile = await firestoreService.getUserProfile(userId);
      
      if (userProfile != null && 
          userProfile['traccarEmail'] != null && 
          userProfile['traccarPassword'] != null) {
        // Connect to Traccar with stored credentials
        final success = await traccarProvider.connect(
          userProfile['traccarEmail'],
          userProfile['traccarPassword'],
        );
        
        if (success) {
          await traccarProvider.refreshDevices();
        }
      }
    } catch (e) {
      print('Error initializing Traccar: $e');
      // User hasn't provisioned a device yet, ignore error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetTrack'),
        actions: [
          // Notifications button
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final unreadCount = notificationProvider.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              final traccar = Provider.of<TraccarProvider>(context, listen: false);
              final device = traccar.devices.isNotEmpty ? traccar.devices.first : null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(device: device),
                ),
              );
            },
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: Consumer<TraccarProvider>(
        builder: (context, traccar, child) {
          if (traccar.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (traccar.devices.isEmpty) {
            return _buildEmptyState();
          }

          return _buildDeviceList(traccar);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToScanner,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Dispositivo'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.pets,
              size: 80,
              color: Color(0xFF2D6A4F),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Bienvenido a PetTrack!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Agrega tu primer dispositivo GPS para comenzar a rastrear a tu mascota',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear Dispositivo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(TraccarProvider traccar) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: traccar.devices.length,
      itemBuilder: (context, index) {
        final device = traccar.devices[index];
        final position = traccar.getLastPosition(device.traccarId!);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: device.isOnline
                  ? Colors.green
                  : Colors.grey,
              child: Icon(
                device.isOnline ? Icons.pets : Icons.pets_outlined,
                color: Colors.white,
              ),
            ),
            title: Text(device.name),
            subtitle: Text(
              position != null
                  ? 'Última ubicación: ${position.address ?? position.coordinatesText}'
                  : 'Sin ubicación',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  device.statusText,
                  style: TextStyle(
                    color: device.isOnline ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (position != null && position.batteryLevel != null)
                  Text(
                    '🔋 ${position.batteryLevel}%',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceDetailScreen(device: device),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);

    // Disconnect Traccar
    await traccarProvider.disconnect();

    // Sign out from Firebase
    await authProvider.signOut();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}
