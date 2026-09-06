import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';

class BackupSummary {
  const BackupSummary({required this.taskCount, required this.sessionCount});
  final int taskCount;
  final int sessionCount;
}

class DataBackupService {
  DataBackupService(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TaskRepository _repository;
  final DateTime Function() _now;

  Future<File> exportToFile() async {
    final data = <String, dynamic>{
      'format': 'qingzhou-backup',
      'version': 1,
      'exportedAt': _now().toIso8601String(),
      'tasks': _repository.getAllTasks().map((item) => item.toJson()).toList(),
      'sessions': _repository
          .getAllSessions()
          .map((item) => item.toJson())
          .toList(),
    };
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}qingzhou-backup-$stamp.json',
    );
    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  Future<BackupSummary> importFromFile(File file) async =>
      importJson(await file.readAsString());

  Future<BackupSummary> importJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'qingzhou-backup') {
      throw const FormatException('不是有效的轻舟备份文件');
    }
    final version = decoded['version'];
    if (version != 1) throw FormatException('不支持的备份版本：$version');
    final rawTasks = decoded['tasks'];
    final rawSessions = decoded['sessions'];
    if (rawTasks is! List || rawSessions is! List) {
      throw const FormatException('备份内容不完整');
    }
    final tasks = rawTasks
        .map((value) => Task.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList();
    final sessions = rawSessions
        .map(
          (value) =>
              FocusSession.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    _ensureUnique(tasks.map((item) => item.id), '任务');
    _ensureUnique(sessions.map((item) => item.id), '专注记录');
    // Parsing and validation above must finish before any existing data is touched.
    // Keep an in-memory rollback snapshot in case a storage write fails midway.
    final previousTasks = _repository.getAllTasks();
    final previousSessions = _repository.getAllSessions();
    try {
      await _repository.replaceAllData(tasks: tasks, sessions: sessions);
    } catch (_) {
      await _repository.replaceAllData(
        tasks: previousTasks,
        sessions: previousSessions,
      );
      rethrow;
    }
    return BackupSummary(
      taskCount: tasks.length,
      sessionCount: sessions.length,
    );
  }

  void _ensureUnique(Iterable<String> ids, String label) {
    final values = ids.toList();
    if (values.toSet().length != values.length) {
      throw FormatException('$label中存在重复编号');
    }
  }
}
