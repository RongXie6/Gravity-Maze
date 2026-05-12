import 'dart:ui';

import 'game_model.dart';

enum ControlMode {
  tilt,
  flip,
}

class SurfacePatch {
  final int col;
  final int row;
  final SurfaceType type;
  const SurfacePatch(this.col, this.row, this.type);
}

class PortalDef {
  final int colA, rowA, colB, rowB;
  final Color color;
  const PortalDef(this.colA, this.rowA, this.colB, this.rowB, this.color);
}

class LevelData {
  final int number;
  final bool hasHoles;
  final bool hasTimer;
  final bool squareBoard;
  final ControlMode controlMode;
  final double timeLimit;
  final List<SurfacePatch> surfaces;
  final List<PortalDef> portalDefs;
  final bool isTutorial;

  const LevelData({
    required this.number,
    required this.hasHoles,
    required this.hasTimer,
    required this.squareBoard,
    required this.controlMode,
    this.timeLimit = 0,
    this.surfaces = const [],
    this.portalDefs = const [],
    this.isTutorial = false,
  });
}

// Coordinate griglia:
// Livelli normali → col 0-4, row 0-6 (5×7)
// Livelli flip → col 0-4, row 0-4 (5×5)
// Start=(0,0), Goal=(4,6) oppure (4,4)

const levels = <LevelData>[

  // ══════════════════════════════════════════════════════════
  // Livello 1 — Tutorial, nessun ostacolo
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 1,
    hasHoles: false,
    hasTimer: false,
    squareBoard: false,
    controlMode: ControlMode.tilt,
    isTutorial: true,
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 2 — Prima esperienza con il ghiaccio (5×7)
  // Alcune caselle ghiacciate al centro della mappa:
  // la pallina scivola quando le attraversa
  //
  //   0  1  2  3  4
  // 0 .  I  I  I  .
  // 1 .  I  I  .  .
  // 2 .  .  .  I  I
  // 3 .  .  .  I  .
  // 4 .  .  .  .  .
  // 5 I  I  .  .  .
  // 6 I  .  .  .  .
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 2,
    hasHoles: true,
    hasTimer: false,
    squareBoard: false,
    controlMode: ControlMode.tilt,
    surfaces: [
      SurfacePatch(1, 0, SurfaceType.ice),
      SurfacePatch(2, 0, SurfaceType.ice),
      SurfacePatch(3, 0, SurfaceType.ice),
      SurfacePatch(1, 1, SurfaceType.ice),
      SurfacePatch(2, 1, SurfaceType.ice),
      SurfacePatch(3, 2, SurfaceType.ice),
      SurfacePatch(4, 2, SurfaceType.ice),
      SurfacePatch(3, 3, SurfaceType.ice),
      SurfacePatch(0, 3, SurfaceType.ice),
      SurfacePatch(0, 5, SurfaceType.ice),
      SurfacePatch(1, 5, SurfaceType.ice),
      SurfacePatch(0, 6, SurfaceType.ice),
    ],
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 3 — Timer + ghiaccio + trappole (5×7)
  // Una fascia ghiacciata attraversa il centro della mappa.
  // Controllo difficile sotto pressione: 40 secondi.
  //
  //   0  1  2  3  4
  // 0 .  .  .  .  .
  // 1 I  I  I  .  .
  // 2 I  I  I  I  .
  // 3 .  .  I  I  I
  // 4 .  .  .  .  .
  // 5 .  .  I  I  .
  // 6 .  .  .  .  .
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 3,
    hasHoles: true,
    hasTimer: true,
    timeLimit: 40,
    squareBoard: false,
    controlMode: ControlMode.tilt,
    surfaces: [
      SurfacePatch(0, 1, SurfaceType.ice),
      SurfacePatch(1, 1, SurfaceType.ice),
      SurfacePatch(2, 1, SurfaceType.ice),
      SurfacePatch(0, 2, SurfaceType.ice),
      SurfacePatch(1, 2, SurfaceType.ice),
      SurfacePatch(2, 2, SurfaceType.ice),
      SurfacePatch(3, 2, SurfaceType.ice),
      SurfacePatch(2, 3, SurfaceType.ice),
      SurfacePatch(3, 3, SurfaceType.ice),
      SurfacePatch(4, 3, SurfaceType.ice),
      SurfacePatch(2, 5, SurfaceType.ice),
      SurfacePatch(3, 5, SurfaceType.ice),
    ],
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 4 — Portali + fango (5×7)
  // I livelli con fango devono avere un timer
  //
  // Logica del livello:
  // - Il fango blocca il passaggio centrale
  // - Portale A: (0,3)↔(4,3)
  // - Portale B: (0,1)↔(4,5)
  // - Il giocatore può:
  //   • attraversare il fango
  //   • usare i portali per aggirarlo
  //
  //   0  1  2  3  4
  // 0 S  .  .  .  .
  // 1 P  .  .  .  P
  // 2 .  M  M  M  .
  // 3 P  M  M  .  P
  // 4 .  .  .  .  .
  // 5 .  .  .  .  P
  // 6 .  .  .  .  E
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 4,
    hasHoles: false,
    hasTimer: true,
    timeLimit: 45,
    squareBoard: false,
    controlMode: ControlMode.tilt,
    surfaces: [
      SurfacePatch(1, 2, SurfaceType.mud),
      SurfacePatch(2, 2, SurfaceType.mud),
      SurfacePatch(3, 2, SurfaceType.mud),
      SurfacePatch(1, 3, SurfaceType.mud),
      SurfacePatch(2, 3, SurfaceType.mud),
    ],
    portalDefs: [
      PortalDef(0, 3, 4, 3, Color(0xFF9C27B0)),
      PortalDef(0, 1, 4, 5, Color(0xFF00BCD4)),
    ],
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 5 — Prima esperienza con il flip (5×5)
  // Nessun effetto speciale sul terreno
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 5,
    hasHoles: true,
    hasTimer: false,
    squareBoard: true,
    controlMode: ControlMode.flip,
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 6 — Flip + fango + portali (5×5)
  // I livelli con fango devono avere un timer
  //
  // Il fango blocca il lato sinistro della mappa.
  // I portali permettono di aggirare l’ostacolo.
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 6,
    hasHoles: false,
    hasTimer: true,
    squareBoard: true,
    controlMode: ControlMode.flip,
    timeLimit: 40,
    surfaces: [
      SurfacePatch(0, 2, SurfaceType.mud),
      SurfacePatch(1, 2, SurfaceType.mud),
      SurfacePatch(0, 3, SurfaceType.mud),
      SurfacePatch(1, 3, SurfaceType.mud),
    ],
    portalDefs: [
      PortalDef(0, 1, 3, 3, Color(0xFF9C27B0)),
      PortalDef(4, 1, 2, 4, Color(0xFFFF5722)),
    ],
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 7 — Flip + ghiaccio + trappole (5×5)
  // Ampia zona ghiacciata al centro:
  // la pallina può perdere facilmente il controllo
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 7,
    hasHoles: true,
    hasTimer: false,
    squareBoard: true,
    controlMode: ControlMode.flip,
    surfaces: [
      SurfacePatch(3, 0, SurfaceType.ice),
      SurfacePatch(4, 0, SurfaceType.ice),
      SurfacePatch(1, 1, SurfaceType.ice),
      SurfacePatch(2, 1, SurfaceType.ice),
      SurfacePatch(3, 1, SurfaceType.ice),
      SurfacePatch(1, 4, SurfaceType.ice),
      SurfacePatch(0, 5, SurfaceType.ice),
      SurfacePatch(0, 5, SurfaceType.ice),
      SurfacePatch(2, 4, SurfaceType.ice),
      SurfacePatch(1, 2, SurfaceType.ice),
      SurfacePatch(2, 2, SurfaceType.ice),
      SurfacePatch(3, 2, SurfaceType.ice),
      SurfacePatch(2, 3, SurfaceType.ice),
    ],
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 8 — Flip + ghiaccio + portali + timer (5×5)
  // Il ghiaccio spinge la pallina verso i portali:
  // bisogna sfruttare bene l’inerzia
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 8,
    hasHoles: true,
    hasTimer: true,
    squareBoard: true,
    controlMode: ControlMode.flip,
    timeLimit: 35,
    surfaces: [
      SurfacePatch(1, 0, SurfaceType.ice),
      SurfacePatch(2, 0, SurfaceType.ice),
      SurfacePatch(3, 0, SurfaceType.ice),
      SurfacePatch(1, 1, SurfaceType.ice),
      SurfacePatch(2, 1, SurfaceType.ice),
      SurfacePatch(2, 2, SurfaceType.ice),
      SurfacePatch(3, 2, SurfaceType.ice),
      SurfacePatch(3, 3, SurfaceType.ice),
      SurfacePatch(4, 3, SurfaceType.ice),
      SurfacePatch(0, 6, SurfaceType.ice),
      SurfacePatch(0, 5, SurfaceType.ice),
    ],
    portalDefs: [
      PortalDef(0, 2, 4, 2, Color(0xFF9C27B0)),
      PortalDef(0, 4, 4, 0, Color(0xFFFF5722)),
    ],
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 9 — Fango + ghiaccio + portali (5×7)
  // I livelli con fango devono avere un timer
  //
  // - Ghiaccio nella parte superiore
  // - Fango al centro della mappa
  // - Portali per saltare oltre il fango
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 9,
    hasHoles: true,
    hasTimer: true,
    squareBoard: false,
    controlMode: ControlMode.tilt,
    timeLimit: 45,
    surfaces: [
      SurfacePatch(2, 1, SurfaceType.ice),
      SurfacePatch(3, 1, SurfaceType.ice),
      SurfacePatch(1, 2, SurfaceType.ice),
      SurfacePatch(2, 2, SurfaceType.ice),
      SurfacePatch(3, 2, SurfaceType.ice),
      SurfacePatch(0, 6, SurfaceType.ice),
      SurfacePatch(1, 6, SurfaceType.ice),

      SurfacePatch(3, 5, SurfaceType.mud),
      SurfacePatch(1, 4, SurfaceType.mud),
      SurfacePatch(2, 4, SurfaceType.mud),
      SurfacePatch(3, 4, SurfaceType.mud),
    ],
    portalDefs: [
      PortalDef(4, 1, 0, 4, Color(0xFF00BCD4)),
      PortalDef(2, 3, 2, 6, Color(0xFFFF5722)),
    ],
  ),

  // ══════════════════════════════════════════════════════════
  // Livello 10 — Sfida finale flip (5×5)
  // I livelli con fango devono avere un timer
  //
  // - Ghiaccio nell’angolo in alto a sinistra
  // - Parete di fango al centro
  // - I portali cambiano completamente il percorso ideale
  // ══════════════════════════════════════════════════════════
  LevelData(
    number: 10,
    hasHoles: true,
    hasTimer: true,
    squareBoard: true,
    controlMode: ControlMode.flip,
    timeLimit: 40,
    surfaces: [
      SurfacePatch(1, 0, SurfaceType.ice),
      SurfacePatch(0, 1, SurfaceType.ice),
      SurfacePatch(1, 1, SurfaceType.ice),
      SurfacePatch(0, 2, SurfaceType.ice),
      SurfacePatch(4, 1, SurfaceType.ice),
      SurfacePatch(1, 4, SurfaceType.ice),
      SurfacePatch(3, 5, SurfaceType.ice),
      SurfacePatch(2, 5, SurfaceType.ice),

      SurfacePatch(2, 1, SurfaceType.mud),
      SurfacePatch(2, 2, SurfaceType.mud),
      SurfacePatch(2, 3, SurfaceType.mud),
    ],
    portalDefs: [
      PortalDef(0, 3, 4, 1, Color(0xFF9C27B0)),
      PortalDef(1, 4, 3, 0, Color(0xFFFF5722)),
    ],
  ),

];