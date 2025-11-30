import 'package:universal_html/html.dart' as html show window;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flame/game.dart';
import 'game_world.dart';
import '../hud/hud_widget.dart';
import '../loot/loot_modal.dart';
import '../menu/game_over_screen.dart';
import '../menu/level_complete_screen.dart';
import '../providers/game_providers.dart';
import '../providers/input_provider.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/entities/equipment_slot.dart';

class GameScreen extends HookConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusNode = useFocusNode();
    final game = useMemoized(() => GameWorld(ref: ref), [ref]);
    final gameState = ref.watch(gameStateProvider);
    
    // Watch for game state changes to reinitialize level when needed
    // Only reinitialize when transitioning from non-playing states (gameOver, levelComplete) to playing
    // NOT when transitioning from lootModal to playing (that's just closing the modal)
    final previousGameState = useRef<GameState?>(null);
    useEffect(() {
      final previous = previousGameState.value;
      final isNowPlaying = gameState == GameState.playing;
      
      // Only reinitialize if:
      // 1. We're now playing
      // 2. We were NOT playing before (or this is the first time)
      // 3. The previous state was NOT lootModal (to avoid resetting when closing loot modal)
      if (isNowPlaying && 
          previous != null && 
          previous != GameState.playing && 
          previous != GameState.lootModal) {
        // Only reinitialize when transitioning TO playing from gameOver or levelComplete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final enemies = ref.read(enemiesProvider);
          if (enemies.isEmpty) {
            // Only reset if there are no enemies (level not initialized)
            game.cameraX = 0;
            game.initializeLevel();
          }
        });
      }
      
      previousGameState.value = gameState;
      return null;
    }, [gameState]);
    
    useEffect(() {
      // Request focus for keyboard input
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.requestFocus();
      });

      // Setup global keyboard listeners for web (backup)
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setupWebKeyboardListeners(ref);
        });
      }
      
      return null;
    }, []);

    return Scaffold(
      body: KeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (kIsWeb) {
            // Handle web keyboard events
            final keys = Map<String, bool>.from(ref.read(keysProvider) ?? {});
            final isPressed = event is RawKeyDownEvent;

            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              keys['ArrowLeft'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              keys['ArrowRight'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              keys['ArrowUp'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              keys['ArrowDown'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
              keys['ArrowLeft'] = isPressed;
              keys['a'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
              keys['ArrowRight'] = isPressed;
              keys['d'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
              keys['ArrowUp'] = isPressed;
              keys['w'] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              keys['ArrowUp'] = isPressed;
              keys[' '] = isPressed;
            } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
              keys['e'] = isPressed;
              if (isPressed) {
                final currentGameState = ref.read(gameStateProvider);
                // If loot modal is open, accept the loot
                if (currentGameState == GameState.lootModal) {
                  final foundLoot = ref.read(foundLootProvider);
                  if (foundLoot != null) {
                    _equipLoot(ref, true);
                  }
                } else {
                  // Handle loot collection (E key) - only if modal is not open
                  final lootTargetId = ref.read(lootTargetIdProvider);
                  if (lootTargetId != null) {
                    final enemyLoot = ref.read(enemyLootProvider);
                    final loot = enemyLoot[lootTargetId];
                    if (loot != null) {
                      Future(() {
                        ref.read(foundLootProvider.notifier).state = loot;
                        ref.read(gameStateProvider.notifier).state = GameState.lootModal;
                      });
                    }
                  }
                }
              }
            } else if (event.logicalKey == LogicalKeyboardKey.keyQ) {
              keys['q'] = isPressed;
              if (isPressed) {
                // Handle loot rejection (Q key)
                final foundLoot = ref.read(foundLootProvider);
                if (foundLoot != null) {
                  final lootTargetId = ref.read(lootTargetIdProvider);
                  if (lootTargetId != null) {
                    final enemies = ref.read(enemiesProvider);
                    if (enemies.isNotEmpty) {
                      final enemy = enemies.firstWhere(
                        (e) => e.id == lootTargetId,
                        orElse: () => enemies.first,
                      );
                      if (!enemy.isLooted) {
                        ref.read(enemiesProvider.notifier).updateEnemy(enemy.copyWith(isLooted: true));
                      }
                      ref.read(enemyLootProvider.notifier).removeLoot(lootTargetId);
                    }
                  }
                  ref.read(foundLootProvider.notifier).state = null;
                  ref.read(lootTargetIdProvider.notifier).state = null;
                  ref.read(gameStateProvider.notifier).state = GameState.playing;
                }
              }
            }

            // Update immediately for responsive input
            ref.read(keysProvider.notifier).state = keys;
          }
        },
        child: Stack(
          children: [
            // Game
            GameWidget(game: game),

            // HUD
            const HUDWidget(),

            // Modals
            if (gameState == GameState.lootModal || ref.watch(foundLootProvider) != null) const LootModal(),

            if (gameState == GameState.gameOver) const GameOverScreen(),

            if (gameState == GameState.levelComplete)
              const LevelCompleteScreen(),
          ],
        ),
      ),
    );
  }

  void _setupWebKeyboardListeners(WidgetRef ref) {
    // Use universal_html for cross-platform keyboard event handling
    if (kIsWeb) {
      html.window.onKeyDown.listen((event) {
        final key = event.key;
        final keys = Map<String, bool>.from(ref.read(keysProvider) ?? {});

        // Map keyboard keys to our key names - SETAS DO TECLADO
        if (key == 'ArrowLeft') keys['ArrowLeft'] = true;
        if (key == 'ArrowRight') keys['ArrowRight'] = true;
        if (key == 'ArrowUp') keys['ArrowUp'] = true;
        if (key == 'ArrowDown') keys['ArrowDown'] = true;

        // WASD
        if (key == 'a' || key == 'A') {
          keys['ArrowLeft'] = true;
          keys['a'] = true;
        }
        if (key == 'd' || key == 'D') {
          keys['ArrowRight'] = true;
          keys['d'] = true;
        }
        if (key == 'w' || key == 'W') {
          keys['ArrowUp'] = true;
          keys['w'] = true;
        }
        if (key == 's' || key == 'S') {
          keys['ArrowDown'] = true;
          keys['s'] = true;
        }

        // Espaço para pular
        if (key == ' ') {
          keys['ArrowUp'] = true;
          keys[' '] = true;
        }

        // Outras teclas
        if (key == 'e' || key == 'E') {
          keys['e'] = true;
          // Handle loot collection (E key)
          final currentGameState = ref.read(gameStateProvider);
          // If loot modal is open, accept the loot
          if (currentGameState == GameState.lootModal) {
            final foundLoot = ref.read(foundLootProvider);
            if (foundLoot != null) {
              Future(() {
                _equipLoot(ref, true);
              });
            }
          } else {
            // Handle loot collection - only if modal is not open
            final lootTargetId = ref.read(lootTargetIdProvider);
            if (lootTargetId != null) {
              final enemyLoot = ref.read(enemyLootProvider);
              final loot = enemyLoot[lootTargetId];
              if (loot != null) {
                Future(() {
                  ref.read(foundLootProvider.notifier).state = loot;
                  ref.read(gameStateProvider.notifier).state = GameState.lootModal;
                });
              }
            }
          }
        }
        if (key == 'q' || key == 'Q') {
          keys['q'] = true;
          // Handle loot rejection (Q key)
          final foundLoot = ref.read(foundLootProvider);
          if (foundLoot != null) {
            // Reject loot
            final lootTargetId = ref.read(lootTargetIdProvider);
            if (lootTargetId != null) {
              final enemies = ref.read(enemiesProvider);
              final enemy = enemies.firstWhere(
                (e) => e.id == lootTargetId,
                orElse: () => enemies.isNotEmpty ? enemies.first : throw StateError('No enemies'),
              );
              if (!enemy.isLooted) {
                ref.read(enemiesProvider.notifier).updateEnemy(enemy.copyWith(isLooted: true));
              }
              ref.read(enemyLootProvider.notifier).removeLoot(lootTargetId);
            }
            ref.read(foundLootProvider.notifier).state = null;
            ref.read(lootTargetIdProvider.notifier).state = null;
            ref.read(gameStateProvider.notifier).state = GameState.playing;
          }
        }
        if (key == 'q' || key == 'Q') keys['q'] = true;

        // Update with microtask to avoid modifying provider during build
        Future.microtask(() {
          ref.read(keysProvider.notifier).state = keys;
        });
      });

      html.window.onKeyUp.listen((event) {
        final key = event.key;
        final keys = Map<String, bool>.from(ref.read(keysProvider) ?? {});

        // Map keyboard keys to our key names - SETAS DO TECLADO
        if (key == 'ArrowLeft') keys['ArrowLeft'] = false;
        if (key == 'ArrowRight') keys['ArrowRight'] = false;
        if (key == 'ArrowUp') keys['ArrowUp'] = false;
        if (key == 'ArrowDown') keys['ArrowDown'] = false;

        // WASD
        if (key == 'a' || key == 'A') {
          keys['ArrowLeft'] = false;
          keys['a'] = false;
        }
        if (key == 'd' || key == 'D') {
          keys['ArrowRight'] = false;
          keys['d'] = false;
        }
        if (key == 'w' || key == 'W') {
          keys['ArrowUp'] = false;
          keys['w'] = false;
        }
        if (key == 's' || key == 'S') {
          keys['ArrowDown'] = false;
          keys['s'] = false;
        }

        // Espaço para pular
        if (key == ' ') {
          keys['ArrowUp'] = false;
          keys[' '] = false;
        }

        // Outras teclas
        if (key == 'e' || key == 'E') keys['e'] = false;
        if (key == 'q' || key == 'Q') keys['q'] = false;

        // Update with microtask to avoid modifying provider during build
        Future.microtask(() {
          ref.read(keysProvider.notifier).state = keys;
        });
      });
    }
  }

  void _equipLoot(WidgetRef ref, bool shouldEquip) {
    final foundLoot = ref.read(foundLootProvider);
    final lootTargetId = ref.read(lootTargetIdProvider);
    
    if (shouldEquip && foundLoot != null) {
      if (foundLoot.type == EquipmentSlot.life) {
        ref.read(playerStatsProvider.notifier).addLife();
      } else {
        ref.read(playerStatsProvider.notifier).equipItem(foundLoot);
      }
    }
    
    // Mark enemy as looted
    if (lootTargetId != null) {
      final enemies = ref.read(enemiesProvider);
      if (enemies.isNotEmpty) {
        final enemy = enemies.firstWhere(
          (e) => e.id == lootTargetId,
          orElse: () => enemies.first,
        );
        if (!enemy.isLooted) {
          ref.read(enemiesProvider.notifier).updateEnemy(enemy.copyWith(isLooted: true));
        }
        // Remove loot from map
        ref.read(enemyLootProvider.notifier).removeLoot(lootTargetId);
      }
    }
    
    Future(() {
      ref.read(foundLootProvider.notifier).state = null;
      ref.read(lootTargetIdProvider.notifier).state = null;
      ref.read(gameStateProvider.notifier).state = GameState.playing;
    });
  }
}
