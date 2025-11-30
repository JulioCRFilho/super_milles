import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import '../../domain/entities/game_state.dart';

class GameOverScreen extends ConsumerWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'FIM DE JOGO',
              style: TextStyle(
                color: Colors.red,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Reset all game state
                ref.read(playerStatsProvider.notifier).reset();
                ref.read(playerProvider.notifier).reset();
                ref.read(enemiesProvider.notifier).setEnemies([]);
                ref.read(particlesProvider.notifier).clear();
                ref.read(floatingTextsProvider.notifier).clear();
                ref.read(stageProvider.notifier).state = 1;
                ref.read(gameStateProvider.notifier).state = GameState.playing;
                // Level will be reinitialized by GameScreen's useEffect when state changes to playing
              },
              child: const Text('REINICIAR'),
            ),
          ],
        ),
      ),
    );
  }
}

