import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/university.dart';

/// 读取内置的软科中国大学排名资产，加载成功后常驻内存。
class UniversityRepository {
  UniversityRepository({
    AssetBundle? bundle,
    String assetPath = defaultAssetPath,
  }) : _bundle = bundle ?? rootBundle,
       _assetPath = assetPath;

  static const String defaultAssetPath = 'assets/data/university_ranking.json';

  final AssetBundle _bundle;
  final String _assetPath;

  UniversityRanking? _cache;

  Future<UniversityRanking> loadRanking() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_assetPath);
    final ranking = UniversityRanking.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache = ranking;
    return ranking;
  }
}
