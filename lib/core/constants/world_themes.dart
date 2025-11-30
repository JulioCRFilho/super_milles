import '../models/world_theme.dart';
import '../../domain/entities/enemy_variant.dart';

class WorldThemes {
  static WorldTheme getTheme(int worldNum) {
    final normalizedWorld = ((worldNum - 1) % 3) + 1;
    return themes[normalizedWorld]!;
  }
  
  static final Map<int, WorldTheme> themes = {
    1: WorldTheme(
      name: "SLIME PLAINS",
      skyColors: ['#4facfe', '#00f2fe'],
      ground: '#e67e22',
      groundDark: '#d35400',
      grass: '#2ecc71',
      grassHighlight: '#a9dfbf',
      brick: '#cd6133',
      brickDark: '#a0400b',
      enemyVariant: EnemyVariant.blob,
    ),
    2: WorldTheme(
      name: "SCORCHED DESERT",
      skyColors: ['#f12711', '#f5af19'],
      ground: '#f1c40f',
      groundDark: '#d4ac0d',
      grass: '#f39c12',
      grassHighlight: '#f7dc6f',
      brick: '#ba4a00',
      brickDark: '#873600',
      enemyVariant: EnemyVariant.crab,
    ),
    3: WorldTheme(
      name: "WATCHER'S VALLEY",
      skyColors: ['#2c3e50', '#000000'],
      ground: '#7f8c8d',
      groundDark: '#2c3e50',
      grass: '#8e44ad',
      grassHighlight: '#9b59b6',
      brick: '#34495e',
      brickDark: '#2c3e50',
      enemyVariant: EnemyVariant.eye,
    ),
  };
}

