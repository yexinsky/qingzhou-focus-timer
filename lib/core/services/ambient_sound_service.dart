import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AmbientSound {
  final String id;
  final String name;
  final String filePath;

  const AmbientSound({
    required this.id,
    required this.name,
    required this.filePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filePath': filePath,
  };

  factory AmbientSound.fromJson(Map<String, dynamic> json) => AmbientSound(
    id: json['id'] as String,
    name: json['name'] as String,
    filePath: json['filePath'] as String,
  );
}

class AmbientSoundService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isPlaying = false;
  double _volume = 0.5;
  String? _currentPath;

  bool get isPlaying => _isPlaying;
  String? get currentPath => _currentPath;
  double get volume => _volume;

  AmbientSoundService() {
    // 播放状态以 just_audio 事件流为唯一事实来源：解码失败等平台侧停止
    // 不会走我们的 stop()，若无此订阅 _isPlaying 会恒为 true，
    // 导致 provider 的 autoStartIfEnabled 早退、无法自愈重播。
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
    });
  }

  Future<Directory> get _soundsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/ambient_sounds');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<AmbientSound> importFile(File sourceFile) async {
    final dir = await _soundsDir;
    final fileName = sourceFile.uri.pathSegments.last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final id = const Uuid().v4();
    final ext = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.'))
        : '';
    final destPath = '${dir.path}/$id$ext';
    await sourceFile.copy(destPath);
    return AmbientSound(id: id, name: nameWithoutExt, filePath: destPath);
  }

  Future<void> deleteFile(AmbientSound sound) async {
    final file = File(sound.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> play(String filePath) async {
    try {
      if (_isPlaying && _currentPath == filePath) return;
      if (_isPlaying) {
        await _player.stop();
      }
      await _player.setFilePath(filePath, preload: true);
      await _player.setLoopMode(LoopMode.all);
      await _player.setVolume(_volume);
      // play() 的 Future 要到停止/播完才完成，状态必须在启动前置标记，
      // 之后再由 playerStateStream 持续校正，避免事后写回陈旧 true 卡死。
      _isPlaying = true;
      _currentPath = filePath;
      await _player.play();
    } catch (e) {
      debugPrint('AmbientSoundService.play failed: $e');
      _isPlaying = false;
      _currentPath = null;
    }
  }

  /// 列表循环：按顺序连续播放全部音频并循环，从 [startIndex] 开始。
  Future<void> playList(List<String> filePaths, int startIndex) async {
    try {
      if (_isPlaying) {
        await _player.stop();
      }
      final safeIndex = startIndex.clamp(0, filePaths.length - 1);
      await _player.setAudioSource(
        ConcatenatingAudioSource(
          children: [for (final p in filePaths) AudioSource.file(p)],
        ),
        initialIndex: safeIndex,
      );
      await _player.setLoopMode(LoopMode.all);
      await _player.setVolume(_volume);
      // 同 play()：启动前置标记，真实状态由事件流校正
      _isPlaying = true;
      _currentPath = filePaths[safeIndex];
      await _player.play();
    } catch (e) {
      debugPrint('AmbientSoundService.playList failed: $e');
      _isPlaying = false;
      _currentPath = null;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
  }

  void dispose() {
    // 先取消订阅再释放播放器，避免关闭竞态产生未处理的流错误
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    _player.dispose();
  }
}
