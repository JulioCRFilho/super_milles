import 'package:flame/components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/game_constants.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/particle.dart';
import '../../../domain/entities/floating_text.dart';
import '../../../domain/entities/equipment_slot.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/generated_loot_data.dart';
import '../../providers/game_providers.dart';
import '../../providers/input_provider.dart';
import '../game_world.dart';

class PhysicsComponent extends Component with HasGameReference<GameWorld> {
  final WidgetRef ref;
  int frame = 0;
  
  // Local player state to avoid provider updates during build
  Entity? _localPlayer;
  
  // Local enemies state to batch updates - initialize as empty list
  List<Entity> _localEnemies = [];

  PhysicsComponent({required this.ref});

  @override
  void onMount() {
    super.onMount();
    _localPlayer = ref.read(playerProvider);
    _localEnemies = ref.read(enemiesProvider);
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
      // Ensure player is on ground when first loaded
      final groundY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
      final correctY = groundY - _localPlayer!.h;
      if ((_localPlayer!.y - correctY).abs() > 1) {
        _localPlayer = _localPlayer!.copyWith(y: correctY, vy: 0);
      }
    }
    var player = _localPlayer!;
    final stats = ref.read(playerStatsProvider);
    final keys = ref.read(keysProvider);

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
      if (game.getTileAt(player.x + 4, bottomY + 2) == 1 ||
          game.getTileAt(player.x + player.w - 4, bottomY + 2) == 1) {
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
    if (game.getTileAt(newX, player.y) == 1 ||
        game.getTileAt(newX + player.w, player.y) == 1 ||
        game.getTileAt(newX, player.y + player.h - 2) == 1 ||
        game.getTileAt(newX + player.w, player.y + player.h - 2) == 1) {
      player = player.copyWith(vx: 0);
    } else {
      player = player.copyWith(x: newX);
    }

    // Y collision
    var newY = player.y + player.vy * dt * 60;
    if (player.vy > 0) {
      // Falling - check multiple points for better collision detection
      // Check slightly above the bottom to catch collision before entering tile
      final checkOffset = 1.0; // Check 1 pixel above to prevent sinking
      final bottomY = newY + player.h - checkOffset;
      final leftCheck = game.getTileAt(player.x + 4, bottomY) == 1;
      final rightCheck = game.getTileAt(player.x + player.w - 4, bottomY) == 1;
      final centerCheck = game.getTileAt(player.x + player.w / 2, bottomY) == 1;
      
      if (leftCheck || rightCheck || centerCheck) {
        // Snap to ground - find the top of the tile (not the bottom)
        // Get the tile Y coordinate and position player on top of it
        final checkTileY = (bottomY / GameConstants.tileSize).floor();
        final tileTopY = checkTileY * GameConstants.tileSize;
        newY = tileTopY - player.h;
        player = player.copyWith(y: newY, vy: 0);
      } else {
        player = player.copyWith(y: newY);
      }
    } else if (player.vy < 0) {
      // Jumping
      final leftCheck = game.getTileAt(player.x + 4, newY) == 1;
      final rightCheck = game.getTileAt(player.x + player.w - 4, newY) == 1;
      final centerCheck = game.getTileAt(player.x + player.w / 2, newY) == 1;
      
      if (leftCheck || rightCheck || centerCheck) {
        newY = ((newY / GameConstants.tileSize).floor() + 1) * GameConstants.tileSize;
        player = player.copyWith(y: newY, vy: 0);
      } else {
        player = player.copyWith(y: newY);
      }
    } else {
      // Not moving vertically (vy == 0) - check if on ground with multiple points
      final bottomY = player.y + player.h;
      final checkY = bottomY + 1; // Check slightly below, but not too much
      final leftCheck = game.getTileAt(player.x + 4, checkY) == 1;
      final rightCheck = game.getTileAt(player.x + player.w - 4, checkY) == 1;
      final centerCheck = game.getTileAt(player.x + player.w / 2, checkY) == 1;
      
      if (leftCheck || rightCheck || centerCheck) {
        // On ground, ensure correct position - snap to top of tile
        final checkTileY = (checkY / GameConstants.tileSize).floor();
        final tileTopY = checkTileY * GameConstants.tileSize;
        final correctY = tileTopY - player.h;
        if ((player.y - correctY).abs() > 0.5) {
          player = player.copyWith(y: correctY, vy: 0);
        }
      } else {
        // Not on ground but vy == 0, apply gravity to prevent floating
        player = player.copyWith(vy: player.vy + GameConstants.gravity * dt * 60);
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
    // Always read fresh from provider to ensure we have latest state
    final providerEnemies = ref.read(enemiesProvider);
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final updatedEnemies = <Entity>[];

    // DEBUG: Check if enemies list is empty
    if (providerEnemies.isEmpty) {
      _localEnemies = [];
      return;
    }
    
    // Use provider enemies for calculations
    final enemies = providerEnemies;

    for (var enemy in enemies) {
      // Respawn check
      if (enemy.isDead) {
        if (enemy.respawnTime != null && currentTime > enemy.respawnTime!) {
          // Respawn enemy at original position, ensuring it's on ground
          final respawnX = enemy.originalX ?? enemy.x;
          final respawnY = enemy.originalY ?? enemy.y;
          
          // Verify and correct Y position to be on ground
          final groundY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
          final correctY = groundY - enemy.h;
          final finalY = (respawnY - correctY).abs() < 10 ? respawnY : correctY;
          
            // Ensure respawned enemy has movement direction
            final respawnDirection = (enemy.id.hashCode % 2 == 0) ? 1 : -1;
            final stage = ref.read(stageProvider);
            final targetSpeed = GameConstants.enemySpeedBase + (stage % 10) * 0.1;

            updatedEnemies.add(enemy.copyWith(
              isDead: false,
              isLooted: false,
              hp: enemy.maxHp,
              x: respawnX,
              y: finalY,
              vx: targetSpeed * respawnDirection,
              vy: 0,
              facing: respawnDirection,
            ));
        } else {
          // --- LOOT COLLECTION LOGIC ---
          if (_localPlayer != null && !enemy.isLooted && _checkCollision(_localPlayer!, enemy)) {
            final enemyLoot = ref.read(enemyLootProvider);
            final loot = enemyLoot[enemy.id];
            
            if (loot != null) {
              final autoLoot = ref.read(autoLootProvider);
              final stats = ref.read(playerStatsProvider);
              
              if (autoLoot && !enemy.isBoss) {
                // INSTANT AUTO LOOT for Mobs
                var updatedEnemy = enemy.copyWith(isLooted: true);
                
                // Smart Compare
                bool shouldEquip = false;
                if (loot.type == EquipmentSlot.life) {
                  shouldEquip = true;
                } else {
                  final current = stats.equipment[loot.type];
                  if (current == null || loot.statBoost > current.statBoost) {
                    shouldEquip = true;
                  }
                }
                
                if (shouldEquip) {
                  if (loot.type == EquipmentSlot.life) {
                    Future.microtask(() {
                      ref.read(playerStatsProvider.notifier).addLife();
                      ref.read(floatingTextsProvider.notifier).addText(FloatingText(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        x: _localPlayer!.x,
                        y: _localPlayer!.y - 20,
                        text: 'AUTO: 1-UP!',
                        life: 1.0,
                        color: '#00FF00',
                        vy: -2,
                      ));
                    });
                  } else {
                    Future.microtask(() {
                      ref.read(playerStatsProvider.notifier).equipItem(loot);
                      ref.read(floatingTextsProvider.notifier).addText(FloatingText(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        x: _localPlayer!.x,
                        y: _localPlayer!.y - 20,
                        text: 'AUTO: ${loot.name}',
                        life: 1.0,
                        color: '#00FF00',
                        vy: -2,
                      ));
                    });
                  }
                } else {
                  Future.microtask(() {
                    ref.read(floatingTextsProvider.notifier).addText(FloatingText(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      x: _localPlayer!.x,
                      y: _localPlayer!.y - 20,
                      text: 'DESCARTADO: ${loot.name}',
                      life: 1.0,
                      color: '#888888',
                      vy: -2,
                    ));
                  });
                }
                
                // Remove loot from map
                Future.microtask(() {
                  ref.read(enemyLootProvider.notifier).removeLoot(enemy.id);
                });
                
                updatedEnemies.add(updatedEnemy);
              } else {
                // Manual Loot Prompt - set loot target (don't open modal yet, wait for E key)
                Future.microtask(() {
                  ref.read(lootTargetIdProvider.notifier).state = enemy.id;
                  // Don't set foundLoot here - wait for E key press
                });
                updatedEnemies.add(enemy);
              }
            } else {
              // No loot to collect - don't mark as looted, just keep enemy as is
              // (isLooted should only be true if loot was actually collected)
              updatedEnemies.add(enemy);
            }
          } else {
            // Dead enemy remains on ground for loot collection
            var newEnemy = enemy;
            
            // Find the ground tile below the enemy using getTileAt
            final enemyCenterX = newEnemy.x + newEnemy.w / 2;
            final enemyBottomY = newEnemy.y + newEnemy.h;
            
            // Check multiple points below to find ground
            bool foundGround = false;
            double groundY = enemyBottomY;
            
            // Check directly below at different offsets
            for (int checkOffset = 0; checkOffset <= 5; checkOffset++) {
              final checkX = enemyCenterX + (checkOffset % 3 - 1) * newEnemy.w / 3;
              final checkY = enemyBottomY + checkOffset;
              
              if (game.getTileAt(checkX, checkY) == 1) {
                // Found ground, calculate exact Y position
                final tileY = (checkY / GameConstants.tileSize).floor() * GameConstants.tileSize;
                groundY = tileY;
                foundGround = true;
                break;
              }
            }
            
            // If ground found, position enemy on top of it
            if (foundGround) {
              final correctY = groundY - newEnemy.h;
              newEnemy = newEnemy.copyWith(
                y: correctY,
                vy: 0,
                vx: 0,
              );
            } else {
              // If no ground found, apply gravity but ensure it doesn't fall too far
              newEnemy = newEnemy.copyWith(
                vy: newEnemy.vy + GameConstants.gravity * dt * 60,
              );
              newEnemy = newEnemy.copyWith(y: newEnemy.y + newEnemy.vy * dt * 60);
              
              // Check if hit ground during fall
              final newBottomY = newEnemy.y + newEnemy.h;
              if (game.getTileAt(newEnemy.x, newBottomY) == 1 ||
                  game.getTileAt(newEnemy.x + newEnemy.w, newBottomY) == 1) {
                final tileY = (newBottomY / GameConstants.tileSize).floor() * GameConstants.tileSize;
                newEnemy = newEnemy.copyWith(
                  y: tileY - newEnemy.h,
                  vy: 0,
                );
              } else {
                // Limit fall distance to prevent falling forever
                final maxFallY = (GameConstants.levelHeight - 2) * GameConstants.tileSize - newEnemy.h;
                if (newEnemy.y > maxFallY) {
                  newEnemy = newEnemy.copyWith(
                    y: maxFallY,
                    vy: 0,
                  );
                }
              }
            }
            
            // Keep dead enemy in place (no horizontal movement)
            newEnemy = newEnemy.copyWith(vx: 0);
            
            updatedEnemies.add(newEnemy);
          }
        }
        continue;
      }

      // Normal enemy behavior
      // --- KNOCKBACK RECOVERY & MOVEMENT ---
      // Apply gravity first
      var newEnemy = enemy;
      
      // Check if enemy is on ground (any solid tile: 1 or 2)
      final bottomY = newEnemy.y + newEnemy.h;
      final checkY = bottomY + 2;
      // Use getRawTileAt to check for any solid tile type
      final isOnGround = game.getRawTileAt(newEnemy.x + newEnemy.w / 2, checkY) > 0 ||
                         game.getRawTileAt(newEnemy.x, checkY) > 0 ||
                         game.getRawTileAt(newEnemy.x + newEnemy.w, checkY) > 0;
      
      if (!isOnGround) {
        // Apply gravity if not on ground
        newEnemy = newEnemy.copyWith(vy: newEnemy.vy + GameConstants.gravity * dt * 60);
      } else if (newEnemy.vy > 0) {
        // Stop falling if on ground
        newEnemy = newEnemy.copyWith(vy: 0);
      }
      
      final stage = ref.read(stageProvider);
      final targetSpeed = GameConstants.enemySpeedBase + (stage % 10) * 0.1;
      
      // CRITICAL: ALWAYS ensure enemy has movement velocity
      // This is the most important check - enemies MUST move
      if (newEnemy.vx.abs() < 0.1) {
        // Determine direction: use facing if set, otherwise use enemy ID hash
        final direction = newEnemy.facing != 0 
            ? (newEnemy.facing > 0 ? 1 : -1)
            : (enemy.id.hashCode % 2 == 0 ? 1 : -1);
        newEnemy = newEnemy.copyWith(
          vx: targetSpeed * direction,
          facing: direction,
        );
      }
      
      // If moving faster than target speed (Knockback), apply friction gradually
      if (newEnemy.vx.abs() > targetSpeed * 1.5) {
        newEnemy = newEnemy.copyWith(vx: newEnemy.vx * 0.9);
      } else if (newEnemy.vx.abs() < targetSpeed * 0.5) {
        // If moving slower than 50% of target speed, restore to target speed immediately
        final direction = newEnemy.vx >= 0 ? 1 : -1;
        newEnemy = newEnemy.copyWith(
          vx: targetSpeed * direction,
          facing: direction,
        );
      }
      
      // Calculate next position - CRITICAL: Use newEnemy.vx, not enemy.vx
      // Also ensure dt is valid (should be around 0.016 for 60fps)
      final effectiveDt = dt.clamp(0.0, 0.1); // Cap dt to prevent huge jumps
      final moveDistance = newEnemy.vx * effectiveDt * 60;
      final nextX = enemy.x + moveDistance;
      
      // Check for wall collision ahead - check at multiple Y positions to avoid false positives
      final wallCheckY1 = enemy.y + enemy.h - 4; // Bottom of enemy
      final wallCheckY2 = enemy.y + enemy.h / 2; // Middle of enemy
      final wallCheckY3 = enemy.y + 4; // Top of enemy
      
      // Check wall collision ahead (any solid tile: 1 or 2)
      // Only check if we're actually moving (avoid false positives when vx is near 0)
      bool wallCollision = false;
      if (newEnemy.vx.abs() > 0.1) {
        if (newEnemy.vx > 0) {
          // Moving right - check right edge
          wallCollision = game.getRawTileAt(nextX + enemy.w, wallCheckY1) > 0 ||
                         game.getRawTileAt(nextX + enemy.w, wallCheckY2) > 0 ||
                         game.getRawTileAt(nextX + enemy.w, wallCheckY3) > 0;
        } else {
          // Moving left - check left edge
          wallCollision = game.getRawTileAt(nextX, wallCheckY1) > 0 ||
                         game.getRawTileAt(nextX, wallCheckY2) > 0 ||
                         game.getRawTileAt(nextX, wallCheckY3) > 0;
        }
      }
      final wallTile = wallCollision ? 1 : 0;

      bool pitDetected = false;
      bool platformEdgeDetected = false;
      
      // Only check for pits and platform edges if enemy is on ground and not in knockback
      if (isOnGround && newEnemy.vx.abs() <= targetSpeed * 1.5) {
        // Check for pits (no solid tile below)
        final pitCheckX = newEnemy.vx > 0 ? nextX + enemy.w : nextX;
        final pitCheckY = enemy.y + enemy.h + 2;
        pitDetected = game.getRawTileAt(pitCheckX, pitCheckY) == 0;
        
        // Check for platform edges (only if on a platform, not ground level)
        final enemyBottomY = enemy.y + enemy.h;
        final enemyTileY = (enemyBottomY / GameConstants.tileSize).floor();
        final groundLevelTileY = GameConstants.levelHeight - 2;
        
        if (enemyTileY < groundLevelTileY) {
          // We're on a platform, check if there's platform ahead
          // Use getRawTileAt to check for any solid tile (1 or 2)
          final aheadX = newEnemy.vx > 0 ? nextX + enemy.w : nextX;
          final platformTileY = enemyTileY + 1;
          
          // Check multiple points ahead to ensure we detect gaps correctly
          final checkPoints = [
            aheadX, // Directly ahead
            aheadX + (newEnemy.vx > 0 ? -5 : 5), // Slightly back
            aheadX + (newEnemy.vx > 0 ? 5 : -5), // Slightly forward
          ];
          
          // Get current tile (any solid tile = 1 or 2)
          final currentRawTile = game.getRawTileAt(enemy.x + enemy.w / 2, platformTileY * GameConstants.tileSize);
          final isOnSolidTile = currentRawTile > 0;
          
          // Check if there's a solid tile ahead at any of the check points
          bool foundSolidTileAhead = false;
          for (final checkX in checkPoints) {
            final aheadRawTile = game.getRawTileAt(checkX, platformTileY * GameConstants.tileSize);
            if (aheadRawTile > 0) {
              foundSolidTileAhead = true;
              break;
            }
          }
          
          // If on solid tile but no solid tile ahead, turn around
          if (isOnSolidTile && !foundSolidTileAhead) {
            platformEdgeDetected = true;
          }
        }
      }

      // Handle collisions and movement (wallTile > 0 means any solid tile)
      if (wallTile > 0 || pitDetected || platformEdgeDetected) {
        // Turn around when hitting obstacle - but ensure velocity is maintained
        final newDirection = newEnemy.vx > 0 ? -1 : 1;
        newEnemy = newEnemy.copyWith(
          vx: targetSpeed * newDirection,
          facing: newDirection,
        );
        // Move in the new direction immediately to prevent getting stuck
        // Use a small movement to ensure we move away from the wall
        final moveAwayDistance = targetSpeed * newDirection * effectiveDt * 60 * 0.5;
        final newX = enemy.x + moveAwayDistance;
        newEnemy = newEnemy.copyWith(x: newX);
      } else {
        // Move normally - CRITICAL: Always update X position when moving
        // Ensure we actually move by at least a small amount
        if ((nextX - enemy.x).abs() < 0.01 && newEnemy.vx.abs() > 0.1) {
          // If movement is too small but we have velocity, force a minimum movement
          final minMove = newEnemy.vx > 0 ? 0.5 : -0.5;
          newEnemy = newEnemy.copyWith(x: enemy.x + minMove);
        } else {
          newEnemy = newEnemy.copyWith(x: nextX);
        }
      }

      // Update Y position with capped dt
      newEnemy = newEnemy.copyWith(y: newEnemy.y + newEnemy.vy * effectiveDt * 60);
      if (newEnemy.vy > 0) {
        // Falling
        final bottomY = newEnemy.y + newEnemy.h;
        if (game.getTileAt(newEnemy.x, bottomY) == 1 ||
            game.getTileAt(newEnemy.x + newEnemy.w, bottomY) == 1) {
          // Snap to ground
          final tileY = (bottomY / GameConstants.tileSize).floor() * GameConstants.tileSize;
          newEnemy = newEnemy.copyWith(
            y: tileY - newEnemy.h,
            vy: 0,
          );
        }
      } else if (newEnemy.vy == 0) {
        // Not moving - check if on ground
        final bottomY = newEnemy.y + newEnemy.h;
        final checkY = bottomY + 2;
        if (game.getTileAt(newEnemy.x + newEnemy.w / 2, checkY) == 1) {
          // On ground, ensure correct position
          final tileY = (bottomY / GameConstants.tileSize).floor() * GameConstants.tileSize;
          final correctY = tileY - newEnemy.h;
          if ((newEnemy.y - correctY).abs() > 0.5) {
            newEnemy = newEnemy.copyWith(y: correctY, vy: 0);
          }
        }
      }

      updatedEnemies.add(newEnemy);
    }

    // Store locally for immediate use in next frame
    _localEnemies = updatedEnemies;
    
    // Update provider after build completes - use Future to avoid modifying during build
    // This ensures the EnemyComponent can read the updated position without causing build errors
    Future(() {
      enemiesNotifier.setEnemies(_localEnemies);
    });
  }

  void _updateCamera() {
    // Use local player state for camera
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }
    final player = _localPlayer!;
    final canvasWidth = game.size.x;
    final mapWidthPixels = game.map[0].length * GameConstants.tileSize;

    final targetCamX = player.x - canvasWidth / 2 + player.w / 2;
    game.cameraX += (targetCamX - game.cameraX) * 0.1;
    game.cameraX = game.cameraX.clamp(0, mapWidthPixels - canvasWidth);
  }

  void _checkCollisions() {
    // Use local player state for collisions
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }
    final player = _localPlayer!;
    // Use local enemies state (updated by _updateEnemies) to ensure we have latest positions
    final enemies = _localEnemies.isNotEmpty ? _localEnemies : ref.read(enemiesProvider);
    final stats = ref.read(playerStatsProvider);
    final enemiesNotifier = ref.read(enemiesProvider.notifier);
    final statsNotifier = ref.read(playerStatsProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);
    final floatingTextsNotifier = ref.read(floatingTextsProvider.notifier);
    final stage = ref.read(stageProvider);

    final updatedEnemies = <Entity>[];
    bool playerHitEnemy = false; // Track if player hit an enemy to prevent multiple hits

    for (var enemy in enemies) {
      // Only process collision if player hasn't already hit an enemy this frame
      if (!playerHitEnemy && _checkCollision(player, enemy) && !enemy.isDead) {
        final hitFromTop = player.vy > 0 && (player.y + player.h) < (enemy.y + enemy.h * 0.7);

        if (hitFromTop) {
          // Hit enemy from top - only process one enemy per frame
          playerHitEnemy = true;
          final newHp = (enemy.hp ?? 1) - 1;
          var updatedEnemy = enemy.copyWith(hp: newHp);

          var updatedPlayer = player.copyWith(vy: -10); // Bounce

          if (newHp <= 0) {
            // Kill enemy - ensure it's positioned on ground
            final enemyBottomY = enemy.y + enemy.h;
            final groundTileY = (enemyBottomY / GameConstants.tileSize).floor() * GameConstants.tileSize;
            final correctY = groundTileY - enemy.h;
            
            updatedEnemy = updatedEnemy.copyWith(
              isDead: true,
              respawnTime: DateTime.now().millisecondsSinceEpoch + GameConstants.respawnTimeMs,
              y: correctY,
              vy: 0,
              vx: 0,
            );
            
            // Generate loot with probabilities: 30% normal, 10% rare, 1% legendary, 9% life, 50% nothing
            final lootRoll = (DateTime.now().millisecondsSinceEpoch + enemy.id.hashCode) % 100;
            GeneratedLootData? droppedLoot;
            
            if (lootRoll < 1) {
              // 1% chance - Legendary item
              final generateFastLootUseCase = ref.read(generateFastLootUseCaseProvider);
              droppedLoot = generateFastLootUseCase(stats.level, rarity: 'legendary');
            } else if (lootRoll < 11) {
              // 10% chance - Rare item
              final generateFastLootUseCase = ref.read(generateFastLootUseCaseProvider);
              droppedLoot = generateFastLootUseCase(stats.level, rarity: 'rare');
            } else if (lootRoll < 41) {
              // 30% chance - Normal item
              final generateFastLootUseCase = ref.read(generateFastLootUseCaseProvider);
              droppedLoot = generateFastLootUseCase(stats.level, rarity: 'normal');
            } else if (lootRoll < 50) {
              // 9% chance - Life extra
              droppedLoot = GeneratedLootData(
                name: "COGUMELO VIDA",
                type: EquipmentSlot.life,
                statBoost: 1,
                description: "Garante uma vida extra!",
              );
            }
            // 50% chance - No loot (lootRoll >= 50)
            
            // Store loot for collection
            if (droppedLoot != null) {
              Future.microtask(() {
                ref.read(enemyLootProvider.notifier).setLoot(enemy.id, droppedLoot!);
              });
            }

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

            final dir = (enemy.x + enemy.w / 2) > (player.x + player.w / 2) ? 1.0 : -1.0;
            updatedEnemy = updatedEnemy.copyWith(
              vx: dir * 8.0,
              vy: -4.0,
            );

            _spawnParticles(enemy.x + enemy.w / 2, enemy.y, '#FF0000', 5);
          }

          // Update player immediately in local state
          _localPlayer = updatedPlayer;
          Future.microtask(() => playerNotifier.update(updatedPlayer));
          
          // Add updated enemy and continue to next enemy
          updatedEnemies.add(updatedEnemy);
          continue;
        } else {
          // Player hurt - only process one enemy per frame
          playerHitEnemy = true;
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

          // Update player immediately in local state
          _localPlayer = updatedPlayer;
          Future.microtask(() => playerNotifier.update(updatedPlayer));
          
          // Add enemy as-is (no changes to enemy when player is hurt)
          updatedEnemies.add(enemy);
          continue;
        }
      }

      // Add enemy without changes
      updatedEnemies.add(enemy);
    }

    // Update enemies - delay to avoid modifying provider during build
    // Also update local state to keep it in sync
    _localEnemies = updatedEnemies;
    Future(() {
      enemiesNotifier.setEnemies(updatedEnemies);
    });
  }

  void _checkWinCondition() {
    // Use local player state
    if (_localPlayer == null) {
      _localPlayer = ref.read(playerProvider);
    }
    final player = _localPlayer!;
    final flagpoleX = (game.map[0].length - 5) * GameConstants.tileSize;

    if (player.x >= flagpoleX) {
      Future.microtask(() {
        ref.read(gameStateProvider.notifier).state = GameState.levelComplete;
        Future.delayed(const Duration(seconds: 4), () {
          final stage = ref.read(stageProvider);
          ref.read(stageProvider.notifier).state = stage + 1;
          
          // Clear local player state first
          _localPlayer = null;
          
          // Reset camera to start of new level
          game.cameraX = 0;
          
          // Initialize new level (this will reset player position)
          game.initializeLevel();
          
          // Ensure player is positioned correctly at start after level initialization
          Future.delayed(const Duration(milliseconds: 100), () {
            final playerNotifier = ref.read(playerProvider.notifier);
            final player = ref.read(playerProvider);
            final groundY = (GameConstants.levelHeight - 3) * GameConstants.tileSize;
            final correctPlayerY = groundY - GameConstants.playerHeight;
            
            // Force player to start position
            playerNotifier.update(
              player.copyWith(
                x: GameConstants.playerStartX,
                y: correctPlayerY,
                vx: 0,
                vy: 0,
              ),
            );
            
            // Clear local state again to ensure fresh start
            _localPlayer = null;
          });
          
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
        // Clear all game entities
        ref.read(enemiesProvider.notifier).setEnemies([]);
        ref.read(particlesProvider.notifier).clear();
        ref.read(floatingTextsProvider.notifier).clear();
        
        // Reset player
        playerNotifier.reset();
        _localPlayer = null;
        
        // Reset camera
        game.cameraX = 0;
        
        // Reinitialize level to reset enemies and map
        game.initializeLevel();
        
        // Ensure game state is playing
        ref.read(gameStateProvider.notifier).state = GameState.playing;
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

