import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';
import '../game_world.dart';

class PlayerComponent extends Component with HasGameRef {
  final WidgetRef ref;
  int frame = 0;

  PlayerComponent({required this.ref});

  @override
  void update(double dt) {
    super.update(dt);
    frame++;
    
    final player = ref.read(playerProvider);
    // Update player position based on physics
    // This would be handled by the game loop
  }

  @override
  void render(Canvas canvas) {
    // Read player state - this should be updated by PhysicsComponent
    final player = ref.read(playerProvider);
    final gameWorld = parent! as GameWorld;
    final cameraX = gameWorld.cameraX;
    
    // Ensure we have valid player data
    if (player.x.isNaN || player.y.isNaN) return;
    
    canvas.save();
    canvas.translate(player.x - cameraX, player.y);
    canvas.scale(player.facing.toDouble(), 1.0);
    
    // Draw player sprite (simplified - would use actual sprite rendering)
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(
      Rect.fromLTWH(-player.w / 2, -player.h / 2, player.w, player.h),
      paint,
    );
    
    canvas.restore();
  }
}

