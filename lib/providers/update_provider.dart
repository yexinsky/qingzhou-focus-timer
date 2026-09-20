import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_update.dart';
import '../data/repositories/update_repository.dart';

/// 仓库按需惰性初始化（SharedPreferences 首次访问时才拉起），
/// 因此无需在 main.dart 中预初始化或注入。
final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => UpdateRepository(),
);

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(ref.watch(updateRepositoryProvider)),
);

class UpdateState {
  const UpdateState({this.checking = false, this.available});

  /// 正在请求远端清单，用于设置页手动检查时的加载态。
  final bool checking;

  /// 自动检查发现且未被跳过的新版本；由 app 根部监听并弹出更新弹窗。
  final AppUpdate? available;

  UpdateState copyWith({bool? checking, AppUpdate? available}) => UpdateState(
    checking: checking ?? this.checking,
    available: available ?? this.available,
  );
}

/// 一次更新检查的结论，手动检查时供调用方给用户反馈。
class UpdateCheckResult {
  const UpdateCheckResult({this.update, this.failed = false});

  /// 非空表示有比当前安装版本更新的版本（手动检查不受"跳过此版本"影响）。
  final AppUpdate? update;

  /// 仅手动检查时向用户提示；自动检查一律静默失败。
  final bool failed;
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier(this._repository) : super(const UpdateState());

  final UpdateRepository _repository;

  /// 检查远端是否有新版本。
  ///
  /// 自动检查（manual = false）全程静默：网络失败不打扰，命中用户
  /// 已跳过的版本不提示，仅把需要弹窗的结果写入 [UpdateState.available]。
  /// 手动检查（manual = true）忽略"跳过此版本"，失败时通过返回值
  /// [UpdateCheckResult.failed] 提示，但不改动自动弹窗的状态。
  Future<UpdateCheckResult> checkForUpdate({bool manual = false}) async {
    if (state.checking) return const UpdateCheckResult();
    state = state.copyWith(checking: true);
    try {
      final update = await _repository.fetchLatestUpdate();
      if (update == null) {
        return const UpdateCheckResult(failed: true);
      }
      if (!await _repository.isUpdateAvailable(update)) {
        return const UpdateCheckResult();
      }
      if (!manual) {
        final skipped = await _repository.getSkippedVersion();
        if (skipped == update.version) return const UpdateCheckResult();
        state = state.copyWith(available: update);
      }
      return UpdateCheckResult(update: update);
    } finally {
      state = state.copyWith(checking: false);
    }
  }

  /// 记住"跳过此版本"：之后自动检查遇到同一版本号不再弹窗，
  /// 手动检查不受影响；取消勾选时清除记录。
  Future<void> skipVersion(String version) => _repository.skipVersion(version);

  Future<void> clearSkippedVersion() => _repository.clearSkippedVersion();
}
