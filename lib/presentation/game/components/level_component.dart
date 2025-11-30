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
    final screenHeight = game.size.y;
    
    final startCol = (cameraX / GameConstants.tileSize).floor();
    final endCol = startCol + (game.size.x / GameConstants.tileSize).ceil() + 1;
    
    // Draw solid ground fill below the map to prevent "floating ground" effect
    // Make it look like a continuation of the ground
    final mapBottomY = GameConstants.levelHeight * GameConstants.tileSize;
    if (mapBottomY < screenHeight) {
      final groundDarkColor = _colorFromHex(theme.groundDark);
      
      // Draw ground blocks extending downward
      for (int x = startCol; x < endCol && x < map[0].length; x++) {
        final px = x * GameConstants.tileSize - cameraX;
        for (double y = mapBottomY; y < screenHeight; y += GameConstants.tileSize) {
          final blockRect = Rect.fromLTWH(px, y, GameConstants.tileSize, GameConstants.tileSize);
          
          // Ground gradient (same as regular ground blocks)
          final groundGradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              groundDarkColor,
              groundDarkColor.withOpacity(0.95),
              groundDarkColor.withOpacity(0.9),
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.0, 0.2, 0.6, 1.0],
          );
          final paint = Paint()..shader = groundGradient.createShader(blockRect);
          canvas.drawRect(blockRect, paint);
          
          // Top edge highlight
          canvas.drawRect(
            Rect.fromLTWH(px, y, GameConstants.tileSize, 2),
            Paint()..color = groundDarkColor.withOpacity(0.5),
          );
          
          // Left edge highlight
          canvas.drawRect(
            Rect.fromLTWH(px, y, 2, GameConstants.tileSize),
            Paint()..color = groundDarkColor.withOpacity(0.3),
          );
          
          // Right and bottom shadows
          canvas.drawRect(
            Rect.fromLTWH(px + GameConstants.tileSize - 2, y, 2, GameConstants.tileSize),
            Paint()..color = Colors.black.withOpacity(0.3),
          );
          canvas.drawRect(
            Rect.fromLTWH(px, y + GameConstants.tileSize - 2, GameConstants.tileSize, 2),
            Paint()..color = Colors.black.withOpacity(0.4),
          );
          
          // Texture pattern
          final tileY = (y / GameConstants.tileSize).floor();
          if ((x + tileY) % 3 == 0) {
            final dirtPath = Path()
              ..addOval(Rect.fromLTWH(
                px + 4 + (x * 3 % 8),
                y + 6 + (tileY * 5 % 8),
                10 + (x % 4),
                6 + (tileY % 3),
              ));
            canvas.drawPath(
              dirtPath,
              Paint()..color = Colors.black.withOpacity(0.2),
            );
          }
          
          // Grid lines
          if (x > startCol) {
            canvas.drawLine(
              Offset(px, y),
              Offset(px, y + GameConstants.tileSize),
              Paint()
                ..color = Colors.black.withOpacity(0.2)
                ..strokeWidth = 1,
            );
          }
          if (tileY > (mapBottomY / GameConstants.tileSize).floor()) {
            canvas.drawLine(
              Offset(px, y),
              Offset(px + GameConstants.tileSize, y),
              Paint()
                ..color = Colors.black.withOpacity(0.2)
                ..strokeWidth = 1,
            );
          }
        }
      }
    }
    
    for (int y = 0; y < GameConstants.levelHeight; y++) {
      for (int x = startCol; x < endCol && x < map[0].length; x++) {
        final rawTile = map[y][x];
        
        if (rawTile > 0) {
          final px = x * GameConstants.tileSize - cameraX;
          final py = y * GameConstants.tileSize;
          
          if (rawTile == 1) {
            // Ground block with realistic 3D appearance
            final groundColor = _colorFromHex(theme.ground);
            final groundDarkColor = _colorFromHex(theme.groundDark);
            
            // Main block with strong gradient for depth
            final groundGradient = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                groundColor,
                groundColor.withOpacity(0.98),
                groundDarkColor.withOpacity(0.95),
                groundDarkColor,
              ],
              stops: const [0.0, 0.15, 0.6, 1.0],
            );
            
            final rect = Rect.fromLTWH(px, py, GameConstants.tileSize, GameConstants.tileSize);
            final paint = Paint()..shader = groundGradient.createShader(rect);
            canvas.drawRect(rect, paint);
            
            // Top edge highlight (sunlight on top)
            canvas.drawRect(
              Rect.fromLTWH(px, py, GameConstants.tileSize, 3),
              Paint()..color = groundColor.withOpacity(0.6),
            );
            
            // Left edge highlight (subtle 3D effect)
            canvas.drawRect(
              Rect.fromLTWH(px, py, 2, GameConstants.tileSize),
              Paint()..color = groundColor.withOpacity(0.4),
            );
            
            // Right edge shadow (depth)
            canvas.drawRect(
              Rect.fromLTWH(px + GameConstants.tileSize - 2, py, 2, GameConstants.tileSize),
              Paint()..color = Colors.black.withOpacity(0.3),
            );
            
            // Bottom edge shadow (stronger depth)
            canvas.drawRect(
              Rect.fromLTWH(px, py + GameConstants.tileSize - 3, GameConstants.tileSize, 3),
              Paint()..color = Colors.black.withOpacity(0.4),
            );
            
            // Dirt/soil texture pattern
            final patternSeed = (x * 7 + y * 11) % 3;
            if (patternSeed == 0) {
              // Irregular dirt patches
              final dirtPath = Path()
                ..addOval(Rect.fromLTWH(
                  px + 4 + (x * 3 % 8),
                  py + 6 + (y * 5 % 8),
                  12 + (x % 4),
                  8 + (y % 3),
                ))
                ..addOval(Rect.fromLTWH(
                  px + 20 + (x * 7 % 6),
                  py + 18 + (y * 3 % 6),
                  10 + (x % 3),
                  6 + (y % 2),
                ));
              canvas.drawPath(
                dirtPath,
                Paint()..color = groundDarkColor.withOpacity(0.25),
              );
            }
            
            // Small pebbles/stones texture
            for (int i = 0; i < 4; i++) {
              final stoneX = px + ((x * 13 + i * 7) % (GameConstants.tileSize - 6).toInt()) + 3;
              final stoneY = py + ((y * 17 + i * 11) % (GameConstants.tileSize - 6).toInt()) + 3;
              final stoneSize = 1.5 + ((x + y + i) % 3) * 0.5;
              canvas.drawCircle(
                Offset(stoneX.toDouble(), stoneY.toDouble()),
                stoneSize,
                Paint()..color = groundDarkColor.withOpacity(0.4),
              );
            }
            
            // Grid lines between blocks (subtle)
            if (x > 0) {
              canvas.drawLine(
                Offset(px, py),
                Offset(px, py + GameConstants.tileSize),
                Paint()
                  ..color = Colors.black.withOpacity(0.15)
                  ..strokeWidth = 1,
              );
            }
            if (y > 0) {
              canvas.drawLine(
                Offset(px, py),
                Offset(px + GameConstants.tileSize, py),
                Paint()
                  ..color = Colors.black.withOpacity(0.15)
                  ..strokeWidth = 1,
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

