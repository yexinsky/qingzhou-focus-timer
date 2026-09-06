import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/data_backup_service.dart';
import '../data/models/focus_session.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'timer_provider.dart';

const timerSnapshotKey = 'timer_session_snapshot_v1';

final dataBackupServiceProvider = Provider<DataBackupService>(
  (ref) => DataBackupService(ref.watch(taskRepositoryProvider)),
);

final sessionHistoryProvider = Provider<List<FocusSession>>((ref) {
  ref.watch(statsRefreshProvider);
  return ref
      .watch(taskRepositoryProvider)
      .getAllSessions()
      .where((session) => session.type == 'focus')
      .toList();
});

final dataManagementProvider =
    StateNotifierProvider<DataManagementNotifier, bool>(
      (ref) => DataManagementNotifier(ref),
    );

class DataManagementNotifier extends StateNotifier<bool> {
  DataManagementNotifier(this._ref) : super(false);
  final Ref _ref;

  Future<T> run<T>(Future<T> Function(DataBackupService service) action) async {
    if (state) throw StateError('数据操作正在进行');
    state = true;
    try {
      final result = await action(_ref.read(dataBackupServiceProvider));
      _refresh();
      return result;
    } finally {
      state = false;
    }
  }

  Future<void> deleteSession(String id) async {
    await _ref.read(taskRepositoryProvider).deleteSession(id);
    _refresh();
  }

  Future<void> clearAllData() async {
    _ref.read(timerProvider.notifier).abandonSession();
    await _ref.read(taskRepositoryProvider).clearAllData();
    await _ref.read(settingsRepositoryProvider).remove(timerSnapshotKey);
    _refresh();
  }

  void _refresh() {
    _ref.read(tasksProvider.notifier).refresh();
    _ref.read(statsRefreshProvider.notifier).state++;
  }
}
