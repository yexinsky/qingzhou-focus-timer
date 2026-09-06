import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/stumble_mark.dart';
import '../../providers/feynman_provider.dart';

class FeynmanSessionView extends ConsumerStatefulWidget {
  const FeynmanSessionView({super.key});
  @override
  ConsumerState<FeynmanSessionView> createState() => _FeynmanSessionViewState();
}

class _FeynmanSessionViewState extends ConsumerState<FeynmanSessionView> {
  Timer? _timer, _debounce;
  final _text = TextEditingController();
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _text.text = ref.read(feynmanProvider)?.textOutput ?? '';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  Future<void> _mark() async {
    final mark = await ref.read(feynmanProvider.notifier).markStumble();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _MarkDialog(
        mark: mark,
        onSave: ref.read(feynmanProvider.notifier).updateMark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(feynmanProvider);
    if (unit == null)
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/feynman'),
            child: const Text('创建费曼学习'),
          ),
        ),
      );
    final notifier = ref.read(feynmanProvider.notifier);
    if (unit.phase == 'ready') {
      return Scaffold(
        appBar: AppBar(title: Text(unit.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.record_voice_over, size: 64),
                const SizedBox(height: 16),
                const Text(
                  '输入完成，请合上资料，用最简单的话讲清楚。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: notifier.beginOutput,
                  child: const Text('开始费曼讲解'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final overtime =
        unit.phase == 'output' && notifier.elapsed >= unit.outputPlannedSeconds;
    return Scaffold(
      appBar: AppBar(title: Text(unit.phase == 'input' ? '输入理解' : '费曼讲解')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              unit.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            Text(
              overtime
                  ? '+${_fmt(notifier.elapsed - unit.outputPlannedSeconds)}'
                  : _fmt(notifier.remaining),
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w300),
            ),
            Text(overtime ? '计划时间已到，可继续讲解' : '剩余时间'),
            if (unit.phase == 'output') ...[
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '假设我要向一个完全不懂的人解释……',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 500),
                      () => notifier.saveDraft(value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _mark,
                      icon: const Icon(Icons.bolt),
                      label: const Text('卡壳了'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await notifier.saveDraft(_text.text);
                        if (context.mounted) context.go('/feynman/review');
                      },
                      child: const Text('结束并复盘'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkDialog extends StatefulWidget {
  const _MarkDialog({required this.mark, required this.onSave});
  final StumbleMark mark;
  final ValueChanged<StumbleMark> onSave;
  @override
  State<_MarkDialog> createState() => _MarkDialogState();
}

class _MarkDialogState extends State<_MarkDialog> {
  final keyword = TextEditingController(),
      note = TextEditingController(),
      reason = TextEditingController();
  int severity = 2;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('刚才卡在哪里？'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: keyword,
            decoration: const InputDecoration(labelText: '关键词'),
          ),
          TextField(
            controller: reason,
            decoration: const InputDecoration(labelText: '原因'),
          ),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: '补充说明'),
          ),
          DropdownButtonFormField<int>(
            initialValue: severity,
            items: const [
              DropdownMenuItem(value: 1, child: Text('轻微')),
              DropdownMenuItem(value: 2, child: Text('明显')),
              DropdownMenuItem(value: 3, child: Text('完全不会')),
            ],
            onChanged: (v) => severity = v ?? 2,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('稍后补充'),
      ),
      FilledButton(
        onPressed: () {
          widget.onSave(
            widget.mark.copyWith(
              keyword: keyword.text,
              note: note.text,
              reason: reason.text,
              severity: severity,
            ),
          );
          Navigator.pop(context);
        },
        child: const Text('保存并继续'),
      ),
    ],
  );
}
