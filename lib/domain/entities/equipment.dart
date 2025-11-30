import 'equipment_slot.dart';
import 'package:equatable/equatable.dart';

class Equipment extends Equatable {
  final String id;
  final String name;
  final EquipmentSlot type;
  final int statBoost;
  final String description;

  const Equipment({
    required this.id,
    required this.name,
    required this.type,
    required this.statBoost,
    required this.description,
  });

  @override
  List<Object?> get props => [id, name, type, statBoost, description];
}

