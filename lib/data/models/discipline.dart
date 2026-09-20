/// 教育部《研究生教育学科专业目录》的门类与专业代码。
///
/// 数据来自应用内置只读资产（assets/data/discipline_catalog.json），
/// 由 tool/fetch_disciplines.py 在开发期从教育部官方 PDF 解析生成，运行时不联网。
class DisciplineCatalog {
  final String source;
  final int edition;
  final int academicCount;
  final int professionalCount;
  final List<DisciplineCategory> categories;

  const DisciplineCatalog({
    required this.source,
    required this.edition,
    required this.academicCount,
    required this.professionalCount,
    required this.categories,
  });

  int get totalCount => academicCount + professionalCount;

  factory DisciplineCatalog.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return DisciplineCatalog(
      source: meta['source'] as String? ?? '研究生教育学科专业目录',
      edition: meta['edition'] as int? ?? 0,
      academicCount: meta['academicCount'] as int? ?? 0,
      professionalCount: meta['professionalCount'] as int? ?? 0,
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DisciplineCategory.fromJson)
          .toList(),
    );
  }
}

/// 学科门类（两位代码，如 08 工学）及其下的专业条目。
class DisciplineCategory {
  final String code;
  final String name;
  final List<DisciplineItem> items;

  const DisciplineCategory({
    required this.code,
    required this.name,
    required this.items,
  });

  factory DisciplineCategory.fromJson(Map<String, dynamic> json) {
    return DisciplineCategory(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DisciplineItem.fromJson)
          .where((item) => item.name.isNotEmpty)
          .toList(),
    );
  }
}

/// 一条专业代码：一级学科（学术学位）或专业学位类别。
class DisciplineItem {
  final String code;

  final String name;

  /// true 为专业学位类别（代码第三位从 5 开始），false 为一级学科。
  final bool professional;

  /// 专业学位类别是否可授博士专业学位。
  final bool doctoral;

  /// 括号注释，如“可授医学、理学学位”。
  final String? note;

  const DisciplineItem({
    required this.code,
    required this.name,
    required this.professional,
    this.doctoral = false,
    this.note,
  });

  factory DisciplineItem.fromJson(Map<String, dynamic> json) {
    final note = (json['note'] as String?)?.trim();
    return DisciplineItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      professional: (json['type'] as String?) == 'professional',
      doctoral: json['doctoral'] as bool? ?? false,
      note: note == null || note.isEmpty ? null : note,
    );
  }

  /// 按代码或名称片段匹配（搜索框输入）。
  bool matches(String query) => code.contains(query) || name.contains(query);
}
