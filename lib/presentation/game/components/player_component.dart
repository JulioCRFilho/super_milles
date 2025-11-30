import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/equipment_slot.dart';
import '../game_world.dart';

class PlayerComponent extends Component with HasGameReference<GameWorld> {
  final WidgetRef ref;
  int frame = 0;

  PlayerComponent({required this.ref});

  @override
  void update(double dt) {
    super.update(dt);
    frame++;
  }

  @override
  void render(Canvas canvas) {
    final player = ref.read(playerProvider);
    final cameraX = game.cameraX;

    if (player.x.isNaN || player.y.isNaN) return;

    canvas.save();
    canvas.translate(
      player.x - cameraX + player.w / 2,
      player.y + player.h / 2,
    );
    canvas.scale(player.facing.toDouble(), 1.0);

    _drawHero(canvas, player.w, player.h, frame);

    canvas.restore();
  }

  void _drawHero(Canvas canvas, double w, double h, int frame) {
    final stats = ref.read(playerStatsProvider);
    final player = ref.read(playerProvider);

    final isRun = player.vx.abs() > 0.5;
    final isJump = player.vy.abs() > 0.5;
    final cycle = (frame * 0.4) % (math.pi * 2);
    final legSwing = isRun ? math.sin(cycle) * 8 : 0;

    final equip = stats.equipment;

    // Helper to get color from item strength (bronze -> iron -> gold -> diamond)
    Color getGearColor(Equipment? item, Color defaultColor) {
      if (item == null) return defaultColor;
      final strength = item.statBoost;
      if (strength > 12) return const Color(0xFFB9F2FF); // Diamond
      if (strength > 8) return const Color(0xFFFFD700); // Gold
      if (strength > 5) return const Color(0xFFC0C0C0); // Iron
      if (strength > 2) return const Color(0xFFCD7F32); // Bronze
      return const Color(0xFF888888); // Stone/Leather
    }

    final pantsColor = getGearColor(
      equip[EquipmentSlot.pants],
      const Color(0xFF0044CC),
    );
    final shoeColor = getGearColor(
      equip[EquipmentSlot.boots],
      const Color(0xFFCC0000),
    );
    final shirtColor = getGearColor(
      equip[EquipmentSlot.armor],
      const Color(0xFFCC0000),
    );
    final gloveColor = getGearColor(
      equip[EquipmentSlot.gloves],
      const Color(0xFFF0F0F0),
    );
    final skinColor = const Color(0xFFFFCCAA);

    // Cape (Dynamic Flow)
    final capeSwing = isRun ? math.sin(frame * 0.2) * 5 : 0;
    final capeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFFFF3333), const Color(0xFF990000)],
    );

    final capePath = Path()
      ..moveTo(-6.0, -10.0)
      ..lineTo(-14.0 - capeSwing, 20.0) // Bottom left tip
      ..lineTo(-2.0 - capeSwing, 20.0) // Bottom right tip
      ..lineTo(6.0, -10.0);

    final capeRect = Rect.fromLTWH(
      -14.0 - capeSwing,
      -10.0,
      20.0 + capeSwing * 2,
      30.0,
    );
    final capePaint = Paint()..shader = capeGradient.createShader(capeRect);
    canvas.drawPath(capePath, capePaint);

    // Legs
    void drawLeg(bool isBack) {
      canvas.save();
      canvas.translate(0, 10);
      double rot = 0;
      if (isJump) {
        rot = isBack ? 0.5 : -0.5;
      } else {
        rot = isBack ? -legSwing * 0.05 : legSwing * 0.05;
      }
      if (!isBack && !isJump) canvas.translate(-legSwing.toDouble(), 0.0);
      if (isBack && !isJump) canvas.translate(legSwing.toDouble(), 0.0);

      canvas.rotate(rot);

      // Leg (pants)
      final legPaint = Paint()..color = pantsColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-5.0, 0.0, 9.0, 14.0),
          const Radius.circular(3),
        ),
        legPaint,
      );

      // Boot
      final bootGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [shoeColor, const Color(0xFF220000)],
      );
      final bootRect = Rect.fromLTWH(-6.0, 10.0, 12.0, 8.0);
      final bootPaint = Paint()..shader = bootGradient.createShader(bootRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bootRect, const Radius.circular(3)),
        bootPaint,
      );
      canvas.restore();
    }

    drawLeg(true); // Back leg
    drawLeg(false); // Front leg

    // Torso
    final torsoGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [shirtColor, Colors.black],
    );
    final torsoRect = Rect.fromLTWH(-7.0, -12.0, 14.0, 24.0);
    final torsoPaint = Paint()..shader = torsoGradient.createShader(torsoRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(4)),
      torsoPaint,
    );

    // Belt
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-7.0, 8.0, 14.0, 4.0),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2.0, 8.0, 4.0, 4.0),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFFFD700), // Buckle
    );

    // Arms
    void drawArm(bool isBack) {
      canvas.save();
      canvas.translate(0.0, -5.0);
      double rot = 0;
      if (isJump) {
        rot = math.pi * 0.8; // Hands up!
      } else if (isRun) {
        rot = isBack ? legSwing * 0.1 : -legSwing * 0.1;
      }
      canvas.rotate(rot);

      // Sleeve/Arm
      final armPaint = Paint()..color = shirtColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-3.0, 0.0, 6.0, 14.0),
          const Radius.circular(3),
        ),
        armPaint,
      );

      // Glove/Hand
      canvas.drawCircle(Offset(0, 14), 5, Paint()..color = gloveColor);
      canvas.restore();
    }

    drawArm(true);
    drawArm(false);

    // Head
    canvas.translate(0, -16);

    // Face
    final faceGradient = RadialGradient(
      colors: [skinColor, const Color(0xFFDCBBAA)],
    );
    final faceRect = Rect.fromLTWH(-10.0, -10.0, 20.0, 20.0);
    final facePaint = Paint()..shader = faceGradient.createShader(faceRect);
    canvas.drawCircle(const Offset(0.0, 0.0), 10.0, facePaint);

    // Face Details
    canvas.drawCircle(
      const Offset(8.0, 2.0),
      3.0,
      Paint()..color = skinColor,
    ); // Nose
    canvas.drawCircle(
      const Offset(4.0, -3.0),
      3.5,
      Paint()..color = Colors.white,
    ); // Eye white
    canvas.drawCircle(
      const Offset(5.0, -3.0),
      1.5,
      Paint()..color = const Color(0xFF00AAEE),
    ); // Iris

    // Hair or Helmet
    if (equip[EquipmentSlot.helmet] != null) {
      final helmColor = getGearColor(
        equip[EquipmentSlot.helmet],
        const Color(0xFFC0C0C0),
      );
      final helmGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, helmColor, const Color(0xFF333333)],
        stops: const [0.0, 0.5, 1.0],
      );

      final helmPath = Path()
        ..addArc(
          Rect.fromLTWH(-11.0, -13.0, 22.0, 22.0),
          math.pi,
          math.pi,
        ) // Dome
        ..lineTo(8.0, 8.0)
        ..lineTo(4.0, 2.0)
        ..lineTo(-4.0, 2.0)
        ..lineTo(-8.0, 8.0)
        ..close();

      final helmRect = Rect.fromLTWH(-11, -13, 22, 22);
      final helmPaint = Paint()..shader = helmGradient.createShader(helmRect);
      canvas.drawPath(helmPath, helmPaint);

      // Plume
      final plumePath = Path()
        ..moveTo(0.0, -13.0)
        ..quadraticBezierTo(8.0, -20.0, 10.0, -8.0)
        ..quadraticBezierTo(0.0, -13.0, 0.0, -13.0);
      canvas.drawPath(plumePath, Paint()..color = const Color(0xFFDD0000));
    } else {
      // Blonde Spiky Hair
      final hairPath = Path()
        ..addArc(
          Rect.fromLTWH(-10.0, -12.0, 20.0, 20.0),
          math.pi,
          math.pi,
        ) // Top skull
        ..moveTo(-10.0, -5.0)
        ..lineTo(-14.0, -10.0)
        ..lineTo(-6.0, -10.0)
        ..lineTo(-8.0, -18.0)
        ..lineTo(0.0, -12.0)
        ..lineTo(8.0, -18.0)
        ..lineTo(6.0, -10.0)
        ..lineTo(14.0, -10.0)
        ..lineTo(10.0, -5.0);
      canvas.drawPath(hairPath, Paint()..color = const Color(0xFFFBD000));
    }
  }
}
