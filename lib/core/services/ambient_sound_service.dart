import 'dart:io';

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
  bool _isPlaying = false;
  double _volume = 0.5;
  String? _currentPath;

  bool get isPlaying => _isPlaying;
  String? get currentPath => _currentPath;
  double get volume => _volume;

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
      await _player.play();
      _isPlaying = true;
      _currentPath = filePath;
    } catch (_) {
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
    _player.dispose();
  }
}
