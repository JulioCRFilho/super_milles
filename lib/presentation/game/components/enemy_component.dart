import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../domain/entities/entity.dart';
import '../../providers/game_providers.dart';

class EnemyComponent extends Component with HasGameRef {
  final WidgetRef ref;
  final Entity enemy;
  int frame = 0;

  EnemyComponent({required this.ref, required this.enemy});

  @override
  void update(double dt) {
    super.update(dt);
    frame++;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(enemy.x, enemy.y);
    
    if (enemy.isBoss) {
      final bossPulse = 1.0 + math.sin(frame * 0.1) * 0.05;
      canvas.scale(bossPulse, bossPulse);
    }
    
    if (enemy.isDead) {
      canvas.scale(1, 0.2);
      canvas.translate(0, 50);
    }
    
    // Draw enemy based on variant (simplified)
    final paint = Paint()..color = _getEnemyColor(enemy.variant);
    canvas.drawRect(
      Rect.fromLTWH(-enemy.w / 2, -enemy.h / 2, enemy.w, enemy.h),
      paint,
    );
    
    canvas.restore();
  }

  Color _getEnemyColor(dynamic variant) {
    // Simplified - would use actual variant colors
    return Colors.green;
  }
}

