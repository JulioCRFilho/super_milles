import 'package:equatable/equatable.dart';

class FloatingText extends Equatable {
  final String id;
  final double x;
  final double y;
  final String text;
  final double life;
  final String color;
  final double vy;

  const FloatingText({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    required this.life,
    required this.color,
    required this.vy,
  });

  FloatingText copyWith({
    String? id,
    double? x,
    double? y,
    String? text,
    double? life,
    String? color,
    double? vy,
  }) {
    return FloatingText(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      text: text ?? this.text,
      life: life ?? this.life,
      color: color ?? this.color,
      vy: vy ?? this.vy,
    );
  }
  
  FloatingText updatePosition(double dt) {
    return copyWith(
      y: y + vy * dt * 60,
      life: life - 0.02 * dt * 60,
    );
  }

  @override
  List<Object?> get props => [id, x, y, text, life, color, vy];
}

