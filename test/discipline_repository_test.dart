import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/discipline.dart';
import 'package:qingzhou_focus/data/repositories/discipline_repository.dart';
import 'package:qingzhou_focus/providers/discipline_provider.dart';

class _StringAssetBundle extends AssetBundle {
  _StringAssetBundle(this.json);

  final String json;
  int loadCount = 0;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loadCount++;
    return json;
  }

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
}

const _sampleJson = '''
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

DisciplineCatalog _parse() =>
    DisciplineCatalog.fromJson(jsonDecode(_sampleJson) as Map<String, dynamic>);

void main() {
  group('DisciplineCatalog.fromJson', () {
    test('解析元信息、门类与条目', () {
      final catalog = _parse();
      expect(catalog.source, '研究生教育学科专业目录（2022年）');
      expect(catalog.edition, 2022);
      expect(catalog.academicCount, 3);
      expect(catalog.professionalCount, 3);
      expect(catalog.totalCount, 6);
      expect(catalog.categories, hasLength(2));

      final ethics = catalog.categories.first.items;
      expect(ethics.first.code, '0101');
      expect(ethics.first.professional, isFalse);
      expect(ethics.last.code, '0151');
      expect(ethics.last.professional, isTrue);
      expect(ethics.last.doctoral, isFalse);
    });

    test('解析注释与可授博士标记，容忍缺失字段', () {
      final catalog = _parse();
      final cs = catalog.categories.last.items.first;
      expect(cs.note, '同时设专业学位类别，代码为 0854');

      final empty = DisciplineCatalog.fromJson({
        'categories': [
          {
            'items': [
              {'code': '0101', 'name': '哲学', 'type': 'academic'},
            ],
          },
        ],
      });
      expect(empty.edition, 0);
      expect(empty.categories.first.items.first.doctoral, isFalse);
      expect(empty.categories.first.items.first.note, isNull);
    });

    test('matches 按代码或名称匹配', () {
      final catalog = _parse();
      final cs = catalog.categories.last.items.first;
      expect(cs.matches('0812'), isTrue);
      expect(cs.matches('计算机'), isTrue);
      expect(cs.matches('081'), isTrue);
      expect(cs.matches('软件'), isFalse);
    });
  });

  group('DisciplineRepository', () {
    test('加载目录并缓存，资产只读取一次', () async {
      final bundle = _StringAssetBundle(_sampleJson);
      final repository = DisciplineRepository(bundle: bundle);

      final first = await repository.loadCatalog();
      final second = await repository.loadCatalog();

      expect(bundle.loadCount, 1);
      expect(identical(first, second), isTrue);
      expect(first.categories, hasLength(2));
    });
  });

  group('filteredDisciplineGroupsProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          disciplineRepositoryProvider.overrideWithValue(
            DisciplineRepository(bundle: _StringAssetBundle(_sampleJson)),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    /// StateNotifierProvider 无 .future，读一次触发加载后等微任务完成
    Future<void> pumpCatalog() async {
      container.read(disciplineCatalogProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('无条件时返回全部分组', () async {
      await pumpCatalog();
      expect(container.read(filteredDisciplineGroupsProvider), hasLength(2));
    });

    test('按搜索词过滤并保留命中的分组', () async {
      await pumpCatalog();
      container.read(disciplineQueryProvider.notifier).state = '计算机';

      final groups = container.read(filteredDisciplineGroupsProvider);
      expect(groups, hasLength(1));
      expect(groups.first.code, '08');
      expect(groups.first.items.map((i) => i.code), ['0812']);
    });

    test('按代码片段搜索', () async {
      await pumpCatalog();
      container.read(disciplineQueryProvider.notifier).state = '086';

      final groups = container.read(filteredDisciplineGroupsProvider);
      expect(groups.first.items.map((i) => i.code), ['0860']);
    });

    test('按门类过滤，与搜索词取交集', () async {
      await pumpCatalog();
      container.read(disciplineCategoryProvider.notifier).state = '01';

      var groups = container.read(filteredDisciplineGroupsProvider);
      expect(groups, hasLength(1));
      expect(groups.first.code, '01');

      container.read(disciplineQueryProvider.notifier).state = '计算机';
      groups = container.read(filteredDisciplineGroupsProvider);
      expect(groups, isEmpty);
    });

    test('筛选状态标记', () async {
      await pumpCatalog();
      expect(container.read(disciplineFilterActiveProvider), isFalse);

      container.read(disciplineQueryProvider.notifier).state = ' 计 ';
      expect(container.read(disciplineFilterActiveProvider), isTrue);

      container.read(disciplineQueryProvider.notifier).state = '';
      container.read(disciplineCategoryProvider.notifier).state = '08';
      expect(container.read(disciplineFilterActiveProvider), isTrue);
    });
  });
}
