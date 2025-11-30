import '../entities/generated_loot_data.dart';
import '../repositories/loot_repository.dart';

class GenerateFastLootUseCase {
  final LootRepository repository;

  GenerateFastLootUseCase(this.repository);

  GeneratedLootData call(int level, {String rarity = 'normal'}) {
    return repository.generateFastLoot(level, rarity: rarity);
  }
}

