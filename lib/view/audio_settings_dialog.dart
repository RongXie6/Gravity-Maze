import 'package:flutter/material.dart';

import '../service/audio_service.dart';

/// Finestra di impostazioni audio riutilizzabile.
/// [onChanged] viene chiamato ogni volta che una impostazione cambia,
/// così il widget chiamante può aggiornare la propria icona.
Future<void> showAudioSettingsDialog(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  return showDialog(
    context: context,
    builder: (_) => _AudioSettingsDialog(onChanged: onChanged),
  );
}

class _AudioSettingsDialog extends StatefulWidget {
  final VoidCallback onChanged;
  const _AudioSettingsDialog({required this.onChanged});

  @override
  State<_AudioSettingsDialog> createState() => _AudioSettingsDialogState();
}

class _AudioSettingsDialogState extends State<_AudioSettingsDialog> {
  static const _brown = Color(0xFF8B5E3C);
  static const _dark  = Color(0xFF2C1A0E);

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF5EDE0),
      title: const Text('Audio', style: TextStyle(color: _dark)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Musica ──────────────────────────────────────────────────
          _SectionRow(
            icon: Icons.music_note_rounded,
            label: 'Musica',
            enabled: audio.musicEnabled,
            onToggle: (v) async {
              await audio.setMusicEnabled(v);
              if (!mounted) return;
              setState(() {});
              widget.onChanged();
            },
          ),
          _VolumeSlider(
            value: audio.musicVolume,
            enabled: audio.musicEnabled,
            onChanged: (v) async {
              await audio.setMusicVolume(v);
              if (!mounted) return;
              setState(() {});
            },
          ),
          const Divider(height: 24),
          // ── Effetti sonori ───────────────────────────────────────────
          _SectionRow(
            icon: Icons.volume_up_rounded,
            label: 'Effetti sonori',
            enabled: audio.sfxEnabled,
            onToggle: (v) async {
              await audio.setSfxEnabled(v);
              if (!mounted) return;
              setState(() {});
              widget.onChanged();
            },
          ),
          _VolumeSlider(
            value: audio.sfxVolume,
            enabled: audio.sfxEnabled,
            onChanged: (v) async {
              await audio.setSfxVolume(v);
              if (!mounted) return;
              setState(() {});
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK',
              style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _SectionRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: const Color(0xFF8B5E3C)),
      title: Text(label),
      value: enabled,
      activeThumbColor: const Color(0xFF8B5E3C),
      onChanged: onToggle,
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _VolumeSlider({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.volume_mute_rounded,
            size: 18,
            color: enabled
                ? const Color(0xFF8B5E3C)
                : const Color(0xFFBFAF9E)),
        Expanded(
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            activeColor: enabled
                ? const Color(0xFF8B5E3C)
                : const Color(0xFFBFAF9E),
            inactiveColor: const Color(0xFFD9CCBC),
            onChanged: enabled ? onChanged : null,
          ),
        ),
        Icon(Icons.volume_up_rounded,
            size: 18,
            color: enabled
                ? const Color(0xFF8B5E3C)
                : const Color(0xFFBFAF9E)),
      ],
    );
  }
}
