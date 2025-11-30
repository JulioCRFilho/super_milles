import 'equipment.dart';
import 'equipment_slot.dart';
import 'package:equatable/equatable.dart';

class PlayerStats extends Equatable {
  final int lives;
  final int level;
  final int xp;
  final int maxXp;
  final int hp;
  final int maxHp;
  final int attack; // Base attack
  final Map<EquipmentSlot, Equipment> equipment;

  const PlayerStats({
    required this.lives,
    required this.level,
    required this.xp,
    required this.maxXp,
    required this.hp,
    required this.maxHp,
    required this.attack,
    required this.equipment,
  });

  PlayerStats copyWith({
    int? lives,
    int? level,
    int? xp,
    int? maxXp,
    int? hp,
    int? maxHp,
    int? attack,
    Map<EquipmentSlot, Equipment>? equipment,
  }) {
    return PlayerStats(
      lives: lives ?? this.lives,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      maxXp: maxXp ?? this.maxXp,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      attack: attack ?? this.attack,
      equipment: equipment ?? this.equipment,
    );
  }

  int getTotalAttack() {
    return attack +
        (equipment[EquipmentSlot.boots]?.statBoost ?? 0) +
        (equipment[EquipmentSlot.gloves]?.statBoost ?? 0);
  }

  int getTotalDefense() {
    return (equipment[EquipmentSlot.helmet]?.statBoost ?? 0) +
        (equipment[EquipmentSlot.armor]?.statBoost ?? 0) +
        (equipment[EquipmentSlot.pants]?.statBoost ?? 0) +
        (equipment[EquipmentSlot.accessory]?.statBoost ?? 0);
  }

  @override
  List<Object?> get props => [
        lives,
        level,
        xp,
        maxXp,
        hp,
        maxHp,
        attack,
        equipment,
      ];
}

