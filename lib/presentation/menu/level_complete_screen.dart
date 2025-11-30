import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import '../../core/constants/game_constants.dart';

class LevelCompleteScreen extends ConsumerWidget {
  const LevelCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(stageProvider);
    final levelNum = ((stage - 1) % GameConstants.levelsPerWorld) + 1;
    final isWorldClear = levelNum == GameConstants.levelsPerWorld;

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Text(
          isWorldClear ? 'MUNDO COMPLETADO!' : 'FASE COMPLETADA!',
          style: const TextStyle(
            color: Colors.yellow,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

