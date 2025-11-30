import 'package:flame/components.dart' hide ParticleSystemComponent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';

class GameParticleSystemComponent extends Component with HasGameRef {
  final WidgetRef ref;

  GameParticleSystemComponent({required this.ref});

  @override
  void update(double dt) {
    super.update(dt);
    
    final particles = ref.read(particlesProvider);
    final updated = particles
        .map((p) => p.updatePosition(dt))
        .where((p) => p.life > 0)
        .toList();
    
    ref.read(particlesProvider.notifier).updateParticles(updated);
  }

  @override
  void render(Canvas canvas) {
    final particles = ref.read(particlesProvider);
    
    for (final particle in particles) {
      final baseColor = _colorFromHex(particle.color);
      final paint = Paint()
        ..color = baseColor.withOpacity(particle.life);
      
      canvas.drawRect(
        Rect.fromLTWH(particle.x, particle.y, particle.w, particle.h),
        paint,
      );
    }
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

