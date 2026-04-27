import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
// Petti is the global theme as of 2026-04-27. The legacy `utils/theme.dart`
// is no longer imported; it can be deleted once we confirm no straggler
// screens reference AppTheme directly. See utils/petti_theme.dart for the
// rationale and full token list.
import 'utils/petti_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/traccar_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const PetTrackApp());
}

class PetTrackApp extends StatelessWidget {
  const PetTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TraccarProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..initialize()),
      ],
      child: MaterialApp(
        title: 'PetTrack',
        theme: PettiTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
