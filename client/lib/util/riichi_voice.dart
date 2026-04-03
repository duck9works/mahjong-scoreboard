import 'package:audioplayers/audioplayers.dart';

class RiichiVoicePreset {
  final int id;
  final String label;
  final String assetPath;

  const RiichiVoicePreset({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

const riichiVoicePresets = <RiichiVoicePreset>[
  RiichiVoicePreset(
    id: 0,
    label: 'Voice 1',
    assetPath: 'voices/voice_01.mp3',
  ),
  RiichiVoicePreset(
    id: 1,
    label: 'Voice 2',
    assetPath: 'voices/voice_02.mp3',
  ),
  RiichiVoicePreset(
    id: 2,
    label: 'Voice 3',
    assetPath: 'voices/voice_03.mp3',
  ),
  RiichiVoicePreset(
    id: 3,
    label: 'Voice 4',
    assetPath: 'voices/voice_04.mp3',
  ),
  RiichiVoicePreset(
    id: 4,
    label: 'Voice 5',
    assetPath: 'voices/voice_05.mp3',
  ),
  RiichiVoicePreset(
    id: 5,
    label: 'Voice 6',
    assetPath: 'voices/voice_06.mp3',
  ),
  RiichiVoicePreset(
    id: 6,
    label: 'Voice 7',
    assetPath: 'voices/voice_07.mp3',
  ),
  RiichiVoicePreset(
    id: 7,
    label: 'Voice 8',
    assetPath: 'voices/voice_08.mp3',
  ),
];

RiichiVoicePreset riichiVoicePresetById(int id) {
  for (final p in riichiVoicePresets) {
    if (p.id == id) {
      return p;
    }
  }
  return riichiVoicePresets.first;
}

class RiichiVoicePlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(int voiceId) async {
    try {
      final preset = riichiVoicePresetById(voiceId);
      await _player.stop();
      try {
        await _player.play(AssetSource(preset.assetPath));
      } catch (_) {
        await _player.play(AssetSource('assets/${preset.assetPath}'));
      }
    } catch (_) {
      // ignore audio failures (e.g. browser autoplay restrictions)
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
