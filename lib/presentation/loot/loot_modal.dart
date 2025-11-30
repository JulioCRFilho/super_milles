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
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a1a),
              border: Border.all(color: const Color(0xFF8B7355), width: 2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'GERANDO ITEM...',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : foundLoot != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with title
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _getRarityColor(foundLoot).withOpacity(0.3),
                                  border: Border.all(
                                    color: _getRarityColor(foundLoot),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    _getLootIcon(foundLoot.type),
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      foundLoot.name,
                                      style: TextStyle(
                                        color: _getRarityColor(foundLoot),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: _getRarityColor(foundLoot).withOpacity(0.5),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (foundLoot.type != EquipmentSlot.life)
                                      Text(
                                        '+${foundLoot.statBoost} Status',
                                        style: const TextStyle(
                                          color: Color(0xFF87CEEB),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else
                                      const Text(
                                        '+1 Vida',
                                        style: TextStyle(
                                          color: Color(0xFFFF6B6B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Description
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF444444),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              foundLoot.description,
                              style: const TextStyle(
                                color: Color(0xFFCCCCCC),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Comparison - Always show if there's a current item
                          if (foundLoot.type != EquipmentSlot.life)
                            _buildComparison(ref, foundLoot),
                          const SizedBox(height: 10),
                          // Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _buildRpgButton(
                                  onPressed: () => _equipLoot(ref, true),
                                  label: 'EQUIPAR [E]',
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildRpgButton(
                                  onPressed: () => _equipLoot(ref, false),
                                  label: 'RECUSAR [Q]',
                                  color: const Color(0xFFD32F2F),
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

  Widget _buildComparison(WidgetRef ref, GeneratedLootData foundLoot) {
    final stats = ref.read(playerStatsProvider);
    final current = stats.equipment[foundLoot.type];
    
    if (current == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 14,
              color: Color(0xFF81C784),
            ),
            const SizedBox(width: 6),
            const Text(
              'Espaço Vazio - Equipar!',
              style: TextStyle(
                color: Color(0xFF81C784),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    final diff = foundLoot.statBoost - current.statBoost;
    final isBetter = diff > 0;
    final isWorse = diff < 0;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isBetter 
            ? const Color(0xFF2E7D32) 
            : isWorse 
                ? const Color(0xFFB71C1C) 
                : const Color(0xFF424242))
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isBetter 
              ? const Color(0xFF4CAF50) 
              : isWorse 
                  ? const Color(0xFFD32F2F) 
                  : const Color(0xFF757575),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBetter 
                    ? Icons.trending_up 
                    : isWorse 
                        ? Icons.trending_down 
                        : Icons.remove,
                size: 14,
                color: isBetter 
                    ? const Color(0xFF81C784) 
                    : isWorse 
                        ? const Color(0xFFE57373) 
                        : const Color(0xFF9E9E9E),
              ),
              const SizedBox(width: 6),
              Text(
                isBetter 
                    ? 'MELHOR' 
                    : isWorse 
                        ? 'PIOR' 
                        : 'IGUAL',
                style: TextStyle(
                  color: isBetter 
                      ? const Color(0xFF81C784) 
                      : isWorse 
                          ? const Color(0xFFE57373) 
                          : const Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Atual:',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    current.name,
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '+${current.statBoost} Status',
                    style: const TextStyle(
                      color: Color(0xFF87CEEB),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Novo Item:',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    foundLoot.name,
                    style: TextStyle(
                      color: _getRarityColor(foundLoot),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '+${foundLoot.statBoost} Status',
                    style: const TextStyle(
                      color: Color(0xFF87CEEB),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Diferença: ',
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 10,
                  ),
                ),
                Text(
                  isBetter 
                      ? '+$diff Status' 
                      : isWorse 
                          ? '$diff Status' 
                          : 'Sem mudança',
                  style: TextStyle(
                    color: isBetter 
                        ? const Color(0xFF81C784) 
                        : isWorse 
                            ? const Color(0xFFE57373) 
                            : const Color(0xFF9E9E9E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRpgButton({
    required VoidCallback onPressed,
    required String label,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
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

