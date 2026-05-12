import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/game_controller.dart';
import '../model/game_model.dart';
import '../model/level_data.dart';
import '../service/auth_service.dart';

class MazeView extends StatefulWidget {
  final GameController controller;
  final UserProfile user;
  const MazeView({super.key, required this.controller, required this.user});

  @override
  State<MazeView> createState() => _MazeViewState();
}

class _MazeViewState extends State<MazeView> with TickerProviderStateMixin {
  late AnimationController _boardEntryCtrl;
  late AnimationController _winCtrl;
  late AnimationController _deadCtrl;
  late AnimationController _portalPulseCtrl;

  final List<_Particle> _particles = [];
  bool _particlesActive = false;

  @override
  void initState() {
    super.initState();

    _boardEntryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();

    _winCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _deadCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _portalPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    widget.controller.addListener(_onControllerChanged);
    widget.controller.onPortalEnter = () {
      HapticFeedback.mediumImpact();
    };
    widget.controller.start();
  }

  void _onControllerChanged() {
    if (widget.controller.model.isWin && !_winCtrl.isAnimating) {
      _triggerWin();
    }
    if (widget.controller.model.isDead && !_deadCtrl.isAnimating) {
      HapticFeedback.heavyImpact();
      _deadCtrl.forward(from: 0);
    }
  }

  void _triggerWin() {
    HapticFeedback.heavyImpact();
    _winCtrl.forward(from: 0);
    _spawnParticles();

    final stars = widget.controller.currentStars;
    final levelNum = widget.controller.level.number;
    AuthService.updateStats(
      username: widget.user.username,
      addStars: stars,
      completedGame: true,
      newAchievement: stars == 3 ? 'Livello $levelNum: tre stelle!' : null,
    );
  }

  void _spawnParticles() {
    final center = widget.controller.boardRect.center;
    final rng = Random();
    _particles.clear();
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        pos: center,
        vel: Offset(
          (rng.nextDouble() - 0.5) * 500,
          (rng.nextDouble() - 0.7) * 600,
        ),
        color: _particleColors[rng.nextInt(_particleColors.length)],
        size: 4 + rng.nextDouble() * 8,
      ));
    }
    setState(() => _particlesActive = true);
  }

  static const _particleColors = [
    Color(0xFFFFD700),
    Color(0xFFFF6B35),
    Color(0xFF4ECDC4),
    Color(0xFFFF1493),
    Color(0xFF7CFC00),
    Color(0xFFFF4500),
    Color(0xFF00BFFF),
  ];

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.disposeController();
    _boardEntryCtrl.dispose();
    _winCtrl.dispose();
    _deadCtrl.dispose();
    _portalPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        widget.controller.onResize(size);

        return GestureDetector(
          onDoubleTap: () {
            HapticFeedback.mediumImpact();
            if (widget.controller.model.isWin) {
              widget.controller.nextLevel();
            } else {
              widget.controller.resetGame();
              _deadCtrl.reset();
              _winCtrl.reset();
              setState(() {
                _particlesActive = false;
                _particles.clear();
              });
            }
          },
          onPanEnd: (details) {
            if (widget.controller.level.controlMode != ControlMode.flip) return;
            final v = details.velocity.pixelsPerSecond;
            HapticFeedback.selectionClick();
            if (v.dx > 0) {
              widget.controller.rotateBoardRight();
            } else {
              widget.controller.rotateBoardLeft();
            }
          },

          child: Column(
            children: [
              // ───────────────────── MAP AREA ─────────────────────
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    widget.controller,
                    _portalPulseCtrl,
                  ]),
                  builder: (_, __) {
                    return Stack(
                      children: [
                        // map
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _boardEntryCtrl,
                            curve: Curves.easeOutBack,
                          ),
                          child: FadeTransition(
                            opacity: _boardEntryCtrl,
                            child: CustomPaint(
                              painter: _MazePainter(
                                widget.controller,
                                portalPhase: _portalPulseCtrl.value,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),

                        // Particle system
                        if (_particlesActive)
                          AnimatedBuilder(
                            animation: _winCtrl,
                            builder: (_, __) => CustomPaint(
                              painter: _ParticlePainter(
                                _particles,
                                _winCtrl.value,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),

                        // Death flash overlay
                        if (widget.controller.model.isDead)
                          AnimatedBuilder(
                            animation: _deadCtrl,
                            builder: (_, __) => Opacity(
                              opacity: sin(_deadCtrl.value * pi) * 0.35,
                              child: Container(color: Colors.red),
                            ),
                          ),

                        // Victory effect
                        if (widget.controller.model.isWin)
                          AnimatedBuilder(
                            animation: _winCtrl,
                            builder: (_, __) => Opacity(
                              opacity: (_winCtrl.value *
                                  (1 - _winCtrl.value) *
                                  4)
                                  .clamp(0.0, 0.5),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Colors.transparent
                                    ],
                                    radius: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),


                        Positioned(
                          top: 12,
                          left: 12,
                          child: SafeArea(
                            child: IconButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                Colors.black.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ───────────────────── HUD─────────────────────
              AnimatedBuilder(
                animation: widget.controller,
                builder: (_, __) {
                  return SafeArea(
                    top: false,
                    child: _HudOverlay(
                      controller: widget.controller,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// Particelle vittoria
// ─────────────────────────────────────────────────
class _Particle {
  Offset pos;
  final Offset vel;
  final Color color;
  final double size;
  _Particle(
      {required this.pos,
      required this.vel,
      required this.color,
      required this.size});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dt = t * 1.2;
      final px = p.pos.dx + p.vel.dx * dt;
      final py = p.pos.dy + p.vel.dy * dt + 300 * dt * dt;
      final alpha = (1.0 - t * 1.3).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), p.size * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

/// ─────────────────────────────────────────────────
// HUD
// ─────────────────────────────────────────────────
class _HudOverlay extends StatelessWidget {
  final GameController controller;
  const _HudOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    final model = controller.model;
    final level = controller.level;

    String message = '';
    IconData icon = Icons.star;
    Color iconColor = const Color(0xFFFFD54F);

    if (model.isWin) {
      message = 'Completato! ${controller.currentStarsText}';
      icon = Icons.emoji_events_rounded;
      iconColor = const Color(0xFFFFD700);
    } else if (model.isDead) {
      message = model.isTimeOver ? 'Tempo scaduto! Doppio tap per riprovare' : 'Caduto in una buca! Doppio tap per riprovare';
      icon = Icons.sentiment_dissatisfied_rounded;
      iconColor = Colors.redAccent;
    }

    return Container(
      color: const Color(0xFF2C1A0E),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statusRow(
                      icon: Icons.star_rounded,
                      color: const Color(0xFFFFD54F),
                      text: controller.currentStarsText,
                    ),
                    if (model.isWin || model.isDead)
                      _statusRow(
                          icon: icon, color: iconColor, text: message),
                    if (!model.isWin && !model.isDead)
                      _statusRow(
                        icon: Icons.touch_app_rounded,
                        color: Colors.white54,
                        text: 'Doppio tap per ricominciare',
                      ),
                  ],
                ),

                // Indicatore superficie attiva
                if (!model.isWin && !model.isDead)
                  _SurfaceIndicator(controller: controller),

                // Timer
                if (level.hasTimer && !model.isDead && !model.isWin) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (model.timeLeft / level.timeLimit).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(
                        model.timeLeft < 10
                            ? Colors.redAccent
                            : const Color(0xFF4ECDC4),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${model.timeLeft.ceil()} s',
                    style: TextStyle(
                        color: model.timeLeft < 10
                            ? Colors.redAccent
                            : Colors.white70,
                        fontSize: 12),
                  ),
                ],

                if (level.controlMode == ControlMode.flip &&
                    !model.isDead &&
                    !model.isWin)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Swipe ← → per ruotare',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusRow(
      {required IconData icon,
        required Color color,
        required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ],
    );
  }
}

/// Piccola pillola che indica se la pallina è su ghiaccio o fango
class _SurfaceIndicator extends StatelessWidget {
  final GameController controller;
  const _SurfaceIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    final surf = controller.model.surfaceMap.isEmpty
        ? SurfaceType.normal
        : _getCurrentSurface();

    if (surf == SurfaceType.normal) return const SizedBox.shrink();

    final isIce = surf == SurfaceType.ice;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIce ? Icons.ac_unit_rounded : Icons.water_drop_rounded,
            size: 14,
            color: isIce ? Colors.lightBlue : Colors.brown[300],
          ),
          const SizedBox(width: 4),
          Text(
            isIce ? 'Ghiaccio!' : 'Fango!',
            style: TextStyle(
              fontSize: 12,
              color: isIce ? Colors.lightBlue : Colors.brown[300],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  SurfaceType _getCurrentSurface() {
    final model = controller.model;
    final br = controller.boardRect;
    if (br == Rect.zero) return SurfaceType.normal;
    final cellW = br.width / model.cols;
    final cellH = br.height / model.rows;
    final col = ((model.ballPos.dx - br.left) / cellW).floor();
    final row = ((model.ballPos.dy - br.top) / cellH).floor();
    if (!model.ok(col, row)) return SurfaceType.normal;
    return model.surfaceAt(col, row);
  }
}

// ─────────────────────────────────────────────────
// Painter principale
// ─────────────────────────────────────────────────
class _MazePainter extends CustomPainter {
  final GameController controller;
  final double portalPhase;

  _MazePainter(this.controller, {required this.portalPhase});

  GameModel get model => controller.model;

  @override
  void paint(Canvas canvas, Size size) {
    // Sfondo legno
    final wood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD8B58A), Color(0xFFC9A173), Color(0xFFD8B58A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wood);

    final boardRect = controller.boardRect;
    final boardCenter = boardRect.center;

    // Ombra board
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          boardRect.shift(const Offset(6, 8)), const Radius.circular(14)),
      shadowPaint,
    );

    // Pannello board
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
      Paint()..color = const Color(0xFFEAD7B7),
    );

    // Cornice
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD4A76A), Color(0xFF8B5E3C)],
        ).createShader(boardRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // ── Rotazione per flip mode ─────────────────────────────────────────────
    canvas.save();
    canvas.translate(boardCenter.dx, boardCenter.dy);
    canvas.rotate(controller.boardAngle);
    canvas.translate(-boardCenter.dx, -boardCenter.dy);

    // ── Superfici (ghiaccio / fango) ───────────────────────────────────────
    _drawSurfaces(canvas, boardRect);

    // ── Portali ────────────────────────────────────────────────────────────
    _drawPortals(canvas);

    // ── Muri ───────────────────────────────────────────────────────────────
    final wallShadow = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final r in model.wallRects) {
      canvas.drawRect(r.shift(const Offset(2, 2)), wallShadow);
    }
    final wallPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B4A2E), Color(0xFF3D2010)],
      ).createShader(boardRect);
    for (final r in model.wallRects) {
      canvas.drawRect(r, wallPaint);
    }

    // ── Traguardo ──────────────────────────────────────────────────────────
    final goalGlow = Paint()
      ..color = const Color(0xFFE74C3C).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(model.goalPos, model.ballRadius * 1.6, goalGlow);
    canvas.drawCircle(
      model.goalPos,
      model.ballRadius * 0.85,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFFFF6B6B), Color(0xFFE74C3C)],
        ).createShader(Rect.fromCircle(
            center: model.goalPos, radius: model.ballRadius)),
    );

    // ── Partenza ───────────────────────────────────────────────────────────
    canvas.drawCircle(
        model.startPos,
        model.ballRadius * 1.2,
        Paint()
          ..color = const Color(0xFF2ECC71).withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(model.startPos, model.ballRadius * 0.55,
        Paint()..color = const Color(0xFF2ECC71));

    // ── Buchi ──────────────────────────────────────────────────────────────
    for (final h in model.holes) {
      canvas.drawCircle(
          h,
          model.ballRadius * 1.0,
          Paint()
            ..color = Colors.black.withOpacity(0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(h, model.ballRadius * 0.75,
          Paint()..color = const Color(0xFF0A0A0A));
      canvas.drawCircle(
          h,
          model.ballRadius * 0.9,
          Paint()
            ..color = const Color(0xFF333333)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // ── Stelle ─────────────────────────────────────────────────────────────
    for (final s in model.stars) {
      canvas.drawCircle(
          s,
          model.ballRadius * 1.1,
          Paint()
            ..color = const Color(0xFFFFD54F).withOpacity(0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      _drawStar(canvas, s, model.ballRadius * 0.75,
          Paint()..color = const Color(0xFFFFD54F));
    }

    // ── Scia ───────────────────────────────────────────────────────────────
    _drawTrail(canvas);

    // ── Pallina (acciaio) ──────────────────────────────────────────────────
    _drawSteelBall(canvas);

    canvas.restore();
  }

  // ── Superfici ─────────────────────────────────────────────────────────────
  void _drawSurfaces(Canvas canvas, Rect boardRect) {
    if (model.surfaceMap.isEmpty) return;

    final cellW = boardRect.width / model.cols;
    final cellH = boardRect.height / model.rows;

    for (final entry in model.surfaceMap.entries) {
      final parts = entry.key.split(',');
      final col = int.parse(parts[0]);
      final row = int.parse(parts[1]);
      final cellRect = Rect.fromLTWH(
        boardRect.left + col * cellW,
        boardRect.top + row * cellH,
        cellW,
        cellH,
      );

      if (entry.value == SurfaceType.ice) {
        // Ghiaccio: tinta azzurra traslucida con pattern diamante
        canvas.drawRect(
          cellRect,
          Paint()..color = const Color(0xFF90CAF9).withOpacity(0.35),
        );
        // Riflesso diagonale
        final shimmer = Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(cellRect.topLeft, cellRect.bottomRight, shimmer);
        canvas.drawLine(cellRect.topRight, cellRect.bottomLeft,
            shimmer..color = Colors.white.withOpacity(0.12));
        // Bordo ghiaccio
        canvas.drawRect(
          cellRect,
          Paint()
            ..color = const Color(0xFF64B5F6).withOpacity(0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      } else {
        // Fango: tinta marrone scura con texture puntini
        canvas.drawRect(
          cellRect,
          Paint()..color = const Color(0xFF5D4037).withOpacity(0.45),
        );
        final dotPaint = Paint()
          ..color = const Color(0xFF3E2723).withOpacity(0.5)
          ..style = PaintingStyle.fill;
        // 4 puntini casuali ma deterministici
        for (int d = 0; d < 4; d++) {
          final dx = ((col * 7 + row * 3 + d * 5) % 10) / 10.0;
          final dy = ((col * 3 + row * 7 + d * 4) % 10) / 10.0;
          canvas.drawCircle(
            Offset(cellRect.left + cellRect.width * (0.15 + dx * 0.7),
                cellRect.top + cellRect.height * (0.15 + dy * 0.7)),
            2.0,
            dotPaint,
          );
        }
        canvas.drawRect(
          cellRect,
          Paint()
            ..color = const Color(0xFF8D6E63).withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  // ── Portali ───────────────────────────────────────────────────────────────
  void _drawPortals(Canvas canvas) {
    for (final portal in model.portals) {
      _drawPortalDisc(canvas, portal.a, portal.color);
      _drawPortalDisc(canvas, portal.b, portal.color);

      // Linea di connessione tratteggiata (sottile)
      final linePaint = Paint()
        ..color = portal.color.withOpacity(0.18)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
    }
  }

  void _drawPortalDisc(Canvas canvas, Offset center, Color color) {
    final r = model.ballRadius * 1.15;
    final pulse = (sin(portalPhase * 2 * pi) * 0.5 + 0.5); // 0→1

    // Alone esterno pulsante
    canvas.drawCircle(
      center,
      r * (1.2 + pulse * 0.3),
      Paint()
        ..color = color.withOpacity(0.15 + pulse * 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + pulse * 6),
    );

    // Anello
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Riempimento
    canvas.drawCircle(
      center,
      r * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.7),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.75)),
    );

    // Rotazione interna (spirale a tratti)
    final angle = portalPhase * 2 * pi;
    for (int i = 0; i < 3; i++) {
      final a = angle + i * (2 * pi / 3);
      final p1 = center + Offset(cos(a) * r * 0.35, sin(a) * r * 0.35);
      final p2 = center + Offset(cos(a) * r * 0.65, sin(a) * r * 0.65);
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.white.withOpacity(0.55)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }
  }

  // ── Scia ──────────────────────────────────────────────────────────────────
  void _drawTrail(Canvas canvas) {
    final trail = model.trail;
    if (trail.length < 2) return;
    final n = trail.length;
    for (int i = 0; i < n - 1; i++) {
      final t = i / (n - 1); // 0 = vecchio, 1 = recente
      final alpha = t * t * 0.55; // quadratico: svanisce verso la testa
      final radius = model.ballRadius * (0.15 + t * 0.45);
      canvas.drawCircle(
        trail[i],
        radius,
        Paint()
          ..color = const Color(0xFFB0BEC5).withOpacity(alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.4),
      );
    }
  }

  // ── Pallina acciaio ────────────────────────────────────────────────────────
  void _drawSteelBall(Canvas canvas) {
    final pos = model.ballPos;
    final r = model.ballRadius;

    // Ombra proiettata sul pavimento (offset fisso, simula luce dall'alto)
    canvas.drawOval(
      Rect.fromCenter(
          center: pos + Offset(r * 0.4, r * 0.55),
          width: r * 1.6,
          height: r * 0.55),
      Paint()
        ..color = Colors.black.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Alone ambiente (luce riflessa dall'ambiente)
    canvas.drawCircle(
      pos,
      r * 1.35,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Corpo principale — gradiente radiale multi-stop stile acciaio lucido
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.5),
          radius: 0.9,
          colors: const [
            Color(0xFFFFFFFF), // speculare bianco
            Color(0xFFE0E8F0), // bianco-azzurro
            Color(0xFFB0BEC5), // grigio medio
            Color(0xFF78909C), // grigio scuro
            Color(0xFF37474F), // bordo quasi nero
          ],
          stops: const [0.0, 0.18, 0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: r)),
    );

    // Riflesso speculare principale (macchia ovale in alto a sinistra)
    canvas.drawOval(
      Rect.fromCenter(
        center: pos + Offset(-r * 0.27, -r * 0.30),
        width: r * 0.44,
        height: r * 0.28,
      ),
      Paint()..color = Colors.white.withOpacity(0.78),
    );

    // Micro-riflesso secondario (simula seconda fonte di luce)
    canvas.drawOval(
      Rect.fromCenter(
        center: pos + Offset(r * 0.28, r * 0.32),
        width: r * 0.16,
        height: r * 0.10,
      ),
      Paint()..color = Colors.white.withOpacity(0.28),
    );

    // Anello di contorno (profondità)
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawStar(Canvas canvas, Offset c, double radius, Paint p) {
    final path = Path();
    const points = 5;
    final inner = radius * 0.48;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final a = (-pi / 2) + i * (pi / points);
      final pt = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => true;
}
