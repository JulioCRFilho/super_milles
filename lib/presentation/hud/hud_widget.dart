import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equipment_slot.dart';
import '../../domain/entities/equipment.dart';
import '../providers/game_providers.dart';
import '../../core/constants/game_constants.dart';

class HUDWidget extends ConsumerStatefulWidget {
  const HUDWidget({super.key});

  @override
  ConsumerState<HUDWidget> createState() => _HUDWidgetState();
}

class _HUDWidgetState extends ConsumerState<HUDWidget> {
  Equipment? selectedItem;

  @override
  Widget build(BuildContext context) {
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
    
    final equipSlots = [
      {'id': EquipmentSlot.helmet, 'label': 'CABEÇA', 'icon': '⛑️'},
      {'id': EquipmentSlot.armor, 'label': 'CORPO', 'icon': '👕'},
      {'id': EquipmentSlot.pants, 'label': 'PERNAS', 'icon': '👖'},
      {'id': EquipmentSlot.boots, 'label': 'PÉS', 'icon': '👢'},
      {'id': EquipmentSlot.gloves, 'label': 'MÃOS', 'icon': '🧤'},
      {'id': EquipmentSlot.accessory, 'label': 'JOIA', 'icon': '💍'},
    ];
    
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
              // Left Column: Stats, Lives & Equipment
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
                      children: [
                        ...List.generate(
                          stats.lives.clamp(0, 5),
                          (i) => const Text('❤', style: TextStyle(fontSize: 16)),
                        ),
                        if (stats.lives > 5)
                          Text('+ ${stats.lives - 5}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
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
                    
                    // Total Stats
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
                                boxShadow: autoLoot ? [
                                  BoxShadow(
                                    color: Colors.lime,
                                    blurRadius: 5,
                                  ),
                                ] : null,
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
                    
                    const SizedBox(height: 8),
                    
                    // Equipment Grid (3x3 like original)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: equipSlots.map((slotData) {
                          final slot = slotData['id'] as EquipmentSlot;
                          final item = stats.equipment[slot];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedItem = item;
                              });
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slotData['icon'] as String,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (item != null)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // Selected Item Detail Pop-up
                    if (selectedItem != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900,
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedItem!.name,
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: +${selectedItem!.statBoost}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedItem!.description,
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedItem = null;
                                });
                              },
                              child: const Text(
                                'FECHAR',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 8,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Right Column: Level Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isBossLevel 
                      ? 'CHEFE $levelNum-$worldNum' 
                      : 'FASE $levelNum-$worldNum',
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
