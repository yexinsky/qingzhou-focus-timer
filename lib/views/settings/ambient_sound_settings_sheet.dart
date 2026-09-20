import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_bottom_sheet.dart';
import '../../providers/ambient_sound_provider.dart';

class AmbientSoundSettingsSheet extends ConsumerWidget {
  const AmbientSoundSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AmbientSoundSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ambientSoundProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('氛围音', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '导入音频文件，专注时自动播放',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _buildSoundList(context, ref, state, primary),
          const SizedBox(height: 16),
          _buildImportButton(context, ref, primary),
          if (state.sounds.length > 1) ...[
            const SizedBox(height: 16),
            _buildLoopModeSelector(context, ref, state, primary),
          ],
          const SizedBox(height: 24),
          _buildVolumeSlider(context, ref, state, primary),
          const SizedBox(height: 20),
          _buildAutoPlayToggle(context, ref, state, primary),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSoundList(
    BuildContext context,
    WidgetRef ref,
    AmbientSoundState state,
    Color primary,
  ) {
    if (state.sounds.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 36,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              '还没有音频文件',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '点击下方按钮导入音频',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: state.sounds.map((sound) {
        final isSelected = state.selectedSoundId == sound.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.08)
                  : AppColors.dividerLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: primary.withValues(alpha: 0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (isSelected) {
                        ref
                            .read(ambientSoundProvider.notifier)
                            .clearSoundSelection();
                      } else {
                        ref
                            .read(ambientSoundProvider.notifier)
                            .selectSound(sound.id);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.music_note_outlined,
                            size: 20,
                            color: isSelected
                                ? primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sound.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? primary
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => _confirmDelete(context, ref, sound.id),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImportButton(
    BuildContext context,
    WidgetRef ref,
    Color primary,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _pickAndImport(context, ref),
        icon: Icon(Icons.add, size: 18, color: primary),
        label: Text('导入音频文件', style: TextStyle(color: primary, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildLoopModeSelector(
    BuildContext context,
    WidgetRef ref,
    AmbientSoundState state,
    Color primary,
  ) {
    return Row(
      children: [
        Icon(
          Icons.repeat_one_on,
          size: 18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          '循环模式',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        for (final (label, playlist) in [
          ('单曲循环', false),
          ('列表循环', true),
        ])
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: state.loopPlaylist == playlist,
              onSelected: (_) => ref
                  .read(ambientSoundProvider.notifier)
                  .setLoopPlaylist(playlist),
              selectedColor: primary.withValues(alpha: 0.18),
            ),
          ),
      ],
    );
  }

  Widget _buildVolumeSlider(
    BuildContext context,
    WidgetRef ref,
    AmbientSoundState state,
    Color primary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.volume_down, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '音量',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              '${(state.volume * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: primary,
            inactiveTrackColor: AppColors.dividerLight.withValues(alpha: 0.3),
            thumbColor: primary,
            overlayColor: primary.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: state.volume,
            onChanged: (value) {
              ref.read(ambientSoundProvider.notifier).setVolume(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAutoPlayToggle(
    BuildContext context,
    WidgetRef ref,
    AmbientSoundState state,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('专注时自动播放', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '开始专注计时时自动播放所选氛围音',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: CupertinoSwitch(
              value: state.enabled,
              activeTrackColor: primary,
              onChanged: (_) {
                ref.read(ambientSoundProvider.notifier).toggleEnabled();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImport(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return;
    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .toList();
    if (paths.isEmpty) return;
    var imported = 0;
    var failed = 0;
    for (final path in paths) {
      final sound = await ref
          .read(ambientSoundProvider.notifier)
          .importFile(File(path));
      if (sound == null) {
        failed++;
      } else {
        imported++;
      }
    }
    if (!context.mounted) return;
    final String message;
    if (imported == 0) {
      message = '导入失败，请重试';
    } else if (failed > 0) {
      message = '已导入 $imported 个音频，$failed 个失败';
    } else {
      message = '已导入 $imported 个音频';
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String soundId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除此音频？'),
        content: const Text('导入的文件会从手机中删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(ambientSoundProvider.notifier).removeSound(soundId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
