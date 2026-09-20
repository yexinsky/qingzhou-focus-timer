import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/ambient_sound_service.dart';
import '../data/repositories/settings_repository.dart';
import 'settings_provider.dart';
import 'timer_provider.dart';

final ambientSoundServiceProvider = Provider<AmbientSoundService>((ref) {
  final service = AmbientSoundService();
  ref.onDispose(() => service.dispose());
  return service;
});

class AmbientSoundState {
  final List<AmbientSound> sounds;
  final String? selectedSoundId;
  final double volume;
  final bool enabled;
  final bool isPlaying;

  const AmbientSoundState({
    this.sounds = const [],
    this.selectedSoundId,
    this.volume = 0.5,
    this.enabled = false,
    this.isPlaying = false,
  });

  AmbientSound? get selectedSound {
    if (selectedSoundId == null) return null;
    for (final s in sounds) {
      if (s.id == selectedSoundId) return s;
    }
    return null;
  }

  AmbientSoundState copyWith({
    List<AmbientSound>? sounds,
    String? selectedSoundId,
    bool clearSelectedSound = false,
    double? volume,
    bool? enabled,
    bool? isPlaying,
  }) {
    return AmbientSoundState(
      sounds: sounds ?? this.sounds,
      selectedSoundId: clearSelectedSound
          ? null
          : (selectedSoundId ?? this.selectedSoundId),
      volume: volume ?? this.volume,
      enabled: enabled ?? this.enabled,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

final ambientSoundProvider =
    StateNotifierProvider<AmbientSoundNotifier, AmbientSoundState>((ref) {
  final service = ref.watch(ambientSoundServiceProvider);
  final settings = ref.watch(settingsProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final notifier = AmbientSoundNotifier(service, settings, settingsRepo);

  ref.listen<TimerStateData>(timerProvider, (prev, next) {
    final isFocusRunning =
        next.state == TimerState.running &&
        next.sessionType == SessionType.focus;
    if (isFocusRunning) {
      notifier.autoStartIfEnabled();
    } else {
      notifier.stopPlayback();
    }
  });

  return notifier;
});

class AmbientSoundNotifier extends StateNotifier<AmbientSoundState> {
  final AmbientSoundService _service;
  final SettingsRepository _settingsRepo;

  AmbientSoundNotifier(
    this._service,
    SettingsState settings,
    this._settingsRepo,
  ) : super(
        AmbientSoundState(
          sounds: _loadSounds(settings),
          selectedSoundId: settings.whiteNoiseSoundId,
          volume: settings.whiteNoiseVolume,
          enabled: settings.autoWhiteNoise,
        ),
      );

  static List<AmbientSound> _loadSounds(SettingsState settings) {
    try {
      final json = settings.ambientSoundsJson;
      final list = jsonDecode(json) as List;
      return list
          .map((e) => AmbientSound.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _persistSounds() {
    final json = jsonEncode(state.sounds.map((s) => s.toJson()).toList());
    _settingsRepo.setAmbientSoundsJson(json);
  }

  Future<AmbientSound?> importFile(File file) async {
    try {
      final sound = await _service.importFile(file);
      state = state.copyWith(sounds: [...state.sounds, sound]);
      _persistSounds();
      return sound;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeSound(String soundId) async {
    final sound = state.sounds.where((s) => s.id == soundId).firstOrNull;
    if (sound == null) return;
    await _service.deleteFile(sound);
    final newSounds = state.sounds.where((s) => s.id != soundId).toList();
    final wasSelected = state.selectedSoundId == soundId;
    state = state.copyWith(
      sounds: newSounds,
      clearSelectedSound: wasSelected,
    );
    if (wasSelected) {
      await _service.stop();
      state = state.copyWith(isPlaying: false);
    }
    _persistSounds();
  }

  Future<void> selectSound(String soundId) async {
    final sound = state.sounds.where((s) => s.id == soundId).firstOrNull;
    if (sound == null) return;
    state = state.copyWith(selectedSoundId: soundId);
    if (state.enabled && state.isPlaying) {
      await _service.play(sound.filePath);
    }
  }

  Future<void> clearSoundSelection() async {
    state = state.copyWith(clearSelectedSound: true);
    await _service.stop();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> toggleEnabled() async {
    final newValue = !state.enabled;
    state = state.copyWith(enabled: newValue);
    if (newValue && state.selectedSoundId != null) {
      await autoStartIfEnabled();
    } else if (!newValue) {
      await _service.stop();
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> setVolume(double vol) async {
    state = state.copyWith(volume: vol);
    await _service.setVolume(vol);
  }

  Future<void> autoStartIfEnabled() async {
    final sound = state.selectedSound;
    if (!state.enabled || sound == null) return;
    await _service.play(sound.filePath);
    state = state.copyWith(isPlaying: true);
  }

  Future<void> stopPlayback() async {
    if (!state.isPlaying) return;
    await _service.stop();
    state = state.copyWith(isPlaying: false);
  }
}
