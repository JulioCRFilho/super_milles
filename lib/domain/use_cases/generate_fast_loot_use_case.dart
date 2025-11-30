import '../entities/generated_loot_data.dart';
import '../repositories/loot_repository.dart';

class GenerateFastLootUseCase {
  final LootRepository repository;

  GenerateFastLootUseCase(this.repository);

  GeneratedLootData call(int level) {
    return repository.generateFastLoot(level);
  }
}

