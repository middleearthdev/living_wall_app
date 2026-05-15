import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/scene.dart';

/// Loads the curated 18-scene catalog from bundled JSON. Cached in memory
/// after the first call — the catalog is static for Phase 1, so we don't
/// pay for repeated bundle reads or re-parsing.
class SceneRepository {
  SceneRepository({AssetBundle? bundle, String assetPath = _defaultAsset})
    : _bundle = bundle ?? rootBundle,
      _assetPath = assetPath;

  static const _defaultAsset = 'assets/scenes.json';

  final AssetBundle _bundle;
  final String _assetPath;
  List<Scene>? _cache;

  Future<List<Scene>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final list = decoded
        .cast<Map<String, dynamic>>()
        .map(Scene.fromJson)
        .toList(growable: false);
    _cache = list;
    return list;
  }

  Future<Scene?> findById(String id) async {
    final all = await loadAll();
    for (final scene in all) {
      if (scene.id == id) return scene;
    }
    return null;
  }
}
