import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/input_provider.dart';

class InputComponent extends Component
    with HasGameReference, KeyboardHandler, TapCallbacks {
  final WidgetRef ref;

  InputComponent({required this.ref});

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Update keys immediately - store in local variable first
    final currentKeys = ref.read(keysProvider);
    final keys = Map<String, bool>.from(currentKeys);
    
    // Update key states based on event type - SETAS DO TECLADO
    if (event is KeyDownEvent) {
      // Setas
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) keys['ArrowLeft'] = true;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) keys['ArrowRight'] = true;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) keys['ArrowUp'] = true;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) keys['ArrowDown'] = true;
      
      // WASD
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        keys['ArrowLeft'] = true;
        keys['a'] = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyD) {
        keys['ArrowRight'] = true;
        keys['d'] = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        keys['ArrowUp'] = true;
        keys['w'] = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        keys['ArrowDown'] = true;
        keys['s'] = true;
      }
      
      // Espaço para pular
      if (event.logicalKey == LogicalKeyboardKey.space) {
        keys['ArrowUp'] = true;
        keys[' '] = true;
      }
      
      // Outras teclas
      if (event.logicalKey == LogicalKeyboardKey.keyE) keys['e'] = true;
      if (event.logicalKey == LogicalKeyboardKey.keyQ) keys['q'] = true;
    } else if (event is KeyUpEvent) {
      // Setas
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) keys['ArrowLeft'] = false;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) keys['ArrowRight'] = false;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) keys['ArrowUp'] = false;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) keys['ArrowDown'] = false;
      
      // WASD
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        keys['ArrowLeft'] = false;
        keys['a'] = false;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyD) {
        keys['ArrowRight'] = false;
        keys['d'] = false;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        keys['ArrowUp'] = false;
        keys['w'] = false;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        keys['ArrowDown'] = false;
        keys['s'] = false;
      }
      
      // Espaço para pular
      if (event.logicalKey == LogicalKeyboardKey.space) {
        keys['ArrowUp'] = false;
        keys[' '] = false;
      }
      
      // Outras teclas
      if (event.logicalKey == LogicalKeyboardKey.keyE) keys['e'] = false;
      if (event.logicalKey == LogicalKeyboardKey.keyQ) keys['q'] = false;
    }

    // Update provider - delay to avoid build issues
    Future(() {
      ref.read(keysProvider.notifier).state = keys;
    });
    return true;
  }

  @override
  bool onTapDown(TapDownEvent event) {
    // Handle touch input for mobile
    final keys = Map<String, bool>.from(ref.read(keysProvider));
    
    // Simple touch controls - tap right side to move right, left side to move left
    final screenWidth = game.size.x;
    if (event.localPosition.x > screenWidth / 2) {
      keys['ArrowRight'] = true;
    } else {
      keys['ArrowLeft'] = true;
    }
    
    ref.read(keysProvider.notifier).state = keys;
    return true;
  }

  @override
  bool onTapUp(TapUpEvent event) {
    final keys = Map<String, bool>.from(ref.read(keysProvider));
    keys['ArrowLeft'] = false;
    keys['ArrowRight'] = false;
    ref.read(keysProvider.notifier).state = keys;
    return true;
  }
}

