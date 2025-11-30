import 'enemy_variant.dart';
import 'package:equatable/equatable.dart';

enum EntityType {
  player,
  enemy,
  particle,
}

class Entity extends Equatable {
  final String id;
  final EntityType type;
  final double x;
  final double y;
  final double w;
  final double h;
  final double vx;
  final double vy;
  final int facing; // 1 or -1
  
  // Enemy specific
  final bool isDead;
  final int? hp;
  final int? maxHp;
  final bool isBoss;
  final EnemyVariant? variant;
  final double? originalX;
  final double? originalY;
  final int? respawnTime;
  final bool isLooted;

  const Entity({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.vx,
    required this.vy,
    this.facing = 1,
    this.isDead = false,
    this.hp,
    this.maxHp,
    this.isBoss = false,
    this.variant,
    this.originalX,
    this.originalY,
    this.respawnTime,
    this.isLooted = false,
  });

  Entity copyWith({
    String? id,
    EntityType? type,
    double? x,
    double? y,
    double? w,
    double? h,
    double? vx,
    double? vy,
    int? facing,
    bool? isDead,
    int? hp,
    int? maxHp,
    bool? isBoss,
    EnemyVariant? variant,
    double? originalX,
    double? originalY,
    int? respawnTime,
    bool? isLooted,
  }) {
    return Entity(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      facing: facing ?? this.facing,
      isDead: isDead ?? this.isDead,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      isBoss: isBoss ?? this.isBoss,
      variant: variant ?? this.variant,
      originalX: originalX ?? this.originalX,
      originalY: originalY ?? this.originalY,
      respawnTime: respawnTime ?? this.respawnTime,
      isLooted: isLooted ?? this.isLooted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        x,
        y,
        w,
        h,
        vx,
        vy,
        facing,
        isDead,
        hp,
        maxHp,
        isBoss,
        variant,
        originalX,
        originalY,
        respawnTime,
        isLooted,
      ];
}

