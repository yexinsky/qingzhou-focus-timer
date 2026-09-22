import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/ambient_sound_service.dart';
import '../data/repositories/settings_repository.dart';
// settingsRepositoryProvider 定义在 timer_provider.dart 中。
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

  /// false = 单曲循环，true = 列表循环（按顺序连续播放全部导入音频）
  final bool loopPlaylist;

  const AmbientSoundState({
    this.sounds = const [],
    this.selectedSoundId,
    this.volume = 0.5,
    this.enabled = false,
    this.isPlaying = false,
    this.loopPlaylist = false,
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
    bool? loopPlaylist,
  }) {
    return AmbientSoundState(
      sounds: sounds ?? this.sounds,
      selectedSoundId: clearSelectedSound
          ? null
          : (selectedSoundId ?? this.selectedSoundId),
      volume: volume ?? this.volume,
      enabled: enabled ?? this.enabled,
      isPlaying: isPlaying ?? this.isPlaying,
      loopPlaylist: loopPlaylist ?? this.loopPlaylist,
    );
  }
}

final ambientSoundProvider =
    StateNotifierProvider<AmbientSoundNotifier, AmbientSoundState>((ref) {
      final service = ref.watch(ambientSoundServiceProvider);
      final settingsRepo = ref.watch(settingsRepositoryProvider);
      final notifier = AmbientSoundNotifier(service, settingsRepo);

      // 计时器联动不在这里注册：本 provider 只在氛围音界面打开时才创建，
      // 届时专注开始的事件早已发出。桥接在 app 根节点用 listenManual 完成。
      return notifier;
    });

class AmbientSoundNotifier extends StateNotifier<AmbientSoundState> {
  final AmbientSoundService _service;
  final SettingsRepository _settingsRepo;

  /// 播放器代际计数：stopPlayback 递增后，仍在等待中的启动完成后必须自我关闭，
  /// 防止"放弃专注"与慢速启动竞态导致已结束的会话恢复外放。
  int _playGeneration = 0;
  bool _starting = false;

  /// 氛围音状态以本 notifier 为唯一来源、直接落盘到仓库。
  /// 不能 watch settingsProvider 重建：重建会用启动时的旧 JSON 覆盖
  /// 会话内新导入的音频列表，导致选择与自动播放静默失效。
  AmbientSoundNotifier(this._service, this._settingsRepo)
    : super(
        AmbientSoundState(
          sounds: _loadSounds(_settingsRepo.ambientSoundsJson),
          selectedSoundId: _settingsRepo.whiteNoiseSoundId,
          volume: _settingsRepo.whiteNoiseVolume,
          enabled: _settingsRepo.autoWhiteNoise,
          loopPlaylist: _settingsRepo.ambientLoopPlaylist,
        ),
      );

  static List<AmbientSound> _loadSounds(String json) {
    try {
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
    final wasSelected = state.selectedSoundId == soundId;
    // 先停播再删文件：Windows 上删除正在播放的文件会抛错；
    // 本方法常在未 await 的按钮回调里调用，异常必须内部消化避免未处理 Zone 错误。
    if (wasSelected) {
      try {
        await _service.stop();
      } catch (e) {
        debugPrint('停止氛围音失败（继续移除）：$e');
      }
    }
    try {
      await _service.deleteFile(sound);
    } catch (e) {
      // 删文件失败也要把条目移出列表：宁可残留孤儿文件，不能让 UI 挂着一个
      // 无法播放的音频。
      debugPrint('删除氛围音文件失败（仅移出列表）：$e');
    }
    final newSounds = state.sounds.where((s) => s.id != soundId).toList();
    state = state.copyWith(sounds: newSounds, clearSelectedSound: wasSelected);
    if (wasSelected) {
      state = state.copyWith(isPlaying: false);
      await _settingsRepo.setWhiteNoiseSoundId(null);
    }
    _persistSounds();
  }

  Future<void> selectSound(String soundId) async {
    final sound = state.sounds.where((s) => s.id == soundId).firstOrNull;
    if (sound == null) return;
    state = state.copyWith(selectedSoundId: soundId);
    await _settingsRepo.setWhiteNoiseSoundId(soundId);
    if (state.enabled && state.isPlaying) {
      await _service.stop();
      await _startPlayback();
    }
  }

  Future<void> clearSoundSelection() async {
    state = state.copyWith(clearSelectedSound: true);
    await _settingsRepo.setWhiteNoiseSoundId(null);
    await _service.stop();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> toggleEnabled() async {
    final newValue = !state.enabled;
    state = state.copyWith(enabled: newValue);
    await _settingsRepo.setAutoWhiteNoise(newValue);
    if (newValue && state.selectedSoundId != null) {
      await autoStartIfEnabled();
    } else if (!newValue) {
      await _service.stop();
      state = state.copyWith(isPlaying: false);
    }
  }

  /// 拖拽过程专用：只更新内存状态与播放器音量，不逐像素写盘。
  /// 交互结束（松手/onChangeEnd）时由调用方再触发 [commitVolume] 落盘。
  Future<void> setVolume(double vol) async {
    state = state.copyWith(volume: vol);
    await _service.setVolume(vol);
  }

  /// 将当前内存音量写入 SharedPreferences，供滑杆拖拽结束时调用。
  Future<void> commitVolume() async {
    await _settingsRepo.setWhiteNoiseVolume(state.volume);
  }

  /// 切换循环模式（false 单曲循环 / true 列表循环），播放中则按新模式重启。
  Future<void> setLoopPlaylist(bool value) async {
    state = state.copyWith(loopPlaylist: value);
    await _settingsRepo.setAmbientLoopPlaylist(value);
    if (state.isPlaying) {
      await _service.stop();
      await _startPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (_starting) return;
    final sound = state.selectedSound;
    if (sound == null) return;
    _starting = true;
    final generation = _playGeneration;
    try {
      if (state.loopPlaylist && state.sounds.length > 1) {
        final index = state.sounds.indexWhere((s) => s.id == sound.id);
        await _service.playList(
          state.sounds.map((s) => s.filePath).toList(),
          index < 0 ? 0 : index,
        );
      } else {
        await _service.play(sound.filePath);
      }
      if (generation != _playGeneration) {
        await _service.stop();
        return;
      }
      state = state.copyWith(isPlaying: _service.isPlaying);
    } finally {
      _starting = false;
    }
  }

  Future<void> autoStartIfEnabled() async {
    if (!state.enabled || state.selectedSound == null) return;
    if (state.isPlaying) return;
    await _startPlayback();
  }

  Future<void> stopPlayback() async {
    _playGeneration++;
    await _service.stop();
    state = state.copyWith(isPlaying: false);
  }
}
