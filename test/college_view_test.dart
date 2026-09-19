import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/repositories/university_repository.dart';
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

const _sampleJson = '''
{
  "meta": {"source": "软科中国大学排名（主榜）", "year": 2026, "generatedAt": "2026-04-01T00:00:00", "count": 4},
  "universities": [
    {"rank": "1", "name": "清华大学", "tags": ["双一流", "985", "211"], "province": "北京", "category": "综合", "score": "1087.1"},
    {"rank": "2", "name": "北京大学", "tags": ["双一流", "985", "211"], "province": "北京", "category": "综合", "score": "1063.5"},
    {"rank": "40", "name": "南京理工大学", "tags": ["211"], "province": "江苏", "category": "理工", "score": "312.6"},
    {"rank": "500+", "name": "郑州师范学院", "tags": [], "province": "河南", "category": "师范", "score": null}
  ]
}
''';

Future<void> _pumpCollegeView(WidgetTester tester) async {
  final repository = UniversityRepository(
    bundle: _StringAssetBundle(_sampleJson),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [universityRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: CollegeView()),
    ),
  );
  // 第一帧为加载态，第二帧等资产解析完成
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('展示榜单列表与统计信息', (tester) async {
    await _pumpCollegeView(tester);

    expect(find.textContaining('共 4 所'), findsOneWidget);
    expect(find.text('清华大学'), findsOneWidget);
    expect(find.text('南京理工大学'), findsOneWidget);
    // 无总分的院校显示 —
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('搜索院校名称并实时过滤', (tester) async {
    await _pumpCollegeView(tester);

    await tester.enterText(find.byType(TextField), '清华');
    await tester.pump();

    expect(find.text('清华大学'), findsOneWidget);
    expect(find.text('北京大学'), findsNothing);

    await tester.enterText(find.byType(TextField), '不存在的学校');
    await tester.pump();
    expect(find.text('未找到匹配的院校'), findsOneWidget);
  });

  testWidgets('标签筛选生效', (tester) async {
    await _pumpCollegeView(tester);

    await tester.tap(find.widgetWithText(GestureDetector, '双一流'));
    await tester.pump();

    expect(find.text('清华大学'), findsOneWidget);
    // 仅 211 标签与无标签的院校被过滤掉
    expect(find.text('南京理工大学'), findsNothing);
    expect(find.text('郑州师范学院'), findsNothing);
  });
}
