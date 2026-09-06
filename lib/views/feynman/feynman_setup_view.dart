import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/feynman_provider.dart';

class FeynmanSetupView extends ConsumerStatefulWidget {
  const FeynmanSetupView({super.key});
  @override
  ConsumerState<FeynmanSetupView> createState() => _State();
}

class _State extends ConsumerState<FeynmanSetupView> {
  final title = TextEditingController(),
      subject = TextEditingController(text: '其他'),
      chapter = TextEditingController(),
      topic = TextEditingController();
  int input = 20, output = 10;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('费曼学习')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '先理解，再用自己的话讲清楚',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: '学习主题 *'),
        ),
        TextField(
          controller: subject,
          decoration: const InputDecoration(labelText: '学科'),
        ),
        TextField(
          controller: chapter,
          decoration: const InputDecoration(labelText: '章节'),
        ),
        TextField(
          controller: topic,
          decoration: const InputDecoration(labelText: '知识点'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: input,
          decoration: const InputDecoration(labelText: '输入理解'),
          items: [10, 20, 30, 45]
              .map((v) => DropdownMenuItem(value: v, child: Text('$v 分钟')))
              .toList(),
          onChanged: (v) => setState(() {
            input = v!;
            if (output * 2 < input) output = (input / 2).ceil();
          }),
        ),
        DropdownButtonFormField<int>(
          initialValue: output,
          decoration: const InputDecoration(labelText: '输出讲解（至少输入的一半）'),
          items: [5, 10, 15, 20, 30, 45]
              .where((v) => v * 2 >= input)
              .map((v) => DropdownMenuItem(value: v, child: Text('$v 分钟')))
              .toList(),
          onChanged: (v) => setState(() => output = v!),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () async {
            if (title.text.trim().isEmpty) return;
            await ref
                .read(feynmanProvider.notifier)
                .start(
                  title: title.text.trim(),
                  subject: subject.text.trim(),
                  chapter: chapter.text.trim(),
                  topic: topic.text.trim(),
                  inputMinutes: input,
                  outputMinutes: output,
                );
            if (c.mounted) c.push('/feynman/session');
          },
          child: const Text('开始输入理解'),
        ),
        TextButton(
          onPressed: () => c.push('/feynman/heatmap'),
          child: const Text('查看卡点热力图'),
        ),
      ],
    ),
  );
}
