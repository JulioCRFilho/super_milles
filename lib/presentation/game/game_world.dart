import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
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
import 'components/physics_component.dart';
import 'components/input_component.dart';
import '../providers/game_providers.dart';
import '../../domain/entities/floating_text.dart';

class GameWorld extends FlameGame with HasGameReference {
  final WidgetRef ref;
  int currentStage = 1;
  WorldTheme? currentTheme;
  List<List<int>> map = [];
  double cameraX = 0;
  int _lastEnemySyncFrame = 0;

  GameWorld({required this.ref});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    initializeLevel();

    // Add physics and input systems
    add(PhysicsComponent(ref: ref));
    add(InputComponent(ref: ref));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Sync enemy components periodically to ensure all enemies are visible
    _lastEnemySyncFrame++;
    if (_lastEnemySyncFrame >= 60) { // Check every ~1 second at 60fps
      _lastEnemySyncFrame = 0;
      _syncEnemyComponents();
    }
  }

  void _syncEnemyComponents() {
    final enemies = ref.read(enemiesProvider);
    final existingEnemyIds = children
        .whereType<EnemyComponent>()
        .map((c) => c.enemyId)
        .toSet();
    
    // Add components for new enemies
    for (final enemy in enemies) {
      if (!existingEnemyIds.contains(enemy.id) && enemy.w > 0 && enemy.h > 0) {
        add(EnemyComponent(enemyId: enemy.id, ref: ref));
      }
    }
    
    // Remove components for enemies that no longer exist
    final currentEnemyIds = enemies.map((e) => e.id).toSet();
    for (final component in children.whereType<EnemyComponent>()) {
      if (!currentEnemyIds.contains(component.enemyId)) {
        remove(component);
      }
    }
  }

  void initializeLevel() {
    currentStage = ref.read(stageProvider);
    currentTheme = WorldThemes.getTheme(
      (currentStage / GameConstants.levelsPerWorld).ceil(),
    );

    // Collect components to remove first (avoid concurrent modification)
    final toRemove = <Component>[];
    toRemove.addAll(children.whereType<BackgroundComponent>());
    toRemove.addAll(children.whereType<LevelComponent>());
    toRemove.addAll(children.whereType<PlayerComponent>());
    toRemove.addAll(children.whereType<EnemyComponent>());
    toRemove.addAll(children.whereType<GameParticleSystemComponent>());
    toRemove.addAll(children.whereType<FloatingTextSystemComponent>());
    
    // Remove collected components
    for (final component in toRemove) {
      remove(component);
    }

    // Generate level map
    generateLevel();

    // Add components
    add(BackgroundComponent(ref: ref, theme: currentTheme!));
    add(LevelComponent(ref: ref, map: map, theme: currentTheme!));

    // Reset player
    ref.read(playerProvider.notifier).reset();
    
    // Ensure player is on ground after reset
    Future.microtask(() {
      final player = ref.read(playerProvider);
      final groundY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
      final correctPlayerY = groundY - GameConstants.playerHeight;
      if ((player.y - correctPlayerY).abs() > 1) {
        ref.read(playerProvider.notifier).update(
          player.copyWith(y: correctPlayerY, vy: 0),
        );
      }
    });

    // Add player
    add(PlayerComponent(ref: ref));

    // Add enemies - ensure all enemies have components
    final enemies = ref.read(enemiesProvider);
    final existingEnemyIds = children
        .whereType<EnemyComponent>()
        .map((c) => c.enemyId)
        .toSet();
    
    for (final enemy in enemies) {
      // Only add component if it doesn't already exist
      if (!existingEnemyIds.contains(enemy.id)) {
        add(EnemyComponent(enemyId: enemy.id, ref: ref));
      }
    }
    
    // Remove components for enemies that no longer exist
    final currentEnemyIds = enemies.map((e) => e.id).toSet();
    for (final component in children.whereType<EnemyComponent>()) {
      if (!currentEnemyIds.contains(component.enemyId)) {
        remove(component);
      }
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
    // enemyDensity: starts high (10), decreases as stage increases
    // This means more enemies early, fewer later (spacing increases)
    final enemyDensity = isBossLevel ? 0.0 : 10.0 - (subStage * 0.5);

    map = [];

    // Initialize empty air
    for (int y = 0; y < GameConstants.levelHeight; y++) {
      final row = List<int>.filled(levelWidth, 0);
      map.add(row);
    }

    // Safe path terrain generation
    int x = 0;
    bool justDidPit = false;
    final enemies = <Entity>[]; // Declare enemies list early

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
      final random = DateTime.now().millisecondsSinceEpoch + x;
      final makePit = !justDidPit && (random % 100) / 100 < pitFrequency;

      if (makePit) {
        // Create Pit
        final pitLength = 2 + (random % 2); // 2 or 3 tiles
        x += pitLength;
        justDidPit = true;
      } else {
        // Create Ground
        final minGround = justDidPit ? 4 : 1;
        final segmentLength = [
          minGround,
          1 + (random % 4),
        ].reduce((a, b) => a > b ? a : b);

        for (int i = 0; i < segmentLength; i++) {
          if (x >= levelWidth - 20) break;

          // Always maintain safe ground path
          map[GameConstants.levelHeight - 1][x] = 1;
          map[GameConstants.levelHeight - 2][x] = 1;

          // Features (Platforms / Walls / Floating Blocks) - Balanced frequency
          if (!justDidPit || i > 1) {
            final featureRoll = (random + i * 13) % 100 / 100.0;
            final localRandom = random + i * 17 + x * 23; // More variation
            
            // PLATFORM - Moderate frequency (10% chance)
            if (!isBossLevel && featureRoll > 0.90) {
              final h = 4 + (localRandom % 2); // 4-5 tiles high
              final py = GameConstants.levelHeight - h;
              final platformWidth = 1 + (localRandom % 3); // 1-3 tiles wide
              
              // Random X offset for more irregular placement
              final xOffset = (localRandom % 3) - 1; // -1, 0, or 1
              final platformX = (x + xOffset).clamp(20, levelWidth - 25);
              
              for (int px = 0; px < platformWidth && platformX + px < levelWidth - 20; px++) {
                if (platformX + px >= 20) {
                  map[py][platformX + px] = 1;
                }
              }
              
              // Spawn enemy on platform (20% chance)
              final platformEnemyRoll = ((localRandom) % 100) / 100.0;
              if (platformEnemyRoll > 0.8) {
                final platformTopY = py * GameConstants.tileSize;
                final enemyY = platformTopY - GameConstants.enemyHeight;
                
                enemies.add(
                  Entity(
                    id: 'enemy_platform_${platformX}_${random}',
                    type: EntityType.enemy,
                    x: platformX * GameConstants.tileSize,
                    y: enemyY,
                    originalX: platformX * GameConstants.tileSize,
                    originalY: enemyY,
                    w: GameConstants.enemyWidth,
                    h: GameConstants.enemyHeight,
                    vx: GameConstants.enemySpeedBase * ((localRandom % 2) == 0 ? 1 : -1),
                    vy: 0,
                    facing: (localRandom % 2) == 0 ? 1 : -1,
                    isDead: false,
                    isLooted: false,
                    variant: currentTheme!.enemyVariant,
                    hp: 1,
                    maxHp: 1,
                    isBoss: false,
                  ),
                );
              }
            }
            // FLOATING BLOCKS - Moderate frequency (5% chance)
            else if (!isBossLevel && featureRoll > 0.85 && featureRoll <= 0.90) {
              final blockHeight = 3 + (localRandom % 2); // 3-4 tiles high
              final blockY = GameConstants.levelHeight - blockHeight;
              
              // Random X offset
              final xOffset = (localRandom % 5) - 2; // -2 to 2
              final blockX = (x + xOffset).clamp(20, levelWidth - 25);
              
              // Only place if there's space above ground
              if (blockY > GameConstants.levelHeight - 5 && blockX >= 20) {
                map[blockY][blockX] = 2; // Brick block (single tile only)
              }
            }
            // PIPE / WALL - Rare (3% chance)
            else if (!isBossLevel && featureRoll > 0.82 && featureRoll <= 0.85) {
              final wallHeight = 2 + (localRandom % 2); // 2-3 tiles tall
              final xOffset = (localRandom % 3) - 1; // Random position
              final wallX = (x + xOffset).clamp(20, levelWidth - 25);
              
              if (wallX >= 20) {
                for (int wy = 0; wy < wallHeight; wy++) {
                  final wallY = GameConstants.levelHeight - 3 - wy;
                  if (wallY >= 0) {
                    map[wallY][wallX] = 2; // Brick block
                  }
                }
              }
            }
          }
          x++;
        }
        justDidPit = false;
      }
    }

    // Add additional random floating blocks and obstacles (post-processing)
    // Balanced distribution
    if (!isBossLevel) {
      final postRandom = DateTime.now().millisecondsSinceEpoch;
      final numRandomBlocks = (levelWidth * 0.05).floor(); // 5% of level width
      
      for (int b = 0; b < numRandomBlocks; b++) {
        // Random X position
        final randomX = 25 + (postRandom + b * 37) % (levelWidth - 55);
        final randomRoll = (postRandom + randomX * 41 + b * 19) % 100 / 100.0;
        
        // 70% chance to actually place a block
        if (randomRoll > 0.3) {
          final floatH = 3 + (postRandom + randomX + b) % 3; // 3-5 tiles high
          final floatY = GameConstants.levelHeight - floatH;
          
          // Only place if there's space and it doesn't block the main path
          if (floatY > 3 && floatY < GameConstants.levelHeight - 4) {
            // Check if ground is clear below (safe path)
            if (map[GameConstants.levelHeight - 2][randomX] == 1) {
              map[floatY][randomX] = 2; // Brick block (single tile only)
            }
          }
        }
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

    // --- Spawn Enemies (enemies list already declared above) ---
    // Use a consistent random seed for deterministic spawns
    final random = DateTime.now().millisecondsSinceEpoch + currentStage * 1000;

    if (isBossLevel) {
      // Add floating text for boss
      ref.read(floatingTextsProvider.notifier).addText(
        FloatingText(
          id: 'boss_text_$random',
          x: 100,
          y: 100,
          text: 'CHEFE CHEGOU!',
          life: 1.0,
          color: '#FF0000',
          vy: -2,
        ),
      );
      // Boss spawn
      final bossX = (levelWidth - 15) * GameConstants.tileSize;
      final groundY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
      final bossY = groundY - GameConstants.bossHeight; // Boss on ground
      final bossHp = 3 + worldNum;

      enemies.add(
        Entity(
                id: 'boss_$currentStage',
          type: EntityType.enemy,
          x: bossX,
          y: bossY,
          w: GameConstants.bossWidth,
          h: GameConstants.bossHeight,
          vx: -GameConstants.enemySpeedBase * 1.5,
          vy: 0,
          facing: -1,
          isBoss: true,
          hp: bossHp,
          maxHp: bossHp,
          variant: currentTheme!.enemyVariant,
          originalX: bossX,
          originalY: bossY,
        ),
      );
    } else {
      // --- Standard Enemies Spawn Pass ---
      // Find random valid spawn positions on the map
      final validSpawnPositions = <MapEntry<int, int>>[];
      
      // Collect all valid ground positions (where enemy can stand)
      for (int x = 20; x < levelWidth - 25; x++) {
        // Check if there's ground tile and space above for enemy to stand
        if (map[GameConstants.levelHeight - 2][x] == 1 &&
            map[GameConstants.levelHeight - 3][x] == 0) {
          validSpawnPositions.add(MapEntry(x, GameConstants.levelHeight - 3));
        }
        
        // Also check platforms for spawn positions
        for (int y = 0; y < GameConstants.levelHeight - 3; y++) {
          // Check if there's a platform tile and space above
          if (map[y][x] == 1 && y > 0 && map[y - 1][x] == 0) {
            validSpawnPositions.add(MapEntry(x, y));
          }
        }
      }
      
      // Calculate number of enemies to spawn based on density - Reduced
      final enemySpacing = [
        10, // Increased from 8 to 10 for more spacing
        enemyDensity.toInt(),
      ].reduce((a, b) => a > b ? a : b);
      final maxEnemies = (levelWidth / enemySpacing).floor().clamp(3, 20); // Reduced from 5-30 to 3-20
      final numEnemiesToSpawn = (maxEnemies * 0.5).floor(); // Reduced from 70% to 50% spawn rate
      
      // Shuffle and select random positions
      if (validSpawnPositions.isNotEmpty) {
        validSpawnPositions.shuffle(Random(random));
        final selectedPositions = validSpawnPositions.take(numEnemiesToSpawn.clamp(0, validSpawnPositions.length));
        
        for (final position in selectedPositions) {
          final spawnX = position.key;
          final spawnY = position.value;
          
          // Random direction for movement - ensure enemies always have velocity
          final direction = (random + spawnX) % 2 == 0 ? 1 : -1;
          // Use base speed directly, not multiplied by direction (direction is separate)
          final initialSpeed = GameConstants.enemySpeedBase * direction;
          
          // Position enemy on ground/platform
          final enemyY = spawnY * GameConstants.tileSize - GameConstants.enemyHeight;
          
          enemies.add(
            Entity(
              id: 'enemy_${spawnX}_${spawnY}_${random}',
              type: EntityType.enemy,
              x: spawnX * GameConstants.tileSize,
              y: enemyY,
              originalX: spawnX * GameConstants.tileSize,
              originalY: enemyY,
              w: GameConstants.enemyWidth,
              h: GameConstants.enemyHeight,
              vx: initialSpeed, // Ensure initial velocity is set
              vy: 0,
              facing: direction,
              isDead: false,
              isLooted: false,
              variant: currentTheme!.enemyVariant,
              hp: 1,
              maxHp: 1,
              isBoss: false,
            ),
          );
        }
      }
    }

    // Ensure all enemies are properly positioned on ground AND have movement velocity
    final correctedEnemies = enemies.map((enemy) {
      if (enemy.isDead) return enemy;
      
      var correctedEnemy = enemy;
      
      // Check if enemy is on ground
      final bottomY = enemy.y + enemy.h;
      final checkY = bottomY + 2;
      final tileX = (enemy.x / GameConstants.tileSize).floor();
      final tileY = (checkY / GameConstants.tileSize).floor();
      
      // If enemy is not on ground, correct position
      if (tileY < map.length && tileX < map[0].length && map[tileY][tileX] == 0) {
        // Find ground below
        for (int y = tileY; y < map.length; y++) {
          if (y < map.length && tileX < map[0].length && map[y][tileX] == 1) {
            final groundY = y * GameConstants.tileSize;
            final correctY = groundY - enemy.h;
            correctedEnemy = enemy.copyWith(y: correctY, vy: 0);
            break;
          }
        }
        // If no ground found, use default ground position
        if (correctedEnemy == enemy) {
          final groundY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
          final correctY = groundY - enemy.h;
          correctedEnemy = enemy.copyWith(y: correctY, vy: 0);
        }
      }
      
      // CRITICAL: Ensure enemy has movement velocity
      if (correctedEnemy.vx.abs() < 0.5) {
        final direction = correctedEnemy.facing != 0 
            ? (correctedEnemy.facing > 0 ? 1 : -1)
            : (enemy.id.hashCode % 2 == 0 ? 1 : -1);
        correctedEnemy = correctedEnemy.copyWith(
          vx: GameConstants.enemySpeedBase * direction,
          facing: direction,
        );
      }
      
      return correctedEnemy;
    }).toList();
    
    ref.read(enemiesProvider.notifier).setEnemies(correctedEnemies);
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
