import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controller/game_controller.dart';
import '../model/game_model.dart';
import '../model/level_data.dart';
import '../service/auth_service.dart';
import 'auth_view.dart';
import 'maze_view.dart';

/// Pagina di selezione livelli — con pannello utente, griglia livelli e achievement
class LevelSelectView extends StatefulWidget {
  final UserProfile user;
  const LevelSelectView({super.key, required this.user});

  @override
  State<LevelSelectView> createState() => _LevelSelectViewState();
}

class _LevelSelectViewState extends State<LevelSelectView>
    with SingleTickerProviderStateMixin {
  Map<int, int> _savedStars = {};
  late AnimationController _staggerCtrl;
  late UserProfile _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadStars();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStars() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <int, int>{};
    for (final lv in levels) {
      map[lv.number] = prefs.getInt('level_${lv.number}_stars') ?? 0;
    }
    if (!mounted) return;
    setState(() => _savedStars = map);
    final total = map.values.fold(0, (a, b) => a + b);
    setState(() => _user.totalStars = total);
  }

  String _starsText(int count) =>
      List.generate(3, (i) => i < count.clamp(0, 3) ? '★' : '☆').join();

  bool _isLevelUnlocked(int levelNumber) {
    if (levelNumber == 1) return true;
    final prevStars = _savedStars[levelNumber - 1] ?? 0;
    return prevStars > 0;
  }

  Future<void> _openLevel(LevelData level) async {
    if (!_isLevelUnlocked(level.number)) {
      HapticFeedback.heavyImpact();
      _showLockedDialog(level);
      return;
    }

    HapticFeedback.lightImpact();
    final model = GameModel(cols: 5, rows: 7);
    final controller = GameController(model);
    controller.setLevel(level.number - 1);

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => Scaffold(
          body: SafeArea(child: MazeView(controller: controller, user: _user)),
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    await _loadStars();
  }

  void _showLockedDialog(LevelData level) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF5EDE0),
        title: const Row(children: [
          Icon(Icons.lock_rounded, color: Color(0xFF8B5E3C)),
          SizedBox(width: 8),
          Text('Livello bloccato', style: TextStyle(color: Color(0xFF2C1A0E))),
        ]),
        content: Text(
          'Completa il livello ${level.number - 1} (almeno 1 stella) per sbloccare questo livello.',
          style: const TextStyle(color: Color(0xFF5C3317)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    color: Color(0xFF8B5E3C), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF5EDE0),
        title: const Text('Esci dall\'account',
            style: TextStyle(color: Color(0xFF2C1A0E))),
        content: const Text('Vuoi davvero uscire dall\'account corrente?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Esci', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0E6D3),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildUserBanner()),
          SliverToBoxAdapter(child: _buildSectionTitle('Scegli livello')),
          _buildLevelGrid(),
          SliverToBoxAdapter(child: _buildAchievementsSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 80,
      backgroundColor: const Color(0xFF5C3317),
      flexibleSpace: const FlexibleSpaceBar(
        title: Text(
          'Labirinto',
          style: TextStyle(
            fontFamily: 'serif',
            letterSpacing: 2,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      actions: [
        if (_user.username != 'Ospite')
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Esci dall\'account',
          ),
      ],
    );
  }

  Widget _buildUserBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5E3C), Color(0xFF5C3317)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF5C3317).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                _user.username.isNotEmpty
                    ? _user.username[0].toUpperCase()
                    : 'G',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _user.rankTitle,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 22)),
              Text(
                '${_user.totalStars}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'Stelle totali',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C1A0E),
        ),
      ),
    );
  }

  Widget _buildLevelGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final level = levels[i];
            final stars = _savedStars[level.number] ?? 0;
            final unlocked = _isLevelUnlocked(level.number);

            final delay = i * 0.12;
            final anim = CurvedAnimation(
              parent: _staggerCtrl,
              curve: Interval(delay.clamp(0.0, 1.0), 1.0,
                  curve: Curves.easeOutBack),
            );

            return AnimatedBuilder(
              animation: anim,
              builder: (_, child) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: _LevelCard(
                level: level,
                starsText: _starsText(stars),
                unlocked: unlocked,
                onTap: () => _openLevel(level),
              ),
            );
          },
          childCount: levels.length,
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final achievements = _user.achievements;
    if (achievements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Obiettivi',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C1A0E)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                achievements.map((a) => _AchievementChip(label: a)).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Card livello
// ─────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final LevelData level;
  final String starsText;
  final bool unlocked;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.starsText,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: unlocked ? Colors.white : const Color(0xFFD9CCBC),
          borderRadius: BorderRadius.circular(18),
          boxShadow: unlocked
              ? [
                  const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ]
              : [],
          border: Border.all(
            color: unlocked
                ? const Color(0xFFE8D9C5)
                : const Color(0xFFBFAF9E),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level ${level.number}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: unlocked
                        ? const Color(0xFF2C1A0E)
                        : const Color(0xFF9E8877),
                  ),
                ),
                if (!unlocked)
                  const Icon(Icons.lock_rounded,
                      size: 18, color: Color(0xFF9E8877)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  starsText,
                  style: const TextStyle(
                      fontSize: 20, color: Color(0xFFFFC107)),
                ),
                Row(
                  children: [
                    if (level.hasTimer)
                      _tag(Icons.timer_outlined, const Color(0xFF2196F3)),
                    if (level.hasHoles)
                      _tag(Icons.circle_outlined, Colors.red),
                    if (level.portalDefs.isNotEmpty)
                      _tag(Icons.blur_circular_rounded,
                          const Color(0xFF9C27B0)),
                    if (level.surfaces
                        .any((s) => s.type == SurfaceType.ice))
                      _tag(Icons.ac_unit_rounded, Colors.lightBlue),
                    if (level.surfaces
                        .any((s) => s.type == SurfaceType.mud))
                      _tag(Icons.water_drop_rounded,
                          const Color(0xFF795548)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  final String label;
  const _AchievementChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFB300)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFFB300).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3E2000)),
      ),
    );
  }
}
