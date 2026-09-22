import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qingzhou_focus/core/services/data_backup_service.dart';
import 'package:qingzhou_focus/data/models/feynman_unit.dart';
import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/data/models/stumble_mark.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/data/repositories/feynman_repository.dart';
import 'package:qingzhou_focus/data/repositories/task_repository.dart';

/// 备份导入导出是数据逃生通道：重点验证 v2 自产备份可导回（历史上白名单只收
/// v1 导致导出格式互斥）、v1 历史备份兼容、以及坏文件不触碰现有数据。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late TaskRepository taskRepository;
  late FeynmanRepository feynmanRepository;
  late DataBackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qingzhou_backup_test_');
    taskRepository = TaskRepository(storagePath: tempDir.path);
    await taskRepository.init();
    // Hive.init 已由 TaskRepository 完成，费曼仓库直接在全局 home 下开 box
    feynmanRepository = FeynmanRepository();
    await feynmanRepository.init();
    service = DataBackupService(
      taskRepository,
      feynmanRepository: feynmanRepository,
      now: () => DateTime(2026, 9, 6, 12),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> seed() async {
    await taskRepository.addTask(
      Task(
        id: 't1',
        title: '高数复习',
        subject: '数学',
        dateKey: '2026-09-06',
        createdAt: 1,
      ),
    );
    await taskRepository.addSession(
      FocusSession(
        id: 's1',
        taskId: 't1',
        taskTitle: '高数复习',
        subject: '数学',
        startTime: 1000,
        duration: 1500,
        type: 'focus',
        dateKey: '2026-09-06',
      ),
    );
    await feynmanRepository.saveUnit(
      FeynmanUnit(id: 'u1', title: '极限', subject: '数学', startedAt: 2000),
    );
    await feynmanRepository.saveMark(
      StumbleMark(
        id: 'm1',
        unitId: 'u1',
        subject: '数学',
        offsetSeconds: 30,
        createdAt: 3000,
      ),
    );
  }

  Map<String, dynamic> decode(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  test('v2 export→import round-trip restores all data', () async {
    await seed();
    final exported = service.exportToJson();
    final decoded = decode(exported);
    expect(decoded['format'], 'qingzhou-backup');
    expect(decoded['version'], 2);

    // 清空后导回，模拟换机恢复
    await taskRepository.clearAllData();
    await feynmanRepository.clear();
    expect(taskRepository.getAllTasks(), isEmpty);

    final summary = await service.importJson(exported);
    expect(summary.taskCount, 1);
    expect(summary.sessionCount, 1);
    expect(summary.feynmanUnitCount, 1);
    expect(summary.stumbleMarkCount, 1);

    final task = taskRepository.getAllTasks().single;
    expect(task.id, 't1');
    expect(task.title, '高数复习');
    expect(task.subject, '数学');
    expect(task.dateKey, '2026-09-06');
    final session = taskRepository.getAllSessions().single;
    expect(session.id, 's1');
    expect(session.taskId, 't1');
    expect(session.taskTitle, '高数复习');
    expect(session.duration, 1500);
    expect(session.timerMode, 'countdown');
    expect(feynmanRepository.units.single.id, 'u1');
    expect(feynmanRepository.marks.single.id, 'm1');
  });

  test('v1 backup without feynman sections still imports', () async {
    final v1 = jsonEncode({
      'format': 'qingzhou-backup',
      'version': 1,
      'exportedAt': '2026-01-01T00:00:00.000',
      'tasks': [
        {
          'id': 'old1',
          'title': '历史任务',
          'subject': '英语',
          'completed': false,
          'dateKey': '2026-01-01',
          'createdAt': 5,
        },
      ],
      'sessions': [
        {
          'id': 'olds1',
          'taskId': null,
          'taskTitle': null,
          'subject': '英语',
          'startTime': 1,
          'duration': 60,
          'type': 'focus',
          'dateKey': '2026-01-01',
        },
      ],
    });
    final summary = await service.importJson(v1);
    expect(summary.taskCount, 1);
    expect(summary.sessionCount, 1);
    expect(summary.feynmanUnitCount, 0);
    expect(summary.stumbleMarkCount, 0);
    expect(taskRepository.getAllTasks().single.id, 'old1');
    // v1 无 timerMode 字段，反序列化回落到默认 countdown
    expect(taskRepository.getAllSessions().single.timerMode, 'countdown');
  });

  test('unsupported future version is rejected', () async {
    final v3 = jsonEncode({
      'format': 'qingzhou-backup',
      'version': 3,
      'tasks': <Object>[],
      'sessions': <Object>[],
    });
    await expectLater(
      service.importJson(v3),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('不支持的备份版本'),
        ),
      ),
    );
  });

  test('corrupt or invalid files leave existing data untouched', () async {
    await seed();
    await expectLater(
      service.importJson('{ not valid json'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.importJson(
        jsonEncode({
          'format': 'something-else',
          'version': 2,
          'tasks': <Object>[],
          'sessions': <Object>[],
        }),
      ),
      throwsA(isA<FormatException>()),
    );
    // 解析/校验全部通过前不得触碰存储：原数据保持完整
    expect(taskRepository.getAllTasks().single.id, 't1');
    expect(taskRepository.getAllSessions().single.id, 's1');
    expect(feynmanRepository.units.single.id, 'u1');
    expect(feynmanRepository.marks.single.id, 'm1');
  });

  test('duplicate ids are rejected before touching storage', () async {
    await seed();
    final duplicate = jsonEncode({
      'format': 'qingzhou-backup',
      'version': 2,
      'exportedAt': '2026-09-06T12:00:00.000',
      'tasks': <Object>[],
      'feynmanUnits': <Object>[],
      'stumbleMarks': <Object>[],
      'sessions': [
        FocusSession(
          id: 'dup',
          subject: '数学',
          startTime: 1,
          duration: 60,
          type: 'focus',
          dateKey: '2026-09-06',
        ).toJson(),
        FocusSession(
          id: 'dup',
          subject: '数学',
          startTime: 2,
          duration: 60,
          type: 'focus',
          dateKey: '2026-09-06',
        ).toJson(),
      ],
    });
    await expectLater(
      service.importJson(duplicate),
      throwsA(isA<FormatException>()),
    );
    expect(taskRepository.getAllSessions().single.id, 's1');
  });
}
