import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/game_constants.dart';
import '../../core/constants/world_themes.dart';
import '../../core/models/world_theme.dart';
import '../../domain/entities/entity.dart';
import 'components/background_component.dart';
import 'components/level_component.dart';
import 'components/player_component.dart';
import 'components/enemy_component.dart';
import 'components/particle_component.dart' show GameParticleSystemComponent;
import 'components/floating_text_component.dart';
import '../providers/game_providers.dart';

class GameWorld extends FlameGame with HasGameRef {
  final WidgetRef ref;
  int currentStage = 1;
  WorldTheme? currentTheme;
  List<List<int>> map = [];
  double cameraX = 0;

  GameWorld({required this.ref});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    initializeLevel();
  }

  void initializeLevel() {
    currentStage = ref.read(stageProvider);
    currentTheme = WorldThemes.getTheme(
      (currentStage / GameConstants.levelsPerWorld).ceil(),
    );

    // Generate level map
    generateLevel();

    // Add components
    add(BackgroundComponent(ref: ref, theme: currentTheme!));
    add(LevelComponent(ref: ref, map: map, theme: currentTheme!));

    // Reset player
    ref.read(playerProvider.notifier).reset();

    // Add player
    add(PlayerComponent(ref: ref));

    // Add enemies
    final enemies = ref.read(enemiesProvider);
    for (final enemy in enemies) {
      add(EnemyComponent(ref: ref, enemy: enemy));
    }

    // Add particle system
    add(GameParticleSystemComponent(ref: ref));

    // Add floating text system
    add(FloatingTextSystemComponent(ref: ref));
  }

  void generateLevel() {
    final worldNum = (currentStage / GameConstants.levelsPerWorld).ceil();
    final subStage = ((currentStage - 1) % GameConstants.levelsPerWorld) + 1;
    final isBossLevel = subStage == GameConstants.levelsPerWorld;

    final levelWidth = isBossLevel
        ? 60
        : GameConstants.levelWidthBase + (subStage * 10);
    final pitFrequency = isBossLevel ? 0.0 : 0.1 + (subStage * 0.03);
    final enemyDensity = isBossLevel ? 0 : 10 - (subStage * 0.5);

    map = [];

    // Initialize empty air
    for (int y = 0; y < GameConstants.levelHeight; y++) {
      final row = List<int>.filled(levelWidth, 0);
      map.add(row);
    }

    // Safe path terrain generation
    int x = 0;
    bool justDidPit = false;

    while (x < levelWidth) {
      // Safe start zone
      if (x < 15) {
        map[GameConstants.levelHeight - 1][x] = 1;
        map[GameConstants.levelHeight - 2][x] = 1;
        x++;
        continue;
      }

      // Safe end zone
      if (x > levelWidth - 20) {
        map[GameConstants.levelHeight - 1][x] = 1;
        map[GameConstants.levelHeight - 2][x] = 1;
        x++;
        continue;
      }

      // Decision: Pit or Ground?
      final makePit =
          !justDidPit &&
          (DateTime.now().millisecondsSinceEpoch % 100) / 100 < pitFrequency;

      if (makePit) {
        final pitLength = 2 + (DateTime.now().millisecondsSinceEpoch % 2);
        x += pitLength;
        justDidPit = true;
      } else {
        final minGround = justDidPit ? 4 : 1;
        final segmentLength = [
          minGround,
          1 + (DateTime.now().millisecondsSinceEpoch % 4),
        ].reduce((a, b) => a > b ? a : b);

        for (int i = 0; i < segmentLength; i++) {
          if (x >= levelWidth - 20) break;

          map[GameConstants.levelHeight - 1][x] = 1;
          map[GameConstants.levelHeight - 2][x] = 1;

          // Features (Platforms / Walls)
          if (!justDidPit || i > 1) {
            final featureRoll =
                (DateTime.now().millisecondsSinceEpoch % 100) / 100;

            // PLATFORM
            if (!isBossLevel && featureRoll > 0.8) {
              final h = 4 + (DateTime.now().millisecondsSinceEpoch % 2);
              final py = GameConstants.levelHeight - h;
              map[py][x] = 1;

              if (x + 1 < levelWidth &&
                  (DateTime.now().millisecondsSinceEpoch % 2) == 0) {
                map[py][x + 1] = 1;
              }
            }
            // PIPE / WALL
            else if (!isBossLevel && featureRoll > 0.96) {
              map[GameConstants.levelHeight - 3][x] = 2;
              map[GameConstants.levelHeight - 4][x] = 2;
            }
          }
          x++;
        }
        justDidPit = false;
      }
    }

    // Walls at world edges
    for (int y = 0; y < GameConstants.levelHeight; y++) {
      map[y][0] = 1;
      map[y][levelWidth - 1] = 1;
    }

    // Flagpole Base
    final endX = levelWidth - 5;
    map[GameConstants.levelHeight - 3][endX] = 1;

    // Spawn enemies - this would be implemented in a separate method
    // For now, we'll set empty list and let the game logic handle spawning
    ref.read(enemiesProvider.notifier).setEnemies([]);
  }

  int getTileAt(double x, double y) {
    final mapY = (y / GameConstants.tileSize).floor();
    final mapX = (x / GameConstants.tileSize).floor();
    if (mapY < 0 || mapY >= map.length || mapX < 0 || mapX >= map[0].length) {
      return 0;
    }
    return map[mapY][mapX] > 0 ? 1 : 0;
  }

  int getRawTileAt(double x, double y) {
    final mapY = (y / GameConstants.tileSize).floor();
    final mapX = (x / GameConstants.tileSize).floor();
    if (mapY < 0 || mapY >= map.length || mapX < 0 || mapX >= map[0].length) {
      return 0;
    }
    return map[mapY][mapX];
  }
}
