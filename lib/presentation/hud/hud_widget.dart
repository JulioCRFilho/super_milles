import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equipment_slot.dart';
import '../providers/game_providers.dart';
import '../../core/constants/game_constants.dart';

class HUDWidget extends ConsumerWidget {
  const HUDWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playerStatsProvider);
    final stage = ref.watch(stageProvider);
    final autoLoot = ref.watch(autoLootProvider);
    
    final worldNum = (stage / GameConstants.levelsPerWorld).ceil();
    final levelNum = ((stage - 1) % GameConstants.levelsPerWorld) + 1;
    final isBossLevel = levelNum == GameConstants.levelsPerWorld;
    
    final xpPercent = (stats.xp / stats.maxXp) * 100;
    final hpPercent = (stats.hp / stats.maxHp) * 100;
    
    final totalAttack = stats.getTotalAttack();
    final totalDefense = stats.getTotalDefense();
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Lives
                    Row(
                      children: [
                        const Text(
                          'MILLES',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: List.generate(
                        stats.lives.clamp(0, 5),
                        (i) => const Text('❤', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    
                    // HP Bar
                    Row(
                      children: [
                        const Text('HP', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(
                          width: 100,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: Colors.white),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: hpPercent / 100,
                            child: Container(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    
                    // Stats
                    Row(
                      children: [
                        Text('ATK: $totalAttack', style: const TextStyle(color: Colors.yellow, fontSize: 10)),
                        const SizedBox(width: 16),
                        Text('DEF: $totalDefense', style: const TextStyle(color: Colors.blue, fontSize: 10)),
                      ],
                    ),
                    
                    // Auto Loot Toggle
                    GestureDetector(
                      onTap: () => ref.read(autoLootProvider.notifier).state = !autoLoot,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: autoLoot ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AUTO-LOOT ${autoLoot ? 'ON' : 'OFF'}',
                              style: TextStyle(
                                color: autoLoot ? Colors.green : Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Equipment Grid
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        EquipmentSlot.life,
                        EquipmentSlot.helmet,
                        EquipmentSlot.armor,
                        EquipmentSlot.pants,
                        EquipmentSlot.boots,
                        EquipmentSlot.gloves,
                        EquipmentSlot.accessory,
                      ].map((slot) {
                        final item = stats.equipment[slot];
                        return Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: item != null
                              ? const Icon(Icons.check, color: Colors.green, size: 16)
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              
              // Right Column: Level Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isBossLevel ? 'CHEFE $levelNum-$worldNum' : 'FASE $levelNum-$worldNum',
                    style: TextStyle(
                      color: isBossLevel ? Colors.red : Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('NIVEL ${stats.level}', style: const TextStyle(fontSize: 10)),
                  Container(
                    width: 120,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.white),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: xpPercent / 100,
                      child: Container(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

