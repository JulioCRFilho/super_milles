import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';

class FloatingTextSystemComponent extends Component with HasGameRef {
  final WidgetRef ref;

  FloatingTextSystemComponent({required this.ref});

  @override
  void update(double dt) {
    super.update(dt);
    
    final texts = ref.read(floatingTextsProvider);
    final updated = texts
        .map((t) => t.updatePosition(dt))
        .where((t) => t.life > 0)
        .toList();
    
    ref.read(floatingTextsProvider.notifier).updateTexts(updated);
  }

  @override
  void render(Canvas canvas) {
    final texts = ref.read(floatingTextsProvider);
    
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
      textPainter.paint(canvas, Offset(text.x, text.y));
    }
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

