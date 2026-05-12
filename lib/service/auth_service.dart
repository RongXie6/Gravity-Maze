import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modello dati utente
class UserProfile {
  final String username;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  int totalStars;
  int gamesCompleted;
  int totalPlayTimeSeconds;

  List<String> achievements;

  UserProfile({
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    this.totalStars = 0,
    this.gamesCompleted = 0,
    this.totalPlayTimeSeconds = 0,
    List<String>? achievements,
  }) : achievements = achievements ?? [];

  Map<String, dynamic> toJson() => {
    'username': username,
    'email': email,
    'passwordHash': passwordHash,
    'createdAt': createdAt.toIso8601String(),
    'totalStars': totalStars,
    'gamesCompleted': gamesCompleted,
    'totalPlayTimeSeconds': totalPlayTimeSeconds,
    'achievements': achievements,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    username: json['username'],
    email: json['email'],
    passwordHash: json['passwordHash'],
    createdAt: DateTime.parse(json['createdAt']),
    totalStars: json['totalStars'] ?? 0,
    gamesCompleted: json['gamesCompleted'] ?? 0,
    totalPlayTimeSeconds: json['totalPlayTimeSeconds'] ?? 0,
    achievements: List<String>.from(json['achievements'] ?? []),
  );

  /// Titolo/rango del giocatore
  String get rankTitle {
    if (totalStars >= 15) return 'Maestro del Labirinto';
    if (totalStars >= 10) return 'Esploratore';
    if (totalStars >= 6) return 'Principiante';
    return 'Novizio';
  }
}

/// Servizio di autenticazione locale
/// Usa SharedPreferences per il salvataggio persistente
class AuthService {
  static const _usersKey = 'users_db';
  static const _currentUserKey = 'current_user';

  /// Hash SHA-256 della password
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Registrazione nuovo utente
  static Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (username.trim().length < 3) {
      return AuthResult.failure(
          'Il nome utente deve contenere almeno 3 caratteri');
    }

    if (!email.contains('@')) {
      return AuthResult.failure('Inserisci un indirizzo email valido');
    }

    if (password.length < 6) {
      return AuthResult.failure(
          'La password deve contenere almeno 6 caratteri');
    }

    final prefs = await SharedPreferences.getInstance();

    final usersJson = prefs.getString(_usersKey);

    final users = usersJson != null
        ? Map<String, dynamic>.from(jsonDecode(usersJson))
        : <String, dynamic>{};

    if (users.containsKey(username)) {
      return AuthResult.failure('Nome utente già utilizzato');
    }

    final profile = UserProfile(
      username: username.trim(),
      email: email.trim(),
      passwordHash: _hashPassword(password),
      createdAt: DateTime.now(),
    );

    users[username] = profile.toJson();

    await prefs.setString(_usersKey, jsonEncode(users));
    await prefs.setString(_currentUserKey, username);

    return AuthResult.success(profile);
  }

  /// Login utente
  static Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) {
      return AuthResult.failure('Utente non trovato');
    }

    final users = Map<String, dynamic>.from(jsonDecode(usersJson));

    if (!users.containsKey(username)) {
      return AuthResult.failure('Utente non trovato');
    }

    final profile = UserProfile.fromJson(
      Map<String, dynamic>.from(users[username]),
    );

    if (profile.passwordHash != _hashPassword(password)) {
      return AuthResult.failure('Password errata');
    }

    await prefs.setString(_currentUserKey, username);

    return AuthResult.success(profile);
  }

  /// Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  /// Recupera l’utente attualmente loggato
  static Future<UserProfile?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();

    final currentUsername = prefs.getString(_currentUserKey);

    if (currentUsername == null) return null;

    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) return null;

    final users = Map<String, dynamic>.from(jsonDecode(usersJson));

    if (!users.containsKey(currentUsername)) return null;

    return UserProfile.fromJson(
      Map<String, dynamic>.from(users[currentUsername]),
    );
  }

  /// Aggiorna le statistiche del giocatore
  static Future<void> updateStats({
    required String username,
    int addStars = 0,
    int addPlaySeconds = 0,
    bool completedGame = false,
    String? newAchievement,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) return;

    final users = Map<String, dynamic>.from(jsonDecode(usersJson));

    if (!users.containsKey(username)) return;

    final profile = UserProfile.fromJson(
      Map<String, dynamic>.from(users[username]),
    );

    profile.totalStars += addStars;
    profile.totalPlayTimeSeconds += addPlaySeconds;

    if (completedGame) {
      profile.gamesCompleted++;
    }

    if (newAchievement != null &&
        !profile.achievements.contains(newAchievement)) {
      profile.achievements.add(newAchievement);
    }

    users[username] = profile.toJson();

    await prefs.setString(_usersKey, jsonEncode(users));
  }

  /// Accesso ospite (nessun salvataggio dati)
  static UserProfile guestProfile() => UserProfile(
    username: 'Ospite',
    email: '',
    passwordHash: '',
    createdAt: DateTime.now(),
  );
}

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final UserProfile? user;

  AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(UserProfile user) =>
      AuthResult._(
        isSuccess: true,
        user: user,
      );

  factory AuthResult.failure(String message) =>
      AuthResult._(
        isSuccess: false,
        errorMessage: message,
      );
}