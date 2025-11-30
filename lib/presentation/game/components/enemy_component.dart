import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game_world.dart';
import '../../providers/game_providers.dart';
import 'package:flutter/rendering.dart';
import '../../../domain/entities/entity.dart';

class EnemyComponent extends Component with HasGameReference<GameWorld> {
  final String enemyId;
  final WidgetRef ref;
  int frame = 0;

  EnemyComponent({required this.enemyId, required this.ref});

  @override
  void update(double dt) {
    super.update(dt);
    // Only increment frame if enemy is alive (dead enemies should not animate)
    final enemies = ref.read(enemiesProvider);
    final enemy = enemies.firstWhere(
      (e) => e.id == enemyId,
      orElse: () => enemies.isNotEmpty
          ? enemies.first
          : Entity(
              id: '',
              type: EntityType.enemy,
              x: 0,
              y: 0,
              w: 0,
              h: 0,
              vx: 0,
              vy: 0,
            ),
    );
    if (!enemy.isDead) {
      frame++;
    }
  }

  @override
  void render(Canvas canvas) {
    final enemies = ref.read(enemiesProvider);
    
    // Find the enemy with this ID
    Entity? enemy;
    try {
      enemy = enemies.firstWhere((e) => e.id == enemyId);
    } catch (e) {
      // Enemy not found - don't render
      return;
    }
    
    // Don't render if enemy has invalid dimensions
    if (enemy.w <= 0 || enemy.h <= 0) {
      return;
    }
    
    // Validate enemy position (should not be NaN or infinite)
    if (enemy.x.isNaN || enemy.y.isNaN || 
        enemy.x.isInfinite || enemy.y.isInfinite) {
      return;
    }
    
    final cameraX = game.cameraX;

    canvas.save();
    canvas.translate(enemy.x - cameraX + enemy.w / 2, enemy.y + enemy.h / 2);

    if (enemy.isDead) {
      // Render dead enemy flattened on ground
      // The enemy position (enemy.y + enemy.h) is already at ground level
      // We need to flatten it visually while keeping it on the ground
      
      // First, adjust the translation to account for the flattened height
      // When we scale Y to 0.2, the visual height becomes 0.2 * enemy.h
      // We want the bottom of the sprite to stay at the same position
      final flattenedHeight = enemy.h * 0.2;
      final heightDifference = enemy.h - flattenedHeight;
      
      // Translate up by half the height difference to keep bottom aligned
      canvas.translate(0, heightDifference * 0.5);
      canvas.scale(1, 0.2);
      
      // Apply slight transparency to show it's dead but still visible
      final layerPaint = Paint()..color = Colors.white.withOpacity(0.7);
      canvas.saveLayer(
        Rect.fromLTWH(-enemy.w / 2, -enemy.h / 2, enemy.w, enemy.h),
        layerPaint,
      );
      
      // Draw enemy sprite (no flip for dead enemies, always face right)
      // Use frame 0 for dead enemies to prevent animation
      canvas.scale(1.0, 1.0); // No flip for dead enemies
      _drawEnemySprite(canvas, enemy.w, enemy.h, enemy.variant, 0, enemy.isBoss);
      
      canvas.restore(); // Restore layer
      
      // Draw chest indicator (above the flattened body)
      final enemyLoot = ref.read(enemyLootProvider);
      final hasLoot = enemyLoot.containsKey(enemy.id);
      
      // Reset transformations for chest
      canvas.restore(); // Restore from previous save
      canvas.save();
      canvas.translate(enemy.x - cameraX + enemy.w / 2, enemy.y - 25);
      
      if (hasLoot && !enemy.isLooted) {
        // Draw closed chest (loot available and not yet collected)
        _drawChest(canvas, isOpen: false);
      } else if (enemy.isLooted && !hasLoot) {
        // Draw open chest (loot was collected - enemy is looted AND loot was removed from provider)
        // This means loot existed and was collected, not that enemy never had loot
        _drawChest(canvas, isOpen: true);
      }
      // If enemy.isLooted && hasLoot, don't show chest (shouldn't happen, but just in case)
      // If !enemy.isLooted && !hasLoot, don't show chest (enemy never had loot)
      
      canvas.restore();
      canvas.save();
      canvas.translate(enemy.x - cameraX + enemy.w / 2, enemy.y + enemy.h / 2);
      canvas.scale(1, 0.2);
      canvas.translate(0, enemy.h * 0.4);
    } else {
      // BOSS SCALE
      if (enemy.isBoss) {
        final bossPulse = 1.0 + math.sin(frame * 0.1) * 0.05;
        canvas.scale(bossPulse, bossPulse);
      }

      // Flip based on facing direction
      canvas.scale(enemy.facing.toDouble(), 1.0);

      // Draw enemy sprite based on variant
      _drawEnemySprite(canvas, enemy.w, enemy.h, enemy.variant, frame, enemy.isBoss);
    }

    canvas.restore();
  }

  void _drawEnemySprite(Canvas canvas, double w, double h, dynamic variant, int frame, bool isBoss) {
    if (isBoss) {
      _drawBossSprite(canvas, w, h, variant, frame);
    } else {
      switch (variant?.toString()) {
        case 'EnemyVariant.blob':
          _drawBlobSprite(canvas, w, h, frame);
          break;
        case 'EnemyVariant.crab':
          _drawCrabSprite(canvas, w, h, frame);
          break;
        case 'EnemyVariant.eye':
          _drawEyeSprite(canvas, w, h, frame);
          break;
        default:
          _drawBlobSprite(canvas, w, h, frame);
      }
    }
  }

  void _drawBlobSprite(Canvas canvas, double w, double h, int frame) {
    // BLOB (Default - Slime) - like original
    final squish = math.sin(frame * 0.2).abs() * 5;
    
    // Translucent Gel Body with gradient
    final slimeGradient = RadialGradient(
      colors: [
        const Color(0xFF2ECC71),
        const Color(0xFF145A32),
      ],
    );
    final slimeRect = Rect.fromLTWH(-w / 2 - squish / 2, -h / 2, w + squish, h);
    final slimePaint = Paint()..shader = slimeGradient.createShader(slimeRect);
    
    final blobPath = Path()
      ..moveTo(-w / 2 - squish / 2, h / 2)
      ..cubicTo(
        -w / 2 - squish, -h / 2 + squish,
        w / 2 + squish, -h / 2 + squish,
        w / 2 + squish / 2, h / 2,
      );
    canvas.drawPath(blobPath, slimePaint);
    
    // Shine
    final shinePath = Path()
      ..addOval(Rect.fromLTWH(-w / 2 + w * 0.2, -h / 2 + h * 0.2, w * 0.3, h * 0.2));
    canvas.drawPath(shinePath, Paint()..color = Colors.white.withOpacity(0.4));
    
    // Face (simple black dots)
    canvas.drawCircle(Offset(-w * 0.2, squish), 2, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(w * 0.2, squish), 2, Paint()..color = Colors.black);
  }

  void _drawCrabSprite(Canvas canvas, double w, double h, int frame) {
    // CRAB - like original
    final anim = math.sin(frame * 0.2);
    final crabWalk = anim * 3;
    
    // Legs (8 legs, animated)
    final legPaint = Paint()
      ..color = const Color(0xFFC0392B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final legPath = Path()
      ..moveTo(-w * 0.3, h * 0.15)
      ..lineTo(-w * 0.6, h * 0.3 + crabWalk)
      ..moveTo(-w * 0.25, h * 0.25)
      ..lineTo(-w * 0.45, h * 0.4 - crabWalk)
      ..moveTo(w * 0.3, h * 0.15)
      ..lineTo(w * 0.6, h * 0.3 - crabWalk)
      ..moveTo(w * 0.25, h * 0.25)
      ..lineTo(w * 0.45, h * 0.4 + crabWalk);
    canvas.drawPath(legPath, legPaint);
    
    // Shell (Gradient) - elliptical
    final shellGradient = RadialGradient(
      center: Alignment(-0.25, -0.5),
      radius: 0.8,
      colors: [
        const Color(0xFFE74C3C),
        const Color(0xFF7B241C),
      ],
    );
    final shellRect = Rect.fromLTWH(-w / 2, -h / 3, w, h * 0.67);
    final shellPaint = Paint()..shader = shellGradient.createShader(shellRect);
    canvas.drawOval(shellRect, shellPaint);
    
    // Claws
    final clawPaint = Paint()..color = const Color(0xFF922B21);
    canvas.drawCircle(Offset(-w * 0.5, -h * 0.15 + crabWalk), 6, clawPaint);
    canvas.drawCircle(Offset(w * 0.5, -h * 0.15 - crabWalk), 6, clawPaint);
    
    // Eyes
    canvas.drawCircle(Offset(-w * 0.25, -h * 0.33), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.25, -h * 0.33), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(-w * 0.25, -h * 0.33), 1.5, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(w * 0.25, -h * 0.33), 1.5, Paint()..color = Colors.black);
  }

  void _drawEyeSprite(Canvas canvas, double w, double h, int frame) {
    // EYE - like original
    final hover = math.sin(frame * 0.1) * 3;
    canvas.translate(0, hover);
    
    // Wings
    final wingPaint = Paint()..color = const Color(0xFF5B2C6F);
    final leftWingPath = Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, -h * 0.47 + hover)
      ..lineTo(w * 0.45, h * 0.31)
      ..close();
    canvas.drawPath(leftWingPath, wingPaint);
    
    final rightWingPath = Path()
      ..moveTo(-w * 0.25, 0)
      ..lineTo(-w * 0.75, -h * 0.47 + hover)
      ..lineTo(-w * 0.45, h * 0.31)
      ..close();
    canvas.drawPath(rightWingPath, wingPaint);
    
    // Eye Ball (Gradient)
    final eyeGradient = RadialGradient(
      colors: [
        const Color(0xFFF5EEF8),
        const Color(0xFFD2B4DE),
      ],
    );
    final eyeRect = Rect.fromLTWH(-w / 2 + 2, -h / 2 + 2, w - 4, h - 4);
    final eyePaint = Paint()..shader = eyeGradient.createShader(eyeRect);
    canvas.drawCircle(const Offset(0, 0), w / 2 - 2, eyePaint);
    
    // Iris (pulsating)
    final irisPulse = 1.0 + math.sin(frame * 0.5) * 0.1;
    canvas.drawCircle(const Offset(0, 0), (w / 4) * irisPulse, Paint()..color = const Color(0xFF8E44AD));
    canvas.drawCircle(const Offset(0, 0), (w / 8) * irisPulse, Paint()..color = Colors.black);
    
    // Veins
    final veinPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, 0), Offset(w * 0.25, h * 0.25), veinPaint);
    canvas.drawLine(const Offset(0, 0), Offset(-w * 0.25, h * 0.2), veinPaint);
  }

  void _drawBossSprite(Canvas canvas, double w, double h, dynamic variant, int frame) {
    // Larger, more menacing version - like original
    final baseColor = variant?.toString() == 'EnemyVariant.eye'
        ? const Color(0xFF8E44AD)
        : variant?.toString() == 'EnemyVariant.crab'
            ? const Color(0xFFE74C3C)
            : const Color(0xFF2ECC71);

    final bodyPaint = Paint()..color = baseColor;
    final eyePaint = Paint()..color = Colors.red;
    final pupilPaint = Paint()..color = Colors.black;
    final spikePaint = Paint()..color = Colors.grey.shade400;

    // Pulsating glow effect
    final currentGlowRadius = 10.0 + math.sin(frame * 0.05) * 5;
    for (int i = 3; i > 0; i--) {
      final glowLayerPaint = Paint()
        ..color = baseColor.withOpacity(0.2 / i)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentGlowRadius * i);
      canvas.drawOval(
        Rect.fromLTWH(-w / 2 - 5, -h / 2 - 5, w + 10, h + 10),
        glowLayerPaint,
      );
    }

    // Main body
    canvas.drawOval(
      Rect.fromLTWH(-w / 2, -h / 2, w, h),
      bodyPaint,
    );

    // Angry eyes
    canvas.drawCircle(Offset(-w * 0.25, -h * 0.2), 10, eyePaint);
    canvas.drawCircle(Offset(w * 0.25, -h * 0.2), 10, eyePaint);
    canvas.drawCircle(Offset(-w * 0.25, -h * 0.2), 5, pupilPaint);
    canvas.drawCircle(Offset(w * 0.25, -h * 0.2), 5, pupilPaint);
    // Angry eyebrows
    final eyebrowPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(-w * 0.3, -h * 0.3),
      Offset(-w * 0.1, -h * 0.25),
      eyebrowPaint,
    );
    canvas.drawLine(
      Offset(w * 0.3, -h * 0.3),
      Offset(w * 0.1, -h * 0.25),
      eyebrowPaint,
    );

    // Spikes/crown
    for (int i = 0; i < 5; i++) {
      final spikeX = -w / 2 + (i * w / 4);
      final spikePath = Path()
        ..moveTo(spikeX, -h / 2)
        ..lineTo(spikeX + w / 8, -h / 2 - 15)
        ..lineTo(spikeX + w / 4, -h / 2);
      canvas.drawPath(spikePath, spikePaint);
      canvas.drawPath(
        spikePath,
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawChest(Canvas canvas, {required bool isOpen}) {
    // Chest size
    const chestWidth = 24.0;
    const chestHeight = 18.0;
    
    // Chest base color (brown/wood)
    final baseColor = const Color(0xFF8B4513);
    final darkColor = const Color(0xFF654321);
    final lightColor = const Color(0xFFA0522D);
    final metalColor = const Color(0xFFC0C0C0);
    final glowColor = isOpen ? Colors.grey : Colors.yellow.withOpacity(0.6);
    
    // Draw glow effect for closed chest
    if (!isOpen) {
      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-chestWidth / 2 - 2, -chestHeight / 2 - 2, chestWidth + 4, chestHeight + 4),
          const Radius.circular(2),
        ),
        glowPaint,
      );
    }
    
    // Chest body (main box)
    final bodyGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightColor, baseColor, darkColor],
      stops: const [0.0, 0.5, 1.0],
    );
    final bodyRect = Rect.fromLTWH(-chestWidth / 2, -chestHeight / 2, chestWidth, chestHeight);
    final bodyPaint = Paint()..shader = bodyGradient.createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      bodyPaint,
    );
    
    // Metal bands/straps
    final bandPaint = Paint()..color = metalColor;
    // Horizontal bands
    canvas.drawRect(
      Rect.fromLTWH(-chestWidth / 2, -chestHeight / 2 + 4, chestWidth, 2),
      bandPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(-chestWidth / 2, chestHeight / 2 - 6, chestWidth, 2),
      bandPaint,
    );
    // Vertical bands
    canvas.drawRect(
      Rect.fromLTWH(-chestWidth / 2 + 4, -chestHeight / 2, 2, chestHeight),
      bandPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(chestWidth / 2 - 6, -chestHeight / 2, 2, chestHeight),
      bandPaint,
    );
    
    // Lock/keyhole
    final lockPaint = Paint()..color = darkColor;
    canvas.drawCircle(const Offset(0, 2), 3, lockPaint);
    canvas.drawCircle(const Offset(0, 2), 1.5, Paint()..color = Colors.black);
    
    if (isOpen) {
      // Draw open lid
      canvas.save();
      canvas.translate(0, -chestHeight / 2);
      canvas.rotate(-0.3); // Slightly open angle
      
      final lidGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [lightColor, baseColor],
      );
      final lidRect = Rect.fromLTWH(-chestWidth / 2, -4, chestWidth, 4);
      final lidPaint = Paint()..shader = lidGradient.createShader(lidRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lidRect, const Radius.circular(2)),
        lidPaint,
      );
      
      // Lid metal band
      canvas.drawRect(
        Rect.fromLTWH(-chestWidth / 2, -4, chestWidth, 1.5),
        bandPaint,
      );
      
      canvas.restore();
      
      // Draw empty chest interior (dark)
      final interiorPaint = Paint()..color = Colors.black.withOpacity(0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-chestWidth / 2 + 2, -chestHeight / 2 + 6, chestWidth - 4, chestHeight - 8),
          const Radius.circular(2),
        ),
        interiorPaint,
      );
    } else {
      // Draw closed lid (flat top)
      final lidGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [lightColor, baseColor],
      );
      final lidRect = Rect.fromLTWH(-chestWidth / 2, -chestHeight / 2, chestWidth, 3);
      final lidPaint = Paint()..shader = lidGradient.createShader(lidRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lidRect, const Radius.circular(2)),
        lidPaint,
      );
      
      // Lid metal band
      canvas.drawRect(
        Rect.fromLTWH(-chestWidth / 2, -chestHeight / 2, chestWidth, 1.5),
        bandPaint,
      );
    }
    
    // Shadow/highlight for depth
    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.3);
    canvas.drawRect(
      Rect.fromLTWH(-chestWidth / 2, chestHeight / 2 - 2, chestWidth, 2),
      shadowPaint,
    );
    
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.2);
    canvas.drawRect(
      Rect.fromLTWH(-chestWidth / 2 + 1, -chestHeight / 2 + 1, chestWidth - 2, 2),
      highlightPaint,
    );
  }
}
