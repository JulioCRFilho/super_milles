import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equipment_slot.dart';
import '../providers/game_providers.dart';
import '../../domain/entities/game_state.dart';

class LootModal extends ConsumerWidget {
  const LootModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundLoot = ref.watch(foundLootProvider);
    final isLoading = ref.watch(isLoadingLootProvider);

    return Container(
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
                        Text(
                          _getLootIcon(foundLoot.type),
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          foundLoot.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          foundLoot.description,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        if (foundLoot.type != EquipmentSlot.life) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Novo Status: +${foundLoot.statBoost}',
                            style: const TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                          _buildComparison(ref, foundLoot),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _equipLoot(ref, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('EQUIPAR [E]'),
                            ),
                            if (foundLoot.type != EquipmentSlot.life) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _equipLoot(ref, false),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('RECUSAR [Q]'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    )
                  : const SizedBox(),
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

  void _equipLoot(WidgetRef ref, bool shouldEquip) {
    final foundLoot = ref.read(foundLootProvider);
    if (shouldEquip && foundLoot != null) {
      ref.read(playerStatsProvider.notifier).equipItem(foundLoot);
    }
    ref.read(foundLootProvider.notifier).state = null;
    ref.read(gameStateProvider.notifier).state = GameState.playing;
  }
}

