import 'equipment_slot.dart';
import 'package:equatable/equatable.dart';

class GeneratedLootData extends Equatable {
  final String name;
  final EquipmentSlot type;
  final int statBoost;
  final String description;

  const GeneratedLootData({
    required this.name,
    required this.type,
    required this.statBoost,
    required this.description,
  });

  @override
  List<Object?> get props => [name, type, statBoost, description];
}

