import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestione centralizzata di musica e effetti sonori.
/// Singleton — accedere tramite AudioService.instance.
class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  static const _keyMusic    = 'audio_music';
  static const _keySfx      = 'audio_sfx';
  static const _keyMusicVol = 'audio_music_vol';
  static const _keySfxVol   = 'audio_sfx_vol';

  final AudioPlayer _bgm = AudioPlayer();

  // Pool di player per effetti sovrapposti
  final AudioPlayer _sfxStar   = AudioPlayer();
  final AudioPlayer _sfxDeath  = AudioPlayer();
  final AudioPlayer _sfxWin    = AudioPlayer();
  final AudioPlayer _sfxPortal = AudioPlayer();
  final AudioPlayer _sfxWood   = AudioPlayer();
  final AudioPlayer _sfxIce    = AudioPlayer();
  final AudioPlayer _sfxMud    = AudioPlayer();

  List<AudioPlayer> get _sfxPlayers =>
      [_sfxStar, _sfxDeath, _sfxWin, _sfxPortal, _sfxWood, _sfxIce, _sfxMud];

  bool   _musicEnabled = true;
  bool   _sfxEnabled   = true;
  bool   _bgmPlaying   = false;
  double _musicVolume  = 0.45;
  double _sfxVolume    = 1.0;

  bool   get musicEnabled => _musicEnabled;
  bool   get sfxEnabled   => _sfxEnabled;
  double get musicVolume  => _musicVolume;
  double get sfxVolume    => _sfxVolume;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_keyMusic)       ?? true;
    _sfxEnabled   = prefs.getBool(_keySfx)         ?? true;
    _musicVolume  = prefs.getDouble(_keyMusicVol)  ?? 0.45;
    _sfxVolume    = prefs.getDouble(_keySfxVol)    ?? 1.0;

    // BGM: focus permanente, mix con altri su iOS
    await _bgm.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    ));

    // SFX: focus transitorio con ducking — la BGM continua senza interrompersi
    final sfxContext = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    );
    for (final p in _sfxPlayers) {
      await p.setAudioContext(sfxContext);
    }

    await _bgm.setReleaseMode(ReleaseMode.loop);
    await _bgm.setVolume(_musicVolume);
    for (final p in _sfxPlayers) {
      await p.setVolume(_sfxVolume);
    }
  }

  // ── BGM ──────────────────────────────────────────────────────────────────

  Future<void> playBgm([String asset = 'audio/bgm.wav']) async {
    if (!_musicEnabled) return;
    try {
      await _bgm.play(AssetSource(asset));
      _bgmPlaying = true;
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    await _bgm.stop();
    _bgmPlaying = false;
  }

  Future<void> pauseBgm() async {
    await _bgm.pause();
  }

  Future<void> resumeBgm() async {
    if (!_musicEnabled || !_bgmPlaying) return;
    try {
      await _bgm.resume();
    } catch (_) {}
  }

  // ── SFX ──────────────────────────────────────────────────────────────────

  Future<void> playStar()   => _play(_sfxStar,   'audio/star.wav');
  Future<void> playDeath()  => _play(_sfxDeath,  'audio/death.wav');
  Future<void> playWin()    => _play(_sfxWin,    'audio/win.wav');
  Future<void> playPortal() => _play(_sfxPortal, 'audio/portal.wav');
  Future<void> playWood()   => _play(_sfxWood,   'audio/wood.wav');
  Future<void> playIce()    => _play(_sfxIce,    'audio/ice.wav');
  Future<void> playMud()    => _play(_sfxMud,    'audio/mud.wav');

  Future<void> _play(AudioPlayer player, String asset) async {
    if (!_sfxEnabled) return;
    try {
      await player.play(AssetSource(asset));
    } catch (_) {}
  }

  // ── Toggle ────────────────────────────────────────────────────────────────

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMusic, value);
    if (value) {
      await resumeBgm();
    } else {
      await pauseBgm();
    }
  }

  Future<void> setSfxEnabled(bool value) async {
    _sfxEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySfx, value);
  }

  // ── Volume ────────────────────────────────────────────────────────────────

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value;
    await _bgm.setVolume(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMusicVol, value);
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value;
    for (final p in _sfxPlayers) {
      await p.setVolume(value);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySfxVol, value);
  }

  Future<void> dispose() async {
    await _bgm.dispose();
    for (final p in _sfxPlayers) {
      await p.dispose();
    }
  }
}
