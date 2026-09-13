import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_formatter.dart';
import '../../providers/timer_provider.dart';
import '../../providers/settings_provider.dart';
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
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showTaskSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskSelectorSheet(
        onTaskSelected: (task) {
          if (task != null) {
            ref.read(timerProvider.notifier).selectTask(task);
          }
          ref.read(timerProvider.notifier).startTimer(task: task);
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
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectColor = timerState.currentTask != null
        ? AppColors.getSubjectColor(timerState.currentTask!.subject)
        : (isDark ? AppColors.primaryDark : AppColors.primaryLight);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: TextButton.icon(
                  onPressed: () => context.push('/feynman'),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('费曼学习'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (timerState.sessionType == SessionType.focus &&
                timerState.state == TimerState.idle) ...[
              _buildModeSelector(timerState),
              const SizedBox(height: 16),
            ],
            _buildStatusBadge(timerState, subjectColor),
            if (timerState.currentTask != null) ...[
              const SizedBox(height: 24),
              _buildTaskInfo(timerState.currentTask!, subjectColor),
            ] else ...[
              const SizedBox(height: 24),
            ],
            Expanded(
              child: Center(
                child: _buildTimerSection(timerState, subjectColor),
              ),
            ),
            if (timerState.state == TimerState.idle)
              _buildDurationChips(timerState, settings),
            if (timerState.state == TimerState.running ||
                timerState.state == TimerState.paused)
              timerState.isFlexible
                  ? _buildFlexibleActions(timerState)
                  : _buildAbandonButton(),
            if (timerState.state == TimerState.completed)
              _buildCompletionActions(timerState, subjectColor),
            const SizedBox(height: 100),
          ],
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

  Widget _buildTimerSection(TimerStateData timerState, Color subjectColor) {
    return GestureDetector(
      onTap: timerState.state == TimerState.idle ? _showTaskSelector : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TimerRing(
            progress: timerState.progress,
            progressColor: subjectColor,
            size: 280,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      TimeFormatter.formatSeconds(timerState.displayedSeconds),
                      key: ValueKey(timerState.displayedSeconds),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w200,
                        fontSize: 72,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timerState.state == TimerState.idle
                        ? '点击开始'
                        : timerState.isFlexible
                        ? '累计时间'
                        : '剩余时间',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          if (timerState.state == TimerState.running ||
              timerState.state == TimerState.paused)
            _buildControlButtons(timerState, subjectColor),
        ],
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

  Widget _buildDurationChips(
    TimerStateData timerState,
    SettingsState settings,
  ) {
    final durations = [25, 45, 60, 90];
    final currentMinutes = timerState.totalTime ~/ 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
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
                        ? (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.primaryDark
                              : AppColors.primaryLight)
                        : AppColors.dividerLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${minutes}分钟',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildModeSelector(TimerStateData timerState) {
    return SegmentedButton<FocusTimerMode>(
      segments: const [
        ButtonSegment(value: FocusTimerMode.countdown, label: Text('固定计时')),
        ButtonSegment(value: FocusTimerMode.stopwatch, label: Text('灵活计时')),
      ],
      selected: {timerState.focusTimerMode},
      onSelectionChanged: (value) =>
          ref.read(timerProvider.notifier).setFocusTimerMode(value.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildFlexibleActions(TimerStateData timerState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: timerState.totalTime > 0 ? _finishFlexible : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('结束并记录'),
          ),
          const SizedBox(width: 12),
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
              : AppColors.dividerLight.withValues(alpha: 0.5),
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
