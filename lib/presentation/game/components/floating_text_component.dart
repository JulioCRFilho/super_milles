import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';
import '../../../domain/entities/floating_text.dart';
import '../game_world.dart';

class FloatingTextSystemComponent extends Component with HasGameReference {
  final WidgetRef ref;

  FloatingTextSystemComponent({required this.ref});

  List<FloatingText> _localTexts = [];
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Use local state to avoid provider updates during build
    if (_localTexts.isEmpty) {
      _localTexts = List<FloatingText>.from(ref.read(floatingTextsProvider));
    }
    
    _localTexts = _localTexts
        .map((t) => t.updatePosition(dt))
        .where((t) => t.life > 0)
        .toList();
    
        // Update provider only when list changes
        final currentTexts = ref.read(floatingTextsProvider);
        if (_localTexts.length != currentTexts.length || 
            _localTexts.isEmpty && currentTexts.isNotEmpty) {
      Future.microtask(() {
        ref.read(floatingTextsProvider.notifier).updateTexts(_localTexts);
      });
    }
  }

  @override
  void render(Canvas canvas) {
    // Use local texts for rendering
    final texts = _localTexts.isEmpty ? ref.read(floatingTextsProvider) : _localTexts;
    final gameWorld = parent! as GameWorld;
    final cameraX = gameWorld.cameraX;
    
    for (final text in texts) {
      final baseColor = _colorFromHex(text.color);
      final paint = Paint()
        ..color = baseColor.withOpacity(text.life);
      
      final textSpan = TextSpan(
        text: text.text,
        style: TextStyle(
          color: paint.color,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(text.x - cameraX, text.y));
    }
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

