import 'entity.dart';
import 'package:equatable/equatable.dart';

class Particle extends Equatable {
  final String id;
  final double x;
  final double y;
  final double w;
  final double h;
  final double vx;
  final double vy;
  final double life;
  final String color;

  const Particle({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
  });

  Particle copyWith({
    String? id,
    double? x,
    double? y,
    double? w,
    double? h,
    double? vx,
    double? vy,
    double? life,
    String? color,
  }) {
    return Particle(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      life: life ?? this.life,
      color: color ?? this.color,
    );
  }
  
  Particle updatePosition(double dt) {
    return copyWith(
      x: x + vx * dt * 60,
      y: y + vy * dt * 60,
      life: life - 0.05 * dt * 60,
    );
  }

  @override
  List<Object?> get props => [id, x, y, w, h, vx, vy, life, color];
}

