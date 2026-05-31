import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'service/audio_service.dart';
import 'service/auth_service.dart';
import 'view/auth_view.dart';
import 'view/level_select_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.instance.init();

  // Blocca orientamento solo verticale
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Labirinto',
      theme: ThemeData(
        fontFamily: 'serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5E3C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
    );
  }
}

/// Schermata iniziale — controlla la sessione e mostra animazione di avvio
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Controller animazione splash
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeIn,
    );

    _ctrl.forward();

    // Dopo lo splash, naviga alla schermata corretta
    Future.delayed(const Duration(milliseconds: 1800), _navigate);
  }

  Future<void> _navigate() async {
    final user = await AuthService.getCurrentUser();

    if (!mounted) return;

    final Widget dest = user != null
        ? LevelSelectView(user: user)
        : const AuthView();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => dest,
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0A00),
              Color(0xFF4A2210),
              Color(0xFF8B5E3C),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD54F).withOpacity(0.2),
                            blurRadius: 40,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.grid_4x4_rounded,
                        size: 62,
                        color: Color(0xFFFFD54F),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'LABIRINTO',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esci dal labirinto, esplora te stesso',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: Colors.white.withOpacity(0.5),
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}