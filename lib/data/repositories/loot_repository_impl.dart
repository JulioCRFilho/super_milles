import '../../domain/entities/generated_loot_data.dart';
import '../../domain/entities/equipment_slot.dart';
import '../../domain/repositories/loot_repository.dart';
import '../data_sources/gemini_data_source.dart';

class LootRepositoryImpl implements LootRepository {
  final GeminiDataSource geminiDataSource;

  LootRepositoryImpl(this.geminiDataSource);

  @override
  Future<GeneratedLootData> generateLoot(int level) async {
    try {
      return await geminiDataSource.generateLoot(level);
    } catch (e) {
      // Fallback to fast loot on error
      return generateFastLoot(level);
    }
  }

  @override
  GeneratedLootData generateFastLoot(int level) {
    // 5% chance for a 1-UP
    if (0.95 < (DateTime.now().millisecondsSinceEpoch % 100) / 100) {
      return GeneratedLootData(
        name: "COGUMELO VIDA",
        type: EquipmentSlot.life,
        statBoost: 1,
        description: "Garante uma vida extra!",
      );
    }

    final materials = ["Couro", "Ferro", "Aço", "Mithril", "Ouro", "Diamante"];
    final material = materials[((level / 3).floor()).clamp(0, materials.length - 1)];

    final slots = [
      EquipmentSlot.boots,
      EquipmentSlot.helmet,
      EquipmentSlot.armor,
      EquipmentSlot.pants,
      EquipmentSlot.gloves,
      EquipmentSlot.accessory,
    ];
    final type = slots[DateTime.now().millisecondsSinceEpoch % slots.length];

    String name = "";
    switch (type) {
      case EquipmentSlot.boots:
        name = "Botas de $material";
        break;
      case EquipmentSlot.helmet:
        name = "Capacete de $material";
        break;
      case EquipmentSlot.armor:
        name = "Peitoral de $material";
        break;
      case EquipmentSlot.pants:
        name = "Calças de $material";
        break;
      case EquipmentSlot.gloves:
        name = "Luvas de $material";
        break;
      case EquipmentSlot.accessory:
        name = "Anel de $material";
        break;
      default:
        name = "Item de $material";
    }

    final baseStat = (level / 2).floor().clamp(1, double.infinity).toInt();
    final variation = (DateTime.now().millisecondsSinceEpoch % 3).toInt();

    return GeneratedLootData(
      name: name,
      type: type,
      statBoost: baseStat + variation,
      description: "Um item feito de ${material.toLowerCase()}.",
    );
  }
}

