import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equipment_slot.dart';
import '../../domain/entities/generated_loot_data.dart';
import '../providers/game_providers.dart';
import '../../domain/entities/game_state.dart';

class LootModal extends ConsumerStatefulWidget {
  const LootModal({super.key});

  @override
  ConsumerState<LootModal> createState() => _LootModalState();
}

class _LootModalState extends ConsumerState<LootModal> {
  @override
  void initState() {
    super.initState();
    // Focus on the modal to capture keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  Widget build(BuildContext context) {
    final foundLoot = ref.watch(foundLootProvider);
    final isLoading = ref.watch(isLoadingLootProvider);

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (KeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyE) {
            _equipLoot(ref, true);
          } else if (event.logicalKey == LogicalKeyboardKey.keyQ) {
            _equipLoot(ref, false);
          }
        }
      },
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: isLoading
              ? const Text('GERANDO ITEM...', style: TextStyle(color: Colors.white))
              : foundLoot != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ITEM ENCONTRADO!',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Item Icon/Image
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _getRarityColor(foundLoot),
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _getLootIcon(foundLoot.type),
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Item Name
                        Text(
                          foundLoot.name,
                          style: TextStyle(
                            color: _getRarityColor(foundLoot),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Item Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            foundLoot.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Item Stats
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              if (foundLoot.type != EquipmentSlot.life) ...[
                                Text(
                                  'Status: +${foundLoot.statBoost}',
                                  style: const TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildComparison(ref, foundLoot),
                              ] else ...[
                                const Text(
                                  'Efeito: +1 Vida Extra',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _equipLoot(ref, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                'ACEITAR [E]',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () => _equipLoot(ref, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                'RECUSAR [Q]',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox(),
        ),
      ),
      ),
    );
  }

  Widget _buildComparison(WidgetRef ref, foundLoot) {
    final stats = ref.read(playerStatsProvider);
    final current = stats.equipment[foundLoot.type];
    
    if (current == null) {
      return const Text(
        'Espaço Vazio (EQUIPAR!)',
        style: TextStyle(color: Colors.green, fontSize: 12),
      );
    }
    
    final diff = foundLoot.statBoost - current.statBoost;
    return Text(
      diff > 0 ? 'MELHOR (+$diff)' : 'PIOR ($diff)',
      style: TextStyle(
        color: diff > 0 ? Colors.green : Colors.red,
        fontSize: 12,
      ),
    );
  }

  String _getLootIcon(EquipmentSlot type) {
    switch (type) {
      case EquipmentSlot.life:
        return '❤';
      case EquipmentSlot.boots:
        return '👢';
      case EquipmentSlot.helmet:
        return '⛑️';
      case EquipmentSlot.armor:
        return '👕';
      case EquipmentSlot.pants:
        return '👖';
      case EquipmentSlot.gloves:
        return '🧤';
      case EquipmentSlot.accessory:
        return '💍';
      default:
        return '🎁';
    }
  }

  Color _getRarityColor(GeneratedLootData loot) {
    // Determine rarity based on stat boost and name
    if (loot.name.contains('Élfico') || loot.statBoost > 20) {
      return Colors.purple; // Legendary
    } else if (loot.name.contains('Mithril') || loot.statBoost > 10) {
      return Colors.blue; // Rare
    } else if (loot.type == EquipmentSlot.life) {
      return Colors.red; // Life
    } else {
      return Colors.grey; // Normal
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
      Future(() {
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
      });
    }
    
    // Clear loot state and return to playing - use Future to avoid build conflicts
    Future(() {
      ref.read(foundLootProvider.notifier).state = null;
      ref.read(lootTargetIdProvider.notifier).state = null;
      ref.read(gameStateProvider.notifier).state = GameState.playing;
    });
  }
}

