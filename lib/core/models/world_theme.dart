import '../../domain/entities/enemy_variant.dart';

class WorldTheme {
  final String name;
  final List<String> skyColors;
  final String ground;
  final String groundDark;
  final String grass;
  final String grassHighlight;
  final String brick;
  final String brickDark;
  final EnemyVariant enemyVariant;

  const WorldTheme({
    required this.name,
    required this.skyColors,
    required this.ground,
    required this.groundDark,
    required this.grass,
    required this.grassHighlight,
    required this.brick,
    required this.brickDark,
    required this.enemyVariant,
  });
}

