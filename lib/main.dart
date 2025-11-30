import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'presentation/game/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (optional - will work without it)
  try {
    await Firebase.initializeApp();
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
