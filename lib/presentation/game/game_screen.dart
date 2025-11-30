import 'dart:html' as html show window;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'game_world.dart';
import '../hud/hud_widget.dart';
import '../loot/loot_modal.dart';
import '../menu/game_over_screen.dart';
import '../menu/level_complete_screen.dart';
import '../providers/game_providers.dart';
import '../providers/input_provider.dart';
import '../../domain/entities/game_state.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final FocusNode _focusNode = FocusNode();
  late final GameWorld _game;

  @override
  void initState() {
    super.initState();
    _game = GameWorld(ref: ref);
    
    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    
    // Setup global keyboard listeners for web (backup)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupWebKeyboardListeners();
      });
    }
  }

  void _setupWebKeyboardListeners() {
    // Use dart:html for direct keyboard event handling on web
    html.window.onKeyDown.listen((event) {
      final key = event.key;
      final keys = Map<String, bool>.from(ref.read(keysProvider) ?? {});
      
      // Map keyboard keys to our key names - SETAS DO TECLADO
      if (key == 'ArrowLeft') keys['ArrowLeft'] = true;
      if (key == 'ArrowRight') keys['ArrowRight'] = true;
      if (key == 'ArrowUp') keys['ArrowUp'] = true;
      if (key == 'ArrowDown') keys['ArrowDown'] = true;
      
      // WASD
      if (key == 'a' || key == 'A') {
        keys['ArrowLeft'] = true;
        keys['a'] = true;
      }
      if (key == 'd' || key == 'D') {
        keys['ArrowRight'] = true;
        keys['d'] = true;
      }
      if (key == 'w' || key == 'W') {
        keys['ArrowUp'] = true;
        keys['w'] = true;
      }
      if (key == 's' || key == 'S') {
        keys['ArrowDown'] = true;
        keys['s'] = true;
      }
      
      // Espaço para pular
      if (key == ' ') {
        keys['ArrowUp'] = true;
        keys[' '] = true;
      }
      
      // Outras teclas
      if (key == 'e' || key == 'E') keys['e'] = true;
      if (key == 'q' || key == 'Q') keys['q'] = true;
      
      // Update immediately - no delay
      ref.read(keysProvider.notifier).state = keys;
    });

    html.window.onKeyUp.listen((event) {
      final key = event.key;
      final keys = Map<String, bool>.from(ref.read(keysProvider) ?? {});
      
      // Map keyboard keys to our key names - SETAS DO TECLADO
      if (key == 'ArrowLeft') keys['ArrowLeft'] = false;
      if (key == 'ArrowRight') keys['ArrowRight'] = false;
      if (key == 'ArrowUp') keys['ArrowUp'] = false;
      if (key == 'ArrowDown') keys['ArrowDown'] = false;
      
      // WASD
      if (key == 'a' || key == 'A') {
        keys['ArrowLeft'] = false;
        keys['a'] = false;
      }
      if (key == 'd' || key == 'D') {
        keys['ArrowRight'] = false;
        keys['d'] = false;
      }
      if (key == 'w' || key == 'W') {
        keys['ArrowUp'] = false;
        keys['w'] = false;
      }
      if (key == 's' || key == 'S') {
        keys['ArrowDown'] = false;
        keys['s'] = false;
      }
      
      // Espaço para pular
      if (key == ' ') {
        keys['ArrowUp'] = false;
        keys[' '] = false;
      }
      
      // Outras teclas
      if (key == 'e' || key == 'E') keys['e'] = false;
      if (key == 'q' || key == 'Q') keys['q'] = false;
      
      // Update immediately - no delay
      ref.read(keysProvider.notifier).state = keys;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);

    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (RawKeyEvent event) {
          if (kIsWeb) {
            // Handle web keyboard events
            final keys = Map<String, bool>.from(ref.read(keysProvider) ?? {});
            final isPressed = event is RawKeyDownEvent;
            
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              keys['ArrowLeft'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              keys['ArrowRight'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              keys['ArrowUp'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              keys['ArrowDown'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
              keys['ArrowLeft'] = isPressed;
              keys['a'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
              keys['ArrowRight'] = isPressed;
              keys['d'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
              keys['ArrowUp'] = isPressed;
              keys['w'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              keys['ArrowUp'] = isPressed;
              keys[' '] = isPressed;
            }
            
            Future.microtask(() {
              ref.read(keysProvider.notifier).state = keys;
            });
          }
        },
        child: Stack(
          children: [
            // Game
            GameWidget(game: _game),

            // HUD
            const HUDWidget(),

            // Modals
            if (gameState == GameState.lootModal) const LootModal(),

            if (gameState == GameState.gameOver) const GameOverScreen(),

            if (gameState == GameState.levelComplete) const LevelCompleteScreen(),
          ],
        ),
      ),
    );
  }
}
