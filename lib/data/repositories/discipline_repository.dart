import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/discipline.dart';

/// 读取内置的研究生学科专业目录资产，加载成功后常驻内存。
class DisciplineRepository {
  DisciplineRepository({
    AssetBundle? bundle,
    String assetPath = defaultAssetPath,
  }) : _bundle = bundle ?? rootBundle,
       _assetPath = assetPath;

  static const String defaultAssetPath = 'assets/data/discipline_catalog.json';

  final AssetBundle _bundle;
  final String _assetPath;

  DisciplineCatalog? _cache;

  Future<DisciplineCatalog> loadCatalog() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_assetPath);
    final catalog = DisciplineCatalog.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache = catalog;
    return catalog;
  }
}
