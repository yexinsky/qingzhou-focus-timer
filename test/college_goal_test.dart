import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/repositories/college_preference_repository.dart';
import 'package:qingzhou_focus/data/repositories/discipline_repository.dart';
import 'package:qingzhou_focus/data/repositories/university_repository.dart';
import 'package:qingzhou_focus/providers/college_preference_provider.dart';
import 'package:qingzhou_focus/providers/discipline_provider.dart';
import 'package:qingzhou_focus/providers/university_provider.dart';
import 'package:qingzhou_focus/views/college/college_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  "meta": {"source": "软科中国大学排名（主榜）", "year": 2026, "generatedAt": "2026-04-01T00:00:00", "count": 3},
  "universities": [
    {"rank": "1", "name": "清华大学", "tags": ["双一流", "985"], "province": "北京", "category": "综合", "score": "1087.1"},
    {"rank": "2", "name": "北京大学", "tags": ["双一流", "985"], "province": "北京", "category": "综合", "score": "1063.5"},
    {"rank": "3", "name": "浙江大学", "tags": ["双一流"], "province": "浙江", "category": "综合", "score": "895.6"}
  ]
}
''';

const _disciplineJson = '''
{
  "meta": {"source": "研究生教育学科专业目录（2022年）", "issuer": "教育部", "edition": 2022, "academicCount": 1, "professionalCount": 1},
  "categories": [
    {"code": "08", "name": "工学", "items": [
      {"code": "0812", "name": "计算机科学与技术", "type": "academic"}
    ]}
  ]
}
''';

Future<void> _pumpCollegeView(
  WidgetTester tester, {
  CollegePreferenceRepository? preferenceRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        universityRepositoryProvider.overrideWithValue(
          UniversityRepository(bundle: _StringAssetBundle(_rankingJson)),
        ),
        disciplineRepositoryProvider.overrideWithValue(
          DisciplineRepository(bundle: _StringAssetBundle(_disciplineJson)),
        ),
        collegePreferenceRepositoryProvider.overrideWithValue(
          preferenceRepository ?? CollegePreferenceRepository(),
        ),
      ],
      child: const MaterialApp(home: CollegeView()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<CollegePreferenceRepository> _initializedRepository({
  String? target,
  DateTime? examDate,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repository = CollegePreferenceRepository();
  await repository.init();
  if (target != null) repository.setTarget(target);
  if (examDate != null) repository.setExamDate(examDate);
  return repository;
}

void main() {
  testWidgets('星标收藏院校并用意向筛选', (tester) async {
    await _pumpCollegeView(tester);

    // 默认无收藏：三个卡片都是空心星
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);

    await tester.tap(find.widgetWithText(GestureDetector, '意向'));
    await tester.pump();
    expect(find.text('清华大学'), findsOneWidget);
    expect(find.text('北京大学'), findsNothing);
    expect(find.text('浙江大学'), findsNothing);
  });

  testWidgets('目标分段：自动倒计时与选目标院校', (tester) async {
    await _pumpCollegeView(
      tester,
      preferenceRepository: await _initializedRepository(target: '清华大学'),
    );

    await tester.tap(find.text('目标'));
    await tester.pump();
    await tester.pump();

    expect(find.text('考研倒计时'), findsOneWidget);
    expect(find.textContaining('自动推算'), findsOneWidget);
    expect(find.text('清华大学'), findsOneWidget);
    expect(find.text('更换'), findsOneWidget);

    // 更换目标：sheet 内搜索并选择浙江大学
    await tester.tap(find.text('更换'));
    await tester.pumpAndSettle();
    expect(find.text('选择目标院校'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '浙江');
    await tester.pump();
    await tester.tap(find.text('浙江大学'));
    await tester.pumpAndSettle();

    expect(find.text('选择目标院校'), findsNothing);
    expect(find.text('浙江大学'), findsOneWidget);
  });

  testWidgets('倒计时日期过去时显示已开考，可恢复自动', (tester) async {
    await _pumpCollegeView(
      tester,
      preferenceRepository: await _initializedRepository(
        examDate: DateTime(2020, 1, 1),
      ),
    );

    await tester.tap(find.text('目标'));
    await tester.pump();
    await tester.pump();

    expect(find.text('初试已开始'), findsOneWidget);
    expect(find.text('恢复自动'), findsOneWidget);

    await tester.tap(find.text('恢复自动'));
    await tester.pump();
    expect(find.text('初试已开始'), findsNothing);
  });

  testWidgets('里程碑添加、完成与删除', (tester) async {
    await _pumpCollegeView(tester);

    await tester.tap(find.text('目标'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '完成数学一轮');
    await tester.tap(find.widgetWithText(FilledButton, '添加里程碑'));
    await tester.pumpAndSettle();
    expect(find.text('完成数学一轮'), findsOneWidget);
    expect(find.text('还没有里程碑，添加一个备考节点吧'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(find.text('完成数学一轮'), findsNothing);
    expect(find.text('还没有里程碑，添加一个备考节点吧'), findsOneWidget);
  });
}
