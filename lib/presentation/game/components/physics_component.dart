import 'package:flame/components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/game_constants.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/particle.dart';
import '../../../domain/entities/floating_text.dart';
import '../../../domain/entities/equipment_slot.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/game_state.dart';
import '../../providers/game_providers.dart';
import '../../providers/input_provider.dart';
import '../game_world.dart';

class PhysicsComponent extends Component with HasGameRef {
  final WidgetRef ref;
  late final GameWorld gameWorld;
  int frame = 0;
  
  // Local player state to avoid provider updates during build
  Entity? _localPlayer;

  PhysicsComponent({required this.ref});

  @override
  void onMount() {
    super.onMount();
    gameWorld = parent! as GameWorld;
    _localPlayer = ref.read(playerProvider);
  }

  @override
  void update(double dt) {
    super.update(dt);
    frame++;

    final gameState = ref.read(gameStateProvider);
    if (gameState != GameState.playing) return;

    // Sync local player state from provider if needed
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }

    _updatePlayer(dt);
    _updateEnemies(dt);
    _updateCamera();
    _checkCollisions();
    _checkWinCondition();
  }

  void _updatePlayer(double dt) {
    final playerNotifier = ref.read(playerProvider.notifier);
    // Use local player state for calculations, fallback to provider if null
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }
    var player = _localPlayer!;
    final stats = ref.read(playerStatsProvider);
    final keys = ref.read(keysProvider) ?? {};

    // Horizontal movement
    if (keys['ArrowRight'] == true || keys['d'] == true) {
      player = player.copyWith(
        vx: (player.vx + 0.8 * dt * 60).clamp(-GameConstants.moveSpeed, GameConstants.moveSpeed),
        facing: 1,
      );
    }
    if (keys['ArrowLeft'] == true || keys['a'] == true) {
      player = player.copyWith(
        vx: (player.vx - 0.8 * dt * 60).clamp(-GameConstants.moveSpeed, GameConstants.moveSpeed),
        facing: -1,
      );
    }

    // Apply friction
    player = player.copyWith(vx: player.vx * GameConstants.friction);

    // Jump
    if ((keys['ArrowUp'] == true || keys[' '] == true || keys['w'] == true) &&
        player.vy == 0) {
      final bottomY = player.y + player.h;
      if (gameWorld.getTileAt(player.x + 4, bottomY + 2) == 1 ||
          gameWorld.getTileAt(player.x + player.w - 4, bottomY + 2) == 1) {
        var jumpForce = GameConstants.jumpForce;
        // Boots give small jump boost
        if (stats.equipment[EquipmentSlot.boots] != null) {
          jumpForce -= 1;
        }
        player = player.copyWith(vy: jumpForce);
      }
    }

    // Apply gravity
    player = player.copyWith(vy: player.vy + GameConstants.gravity * dt * 60);

    // X collision
    var newX = player.x + player.vx * dt * 60;
    if (gameWorld.getTileAt(newX, player.y) == 1 ||
        gameWorld.getTileAt(newX + player.w, player.y) == 1 ||
        gameWorld.getTileAt(newX, player.y + player.h - 2) == 1 ||
        gameWorld.getTileAt(newX + player.w, player.y + player.h - 2) == 1) {
      player = player.copyWith(vx: 0);
    } else {
      player = player.copyWith(x: newX);
    }

    // Y collision
    var newY = player.y + player.vy * dt * 60;
    if (player.vy > 0) {
      // Falling
      if (gameWorld.getTileAt(player.x + 4, newY + player.h) == 1 ||
          gameWorld.getTileAt(player.x + player.w - 4, newY + player.h) == 1) {
        newY = (newY / GameConstants.tileSize).floor() * GameConstants.tileSize +
            (GameConstants.tileSize - player.h);
        player = player.copyWith(y: newY, vy: 0);
      } else {
        player = player.copyWith(y: newY);
      }
    } else if (player.vy < 0) {
      // Jumping
      if (gameWorld.getTileAt(player.x + 4, newY) == 1 ||
          gameWorld.getTileAt(player.x + player.w - 4, newY) == 1) {
        newY = ((newY / GameConstants.tileSize).floor() + 1) * GameConstants.tileSize;
        player = player.copyWith(y: newY, vy: 0);
      } else {
        player = player.copyWith(y: newY);
      }
    }

    // Death pit
    if (player.y > GameConstants.levelHeight * GameConstants.tileSize + 100) {
      Future.microtask(() => _handlePlayerDeath());
      return;
    }

    // Update local state immediately
    _localPlayer = player;
    
    // Update provider immediately - use microtask to avoid build issues but keep it fast
    // This ensures the PlayerComponent can read the updated position
    Future.microtask(() {
      playerNotifier.update(player);
    });
  }

  void _updateEnemies(double dt) {
    final enemiesNotifier = ref.read(enemiesProvider.notifier);
    final enemies = ref.read(enemiesProvider);
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final updatedEnemies = <Entity>[];

    for (var enemy in enemies) {
      // Respawn check
      if (enemy.isDead) {
        if (enemy.respawnTime != null && currentTime > enemy.respawnTime!) {
          updatedEnemies.add(enemy.copyWith(
            isDead: false,
            isLooted: false,
            hp: enemy.maxHp,
            x: enemy.originalX ?? enemy.x,
            y: enemy.originalY ?? enemy.y,
            vx: GameConstants.enemySpeedBase * (frame % 2 == 0 ? 1 : -1),
            vy: 0,
          ));
        } else {
          // Dead enemy falls
          var newEnemy = enemy;
          if (gameWorld.getTileAt(enemy.x, enemy.y + enemy.h + 2) == 0) {
            newEnemy = newEnemy.copyWith(
              vy: newEnemy.vy + GameConstants.gravity * dt * 60,
            );
            newEnemy = newEnemy.copyWith(y: newEnemy.y + newEnemy.vy * dt * 60);
            if (gameWorld.getTileAt(newEnemy.x, newEnemy.y + newEnemy.h) == 1) {
              newEnemy = newEnemy.copyWith(
                y: (newEnemy.y / GameConstants.tileSize).floor() *
                        GameConstants.tileSize +
                    (GameConstants.tileSize - newEnemy.h),
                vy: 0,
              );
            }
          }
          updatedEnemies.add(newEnemy);
        }
        continue;
      }

      // Normal enemy behavior
      var newEnemy = enemy.copyWith(vy: enemy.vy + GameConstants.gravity * dt * 60);

      final targetSpeed = GameConstants.enemySpeedBase;
      final isGrounded = gameWorld.getTileAt(
              enemy.x + enemy.w / 2, enemy.y + enemy.h + 2) ==
          1;

      if (isGrounded) {
        final nextX = enemy.x + enemy.vx * dt * 60;
        final wallCheckY = enemy.y + enemy.h - 4;
        final wallTile = enemy.vx > 0
            ? gameWorld.getTileAt(nextX + enemy.w, wallCheckY)
            : gameWorld.getTileAt(nextX, wallCheckY);

        final pitCheckX = enemy.vx > 0 ? nextX + enemy.w : nextX;
        final pitDetected = gameWorld.getTileAt(pitCheckX, enemy.y + enemy.h + 2) == 0;

        if (wallTile == 1 || pitDetected) {
          newEnemy = newEnemy.copyWith(vx: -enemy.vx, facing: -enemy.facing);
        } else {
          newEnemy = newEnemy.copyWith(x: nextX);
        }
      }

      newEnemy = newEnemy.copyWith(y: newEnemy.y + newEnemy.vy * dt * 60);
      if (newEnemy.vy > 0) {
        if (gameWorld.getTileAt(newEnemy.x, newEnemy.y + newEnemy.h) == 1 ||
            gameWorld.getTileAt(newEnemy.x + newEnemy.w, newEnemy.y + newEnemy.h) == 1) {
          newEnemy = newEnemy.copyWith(
            y: (newEnemy.y / GameConstants.tileSize).floor() *
                    GameConstants.tileSize +
                (GameConstants.tileSize - newEnemy.h),
            vy: 0,
          );
        }
      }

      updatedEnemies.add(newEnemy);
    }

    // Update enemies - delay to avoid modifying provider during build
    Future.microtask(() => enemiesNotifier.setEnemies(updatedEnemies));
  }

  void _updateCamera() {
    // Use local player state for camera
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }
    final player = _localPlayer!;
    final canvasWidth = gameWorld.size.x;
    final mapWidthPixels = gameWorld.map[0].length * GameConstants.tileSize;

    final targetCamX = player.x - canvasWidth / 2 + player.w / 2;
    gameWorld.cameraX += (targetCamX - gameWorld.cameraX) * 0.1;
    gameWorld.cameraX = gameWorld.cameraX.clamp(0, mapWidthPixels - canvasWidth);
  }

  void _checkCollisions() {
    // Use local player state for collisions
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }
    final player = _localPlayer!;
    final enemies = ref.read(enemiesProvider);
    final stats = ref.read(playerStatsProvider);
    final enemiesNotifier = ref.read(enemiesProvider.notifier);
    final statsNotifier = ref.read(playerStatsProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);
    final particlesNotifier = ref.read(particlesProvider.notifier);
    final floatingTextsNotifier = ref.read(floatingTextsProvider.notifier);
    final stage = ref.read(stageProvider);

    final updatedEnemies = <Entity>[];

    for (var enemy in enemies) {
      if (_checkCollision(player, enemy) && !enemy.isDead) {
        final hitFromTop = player.vy > 0 && (player.y + player.h) < (enemy.y + enemy.h * 0.7);

        if (hitFromTop) {
          // Hit enemy from top
          final newHp = (enemy.hp ?? 1) - 1;
          var updatedEnemy = enemy.copyWith(hp: newHp);

          var updatedPlayer = player.copyWith(vy: -10); // Bounce

          if (newHp <= 0) {
            // Kill enemy
            updatedEnemy = updatedEnemy.copyWith(
              isDead: true,
              respawnTime: DateTime.now().millisecondsSinceEpoch + GameConstants.respawnTimeMs,
            );

            _spawnParticles(
                enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#8B4513', 12);

            final xpGain = (enemy.isBoss ? 200 : 15) + (stage * 2);
            final currentStats = ref.read(playerStatsProvider);
            Future.microtask(() => statsNotifier.addXp(xpGain));

            if (currentStats.xp + xpGain >= currentStats.maxXp) {
              _spawnParticles(player.x, player.y, '#FFD700', 40);
              Future.microtask(() => floatingTextsNotifier.addText(FloatingText(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                x: player.x,
                y: player.y - 20,
                text: 'NIVEL SUBIU!',
                life: 1.0,
                color: '#FFD700',
                vy: -2,
              )));
            } else {
              Future.microtask(() => floatingTextsNotifier.addText(FloatingText(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                x: player.x,
                y: player.y - 20,
                text: '+$xpGain XP',
                life: 1.0,
                color: '#FFFFFF',
                vy: -2,
              )));
            }
          } else {
            Future.microtask(() => floatingTextsNotifier.addText(FloatingText(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              x: enemy.x,
              y: enemy.y,
              text: 'POW!',
              life: 1.0,
              color: '#FFFFFF',
              vy: -2,
            )));

            final dir = (enemy.x + enemy.w / 2) > (player.x + player.w / 2) ? 1 : -1;
            updatedEnemy = updatedEnemy.copyWith(
              vx: dir * 8,
              vy: -4,
            );

            _spawnParticles(enemy.x + enemy.w / 2, enemy.y, '#FF0000', 5);
          }

          Future.microtask(() => playerNotifier.update(updatedPlayer));
          updatedEnemies.add(updatedEnemy);
          continue;
        } else {
          // Player hurt
          var updatedPlayer = player.copyWith(
            vy: -5,
            vx: player.x < enemy.x ? -8 : 8,
          );

          final defense = (stats.equipment[EquipmentSlot.helmet]?.statBoost ?? 0) +
              (stats.equipment[EquipmentSlot.armor]?.statBoost ?? 0) +
              (stats.equipment[EquipmentSlot.pants]?.statBoost ?? 0) +
              (stats.equipment[EquipmentSlot.accessory]?.statBoost ?? 0);

          final damage = ((enemy.isBoss ? 3 : 1) - (defense / 3).floor()).clamp(1, 999);
          final currentStats = ref.read(playerStatsProvider);
          Future.microtask(() => statsNotifier.takeDamage(damage));

          Future.microtask(() => floatingTextsNotifier.addText(FloatingText(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            x: player.x,
            y: player.y - 20,
            text: '-$damage HP',
            life: 1.0,
            color: '#FF0000',
            vy: -2,
          )));

          if (currentStats.hp - damage <= 0) {
            Future.microtask(() => _handlePlayerDeath());
            return;
          }

          Future.microtask(() => playerNotifier.update(updatedPlayer));
        }
      }

      updatedEnemies.add(enemy);
    }

    // Update enemies - delay to avoid modifying provider during build
    Future.microtask(() => enemiesNotifier.setEnemies(updatedEnemies));
  }

  void _checkWinCondition() {
    // Use local player state
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }
    final player = _localPlayer!;
    final flagpoleX = (gameWorld.map[0].length - 5) * GameConstants.tileSize;

    if (player.x >= flagpoleX) {
      Future.microtask(() {
        ref.read(gameStateProvider.notifier).state = GameState.levelComplete;
        Future.delayed(const Duration(seconds: 4), () {
          final stage = ref.read(stageProvider);
          ref.read(stageProvider.notifier).state = stage + 1;
          gameWorld.initializeLevel();
          ref.read(gameStateProvider.notifier).state = GameState.playing;
        });
      });
    }
  }

  void _handlePlayerDeath() {
    final statsNotifier = ref.read(playerStatsProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);
    final stats = ref.read(playerStatsProvider);

    if (stats.lives > 1) {
      Future.microtask(() {
        statsNotifier.loseLife();
        statsNotifier.heal(999); // Full heal
      });

      // Item loss penalty
      final currentStats = ref.read(playerStatsProvider);
      final slots = [
        EquipmentSlot.boots,
        EquipmentSlot.accessory,
        EquipmentSlot.helmet,
        EquipmentSlot.armor,
        EquipmentSlot.pants,
        EquipmentSlot.gloves,
      ];
      final equippedSlots = slots.where((s) => currentStats.equipment[s] != null).toList();

      if (equippedSlots.isNotEmpty) {
        final slotToLose = equippedSlots[DateTime.now().millisecondsSinceEpoch % equippedSlots.length];
        final lostItem = currentStats.equipment[slotToLose];
        final equipment = Map<EquipmentSlot, Equipment>.from(currentStats.equipment);
        equipment.remove(slotToLose);
        Future.microtask(() => statsNotifier.updateStats(currentStats.copyWith(equipment: equipment)));

        Future.microtask(() {
          Future.delayed(const Duration(milliseconds: 500), () {
            final player = ref.read(playerProvider);
            ref.read(floatingTextsProvider.notifier).addText(FloatingText(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              x: player.x,
              y: player.y - 40,
              text: 'PERDEU ${lostItem?.name}!',
              life: 1.0,
              color: '#FF0000',
              vy: -2,
            ));
          });
        });
      }

      Future.microtask(() {
        playerNotifier.reset();
        gameWorld.cameraX = 0;
      });
    } else {
      Future.microtask(() {
        statsNotifier.loseLife();
        ref.read(gameStateProvider.notifier).state = GameState.gameOver;
      });
    }
  }

  bool _checkCollision(Entity a, Entity b) {
    return a.x < b.x + b.w &&
        a.x + a.w > b.x &&
        a.y < b.y + b.h &&
        a.y + a.h > b.y;
  }

  void _spawnParticles(double x, double y, String color, int count) {
    final particlesNotifier = ref.read(particlesProvider.notifier);
    final random = DateTime.now().millisecondsSinceEpoch;

    Future.microtask(() {
      for (int i = 0; i < count; i++) {
        particlesNotifier.addParticle(Particle(
          id: '${x}_${y}_${i}_$random',
          x: x,
          y: y,
          w: 6,
          h: 6,
          vx: ((random + i) % 100 - 50) / 4.0,
          vy: ((random + i * 7) % 100 - 50) / 4.0,
          life: 1.0,
          color: color,
        ));
      }
    });
  }
}

