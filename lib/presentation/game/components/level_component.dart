import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/models/world_theme.dart';
import '../game_world.dart';

class LevelComponent extends Component with HasGameReference<GameWorld> {
  final WidgetRef ref;
  final List<List<int>> map;
  final WorldTheme theme;
  int frame = 0;

  LevelComponent({required this.ref, required this.map, required this.theme});

  @override
  void update(double dt) {
    super.update(dt);
    frame++;
  }

  @override
  void render(Canvas canvas) {
    final cameraX = game.cameraX;
    
    final startCol = (cameraX / GameConstants.tileSize).floor();
    final endCol = startCol + (game.size.x / GameConstants.tileSize).ceil() + 1;
    
    for (int y = 0; y < GameConstants.levelHeight; y++) {
      for (int x = startCol; x < endCol && x < map[0].length; x++) {
        final rawTile = map[y][x];
        
        if (rawTile > 0) {
          final px = x * GameConstants.tileSize - cameraX;
          final py = y * GameConstants.tileSize;
          
          if (rawTile == 1) {
            // Ground with enhanced details
            final groundGradient = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _colorFromHex(theme.ground),
                _colorFromHex(theme.ground).withOpacity(0.9),
                _colorFromHex(theme.groundDark),
              ],
              stops: const [0.0, 0.3, 1.0],
            );
            
            final rect = Rect.fromLTWH(px, py, GameConstants.tileSize, GameConstants.tileSize);
            final paint = Paint()..shader = groundGradient.createShader(rect);
            canvas.drawRect(rect, paint);
            
            // Ground texture/pattern
            if ((x + y) % 2 == 0) {
              canvas.drawRect(
                Rect.fromLTWH(px + 2, py + 2, GameConstants.tileSize - 4, GameConstants.tileSize - 4),
                Paint()..color = _colorFromHex(theme.groundDark).withOpacity(0.2),
              );
            }
            
            // Top grass with more detail
            if (y > 0 && map[y - 1][x] == 0) {
              // Grass base
              canvas.drawRect(
                Rect.fromLTWH(px, py, GameConstants.tileSize, 10),
                Paint()..color = _colorFromHex(theme.grass),
              );
              // Grass highlight
              canvas.drawRect(
                Rect.fromLTWH(px, py, GameConstants.tileSize, 5),
                Paint()..color = _colorFromHex(theme.grassHighlight),
              );
              // Individual grass blades
              for (int i = 0; i < 5; i++) {
                final bladeX = px + (i * GameConstants.tileSize / 5);
                final bladePath = Path()
                  ..moveTo(bladeX, py)
                  ..quadraticBezierTo(bladeX + 2, py - 3, bladeX + 1, py - 5)
                  ..quadraticBezierTo(bladeX, py - 3, bladeX, py);
                canvas.drawPath(
                  bladePath,
                  Paint()..color = _colorFromHex(theme.grassHighlight)..style = PaintingStyle.fill,
                );
              }
            }
            
            // Side shadows for depth
            if (x > 0 && map[y][x - 1] == 0) {
              canvas.drawRect(
                Rect.fromLTWH(px, py, 2, GameConstants.tileSize),
                Paint()..color = Colors.black.withOpacity(0.2),
              );
            }
            if (x < map[0].length - 1 && map[y][x + 1] == 0) {
              canvas.drawRect(
                Rect.fromLTWH(px + GameConstants.tileSize - 2, py, 2, GameConstants.tileSize),
                Paint()..color = Colors.black.withOpacity(0.2),
              );
            }
            } else if (rawTile == 2) {
              // Brick Block - like original
              // Mortar base
              canvas.drawRect(
                Rect.fromLTWH(px, py, GameConstants.tileSize, GameConstants.tileSize),
                Paint()..color = Colors.grey.shade700,
              );
              
              // Draw 4 bricks with gradient
              final gap = 2.0;
              final bw = (GameConstants.tileSize - gap * 3) / 2;
              final bh = (GameConstants.tileSize - gap * 3) / 2;
              
              // Helper to draw beveled brick
              void drawBrick(double bx, double by) {
                final bGradient = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _colorFromHex(theme.brick),
                    _colorFromHex(theme.brickDark),
                  ],
                );
                final bRect = Rect.fromLTWH(bx, by, bw, bh);
                final bPaint = Paint()..shader = bGradient.createShader(bRect);
                canvas.drawRect(bRect, bPaint);
                // Highlight
                final highlightPaint = Paint()..color = Colors.white.withOpacity(0.2);
                canvas.drawRect(Rect.fromLTWH(bx, by, bw, 2), highlightPaint);
                canvas.drawRect(Rect.fromLTWH(bx, by, 2, bh), highlightPaint);
              }

              drawBrick(px + gap, py + gap);
              drawBrick(px + gap + bw + gap, py + gap);
              drawBrick(px + gap, py + gap + bh + gap);
              drawBrick(px + gap + bw + gap, py + gap + bh + gap);
            }
        }
      }
    }
    
    // Flagpole (like original)
    final flagpoleX = (map[0].length - 5) * GameConstants.tileSize - cameraX;
    final flagpoleY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
    
    // Pole Gradient
    final poleGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        const Color(0xFF27AE60),
        const Color(0xFFA9DFBF),
        const Color(0xFF1E8449),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final poleRect = Rect.fromLTWH(flagpoleX, flagpoleY - 200, 10, 200);
    final polePaint = Paint()..shader = poleGradient.createShader(poleRect);
    canvas.drawRect(poleRect, polePaint);
    
    // Ball (top ornament with gradient)
    final ballGradient = RadialGradient(
      colors: [Colors.white, const Color(0xFFF1C40F)],
    );
    final ballRect = Rect.fromLTWH(flagpoleX - 3, flagpoleY - 218, 16, 16);
    final ballPaint = Paint()..shader = ballGradient.createShader(ballRect);
    canvas.drawCircle(Offset(flagpoleX + 5, flagpoleY - 210), 8, ballPaint);
    
    // Flag (Waving) - like original
    final wave = math.sin(frame * 0.1) * 5;
    final flagPath = Path()
      ..moveTo(flagpoleX + 10, flagpoleY - 200)
      ..lineTo(flagpoleX + 60, flagpoleY - 180 + wave)
      ..lineTo(flagpoleX + 10, flagpoleY - 160)
      ..close();
    
    canvas.drawPath(flagPath, Paint()..color = const Color(0xFFC0392B));
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

