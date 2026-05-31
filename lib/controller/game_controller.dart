import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/game_model.dart';
import '../model/level_data.dart';
import 'ball_physics.dart';

/// Controller del gioco — gestisce input, livelli, timer, fisica e statistiche.
class GameController extends ChangeNotifier {
  final GameModel model;
  final String username;
  GameController(this.model, {this.username = 'guest'});

  StreamSubscription? _accSub;
  Timer? _timer;

  Rect boardRect = Rect.zero;
  Size _screenSize = Size.zero;
  DateTime _lastTick = DateTime.now();

  Offset _accFiltered = Offset.zero;
  double boardAngle = 0.0;

  // Parametri fisici base
  double accelScale = 180.0;
  double maxSpeed = 430.0;
  double _baseFriction = 5.0;
  double bounce = 0.05;
  double filterAlpha = 0.15;

  // Attrito effettivo (cambia in base alla superficie)
  double get friction => _currentFriction;
  double _currentFriction = 5.0;

  // Moltiplicatori superficie
  static const double _iceFriction  = 0.6;   // scivoloso
  static const double _mudFriction  = 22.0;  // frenante
  static const double _normalFriction = 5.0;

  // Tempo di gioco per le statistiche utente
  double _sessionSeconds = 0.0;

  // Callback per notificare eventi al layer UI
  VoidCallback? onStarCollected;
  VoidCallback? onHoleDeath;
  VoidCallback? onPortalEnter;
  void Function(double dir)? onBoardRotate;
  void Function(SurfaceType)? onSurfaceChanged;

  SurfaceType _lastSurface = SurfaceType.normal;

  LevelData get level => levels[model.levelIndex];

  // Animazione rotazione (effetto ribaltamento)
  double _rotateAnimProgress = 0.0; // 0→1 avanzamento animazione
  double _rotateAnimDir = 1.0; // +1=destra, -1=sinistra
  bool isRotating = false;
  static const double _rotateDuration = 0.35; // secondi
  double _rotateElapsed = 0.0;
  double _rotateFrom = 0.0;
  double _rotateTo = 0.0;

  void start() {
    _accSub?.cancel();
    _accSub = accelerometerEvents.listen((e) {
      final raw = Offset(-e.x, e.y);
      _accFiltered = Offset(
        _accFiltered.dx + (raw.dx - _accFiltered.dx) * filterAlpha,
        _accFiltered.dy + (raw.dy - _accFiltered.dy) * filterAlpha,
      );
    });

    _timer?.cancel();
    _lastTick = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void disposeController() {
    _accSub?.cancel();
    _timer?.cancel();
  }

  void nextLevel() {
    if (model.levelIndex < levels.length - 1) {
      model.levelIndex++;
      resetGame();
    }
  }

  void setLevel(int index) {
    model.levelIndex = index.clamp(0, levels.length - 1);
    resetGame();
  }

  void rotateBoardLeft() {
    if (isRotating) return;
    _startRotate(-pi / 2);
    onBoardRotate?.call(-1.0);
  }

  void rotateBoardRight() {
    if (isRotating) return;
    _startRotate(pi / 2);
    onBoardRotate?.call(1.0);
  }

  void _startRotate(double delta) {
    _rotateFrom = boardAngle;
    _rotateTo = boardAngle + delta;
    _rotateAnimDir = delta > 0 ? 1.0 : -1.0;
    _rotateElapsed = 0.0;
    _rotateAnimProgress = 0.0;
    isRotating = true;
    model.ballVel = Offset.zero;
  }

  void onResize(Size size) {
    _screenSize = size;
    _recalcBoardRect(size);
    _buildLevel();
    notifyListeners();
  }

  void _recalcBoardRect(Size size) {
    if (level.squareBoard) {
      final side = min(size.width * 0.88, size.height * 0.78);
      boardRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: side,
        height: side,
      );
    } else {
      boardRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.88,
        height: size.height * 0.84,
      );
    }
  }

  void resetGame() {
    model.score = 0;
    model.isDead = false;
    model.isWin = false;
    model.isTimeOver = false;
    model.ballVel = Offset.zero;
    model.trail.clear();
    _accFiltered = Offset.zero;
    boardAngle = 0.0;
    _sessionSeconds = 0.0;
    _currentFriction = _baseFriction;

    _lastSurface = SurfaceType.normal;
    model.timeLeft = level.hasTimer ? level.timeLimit : 0;
    model.makeMaze();

    if (_screenSize != Size.zero) {
      _recalcBoardRect(_screenSize);
    }

    _buildLevel();
    notifyListeners();
  }

  void _buildLevel() {
    if (boardRect == Rect.zero) return;

    final cellW = boardRect.width / model.cols;
    final cellH = boardRect.height / model.rows;
    final base = min(cellW, cellH);

    model.ballRadius = base * 0.2;
    model.startPos = _cellCenter(0, 0);
    model.goalPos = _cellCenter(model.cols - 1, model.rows - 1);
    model.ballPos = model.startPos;

    model.wallRects = _buildWalls();
    _applyLevelSurfaces();
    _applyLevelPortals();  // portali prima di _placeItems per evitare sovrapposizioni
    _placeItems();
  }

  // ── Superfici ─────────────────────────────────────────────────────────────

  void _applyLevelSurfaces() {
    model.surfaceMap.clear();
    for (final patch in level.surfaces) {
      model.surfaceMap[GameModel.surfaceKey(patch.col, patch.row)] =
          patch.type;
    }
  }

  /// Restituisce il tipo di superficie sotto la pallina
  SurfaceType _surfaceUnderBall() {
    final cellW = boardRect.width / model.cols;
    final cellH = boardRect.height / model.rows;
    final col = ((model.ballPos.dx - boardRect.left) / cellW).floor();
    final row = ((model.ballPos.dy - boardRect.top) / cellH).floor();
    if (!model.ok(col, row)) return SurfaceType.normal;
    return model.surfaceAt(col, row);
  }

  void _updateSurfaceFriction() {
    final surface = _surfaceUnderBall();
    switch (surface) {
      case SurfaceType.ice:
        _currentFriction = _iceFriction;
        break;
      case SurfaceType.mud:
        _currentFriction = _mudFriction;
        break;
      case SurfaceType.normal:
        _currentFriction = _normalFriction;
        break;
    }
    if (surface != _lastSurface) {
      _lastSurface = surface;
      onSurfaceChanged?.call(surface);
    }
  }

  // ── Portali ───────────────────────────────────────────────────────────────

  void _applyLevelPortals() {
    model.portals.clear();
    for (final def in level.portalDefs) {
      model.portals.add(Portal(
        a: _cellCenter(def.colA, def.rowA),
        b: _cellCenter(def.colB, def.rowB),
        color: def.color,
      ));
    }
  }

  void _checkPortals() {
    for (final portal in model.portals) {
      if (portal.cooldown) {
        // Resetta il cooldown se la pallina è lontana da entrambi gli ingressi
        final distA = (model.ballPos - portal.a).distance;
        final distB = (model.ballPos - portal.b).distance;
        if (distA > model.ballRadius * 3 && distB > model.ballRadius * 3) {
          portal.cooldown = false;
        }
        continue;
      }

      final distA = (model.ballPos - portal.a).distance;
      final distB = (model.ballPos - portal.b).distance;

      if (distA < model.ballRadius * 1.15) {
        model.ballPos = portal.b;
        portal.cooldown = true;
        onPortalEnter?.call();
        return;
      }
      if (distB < model.ballRadius * 1.15) {
        model.ballPos = portal.a;
        portal.cooldown = true;
        onPortalEnter?.call();
        return;
      }
    }
  }

  // ── Tick ──────────────────────────────────────────────────────────────────

  Offset _cellCenter(int x, int y) {
    final cellW = boardRect.width / model.cols;
    final cellH = boardRect.height / model.rows;
    return Offset(
      boardRect.left + (x + 0.5) * cellW,
      boardRect.top + (y + 0.5) * cellH,
    );
  }

  List<Rect> _buildWalls() {
    final walls = <Rect>[];
    final cellW = boardRect.width / model.cols;
    final cellH = boardRect.height / model.rows;
    final t = max(2.0, min(cellW, cellH) * 0.07);

    walls.add(Rect.fromLTWH(boardRect.left, boardRect.top, boardRect.width, t));
    walls.add(Rect.fromLTWH(boardRect.left, boardRect.bottom - t, boardRect.width, t));
    walls.add(Rect.fromLTWH(boardRect.left, boardRect.top, t, boardRect.height));
    walls.add(Rect.fromLTWH(boardRect.right - t, boardRect.top, t, boardRect.height));

    for (int y = 0; y < model.rows; y++) {
      for (int x = 0; x < model.cols - 1; x++) {
        if (model.cell(x, y).open[1]) continue;
        final wallX = boardRect.left + (x + 1) * cellW;
        walls.add(Rect.fromLTWH(wallX - t / 2, boardRect.top + y * cellH, t, cellH));
      }
    }

    for (int y = 0; y < model.rows - 1; y++) {
      for (int x = 0; x < model.cols; x++) {
        if (model.cell(x, y).open[2]) continue;
        final wallY = boardRect.top + (y + 1) * cellH;
        walls.add(Rect.fromLTWH(boardRect.left + x * cellW, wallY - t / 2, cellW, t));
      }
    }

    return walls;
  }

  void _placeItems() {
    model.holes = [];
    model.stars = [];

    // Raccoglie tutte le posizioni dei portali, da evitare durante il posizionamento
    final portalPositions = <Offset>[
      for (final p in model.portals) p.a,
      for (final p in model.portals) p.b,
    ];
    // Distanza di sicurezza dai portali: raggio pallina × 6 (circa una cella e mezza)
    final portalSafeR = model.ballRadius * 6;

    bool nearPortal(Offset pos) =>
        portalPositions.any((p) => (pos - p).distance < portalSafeR);

    final candidates = <Point<int>>[];
    for (int y = 0; y < model.rows; y++) {
      for (int x = 0; x < model.cols; x++) {
        if (!(x == 0 && y == 0) &&
            !(x == model.cols - 1 && y == model.rows - 1)) {
          candidates.add(Point(x, y));
        }
      }
    }
    candidates.shuffle(model.rng);

    if (level.hasHoles) {
      int i = 0;
      while (model.holes.length < 5 && i < candidates.length) {
        final p = candidates[i++];
        final h = _randomPointInCell(p.x, p.y);
        if (model.holes.any((o) => (h - o).distance < model.ballRadius * 12)) continue;
        if (nearPortal(h)) continue; // le trappole non possono stare vicino ai portali
        model.holes.add(h);
      }
    }

    int tries = 0;
    while (model.stars.length < 3 && tries < 200) {
      tries++;
      final x = model.rng.nextInt(model.cols);
      final y = model.rng.nextInt(model.rows);
      if ((x == 0 && y == 0) || (x == model.cols - 1 && y == model.rows - 1)) continue;
      final s = _randomPointInCell(x, y);
      if (model.holes.any((h) => (s - h).distance < model.ballRadius * 8)) continue;
      if (model.stars.any((o) => (s - o).distance < model.ballRadius * 12)) continue;
      if (nearPortal(s)) continue; // ⭐ le stelle non possono comparire sopra i portali
      model.stars.add(s);
    }
  }

  Offset _randomPointInCell(int x, int y) {
    final cellW = boardRect.width / model.cols;
    final cellH = boardRect.height / model.rows;
    final margin = model.ballRadius * 2;
    final left = boardRect.left + x * cellW + margin;
    final top = boardRect.top + y * cellH + margin;
    final right = boardRect.left + (x + 1) * cellW - margin;
    final bottom = boardRect.top + (y + 1) * cellH - margin;
    return Offset(
      left + model.rng.nextDouble() * max(1.0, right - left),
      top + model.rng.nextDouble() * max(1.0, bottom - top),
    );
  }

  Offset _screenDownInBoardLocal() {
    const g = Offset(0, 1.7);
    final c = cos(-boardAngle);
    final s = sin(-boardAngle);
    return Offset(g.dx * c - g.dy * s, g.dx * s + g.dy * c);
  }

  void _tick() {
    if (boardRect == Rect.zero || model.isDead || model.isWin) return;

    final now = DateTime.now();
    double dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    _lastTick = now;
    dt = dt.clamp(0.0, 0.033);

    _sessionSeconds += dt;

    // Animazione rotazione
    if (isRotating) {
      _rotateElapsed += dt;
      final p = (_rotateElapsed / _rotateDuration).clamp(0.0, 1.0);
      // Curva easeInOutCubic
      _rotateAnimProgress = p;
      final eased = p < 0.5
          ? 4 * p * p * p
          : 1 - pow(-2 * p + 2, 3) / 2;
      boardAngle = _rotateFrom + (_rotateTo - _rotateFrom) * eased;
      if (p >= 1.0) {
        boardAngle = _rotateTo;
        isRotating = false;
        _rotateElapsed = 0.0;
      }
    }



    if (level.hasTimer) {
      model.timeLeft -= dt;
      if (model.timeLeft <= 0) {
        model.timeLeft = 0;
        model.isTimeOver = true;
        model.isDead = true;
        notifyListeners();
        return;
      }
    }

    // Aggiorna attrito superficie
    _updateSurfaceFriction();

    final inputAcc = level.controlMode == ControlMode.tilt
        ? _accFiltered
        : _screenDownInBoardLocal();

    final result = BallPhysics.step(
      pos: model.ballPos,
      vel: model.ballVel,
      acc: inputAcc,
      dt: dt,
      radius: model.ballRadius,
      boardRect: boardRect,
      walls: model.wallRects,
      accelScale: accelScale,
      friction: _currentFriction,
      maxSpeed: maxSpeed,
      bounce: bounce,
    );

    model.ballPos = result.pos;
    model.ballVel = result.vel;

    // Aggiorna la scia
    model.trail.add(model.ballPos);
    if (model.trail.length > GameModel.trailLength) {
      model.trail.removeAt(0);
    }

    // Controlla portali
    _checkPortals();

    _checkItemsAndGoal();
    notifyListeners();
  }

  void _checkItemsAndGoal() {
    final r = model.ballRadius;

    // Raccolta stelle
    final starsBefore = model.stars.length;
    model.stars.removeWhere((s) {
      if ((s - model.ballPos).distance <= r * 1.3) {
        model.score += 10;
        return true;
      }
      return false;
    });
    if (model.stars.length < starsBefore) {
      onStarCollected?.call();
    }

    // Caduta nei buchi
    for (final h in model.holes) {
      if ((h - model.ballPos).distance <= r * 0.95) {
        model.isDead = true;
        onHoleDeath?.call();
        return;
      }
    }

    // Traguardo
    if ((model.goalPos - model.ballPos).distance <= r * 1.5) {
      if (!model.isWin) {
        model.isWin = true;
        _saveBestStars();
      }
    }
  }

  int get currentStars => (model.score ~/ 10).clamp(0, 3);

  String get currentStarsText =>
      List.generate(3, (i) => i < currentStars ? '★' : '☆').join();

  int get sessionSeconds => _sessionSeconds.toInt();

  Future<void> _saveBestStars() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${username}_level_${level.number}_stars';
    final oldStars = prefs.getInt(key) ?? 0;
    if (currentStars > oldStars) {
      await prefs.setInt(key, currentStars);
    }
  }
}