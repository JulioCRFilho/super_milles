import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'game_world.dart';
import '../hud/hud_widget.dart';
import '../loot/loot_modal.dart';
import '../menu/game_over_screen.dart';
import '../menu/level_complete_screen.dart';
import '../providers/game_providers.dart';
import '../../domain/entities/game_state.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final game = GameWorld(ref: ref);

    return Scaffold(
      body: Stack(
        children: [
          // Game
          GameWidget(game: game),

          // HUD
          const HUDWidget(),

          // Modals
          if (gameState == GameState.lootModal) const LootModal(),

          if (gameState == GameState.gameOver) const GameOverScreen(),

          if (gameState == GameState.levelComplete) const LevelCompleteScreen(),
        ],
      ),
    );
  }
}
