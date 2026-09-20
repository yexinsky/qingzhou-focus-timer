/// 软科中国大学排名（主榜）的榜单元信息与院校记录。
///
/// 数据来自应用内置只读资产（assets/data/university_ranking.json），
/// 由 tool/fetch_bcur.dart 在开发期从软科官网接口抓取生成，应用运行时不联网。
class UniversityRanking {
  final String source;
  final int year;
  final String generatedAt;
  final List<University> universities;

  const UniversityRanking({
    required this.source,
    required this.year,
    required this.generatedAt,
    required this.universities,
  });

  factory UniversityRanking.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return UniversityRanking(
      source: meta['source'] as String? ?? '软科中国大学排名',
      year: meta['year'] as int? ?? 0,
      generatedAt: meta['generatedAt'] as String? ?? '',
      universities: (json['universities'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(University.fromJson)
          .where((university) => university.name.isNotEmpty)
          .toList(),
    );
  }
}

/// 单条院校记录。列表顺序即官方排名顺序。
class University {
  /// 排名。软科存在「500+」这类区间值，因此保持字符串，不可转整数。
  final String rank;

  final String name;
  final List<String> tags;
  final String province;
  final String category;

  /// 总分；榜单尾部部分院校无总分，为 null。
  final String? score;

  const University({
    required this.rank,
    required this.name,
    required this.tags,
    required this.province,
    required this.category,
    this.score,
  });

  factory University.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as String?)?.trim();
    return University(
      rank: json['rank'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      province: json['province'] as String? ?? '',
      category: json['category'] as String? ?? '',
      score: score == null || score.isEmpty ? null : score,
    );
  }
}
