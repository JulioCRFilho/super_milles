import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart' show StateProvider, StateNotifierProvider;
import 'package:state_notifier/state_notifier.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/particle.dart';
import '../../domain/entities/floating_text.dart';
import '../../domain/entities/generated_loot_data.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/equipment_slot.dart';
import '../../domain/repositories/loot_repository.dart';
import '../../data/repositories/loot_repository_impl.dart';
import '../../data/data_sources/gemini_data_source.dart';
import '../../domain/use_cases/generate_loot_use_case.dart';
import '../../domain/use_cases/generate_fast_loot_use_case.dart';
import '../../core/constants/game_constants.dart';

// Loot Repository Provider
final lootRepositoryProvider = Provider<LootRepository>((ref) {
  // Get API key from environment or config
  const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  return LootRepositoryImpl(GeminiDataSource(apiKey: apiKey.isEmpty ? null : apiKey));
});

// Use Cases
final generateLootUseCaseProvider = Provider<GenerateLootUseCase>((ref) {
  return GenerateLootUseCase(ref.watch(lootRepositoryProvider));
});

final generateFastLootUseCaseProvider = Provider<GenerateFastLootUseCase>((ref) {
  return GenerateFastLootUseCase(ref.watch(lootRepositoryProvider));
});

// Game State
final gameStateProvider = StateProvider<GameState>((ref) => GameState.playing);

// Stage
final stageProvider = StateProvider<int>((ref) => 1);

// Player Stats
final playerStatsProvider = StateNotifierProvider<PlayerStatsNotifier, PlayerStats>((ref) {
  return PlayerStatsNotifier();
});

class PlayerStatsNotifier extends StateNotifier<PlayerStats> {
  PlayerStatsNotifier()
      : super(PlayerStats(
          lives: GameConstants.initialLives,
          level: 1,
          xp: 0,
          maxXp: 300,
          hp: 3,
          maxHp: 3,
          attack: 1,
          equipment: {},
        ));

  void reset() {
    state = PlayerStats(
      lives: GameConstants.initialLives,
      level: 1,
      xp: 0,
      maxXp: 300,
      hp: 3,
      maxHp: 3,
      attack: 1,
      equipment: {},
    );
  }

  void updateStats(PlayerStats stats) {
    state = stats;
  }

  void addXp(int amount) {
    var newXp = state.xp + amount;
    var newLevel = state.level;
    var newMaxXp = state.maxXp;
    var newMaxHp = state.maxHp;
    var newHp = state.hp;

    if (newXp >= state.maxXp) {
      newXp -= state.maxXp;
      newLevel++;
      newMaxHp++;
      newHp = newMaxHp;
      newMaxXp = (newMaxXp * 1.5).floor();
    }

    state = state.copyWith(
      xp: newXp,
      level: newLevel,
      maxXp: newMaxXp,
      maxHp: newMaxHp,
      hp: newHp,
    );
  }

  void takeDamage(int damage) {
    state = state.copyWith(hp: (state.hp - damage).clamp(0, state.maxHp));
  }

  void heal(int amount) {
    state = state.copyWith(hp: (state.hp + amount).clamp(0, state.maxHp));
  }

  void loseLife() {
    state = state.copyWith(lives: state.lives - 1);
  }

  void addLife() {
    state = state.copyWith(lives: state.lives + 1);
  }

  void equipItem(GeneratedLootData loot) {
    if (loot.type == EquipmentSlot.life) {
      addLife();
    } else {
      final equipment = Map<EquipmentSlot, Equipment>.from(state.equipment);
      // Convert GeneratedLootData to Equipment
      final equipmentItem = Equipment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: loot.name,
        type: loot.type,
        statBoost: loot.statBoost,
        description: loot.description,
      );
      equipment[loot.type] = equipmentItem;
      state = state.copyWith(equipment: Map<EquipmentSlot, Equipment>.from(equipment));
    }
  }
}

// Player Entity
final playerProvider = StateNotifierProvider<PlayerNotifier, Entity>((ref) {
  return PlayerNotifier();
});

class PlayerNotifier extends StateNotifier<Entity> {
  PlayerNotifier()
      : super(Entity(
          id: 'p1',
          type: EntityType.player,
          x: GameConstants.playerStartX,
          y: GameConstants.playerStartY,
          w: GameConstants.playerWidth,
          h: GameConstants.playerHeight,
          vx: 0,
          vy: 0,
          facing: 1,
        ));

  void reset() {
    state = Entity(
      id: 'p1',
      type: EntityType.player,
      x: GameConstants.playerStartX,
      y: GameConstants.playerStartY,
      w: GameConstants.playerWidth,
      h: GameConstants.playerHeight,
      vx: 0,
      vy: 0,
      facing: 1,
    );
  }

  void update(Entity entity) {
    state = entity;
  }
}

// Enemies
final enemiesProvider = StateNotifierProvider<EnemiesNotifier, List<Entity>>((ref) {
  return EnemiesNotifier();
});

class EnemiesNotifier extends StateNotifier<List<Entity>> {
  EnemiesNotifier() : super([]);

  void setEnemies(List<Entity> enemies) {
    state = enemies;
  }

  void updateEnemy(Entity enemy) {
    state = state.map((e) => e.id == enemy.id ? enemy : e).toList();
  }

  void removeEnemy(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

// Particles
final particlesProvider = StateNotifierProvider<ParticlesNotifier, List<Particle>>((ref) {
  return ParticlesNotifier();
});

class ParticlesNotifier extends StateNotifier<List<Particle>> {
  ParticlesNotifier() : super([]);

  void addParticle(Particle particle) {
    state = [...state, particle];
  }

  void updateParticles(List<Particle> updated) {
    state = updated;
  }

  void clear() {
    state = [];
  }
}

// Floating Texts
final floatingTextsProvider = StateNotifierProvider<FloatingTextsNotifier, List<FloatingText>>((ref) {
  return FloatingTextsNotifier();
});

class FloatingTextsNotifier extends StateNotifier<List<FloatingText>> {
  FloatingTextsNotifier() : super([]);

  void addText(FloatingText text) {
    state = [...state, text];
  }

  void updateTexts(List<FloatingText> updated) {
    state = updated;
  }

  void clear() {
    state = [];
  }
}

// Auto Loot
final autoLootProvider = StateProvider<bool>((ref) => false);

// Found Loot
final foundLootProvider = StateProvider<GeneratedLootData?>((ref) => null);

// Loot Target
final lootTargetIdProvider = StateProvider<String?>((ref) => null);

// Loading Loot
final isLoadingLootProvider = StateProvider<bool>((ref) => false);

