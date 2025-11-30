class GameConstants {
  // Physics
  static const double tileSize = 48.0;
  static const double gravity = 0.65;
  static const double jumpForce = -14.0;
  static const double moveSpeed = 6.0;
  static const double friction = 0.85;
  static const double enemySpeedBase = 2.0;
  
  // Level Generation
  static const int levelWidthBase = 150;
  static const int levelHeight = 12; // 12 tiles high
  static const int levelsPerWorld = 13;
  static const int respawnTimeMs = 30000; // 30 seconds
  static const int initialLives = 3;
  
  // Player
  static const double playerWidth = 32.0;
  static const double playerHeight = 44.0;
  static const double playerStartX = 100.0;
  static const double playerStartY = 100.0;
  
  // Enemy
  static const double enemyWidth = 32.0;
  static const double enemyHeight = 32.0;
  static const double bossWidth = 64.0;
  static const double bossHeight = 64.0;
}

