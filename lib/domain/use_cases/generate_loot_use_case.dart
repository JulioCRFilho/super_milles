import '../entities/generated_loot_data.dart';
import '../repositories/loot_repository.dart';

class GenerateLootUseCase {
  final LootRepository repository;

  GenerateLootUseCase(this.repository);

  Future<GeneratedLootData> call(int level) {
    return repository.generateLoot(level);
  }
}

