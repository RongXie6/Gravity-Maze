import 'dart:math';
import 'dart:ui';

// ── Tipo di superficie ──────────────────────────────────────────────────────
enum SurfaceType { normal, ice, mud }

// ── Portale (coppia A→B) ─────────────────────────────────────────────────────
class Portal {
  final Offset a;
  final Offset b;
  final Color color;
  bool cooldown = false; // evita loop continui

  Portal({required this.a, required this.b, required this.color});
}

/// Modello principale del gioco.
/// Contiene stato del labirinto, pallina, stelle, buchi e livello.
class GameModel {
  final int cols;
  final int rows;
  final Random rng;

  /// Dati usati da controller e painter.
  List<Rect> wallRects = [];
  List<Offset> holes = [];
  List<Offset> stars = [];

  /// Superfici speciali: mappa (col, row) → tipo
  Map<String, SurfaceType> surfaceMap = {};

  /// Portali
  List<Portal> portals = [];

  /// Scia della pallina — ultimi N framerow
  static const int trailLength = 22;
  final List<Offset> trail = [];

  /// Stato della pallina.
  double ballRadius = 8;
  Offset ballPos = Offset.zero;
  Offset ballVel = Offset.zero;

  /// Posizioni di inizio e fine.
  Offset startPos = Offset.zero;
  Offset goalPos = Offset.zero;

  /// Stato della partita.
  int score = 0;
  bool isDead = false;
  bool isWin = false;

  /// Stato del livello.
  int levelIndex = 0;
  double timeLeft = 0;
  bool isTimeOver = false;

  /// Griglia del labirinto.
  late List<List<Cell>> grid;

  GameModel({
    required this.cols,
    required this.rows,
    Random? rng,
  }) : rng = rng ?? Random() {
    grid = List.generate(
      rows,
      (y) => List.generate(cols, (x) => Cell(x, y)),
    );
  }

  Cell cell(int x, int y) => grid[y][x];

  bool ok(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;

  /// Chiave stringa per la mappa superfici
  static String surfaceKey(int col, int row) => '$col,$row';

  SurfaceType surfaceAt(int col, int row) =>
      surfaceMap[surfaceKey(col, row)] ?? SurfaceType.normal;

  /// Genera il labirinto con DFS ricorsiva.
  void makeMaze() {
    for (final row in grid) {
      for (final c in row) {
        c.visited = false;
        c.open = [false, false, false, false];
      }
    }
    surfaceMap.clear();
    portals.clear();
    trail.clear();

    final start = cell(0, 0);
    start.visited = true;
    _dfs(start);
  }

  void _dfs(Cell cur) {
    while (true) {
      final nexts = <(Dir, Cell)>[];

      if (ok(cur.x, cur.y - 1) && !cell(cur.x, cur.y - 1).visited)
        nexts.add((Dir.n, cell(cur.x, cur.y - 1)));
      if (ok(cur.x + 1, cur.y) && !cell(cur.x + 1, cur.y).visited)
        nexts.add((Dir.e, cell(cur.x + 1, cur.y)));
      if (ok(cur.x, cur.y + 1) && !cell(cur.x, cur.y + 1).visited)
        nexts.add((Dir.s, cell(cur.x, cur.y + 1)));
      if (ok(cur.x - 1, cur.y) && !cell(cur.x - 1, cur.y).visited)
        nexts.add((Dir.w, cell(cur.x - 1, cur.y)));

      if (nexts.isEmpty) return;

      final pick = nexts[rng.nextInt(nexts.length)];
      final dir = pick.$1;
      final nxt = pick.$2;

      _open(cur, nxt, dir);
      nxt.visited = true;
      _dfs(nxt);
    }
  }

  void _open(Cell a, Cell b, Dir dir) {
    switch (dir) {
      case Dir.n:
        a.open[0] = true;
        b.open[2] = true;
        break;
      case Dir.e:
        a.open[1] = true;
        b.open[3] = true;
        break;
      case Dir.s:
        a.open[2] = true;
        b.open[0] = true;
        break;
      case Dir.w:
        a.open[3] = true;
        b.open[1] = true;
        break;
    }
  }
}

class Cell {
  final int x;
  final int y;

  bool visited = false;

  /// Lati aperti: N, E, S, W.
  List<bool> open = [false, false, false, false];

  Cell(this.x, this.y);
}

enum Dir { n, e, s, w }
