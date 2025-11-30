import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/models/world_theme.dart';

class LevelComponent extends Component with HasGameRef {
  final WidgetRef ref;
  final List<List<int>> map;
  final WorldTheme theme;

  LevelComponent({required this.ref, required this.map, required this.theme});

  @override
  void render(Canvas canvas) {
    final cameraX = 0.0; // Get from game world
    
    final startCol = (cameraX / GameConstants.tileSize).floor();
    final endCol = startCol + (gameRef.size.x / GameConstants.tileSize).ceil() + 1;
    
    for (int y = 0; y < GameConstants.levelHeight; y++) {
      for (int x = startCol; x < endCol && x < map[0].length; x++) {
        final rawTile = map[y][x];
        
        if (rawTile > 0) {
          final px = x * GameConstants.tileSize - cameraX;
          final py = y * GameConstants.tileSize;
          
          if (rawTile == 1) {
            // Ground
            final groundGradient = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _colorFromHex(theme.ground),
                _colorFromHex(theme.groundDark),
              ],
            );
            
            final rect = Rect.fromLTWH(px, py, GameConstants.tileSize, GameConstants.tileSize);
            final paint = Paint()..shader = groundGradient.createShader(rect);
            canvas.drawRect(rect, paint);
            
            // Top grass
            if (y > 0 && map[y - 1][x] == 0) {
              canvas.drawRect(
                Rect.fromLTWH(px, py, GameConstants.tileSize, 8),
                Paint()..color = _colorFromHex(theme.grass),
              );
              canvas.drawRect(
                Rect.fromLTWH(px, py, GameConstants.tileSize, 4),
                Paint()..color = _colorFromHex(theme.grassHighlight),
              );
            }
          } else if (rawTile == 2) {
            // Brick
            canvas.drawRect(
              Rect.fromLTWH(px, py, GameConstants.tileSize, GameConstants.tileSize),
              Paint()..color = Colors.grey.shade800,
            );
            
            final brickPaint = Paint()..color = _colorFromHex(theme.brick);
            final gap = 2.0;
            final bw = (GameConstants.tileSize - gap * 3) / 2;
            final bh = (GameConstants.tileSize - gap * 3) / 2;
            
            canvas.drawRect(Rect.fromLTWH(px + gap, py + gap, bw, bh), brickPaint);
            canvas.drawRect(Rect.fromLTWH(px + gap + bw + gap, py + gap, bw, bh), brickPaint);
            canvas.drawRect(Rect.fromLTWH(px + gap, py + gap + bh + gap, bw, bh), brickPaint);
            canvas.drawRect(Rect.fromLTWH(px + gap + bw + gap, py + gap + bh + gap, bw, bh), brickPaint);
          }
        }
      }
    }
    
    // Flagpole
    final flagpoleX = (map[0].length - 5) * GameConstants.tileSize - cameraX;
    final flagpoleY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
    
    final poleGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.green.shade600, Colors.green.shade300, Colors.green.shade800],
    );
    
    final poleRect = Rect.fromLTWH(flagpoleX, flagpoleY - 200, 10, 200);
    final polePaint = Paint()..shader = poleGradient.createShader(poleRect);
    canvas.drawRect(poleRect, polePaint);
    
    // Flag
    final flagPath = Path()
      ..moveTo(flagpoleX + 10, flagpoleY - 200)
      ..lineTo(flagpoleX + 60, flagpoleY - 180)
      ..lineTo(flagpoleX + 10, flagpoleY - 160);
    canvas.drawPath(flagPath, Paint()..color = Colors.red);
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

