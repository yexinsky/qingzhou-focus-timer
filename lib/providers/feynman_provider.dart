import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/feynman_unit.dart';
import '../data/models/stumble_mark.dart';
import '../data/repositories/feynman_repository.dart';

final feynmanRepositoryProvider = Provider<FeynmanRepository>(
  (_) => throw UnimplementedError(),
);
final feynmanRefreshProvider = StateProvider<int>((_) => 0);
final feynmanUnitsProvider = Provider<List<FeynmanUnit>>((ref) {
  ref.watch(feynmanRefreshProvider);
  return ref.watch(feynmanRepositoryProvider).units;
});
final stumbleMarksProvider = Provider<List<StumbleMark>>((ref) {
  ref.watch(feynmanRefreshProvider);
  return ref.watch(feynmanRepositoryProvider).marks;
});
final feynmanProvider = StateNotifierProvider<FeynmanNotifier, FeynmanUnit?>(
  (ref) => FeynmanNotifier(ref),
);

class FeynmanNotifier extends StateNotifier<FeynmanUnit?> {
  static const outcomeExplained = 'explained';
  static const outcomeBlindSpot = 'blind_spot';
  static const outcomeReread = 'reread';
  FeynmanNotifier(this.ref)
    : super(ref.read(feynmanRepositoryProvider).activeUnit) {
    if (state != null) _startTicker();
  }
  final Ref ref;
  Timer? _ticker;
  int get elapsed {
    final u = state;
    if (u == null) return 0;
    if (u.phase == 'ready' || u.phase == 'review' || u.status != 'active') {
      return u.accumulatedPhaseSeconds;
    }
    return u.accumulatedPhaseSeconds +
        DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(u.phaseStartedAt))
            .inSeconds;
  }

  int get remaining {
    final u = state;
    if (u == null) return 0;
    final plan = u.phase == 'input'
        ? u.inputPlannedSeconds
        : u.outputPlannedSeconds;
    return (plan - elapsed).clamp(0, plan);
  }

  Future<void> start({
    required String title,
    required String subject,
    String chapter = '',
    String topic = '',
    String? taskId,
    int inputMinutes = 20,
    int outputMinutes = 10,
  }) async {
    if (state?.status == 'active') return;
    if (outputMinutes * 2 < inputMinutes)
      throw ArgumentError('输出时间不得低于输入时间的50%');
    final now = DateTime.now().millisecondsSinceEpoch;
    state = FeynmanUnit(
      id: const Uuid().v4(),
      taskId: taskId,
      title: title,
      subject: subject,
      chapter: chapter,
      topic: topic,
      inputPlannedSeconds: inputMinutes * 60,
      outputPlannedSeconds: outputMinutes * 60,
      startedAt: now,
    );
    await _save();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final u = state;
      if (u == null || u.status != 'active') return;
      if (u.phase == 'input' && elapsed >= u.inputPlannedSeconds) {
        state = u.copyWith(
          inputActualSeconds: elapsed,
          phase: 'ready',
          accumulatedPhaseSeconds: 0,
        );
        await _save();
        _ticker?.cancel();
      } else {
        state = u.copyWith();
      }
    });
  }

  Future<void> beginOutput() async {
    final u = state;
    if (u == null || u.status != 'active' || u.phase != 'ready') return;
    state = u.copyWith(
      phase: 'output',
      phaseStartedAt: DateTime.now().millisecondsSinceEpoch,
      accumulatedPhaseSeconds: 0,
    );
    await _save();
    _startTicker();
  }

  Future<void> saveDraft(String text) async {
    if (state == null) return;
    state = state!.copyWith(textOutput: text);
    await _save();
  }

  Future<StumbleMark?> markStumble() async {
    final u = state;
    if (u == null || u.status != 'active' || u.phase != 'output') return null;
    final mark = StumbleMark(
      id: const Uuid().v4(),
      unitId: u.id,
      subject: u.subject,
      chapter: u.chapter,
      topic: u.topic,
      offsetSeconds: elapsed,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(feynmanRepositoryProvider).saveMark(mark);
    _refresh();
    return mark;
  }

  Future<void> updateMark(StumbleMark mark) => ref
      .read(feynmanRepositoryProvider)
      .saveMark(mark)
      .then((_) => _refresh());
  Future<void> beginReview() async {
    final u = state;
    if (u == null || u.status != 'active' || u.phase != 'output') return;
    final output = elapsed;
    state = u.copyWith(
      outputActualSeconds: output,
      phase: 'review',
      accumulatedPhaseSeconds: output,
    );
    _ticker?.cancel();
    await _save();
  }

  Future<void> complete({required String outcome}) async {
    final u = state;
    if (u == null || u.status != 'active' || u.phase != 'review') return;
    if (outcome != outcomeExplained &&
        outcome != outcomeBlindSpot &&
        outcome != outcomeReread) {
      throw ArgumentError.value(outcome, 'outcome', '未知复盘结果');
    }
    final input = u.inputActualSeconds == 0 && u.phase != 'input'
        ? u.inputPlannedSeconds
        : u.inputActualSeconds;
    final output = u.outputActualSeconds;
    final met = output * 2 >= input;
    state = u.copyWith(
      inputActualSeconds: input,
      outputActualSeconds: output,
      completedAt: DateTime.now().millisecondsSinceEpoch,
      status: outcome,
      recommendReread: outcome != outcomeExplained || !met,
      phase: 'review',
      accumulatedPhaseSeconds: output,
    );
    await _save();
    _ticker?.cancel();
  }

  Future<void> reset() async {
    state = null;
    _ticker?.cancel();
  }

  Future<void> _save() async {
    await ref.read(feynmanRepositoryProvider).saveUnit(state!);
    _refresh();
  }

  void _refresh() => ref.read(feynmanRefreshProvider.notifier).state++;
  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
