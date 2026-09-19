import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/university.dart';
import 'package:qingzhou_focus/data/repositories/university_repository.dart';
import 'package:qingzhou_focus/providers/university_provider.dart';

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
  "meta": {"source": "软科中国大学排名（主榜）", "year": 2026, "generatedAt": "2026-04-01T00:00:00", "count": 4},
  "universities": [
    {"rank": "1", "name": "清华大学", "tags": ["双一流", "985", "211"], "province": "北京", "category": "综合", "score": "1087.1"},
    {"rank": "2", "name": "北京大学", "tags": ["双一流", "985", "211"], "province": "北京", "category": "综合", "score": "1063.5"},
    {"rank": "40", "name": "南京理工大学", "tags": ["211"], "province": "江苏", "category": "理工", "score": "312.6"},
    {"rank": "500+", "name": "郑州师范学院", "tags": [], "province": "河南", "category": "师范", "score": null}
  ]
}
''';

List<University> _parseSample() => UniversityRanking.fromJson(
  jsonDecode(_sampleJson) as Map<String, dynamic>,
).universities;

void main() {
  group('UniversityRanking.fromJson', () {
    test('解析 meta 与院校列表', () {
      final ranking = UniversityRanking.fromJson(
        jsonDecode(_sampleJson) as Map<String, dynamic>,
      );
      expect(ranking.source, '软科中国大学排名（主榜）');
      expect(ranking.year, 2026);
      expect(ranking.universities, hasLength(4));

      final tsinghua = ranking.universities.first;
      expect(tsinghua.rank, '1');
      expect(tsinghua.name, '清华大学');
      expect(tsinghua.tags, ['双一流', '985', '211']);
      expect(tsinghua.province, '北京');
      expect(tsinghua.category, '综合');
      expect(tsinghua.score, '1087.1');
    });

    test('容忍缺失字段、空总分与脏数据', () {
      final ranking = UniversityRanking.fromJson({
        'universities': [
          {'name': '某大学'},
          {'rank': '500+', 'name': '另一大学', 'score': ''},
          {'name': ''},
        ],
      });
      expect(ranking.year, 0);
      expect(ranking.universities, hasLength(2));
      expect(ranking.universities.first.rank, '');
      expect(ranking.universities.first.score, isNull);
      expect(ranking.universities.last.tags, isEmpty);
    });
  });

  group('UniversityRepository', () {
    test('加载榜单并缓存，资产只读取一次', () async {
      final bundle = _StringAssetBundle(_sampleJson);
      final repository = UniversityRepository(bundle: bundle);

      final first = await repository.loadRanking();
      final second = await repository.loadRanking();

      expect(bundle.loadCount, 1);
      expect(identical(first, second), isTrue);
      expect(first.universities, hasLength(4));
    });
  });

  group('filterUniversities', () {
    final universities = _parseSample();

    test('默认条件返回全部且保持官方排名顺序', () {
      final result = filterUniversities(universities, const UniversityFilter());
      expect(result.map((u) => u.name).toList(), [
        '清华大学',
        '北京大学',
        '南京理工大学',
        '郑州师范学院',
      ]);
    });

    test('按校名搜索，忽略首尾空格', () {
      const filter = UniversityFilter(query: '清华');
      expect(filterUniversities(universities, filter).map((u) => u.name), [
        '清华大学',
      ]);

      const padded = UniversityFilter(query: ' 大学 ');
      expect(filterUniversities(universities, padded), hasLength(3));
    });

    test('按省份过滤', () {
      const filter = UniversityFilter(province: '北京');
      expect(filterUniversities(universities, filter).map((u) => u.name), [
        '清华大学',
        '北京大学',
      ]);
    });

    test('按类型过滤', () {
      const filter = UniversityFilter(category: '师范');
      expect(filterUniversities(universities, filter).map((u) => u.name), [
        '郑州师范学院',
      ]);
    });

    test('按标签过滤', () {
      const filter = UniversityFilter(tag: '985');
      expect(filterUniversities(universities, filter).map((u) => u.name), [
        '清华大学',
        '北京大学',
      ]);
    });

    test('组合条件取交集', () {
      const filter = UniversityFilter(province: '北京', tag: '985');
      expect(filterUniversities(universities, filter), hasLength(2));

      const conflicting = UniversityFilter(query: '清华', province: '河南');
      expect(filterUniversities(universities, conflicting), isEmpty);
    });
  });
}
