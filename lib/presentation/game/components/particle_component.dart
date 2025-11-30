import 'package:flame/components.dart' hide ParticleSystemComponent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';
import '../../../domain/entities/particle.dart';
import '../game_world.dart';

class GameParticleSystemComponent extends Component with HasGameReference {
  final WidgetRef ref;

  GameParticleSystemComponent({required this.ref});

  List<Particle> _localParticles = [];
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Use local state to avoid provider updates during build
    if (_localParticles.isEmpty) {
      _localParticles = List<Particle>.from(ref.read(particlesProvider));
    }
    
    _localParticles = _localParticles
        .map((p) => p.updatePosition(dt))
        .where((p) => p.life > 0)
        .toList();
    
    // Update provider only when list changes significantly
    final currentParticles = ref.read(particlesProvider);
    if (_localParticles.length != currentParticles.length || 
        _localParticles.length == 0 && currentParticles.isNotEmpty) {
      Future.microtask(() {
        ref.read(particlesProvider.notifier).updateParticles(_localParticles);
      });
    }
  }

  @override
  void render(Canvas canvas) {
    // Use local particles for rendering
    final particles = _localParticles.isEmpty ? ref.read(particlesProvider) : _localParticles;
    final gameWorld = parent! as GameWorld;
    final cameraX = gameWorld.cameraX;
    
    for (final particle in particles) {
      final baseColor = _colorFromHex(particle.color);
      final paint = Paint()
        ..color = baseColor.withOpacity(particle.life);
      
      canvas.drawRect(
        Rect.fromLTWH(particle.x - cameraX, particle.y, particle.w, particle.h),
        paint,
      );
    }
  }

  Color _colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

