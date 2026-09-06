import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qingzhou_focus/data/models/feynman_unit.dart';
import 'package:qingzhou_focus/data/models/stumble_mark.dart';
import 'package:qingzhou_focus/data/repositories/feynman_repository.dart';
import 'package:qingzhou_focus/providers/feynman_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FeynmanRepository repository;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qingzhou_feynman_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FeynmanUnitAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(StumbleMarkAdapter());
    }
    repository = FeynmanRepository();
    await repository.init();
    container = ProviderContainer(
      overrides: [feynmanRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('start rejects output duration below 50 percent', () async {
    final notifier = container.read(feynmanProvider.notifier);
    await expectLater(
      notifier.start(
        title: '极限',
        subject: '数学',
        inputMinutes: 20,
        outputMinutes: 9,
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(container.read(feynmanProvider), isNull);
    expect(repository.units, isEmpty);
  });

  test(
    'text workflow persists draft, anonymous stumble and edited mark',
    () async {
      final notifier = container.read(feynmanProvider.notifier);
      await notifier.start(
        title: '极限',
        subject: '数学',
        chapter: '第一章',
        topic: '定义',
        inputMinutes: 2,
        outputMinutes: 1,
      );
      final input = container.read(feynmanProvider)!;
      await repository.saveUnit(input.copyWith(phase: 'ready'));
      container.dispose();
      container = ProviderContainer(
        overrides: [feynmanRepositoryProvider.overrideWithValue(repository)],
      );
      final outputNotifier = container.read(feynmanProvider.notifier);
      await outputNotifier.beginOutput();
      await outputNotifier.saveDraft('极限描述函数趋近时的行为');

      final anonymous = (await outputNotifier.markStumble())!;
      expect(repository.marks, hasLength(1));
      expect(repository.marks.single.keyword, isEmpty);
      expect(anonymous.unitId, container.read(feynmanProvider)!.id);

      await outputNotifier.updateMark(
        anonymous.copyWith(
          keyword: '邻域',
          note: '无法用简单语言解释',
          reason: '定义不熟',
          severity: 3,
        ),
      );

      final saved = repository.activeUnit!;
      expect(saved.phase, 'output');
      expect(saved.textOutput, '极限描述函数趋近时的行为');
      expect(repository.marks.single.keyword, '邻域');
      expect(repository.marks.single.severity, 3);
    },
  );

  test(
    'short output recommends reread even when outcome is explained',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final unit = FeynmanUnit(
        id: 'short-output',
        title: '导数',
        subject: '数学',
        inputPlannedSeconds: 1200,
        outputPlannedSeconds: 600,
        inputActualSeconds: 1200,
        startedAt: now,
        phase: 'output',
        phaseStartedAt: now,
      );
      await repository.saveUnit(unit);
      container.dispose();
      container = ProviderContainer(
        overrides: [feynmanRepositoryProvider.overrideWithValue(repository)],
      );

      final notifier = container.read(feynmanProvider.notifier);
      await notifier.beginReview();
      await notifier.complete(outcome: FeynmanNotifier.outcomeExplained);

      final completed = container.read(feynmanProvider)!;
      expect(completed.status, 'explained');
      expect(completed.outputActualSeconds, lessThan(600));
      expect(completed.recommendReread, isTrue);
      expect(repository.activeUnit, isNull);
    },
  );

  test(
    'blind spot outcome recommends reread regardless of time ratio',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final unit = FeynmanUnit(
        id: 'blind-spot',
        title: '积分',
        subject: '数学',
        inputPlannedSeconds: 120,
        outputPlannedSeconds: 60,
        inputActualSeconds: 120,
        startedAt: now,
        phase: 'output',
        phaseStartedAt: now - 70000,
      );
      await repository.saveUnit(unit);
      container.dispose();
      container = ProviderContainer(
        overrides: [feynmanRepositoryProvider.overrideWithValue(repository)],
      );

      final notifier = container.read(feynmanProvider.notifier);
      await notifier.beginReview();
      await notifier.complete(outcome: FeynmanNotifier.outcomeBlindSpot);
      expect(
        container.read(feynmanProvider)!.outputActualSeconds,
        greaterThanOrEqualTo(60),
      );
      expect(container.read(feynmanProvider)!.recommendReread, isTrue);
    },
  );

  test('start is idempotent while another unit is active', () async {
    final notifier = container.read(feynmanProvider.notifier);
    await notifier.start(title: 'first', subject: 'math');
    final firstId = container.read(feynmanProvider)!.id;
    await notifier.start(title: 'second', subject: 'physics');

    expect(repository.units, hasLength(1));
    expect(container.read(feynmanProvider)!.id, firstId);
    expect(container.read(feynmanProvider)!.title, 'first');
  });

  test('beginOutput only transitions from ready', () async {
    final notifier = container.read(feynmanProvider.notifier);
    await notifier.start(title: 'limit', subject: 'math');
    await notifier.beginOutput();
    expect(container.read(feynmanProvider)!.phase, 'input');

    final input = container.read(feynmanProvider)!;
    await repository.saveUnit(input.copyWith(phase: 'ready'));
    container.dispose();
    container = ProviderContainer(
      overrides: [feynmanRepositoryProvider.overrideWithValue(repository)],
    );
    final restored = container.read(feynmanProvider.notifier);
    await restored.beginOutput();
    expect(container.read(feynmanProvider)!.phase, 'output');
    final startedAt = container.read(feynmanProvider)!.phaseStartedAt;
    await restored.beginOutput();
    expect(container.read(feynmanProvider)!.phaseStartedAt, startedAt);
  });

  test('markStumble is safe and only records during active output', () async {
    final notifier = container.read(feynmanProvider.notifier);
    expect(await notifier.markStumble(), isNull);
    await notifier.start(title: 'limit', subject: 'math');
    expect(await notifier.markStumble(), isNull);
    expect(repository.marks, isEmpty);
  });

  test('beginReview freezes output elapsed time', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await repository.saveUnit(
      FeynmanUnit(
        id: 'freeze-output',
        title: 'derivative',
        subject: 'math',
        inputPlannedSeconds: 120,
        outputPlannedSeconds: 60,
        inputActualSeconds: 120,
        startedAt: now,
        phase: 'output',
        phaseStartedAt: now - 5000,
      ),
    );
    container.dispose();
    container = ProviderContainer(
      overrides: [feynmanRepositoryProvider.overrideWithValue(repository)],
    );
    final notifier = container.read(feynmanProvider.notifier);
    await notifier.beginReview();
    final frozen = container.read(feynmanProvider)!.outputActualSeconds;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(notifier.elapsed, frozen);
    await notifier.complete(outcome: FeynmanNotifier.outcomeExplained);
    expect(container.read(feynmanProvider)!.outputActualSeconds, frozen);
  });
}
