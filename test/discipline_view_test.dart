import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/repositories/discipline_repository.dart';
import 'package:qingzhou_focus/data/repositories/university_repository.dart';
import 'package:qingzhou_focus/providers/discipline_provider.dart';
import 'package:qingzhou_focus/providers/university_provider.dart';
import 'package:qingzhou_focus/views/college/college_view.dart';

class _StringAssetBundle extends AssetBundle {
  _StringAssetBundle(this.json);

  final String json;

  @override
  Future<String> loadString(String key, {bool cache = true}) async => json;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
}

const _rankingJson = '''
{
  "meta": {"source": "软科中国大学排名（主榜）", "year": 2026, "generatedAt": "2026-04-01T00:00:00", "count": 2},
  "universities": [
    {"rank": "1", "name": "清华大学", "tags": ["双一流"], "province": "北京", "category": "综合", "score": "1087.1"},
    {"rank": "2", "name": "北京大学", "tags": ["双一流"], "province": "北京", "category": "综合", "score": "1063.5"}
  ]
}
''';

const _disciplineJson = '''
{
  "meta": {"source": "研究生教育学科专业目录（2022年）", "issuer": "国务院学位委员会 教育部", "edition": 2022, "academicCount": 3, "professionalCount": 3},
  "categories": [
    {"code": "01", "name": "哲学", "items": [
      {"code": "0101", "name": "哲学", "type": "academic"},
      {"code": "0151", "name": "应用伦理", "type": "professional", "doctoral": false}]},
    {"code": "08", "name": "工学", "items": [
      {"code": "0812", "name": "计算机科学与技术", "type": "academic", "note": "同时设专业学位类别，代码为 0854"},
      {"code": "0854", "name": "电子信息", "type": "professional", "doctoral": true},
      {"code": "0860", "name": "生物与医药", "type": "professional", "doctoral": true}
    ]}
  ]
}
''';

Future<void> _pumpCollegeView(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        universityRepositoryProvider.overrideWithValue(
          UniversityRepository(bundle: _StringAssetBundle(_rankingJson)),
        ),
        disciplineRepositoryProvider.overrideWithValue(
          DisciplineRepository(bundle: _StringAssetBundle(_disciplineJson)),
        ),
      ],
      child: const MaterialApp(home: CollegeView()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('默认展示排名面板，切换后进入专业代码面板', (tester) async {
    await _pumpCollegeView(tester);

    expect(find.text('清华大学'), findsOneWidget);

    await tester.tap(find.text('专业代码'));
    await tester.pump();
    await tester.pump();

    expect(find.text('01 哲学'), findsOneWidget);
    expect(find.text('08 工学'), findsOneWidget);
    // 折叠态不渲染条目
    expect(find.text('0101'), findsNothing);

    await tester.tap(find.text('01 哲学'));
    await tester.pumpAndSettle();

    expect(find.text('0101'), findsOneWidget);
    expect(find.text('应用伦理'), findsOneWidget);
    expect(find.text('一级学科'), findsOneWidget);
    // 工学组仍折叠，只有展开的哲学组里 0151 的徽章可见
    expect(find.text('专业学位'), findsOneWidget);
    expect(find.text('2 项'), findsOneWidget);
  });

  testWidgets('按名称搜索并跨门类命中', (tester) async {
    await _pumpCollegeView(tester);

    await tester.tap(find.text('专业代码'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '计算机');
    await tester.pump();

    expect(find.text('0812'), findsOneWidget);
    expect(find.text('计算机科学与技术'), findsOneWidget);
    expect(find.text('应用伦理'), findsNothing);
  });

  testWidgets('门类筛选与一键清除', (tester) async {
    await _pumpCollegeView(tester);

    await tester.tap(find.text('专业代码'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '计算机');
    await tester.pump();

    // 工学门类 + 搜索词无交集的分支：先选哲学，再输入搜索词应得到空态
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('哲学'));
    await tester.pump();
    expect(find.text('2 项'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '计算机');
    await tester.pump();
    expect(find.text('未找到匹配的专业代码'), findsOneWidget);

    await tester.tap(find.text('清除筛选条件'));
    await tester.pump();
    expect(find.text('01 哲学'), findsOneWidget);
    expect(find.text('08 工学'), findsOneWidget);
    expect(find.text('未找到匹配的专业代码'), findsNothing);
  });
}
