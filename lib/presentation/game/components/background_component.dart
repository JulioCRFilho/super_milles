import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/world_theme.dart';

class BackgroundComponent extends Component with HasGameRef {
  final WidgetRef ref;
  final WorldTheme theme;

  BackgroundComponent({required this.ref, required this.theme});

  @override
  void render(Canvas canvas) {
    final size = gameRef.size;
    
    // Sky Gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _colorFromHex(theme.skyColors[0]),
        _colorFromHex(theme.skyColors[1]),
      ],
    );
    
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
    
    // Sun or Moon
    final isNight = theme.skyColors[0] == '#2c3e50';
    final orbColor = isNight ? Colors.white : Colors.yellow;
    
    final orbPaint = Paint()
      ..color = orbColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    
    canvas.drawCircle(
      Offset(size.x - 100, 80),
      40,
      orbPaint,
    );
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

