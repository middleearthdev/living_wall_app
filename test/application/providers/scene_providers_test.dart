import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/application/providers/scene_providers.dart';
import 'package:living_wall_app/application/providers/wall_providers.dart';
import 'package:living_wall_app/data/models/aspect_class.dart';
import 'package:living_wall_app/data/models/scene.dart';
import 'package:living_wall_app/data/models/wall.dart';

import '../../_helpers/wall_factory.dart';

/// Minimal fixture catalog covering all three compatibility classes and
/// enough scenes to exercise the stable-sort across multiple priority buckets.
final _testCatalog = <Scene>[
  _scene('ocean', SceneCompatibility.landscape),
  _scene('candle', SceneCompatibility.universal),
  _scene('rain', SceneCompatibility.portrait),
  _scene('sunset', SceneCompatibility.landscape),
  _scene('breathe', SceneCompatibility.universal),
  _scene('dawn', SceneCompatibility.portrait),
];

Scene _scene(String id, SceneCompatibility compat) => Scene(
  id: id,
  name: id,
  category: SceneCategory.tenang,
  compatibility: compat,
  description: '',
  useCase: '',
  thumbnailAsset: '',
  defaultBri: 128,
  fx: 0,
  pal: 0,
);

ProviderContainer _containerFor(Wall wall) {
  return ProviderContainer(
    overrides: [
      sceneCatalogProvider.overrideWith((_) async => _testCatalog),
      wallByIdProvider(wall.id).overrideWith((_) async => wall),
    ],
  );
}

void main() {
  group('sortedScenesForWallProvider', () {
    test('landscape wall: landscape scenes first, universal next, portrait last',
        () async {
      final wall = makeTestWall(
        id: 'w1',
        gridWidth: 72,
        gridHeight: 48,
        aspectClass: AspectClass.landscape,
      );
      final container = _containerFor(wall);
      addTearDown(container.dispose);

      // Let async overrides resolve.
      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider(wall.id).future);

      final sorted = container.read(sortedScenesForWallProvider(wall.id));
      final ids = sorted.map((s) => s.scene.id).toList();

      // Original catalog order preserved within each priority bucket.
      expect(ids, ['ocean', 'sunset', 'candle', 'breathe', 'rain', 'dawn']);

      // Optimality flag set correctly.
      expect(sorted[0].isOptimal, isTrue, reason: 'ocean (landscape match)');
      expect(sorted[2].isOptimal, isTrue, reason: 'candle (universal)');
      expect(sorted[4].isOptimal, isFalse, reason: 'rain (portrait mismatch)');
    });

    test('portrait wall: portrait scenes first, then universal, then landscape',
        () async {
      final wall = makeTestWall(
        id: 'w2',
        gridWidth: 48,
        gridHeight: 72,
        aspectClass: AspectClass.portrait,
      );
      final container = _containerFor(wall);
      addTearDown(container.dispose);

      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider(wall.id).future);

      final sorted = container.read(sortedScenesForWallProvider(wall.id));
      expect(sorted.map((s) => s.scene.id).toList(), [
        'rain',
        'dawn',
        'candle',
        'breathe',
        'ocean',
        'sunset',
      ]);
      expect(sorted[0].isOptimal, isTrue);
      expect(sorted.last.isOptimal, isFalse);
    });

    test('square wall: universal first, all orientation-specific marked mismatch',
        () async {
      final wall = makeTestWall(
        id: 'w3',
        gridWidth: 48,
        gridHeight: 48,
        aspectClass: AspectClass.square,
      );
      final container = _containerFor(wall);
      addTearDown(container.dispose);

      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider(wall.id).future);

      final sorted = container.read(sortedScenesForWallProvider(wall.id));
      // Universals lead; both landscape and portrait scenes follow, all
      // marked non-optimal (no exact-match orientation exists for square).
      expect(sorted.map((s) => s.scene.id).take(2).toList(),
          ['candle', 'breathe']);
      expect(sorted.skip(2).every((s) => !s.isOptimal), isTrue);
    });

    test('falls back to unsorted optimistic list when wall is missing', () async {
      final container = ProviderContainer(
        overrides: [
          sceneCatalogProvider.overrideWith((_) async => _testCatalog),
          // Family override per-key — without this the default provider would
          // try to reach the real drift database from a test environment.
          wallByIdProvider('unknown').overrideWith((_) async => null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider('unknown').future);

      final sorted = container.read(sortedScenesForWallProvider('unknown'));
      expect(sorted, hasLength(_testCatalog.length));
      // All marked optimal — without a wall we can't say otherwise, so the UI
      // shouldn't paint warning badges based on missing data.
      expect(sorted.every((s) => s.isOptimal), isTrue);
    });
  });
}
