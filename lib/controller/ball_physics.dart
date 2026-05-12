import 'dart:math';
import 'dart:ui';

/// Gestisce la fisica della pallina:
/// - accelerazione
/// - attrito
/// - limite di velocità
/// - collisioni con i muri
/// - movimento separato sugli assi X e Y (sweep per asse)
class BallPhysics {
  static MoveResult step({
    required Offset pos,
    required Offset vel,
    required Offset acc,
    required double dt,
    required double radius,
    required Rect boardRect,
    required List<Rect> walls,
    required double accelScale,
    required double friction,
    required double maxSpeed,
    required double bounce,
  }) {
    final ax = acc.dx * accelScale;
    final ay = acc.dy * accelScale;

    var vx = vel.dx + ax * dt;
    var vy = vel.dy + ay * dt;

    final damp = exp(-friction * dt);
    vx *= damp;
    vy *= damp;

    final speed = sqrt(vx * vx + vy * vy);
    if (speed > maxSpeed) {
      final k = maxSpeed / speed;
      vx *= k;
      vy *= k;
    }

    var newPos = pos;
    var newVel = Offset(vx, vy);

    final proposed = Offset(
      newPos.dx + newVel.dx * dt,
      newPos.dy + newVel.dy * dt,
    );

    final afterX = _moveAxis(
      pos: newPos,
      delta: Offset(proposed.dx - newPos.dx, 0),
      vel: newVel,
      axis: Axis.x,
      radius: radius,
      boardRect: boardRect,
      walls: walls,
      bounce: bounce,
    );
    newPos = afterX.pos;
    newVel = afterX.vel;

    final afterY = _moveAxis(
      pos: newPos,
      delta: Offset(0, proposed.dy - newPos.dy),
      vel: newVel,
      axis: Axis.y,
      radius: radius,
      boardRect: boardRect,
      walls: walls,
      bounce: bounce,
    );
    newPos = afterY.pos;
    newVel = afterY.vel;

    return MoveResult(newPos, newVel);
  }

  static MoveResult _moveAxis({
    required Offset pos,
    required Offset delta,
    required Offset vel,
    required Axis axis,
    required double radius,
    required Rect boardRect,
    required List<Rect> walls,
    required double bounce,
  }) {
    if (delta == Offset.zero) return MoveResult(pos, vel);

    const epsilon = 0.6;

    var newPos = pos + delta;
    var newVel = vel;

    Rect ballRect() => Rect.fromCircle(center: newPos, radius: radius);

    for (int i = 0; i < 4; i++) {
      final br = ballRect();
      Rect? hit;

      for (final wall in walls) {
        if (wall.overlaps(br)) {
          hit = wall;
          break;
        }
      }

      if (hit == null) break;

      if (axis == Axis.x) {
        newPos = Offset(
          delta.dx > 0 ? hit.left - radius - epsilon : hit.right + radius + epsilon,
          newPos.dy,
        );
        newVel = Offset(-newVel.dx * bounce, newVel.dy);
      } else {
        newPos = Offset(
          newPos.dx,
          delta.dy > 0 ? hit.top - radius - epsilon : hit.bottom + radius + epsilon,
        );
        newVel = Offset(newVel.dx, -newVel.dy * bounce);
      }
    }

    newPos = Offset(
      newPos.dx.clamp(boardRect.left + radius, boardRect.right - radius),
      newPos.dy.clamp(boardRect.top + radius, boardRect.bottom - radius),
    );

    return MoveResult(newPos, newVel);
  }
}

enum Axis { x, y }

class MoveResult {
  final Offset pos;
  final Offset vel;

  MoveResult(this.pos, this.vel);
}
