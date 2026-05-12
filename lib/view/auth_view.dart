import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../service/auth_service.dart';
import '../view/level_select_view.dart';


class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMsg;

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    AuthResult result;
    if (_isLogin) {
      result = await AuthService.login(
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );
    } else {
      result = await AuthService.register(
        username: _usernameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      HapticFeedback.lightImpact();
      _openHome(result.user!);
    } else {
      HapticFeedback.vibrate();
      setState(() => _errorMsg = result.errorMessage);
    }
  }

  void _continueAsGuest() {
    HapticFeedback.lightImpact();
    _openHome(AuthService.guestProfile());
  }

  void _openHome(UserProfile user) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => LevelSelectView(user: user),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMsg = null;
    });
    _animCtrl.forward(from: 0);
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
              Color(0xFF2C1A0E),
              Color(0xFF5C3317),
              Color(0xFF8B5E3C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 36),
                      _buildCard(),
                      const SizedBox(height: 20),
                      _buildGuestButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: const Icon(Icons.grid_4x4_rounded,
              size: 52, color: Color(0xFFFFD54F)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Labirinto',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Esplora il labirinto, scopri te stesso',
          style: TextStyle(
              fontSize: 14, color: Colors.white.withOpacity(0.65)),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          )
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab 
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEE8E0),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _tabButton('Accedi', _isLogin),
                  _tabButton('Registrati', !_isLogin),
                ],
              ),
            ),
            const SizedBox(height: 24),

           
            _buildField(
              controller: _usernameCtrl,
              label: 'Nome utente',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Inserisci un nome utente' : null,
            ),

         
            if (!_isLogin) ...[
              const SizedBox(height: 14),
              _buildField(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Inserisci un\'email valida' : null,
              ),
            ],

            const SizedBox(height: 14),

            _buildField(
              controller: _passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              suffix: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                color: const Color(0xFF8B5E3C),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'La password deve avere almeno 6 caratteri' : null,
            ),

        
            if (_errorMsg != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFE53935), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(
                            color: Color(0xFFB71C1C), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

       
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5E3C), Color(0xFF5C3317)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5C3317).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: MaterialButton(
                onPressed: _loading ? null : _submit,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isLogin ? 'Accedi' : 'Crea account',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 16),

 
            GestureDetector(
              onTap: _toggleMode,
              child: Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Color(0xFF8B8078), fontSize: 13),
                    children: [
                      TextSpan(
                          text: _isLogin ? 'Non hai un account? ' : 'Hai già un account? '),
                      TextSpan(
                        text: _isLogin ? 'Registrati' : 'Accedi',
                        style: const TextStyle(
                            color: Color(0xFF8B5E3C),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: active ? null : _toggleMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: active
                    ? const Color(0xFF5C3317)
                    : const Color(0xFF9E8877),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF2C1A0E)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8B5E3C), size: 20),
        suffixIcon: suffix,
        labelStyle:
            const TextStyle(color: Color(0xFF9E8877), fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDD3C8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF8B5E3C), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE53935), width: 1.8),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F3EE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildGuestButton() {
    return GestureDetector(
      onTap: _continueAsGuest,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline_rounded,
                color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              'Continua come ospite',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
