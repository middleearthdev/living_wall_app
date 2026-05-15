import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/data/models/scene.dart';
import 'package:living_wall_app/data/repositories/scene_repository.dart';

void main() {
  group('SceneRepository', () {
    late String rawJson;

    setUpAll(() async {
      // Read straight from the project asset so any regression in
      // scenes.json (missing field, wrong category, dupe id) is caught here
      // rather than at first launch on a device.
      rawJson = await File('assets/scenes.json').readAsString();
    });

    test('parses every entry into a Scene', () async {
      final repo = SceneRepository(bundle: _RawBundle(rawJson));
      final scenes = await repo.loadAll();
      expect(scenes, hasLength(18));
      // Ids are unique — duplicates would silently mask scenes from the gallery.
      expect(scenes.map((s) => s.id).toSet().length, scenes.length);
    });

    test('catalog covers each category at the spec-defined count', () async {
      final repo = SceneRepository(bundle: _RawBundle(rawJson));
      final scenes = await repo.loadAll();
      final byCat = <SceneCategory, int>{};
      for (final s in scenes) {
        byCat[s.category] = (byCat[s.category] ?? 0) + 1;
      }
      expect(byCat[SceneCategory.tenang], 6);
      expect(byCat[SceneCategory.fokus], 3);
      expect(byCat[SceneCategory.sosial], 6);
      expect(byCat[SceneCategory.dinamis], 3);
    });

    test('caches the catalog — bundle is read once across calls', () async {
      final bundle = _RawBundle(rawJson);
      final repo = SceneRepository(bundle: bundle);
      await repo.loadAll();
      await repo.loadAll();
      await repo.findById('ocean');
      expect(bundle.loadCount, 1);
    });

    test('findById returns null for unknown id', () async {
      final repo = SceneRepository(bundle: _RawBundle(rawJson));
      expect(await repo.findById('does-not-exist'), isNull);
    });

    test('findById returns the scene when present', () async {
      final repo = SceneRepository(bundle: _RawBundle(rawJson));
      final ocean = await repo.findById('ocean');
      expect(ocean, isNotNull);
      expect(ocean!.name, 'Ocean Drift');
      expect(ocean.category, SceneCategory.tenang);
    });
  });
}

/// Test asset bundle that returns a fixed string body and counts loads.
class _RawBundle extends CachingAssetBundle {
  _RawBundle(this.raw);

  final String raw;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount += 1;
    final bytes = Uint8List.fromList(utf8.encode(raw));
    return ByteData.view(bytes.buffer);
  }
}
