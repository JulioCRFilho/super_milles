import '../entities/generated_loot_data.dart';

abstract class LootRepository {
  Future<GeneratedLootData> generateLoot(int level);
  GeneratedLootData generateFastLoot(int level, {String rarity = 'normal'});
}

