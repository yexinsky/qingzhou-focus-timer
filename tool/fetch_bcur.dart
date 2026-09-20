// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// 抓取软科中国大学排名（主榜）并生成本地内置数据文件。
///
/// 软科官方无公开 API，此脚本请求其官网前端使用的接口（非官方，可能随官网改版失效），
/// 仅在开发期运行，产出 `assets/data/university_ranking.json` 随应用打包，运行时不联网。
///
/// 用法：`dart run tool/fetch_bcur.dart [年份]`（不传年份则取当前年份）
/// 软科每年约 4 月发布新榜，届时重新执行本脚本并随版本发布更新数据。
Future<void> main(List<String> args) async {
  final year = args.isNotEmpty
      ? int.tryParse(args.first) ?? DateTime.now().year
      : DateTime.now().year;
  final uri = Uri.parse(
    'https://www.shanghairanking.cn/api/pub/v1/bcur?bcur_type=11&year=$year',
  );

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    );
    final response = await request.close();
    if (response.statusCode != 200) {
      stderr.writeln('请求失败：HTTP ${response.statusCode}');
      exitCode = 1;
      return;
    }
    final body = await response.transform(utf8.decoder).join();
    final payload = jsonDecode(body) as Map<String, dynamic>;
    if (payload['code'] != 200) {
      stderr.writeln('接口返回异常：code=${payload['code']} msg=${payload['msg']}');
      exitCode = 1;
      return;
    }
    final rankings =
        (payload['data'] as Map<String, dynamic>?)?['rankings']
            as List<dynamic>?;
    if (rankings == null || rankings.isEmpty) {
      stderr.writeln('接口未返回榜单数据（year=$year），请确认该年份榜单是否已发布。');
      exitCode = 1;
      return;
    }

    final universities = rankings
        .map(_trimEntry)
        .whereType<Map<String, dynamic>>()
        .toList();

    final output = {
      'meta': {
        'source': '软科中国大学排名（主榜）',
        'year': year,
        'generatedAt': DateTime.now().toIso8601String(),
        'count': universities.length,
      },
      'universities': universities,
    };

    final file = File('assets/data/university_ranking.json');
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(output));

    print(
      '已生成 ${file.path}：${universities.length} 所院校（year=$year，'
      '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB）',
    );
    print('前3名：${universities.take(3).map((u) => u['name']).join('、')}');
  } finally {
    client.close();
  }
}

/// 精简单条记录，只保留应用展示所需字段；校名为空的脏数据直接丢弃。
Map<String, dynamic>? _trimEntry(dynamic raw) {
  final entry = raw as Map<String, dynamic>;
  final name = _clean(entry['univNameCn']);
  if (name == null) return null;
  return {
    'rank': _clean(entry['ranking']) ?? '',
    'name': name,
    'tags': (entry['univTags'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .where((tag) => tag.isNotEmpty)
        .toList(),
    'province': _clean(entry['province']) ?? '',
    'category': _clean(entry['univCategory']) ?? '',
    'score': _clean(entry['score']),
  };
}

String? _clean(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
