import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/layout_utils.dart';
import '../../core/utils/time_formatter.dart';
import '../../core/widgets/adaptive_bottom_sheet.dart';
import '../../providers/timer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/college_preference_provider.dart';
import '../../providers/stats_provider.dart';
import '../../data/models/college_preference.dart';
import '../../data/models/task.dart';
import 'widgets/timer_ring.dart';
import 'widgets/task_selector_sheet.dart';

class FocusView extends ConsumerStatefulWidget {
  const FocusView({super.key});

  @override
  ConsumerState<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends ConsumerState<FocusView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // 页面挂载时计时可能已在运行（如快照恢复），按当前状态起停呼吸动画。
    _syncPulse(ref.read(timerProvider).state);
  }

  /// 呼吸动画仅计时运行中播放，其余状态停掉常驻 Ticker 以省电并允许 settle。
  void _syncPulse(TimerState state) {
    final shouldPulse = state == TimerState.running;
    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldPulse && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showTaskSelector() {
    showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskSelectorSheet(
        onTaskSelected: (task) {
          if (task != null) {
            ref.read(timerProvider.notifier).selectTask(task);
          }
          ref.read(timerProvider.notifier).startTimer(task: task);
        },
        onSubjectSelected: (subject) {
          final notifier = ref.read(timerProvider.notifier);
          notifier.selectSubject(subject);
          notifier.startTimer();
        },
      ),
    );
  }

  void _showAbandonConfirm() {
    final settings = ref.read(settingsProvider);
    if (settings.strictMode) {
      showDialog(
        context: context,
        builder: (context) => _StrictModeConfirmDialog(
          onConfirm: () {
            ref.read(timerProvider.notifier).abandonSession();
            Navigator.pop(context);
          },
        ),
      );
    } else {
      ref.read(timerProvider.notifier).abandonSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    _syncPulse(timerState.state);
    final preferences = ref.watch(collegePreferenceProvider);
    final countdown = ref.watch(examCountdownProvider);
    final todayMinutes = ref.watch(statsProvider).getTodayStats().totalMinutes;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final focusTargetColor =
        timerState.currentTask?.subject ?? timerState.currentSubject;
    final subjectColor = focusTargetColor != null
        ? AppColors.getSubjectColor(focusTargetColor)
        : (isDark ? AppColors.primaryDark : AppColors.primaryLight);

    // 底部固定操作区：运行 / 暂停为控制按钮 + 放弃入口，完成态为后续动作按钮。
    // idle 态没有底部操作区——分钟栏已并入计时环下方的视觉簇（见 build），
    // 页面因此不会被一条「贴底的工具栏」压住。
    final bottomActions = _buildBottomActions(timerState, subjectColor);
    final hasGoalBanner = preferences.target != null && countdown != null;
    final showModeSelector =
        timerState.sessionType == SessionType.focus &&
        timerState.state == TimerState.idle;
    // 分钟栏跟着计时内容走（见 build 内的注释），只在「未开始」时出现；
    // 与改造前一致——一旦开始计时就不再需要改时长。
    final showDurationChips = timerState.state == TimerState.idle;

    return Scaffold(
      // 页面本身没有输入框，但保持默认的键盘避让：若将来在内容区出现输入，
      // body 会被压缩，底部固定操作区随之上移而不会被键盘盖住。
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            // 底部操作区最多占视口 55%（留 45% 给内容区），
            // 极端字号下操作区自身再滚动，而不是把内容区压成负数高度。
            final bottomMaxHeight = viewport.maxHeight * 0.55;
            const contentBottomGap = 8.0;

            return Column(
              children: [
                // 顶部固定区：状态徽标在左、费曼学习入口在右，贴着安全区顶部。
                // 旧实现把两者塞进「居中」的内容列里，内容不足一屏时整列被垂直
                // 居中，费曼入口浮到约 1/4 屏高处、上下各留一大片空白，
                // 看起来像一块悬空漂着的文字；移到固定栏后页面有了明确的顶部边界。
                _buildTopBar(timerState, subjectColor),
                if (hasGoalBanner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildGoalBanner(
                      preferences,
                      countdown,
                      todayMinutes,
                    ),
                  ),
                // 内容区：可滚动。内容不足一屏时在「头部之下、操作区之上」的
                // 剩余空间里居中，超出时滚动，任何高度 / 字号下都不会溢出。
                Expanded(
                  // 这一层 LayoutBuilder 量的是内容区自己的真实可视高度
                  // （已扣掉头部与底部操作区），计时环和居中都以它为基准，
                  // 否则 maxHeight 会多算头部那 100 多 dp，环会被推低。
                  child: LayoutBuilder(
                    builder: (context, contentBox) {
                      // 计时环直径：宽度取 70%（411dp 机型约 288，设计稿 280 上限），
                      // 高度再封 52% 的闸，防止矮屏 / 横屏 / 键盘弹起时把环撑破
                      // 内容区；最小 150 保证数字仍然清晰可读。
                      final ringSize = math
                          .min(
                            contentBox.maxWidth * 0.70,
                            contentBox.maxHeight * 0.52,
                          )
                          .clamp(150.0, 288.0);
                      return SingleChildScrollView(
                        // 底部留呼吸位：滚到底时最后一项不贴操作区；
                        // 刘海 / 手势条已由外层 SafeArea 扣掉，这里无需重复补。
                        padding: const EdgeInsets.only(
                          bottom: contentBottomGap,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              contentBox.maxHeight - contentBottomGap,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 模式开关 + 任务名 + 计时环是同一个视觉簇：
                              // 开关决定计时方式，紧贴环上方才符合「一组控件」的
                              // 直觉；如果把它钉在顶栏下方，中间会被拉开一百多 dp
                              // 的空洞，反而显得散。整簇作为一个整体居中。
                              if (showModeSelector) ...[
                                _buildModeSelector(timerState),
                                const SizedBox(height: 20),
                              ],
                              // 任务 / 科目名与计时环同属一簇：名字贴在环的正上方，
                              // 环下不再压任何元素，整簇作为一个整体居中。
                              if (timerState.currentTask != null) ...[
                                _buildTaskInfo(
                                  timerState.currentTask!,
                                  subjectColor,
                                ),
                                const SizedBox(height: 20),
                              ] else if (timerState.currentSubject != null) ...[
                                _buildSubjectInfo(
                                  timerState.currentSubject!,
                                  subjectColor,
                                ),
                                const SizedBox(height: 20),
                              ],
                              _buildTimerSection(
                                timerState,
                                subjectColor,
                                ringSize,
                              ),
                              // 分钟栏跟着计时环走，不钉在屏幕底部：
                              // 它是「选择本次专注多久」的输入控件，与环是同一组
                              // 语义（上面选方式、中间看时长、下面选时长），
                              // 贴底会让它看起来像一条全局工具栏，
                              // 且和底栏只隔一条分隔线，视觉发黏。
                              if (showDurationChips) ...[
                                const SizedBox(height: 28),
                                _buildDurationChips(timerState),
                              ],
                              // 光学居中：主视觉略高于几何中心更好看，
                              // 环下方留一点余量，不至于整簇贴到操作区上。
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (bottomActions != null)
                  // 底部固定操作区：外层 SafeArea 已扣掉刘海 / 手势条，
                  // 这里只约束最大高度并补视觉留白；超高时操作区自身可滚动，
                  // 保证按钮永远停在屏幕内且可点。
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: bottomMaxHeight),
                    child: Padding(
                      // 上下留白不对称：上面给 14 把操作区和计时内容分开，
                      // 下面给 22 让胶囊浮起来。原来上下都是 8，胶囊直接压在
                      // 底栏那根分隔线上，看上去像是「粘」在底边的工具栏。
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 22),
                      child: SingleChildScrollView(child: bottomActions),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 顶部固定栏：左侧当前计时状态，右侧费曼学习入口。
  Widget _buildTopBar(TimerStateData timerState, Color subjectColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
      child: Row(
        children: [
          // Expanded + Align：状态徽标按自身内容宽度靠左，整行剩下的宽度
          // 都交给它，极端字号下徽标内部会省略而不是把入口挤出屏幕。
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(timerState, subjectColor),
            ),
          ),
          const SizedBox(width: 12),
          _buildFeynmanEntry(),
        ],
      ),
    );
  }

  /// 费曼学习入口：顶部次级入口，样式刻意做轻（小图标 + 13 号字），
  /// 避免和页面中央的计时环抢视觉重心。
  Widget _buildFeynmanEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    return ClampedTextScale(
      maxScaleFactor: 1.3,
      child: TextButton.icon(
        onPressed: () => context.push('/feynman'),
        icon: const Icon(Icons.school_outlined, size: 18),
        label: const Text('费曼学习'),
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// 当前状态下需要固定在页面底部的操作区。
  Widget? _buildBottomActions(TimerStateData timerState, Color subjectColor) {
    switch (timerState.state) {
      case TimerState.idle:
        // 分钟栏已随计时环一起排版，底部不再固定任何东西（内容不足一屏时
        // 计时内容整体居中，页面底部保持干净的留白）。
        return null;
      case TimerState.running:
      case TimerState.paused:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlButtons(timerState, subjectColor),
            const SizedBox(height: 4),
            if (timerState.isFlexible)
              _buildFlexibleActions(timerState)
            else
              _buildAbandonButton(),
          ],
        );
      case TimerState.completed:
        return _buildCompletionActions(timerState, subjectColor);
    }
  }

  /// 目标院校轻胶囊：设置了目标院校后常驻显示，点击进入院校"目标"分段。
  /// 仅会话落库后"今日分钟"才会增长（与会话统计刷新机制一致）。
  Widget _buildGoalBanner(
    CollegePreferences preferences,
    ExamCountdown? countdown,
    int todayMinutes,
  ) {
    final target = preferences.target;
    if (target == null || countdown == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final detail = countdown.daysRemaining < 0
        ? '考研初试已开始'
        : countdown.daysRemaining == 0
        ? '考研初试就在今天'
        : '距考研 ${countdown.daysRemaining} 天';
    final timePart = todayMinutes > 0
        ? ' · 今日 $todayMinutes 分钟'
        : ' · 今日还没开始专注';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: GestureDetector(
          onTap: () {
            ref.read(collegeSegmentProvider.notifier).state = 'goals';
            context.go('/college');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_outlined, size: 14, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '目标 $target · $detail$timePart',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TimerStateData timerState, Color subjectColor) {
    final isRunning = timerState.state == TimerState.running;
    final isPaused = timerState.state == TimerState.paused;

    String statusText;
    if (timerState.sessionType == SessionType.focus) {
      statusText = isRunning ? '进行中' : '待开始';
    } else {
      statusText = isRunning ? '休息中' : '休息';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: subjectColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isRunning ? subjectColor : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: isPaused ? AppColors.textSecondary : subjectColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInfo(Task task, Color subjectColor) {
    return Text.rich(
      TextSpan(
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w300),
        children: [
          TextSpan(text: '${task.title} · '),
          TextSpan(
            text: task.subject,
            style: TextStyle(color: subjectColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectInfo(String subject, Color subjectColor) {
    return Text(
      subject,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w300,
        color: subjectColor,
      ),
    );
  }

  /// 计时区（计时环 + 倒计时）。
  ///
  /// [ringSize] 由上层 LayoutBuilder 按内容区最短边算出，避免在矮屏 / 横屏下
  /// 固定 280 撞穿可用高度。
  ///
  /// 环内排版要点：倒计时数字与「点击开始 / 剩余时间」是两种量级的信息，
  /// 必须各自独立缩放。旧实现把「数字 + 说明」整列塞进同一个 FittedBox，
  /// 数字撑满环内宽度时会把说明文字一起等比压到 6pt 左右（几乎看不见）；
  /// 现在只有数字参与缩放，说明文字保持真实字号。
  Widget _buildTimerSection(
    TimerStateData timerState,
    Color subjectColor,
    double ringSize,
  ) {
    // 环内左右各留 14% 做安全边，数字再大也只是先缩到环内。
    final innerWidth = ringSize * 0.72;
    // 数字字号跟环径走：411dp 机型环约 255 → 数字约 70，与设计稿 72 基本持平；
    // 小屏环 198 → 数字 54，仍然显著大于说明文字，层级不塌。
    final digitSize = (ringSize * 0.275).clamp(40.0, 74.0);

    return GestureDetector(
      onTap: timerState.state == TimerState.idle ? _showTaskSelector : null,
      child: TimerRing(
        progress: timerState.progress,
        progressColor: subjectColor,
        size: ringSize,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ringSize * 0.14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 只有数字进 FittedBox：宽度被环内可用宽卡住，超出才等比缩，
                // 说明文字不受牵连。
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: innerWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        TimeFormatter.formatSeconds(
                          timerState.displayedSeconds,
                        ),
                        key: ValueKey(timerState.displayedSeconds),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w200,
                              fontSize: digitSize,
                              letterSpacing: -1,
                            ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ringSize * 0.035),
                ClampedTextScale(
                  maxScaleFactor: 1.2,
                  child: Text(
                    timerState.state == TimerState.idle
                        ? '点击开始'
                        : timerState.isFlexible
                        ? '累计时间'
                        : '剩余时间',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(TimerStateData timerState, Color subjectColor) {
    final isRunning = timerState.state == TimerState.running;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.refresh,
          onTap: () => ref.read(timerProvider.notifier).resetTimer(),
          size: 48,
        ),
        const SizedBox(width: 24),
        ScaleTransition(
          scale: _pulseAnimation,
          child: _ControlButton(
            icon: isRunning ? Icons.pause : Icons.play_arrow,
            onTap: () => ref.read(timerProvider.notifier).toggleTimer(),
            size: 72,
            isPrimary: true,
            primaryColor: subjectColor,
          ),
        ),
        const SizedBox(width: 24),
        _ControlButton(
          icon: Icons.stop_outlined,
          onTap: _showAbandonConfirm,
          size: 48,
          iconColor: AppColors.error,
        ),
      ],
    );
  }

  /// 固定分钟栏（25 / 45 / 60 分钟）。
  ///
  /// 修复点：原实现是 `SingleChildScrollView > Row(mainAxisAlignment: center)`，
  /// 水平滚动视口内 Row 的宽度是无界的，`center` 会把内容整体左移，
  /// 内容宽于视口时第一枚胶囊被推到负偏移裁到屏幕外且滚不回来（小屏 / 字体放大触发）。
  /// 现在改为：内层 ConstrainedBox 保证内容至少与视口同宽（够宽时居中、不偏移），
  /// 内容更宽时按左端起点滚动，两端留 padding，任何宽度都看得到第 1 枚胶囊。
  Widget _buildDurationChips(TimerStateData timerState) {
    final durations = [25, 45, 60];
    final currentMinutes = timerState.totalTime ~/ 60;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const horizontalPadding = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: math.max(
                0,
                constraints.maxWidth - horizontalPadding * 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: durations.map((minutes) {
                final isSelected = currentMinutes == minutes;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(timerProvider.notifier).setDuration(minutes),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primaryLight)
                            : (isDark
                                      ? AppColors.dividerDark
                                      : AppColors.dividerLight)
                                  .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${minutes}分钟',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSelector(TimerStateData timerState) {
    // 分段按钮必须挤在一行里，字号放大到 1.4 倍以上时统一封顶，避免横向撑破。
    return ClampedTextScale(
      child: SegmentedButton<FocusTimerMode>(
        segments: const [
          ButtonSegment(value: FocusTimerMode.countdown, label: Text('固定计时')),
          ButtonSegment(value: FocusTimerMode.stopwatch, label: Text('灵活计时')),
        ],
        selected: {timerState.focusTimerMode},
        onSelectionChanged: (value) =>
            ref.read(timerProvider.notifier).setFocusTimerMode(value.first),
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildFlexibleActions(TimerStateData timerState) {
    // 用 Wrap 而不是 Row：字体放大 / 窄屏放不下时自动换行，而不是溢出。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          FilledButton.icon(
            onPressed: timerState.totalTime > 0 ? _finishFlexible : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('结束并记录'),
          ),
          TextButton(
            onPressed: _showAbandonConfirm,
            child: const Text('放弃且不记录'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishFlexible() async {
    final saved = await ref
        .read(timerProvider.notifier)
        .finishFlexibleSession();
    if (saved && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本次灵活专注已记录')));
    }
  }

  Widget _buildAbandonButton() {
    return TextButton(
      onPressed: _showAbandonConfirm,
      child: Text(
        '放弃本次专注',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildCompletionActions(
    TimerStateData timerState,
    Color subjectColor,
  ) {
    final completedFocus = timerState.sessionType == SessionType.focus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            completedFocus ? '本轮专注已完成' : '休息结束，准备继续',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final notifier = ref.read(timerProvider.notifier);
              if (completedFocus) {
                notifier.startBreak(startImmediately: true);
              } else {
                notifier.switchToFocus(startImmediately: true);
              }
            },
            icon: Icon(completedFocus ? Icons.coffee : Icons.play_arrow),
            label: Text(completedFocus ? '开始休息' : '开始下一轮'),
            style: FilledButton.styleFrom(backgroundColor: subjectColor),
          ),
          TextButton(
            onPressed: () => ref.read(timerProvider.notifier).switchToFocus(),
            child: Text(completedFocus ? '跳过休息' : '稍后开始'),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isPrimary;
  final Color? primaryColor;
  final Color? iconColor;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.isPrimary = false,
    this.primaryColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPrimary
              ? (primaryColor ?? AppColors.primaryLight)
              : (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight)
                    .withValues(alpha: 0.5),
          shape: BoxShape.circle,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: (primaryColor ?? AppColors.primaryLight).withValues(
                      alpha: 0.3,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: size * 0.4,
          color: isPrimary
              ? Colors.white
              : (iconColor ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _StrictModeConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const _StrictModeConfirmDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '确定要放弃吗？',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '开启严苛模式后，不建议中途退出专注',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          '继续专注',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('确认放弃'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
