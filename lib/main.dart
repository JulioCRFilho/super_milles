import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'presentation/game/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (optional - will work without it)
  // Only initialize if FirebaseOptions are available
  // For web, Firebase needs to be configured via firebase_options.dart
  // For now, we'll skip Firebase initialization if not configured
  try {
    // Check if we're on web and Firebase is configured
    // If not configured, skip initialization
    if (kIsWeb) {
      // On web, Firebase needs explicit configuration
      // Skip for now if not configured
      debugPrint('Firebase initialization skipped on web (not configured)');
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    // Firebase not configured - continue without it
    debugPrint('Firebase initialization skipped: $e');
  }

  runApp(const ProviderScope(child: SuperMillesApp()));
}

class SuperMillesApp extends StatelessWidget {
  const SuperMillesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Milles',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
