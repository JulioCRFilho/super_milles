import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/world_theme.dart';
import '../game_world.dart';

class BackgroundComponent extends Component with HasGameReference<GameWorld> {
  final WidgetRef ref;
  final WorldTheme theme;

  BackgroundComponent({required this.ref, required this.theme});

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final cameraX = game.cameraX; // Access cameraX from GameWorld
    
    // Sky Gradient with multiple stops for depth
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _colorFromHex(theme.skyColors[0]),
        _colorFromHex(theme.skyColors[0]).withOpacity(0.8),
        _colorFromHex(theme.skyColors[1]),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
    
    // Clouds with parallax effect (slower than camera)
    final cloudOffset = (cameraX * 0.1) % (size.x * 2);
    for (int i = 0; i < 3; i++) {
      final cloudX = -cloudOffset + (i * size.x * 0.7);
      _drawCloud(canvas, cloudX, 60 + i * 40, 30 + i * 10);
    }
    
    // Sun or Moon with glow (fixed position)
    final isNight = theme.skyColors[0] == '#2c3e50';
    final orbColor = isNight ? Colors.white : Colors.yellow;
    final orbGlowColor = isNight ? Colors.white70 : Colors.orange;
    
    // Glow layers
    for (int i = 3; i > 0; i--) {
      final glowPaint = Paint()
        ..color = orbGlowColor.withOpacity(0.3 / i)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20.0 * i);
      canvas.drawCircle(
        Offset(size.x - 100, 80),
        40 + (i * 15),
        glowPaint,
      );
    }
    
    // Main orb
    final orbPaint = Paint()
      ..color = orbColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawCircle(
      Offset(size.x - 100, 80),
      40,
      orbPaint,
    );
    
    // Stars (night theme only) with parallax
    if (isNight) {
      for (int i = 0; i < 20; i++) {
        final starX = (cameraX * 0.05 + i * 50) % size.x;
        final starY = 30 + (i * 37) % (size.y * 0.4);
        final twinkle = (DateTime.now().millisecondsSinceEpoch + i * 1000) % 2000 < 1000 ? 1.0 : 0.5;
        canvas.drawCircle(
          Offset(starX, starY),
          1.5 * twinkle,
          Paint()..color = Colors.white.withOpacity(0.8 * twinkle),
        );
      }
    }
    
    // Far Hills (Parallax) - like original
    final hillColor = isNight 
        ? const Color(0xFF1A252F) 
        : const Color(0xFF27AE60).withOpacity(0.4);
    final hillPaint = Paint()..color = hillColor;
    
    for (int i = 0; i < 3; i++) {
      final hx = ((i * 600) - (cameraX * 0.2)) % (size.x + 600) - 300;
      final hillPath = Path()
        ..moveTo(hx, size.y)
        ..quadraticBezierTo(hx + 200, size.y - 300, hx + 400, size.y)
        ..close();
      canvas.drawPath(hillPath, hillPaint);
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double size) {
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.3);
    canvas.drawCircle(Offset(x, y), size, cloudPaint);
    canvas.drawCircle(Offset(x + size * 0.6, y), size * 0.8, cloudPaint);
    canvas.drawCircle(Offset(x + size * 1.2, y), size * 0.9, cloudPaint);
    canvas.drawCircle(Offset(x + size * 0.3, y - size * 0.3), size * 0.7, cloudPaint);
    canvas.drawCircle(Offset(x + size * 0.9, y - size * 0.3), size * 0.7, cloudPaint);
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

