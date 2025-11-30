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
  GeneratedLootData generateFastLoot(int level, {String rarity = 'normal'}) {
    final slots = [
      EquipmentSlot.boots,
      EquipmentSlot.helmet,
      EquipmentSlot.armor,
      EquipmentSlot.pants,
      EquipmentSlot.gloves,
      EquipmentSlot.accessory,
    ];
    final random = DateTime.now().millisecondsSinceEpoch;
    final type = slots[random % slots.length];

    String material;
    int statBoost;
    String description;
    String name;

    switch (rarity) {
      case 'legendary':
        material = "Élfico";
        statBoost = (level * 2.5).floor().clamp(1, 999) + (random % 5);
        description = "Um artefato lendário de poder imenso!";
        break;
      case 'rare':
        material = "Mithril";
        statBoost = (level * 1.5).floor().clamp(1, 999) + (random % 3);
        description = "Um item raro de qualidade excepcional!";
        break;
      case 'normal':
      default:
        final materials = ["Couro", "Ferro", "Aço", "Ouro"];
        material = materials[((level / 3).floor()).clamp(0, materials.length - 1)];
        statBoost = (level / 2).floor().clamp(1, 999) + (random % 3);
        description = "Um item feito de ${material.toLowerCase()}.";
        break;
    }

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

    return GeneratedLootData(
      name: name,
      type: type,
      statBoost: statBoost,
      description: description,
    );
  }
}

