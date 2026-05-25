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

  group('wallQuickScenesProvider', () {
    // Wider fixture covering every ID referenced by the curated quick-scene
    // lists across all three aspect classes.
    final fullCatalog = <Scene>[
      _scene('ocean', SceneCompatibility.landscape),
      _scene('sunset', SceneCompatibility.landscape),
      _scene('golden', SceneCompatibility.landscape),
      _scene('rain', SceneCompatibility.portrait),
      _scene('dawn', SceneCompatibility.portrait),
      _scene('dinner', SceneCompatibility.portrait),
      _scene('focus', SceneCompatibility.universal),
      _scene('candle', SceneCompatibility.universal),
      _scene('forest', SceneCompatibility.universal),
      _scene('breathe', SceneCompatibility.universal),
      _scene('sakura', SceneCompatibility.universal),
      _scene('twinkle', SceneCompatibility.universal),
    ];

    ProviderContainer containerForWall(Wall wall) => ProviderContainer(
      overrides: [
        sceneCatalogProvider.overrideWith((_) async => fullCatalog),
        wallByIdProvider(wall.id).overrideWith((_) async => wall),
      ],
    );

    test('landscape wall gets landscape-leaning quick scenes', () async {
      final wall = makeTestWall(
        id: 'w_land',
        aspectClass: AspectClass.landscape,
      );
      final container = containerForWall(wall);
      addTearDown(container.dispose);

      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider(wall.id).future);

      final ids = container
          .read(wallQuickScenesProvider(wall.id))
          .map((s) => s.id)
          .toList();
      expect(ids, ['ocean', 'sunset', 'focus', 'candle', 'forest', 'golden']);
    });

    test('portrait wall gets portrait-leaning quick scenes', () async {
      final wall = makeTestWall(
        id: 'w_port',
        gridWidth: 48,
        gridHeight: 24,
        lengthMm: 800,
        heightMm: 1200,
        aspectClass: AspectClass.portrait,
      );
      final container = containerForWall(wall);
      addTearDown(container.dispose);

      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider(wall.id).future);

      final ids = container
          .read(wallQuickScenesProvider(wall.id))
          .map((s) => s.id)
          .toList();
      expect(ids, ['rain', 'dawn', 'focus', 'candle', 'forest', 'dinner']);
    });

    test('square wall gets all-universal quick scenes', () async {
      final wall = makeTestWall(
        id: 'w_sq',
        gridWidth: 24,
        gridHeight: 8,
        lengthMm: 400,
        heightMm: 400,
        aspectClass: AspectClass.square,
      );
      final container = containerForWall(wall);
      addTearDown(container.dispose);

      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider(wall.id).future);

      final scenes = container.read(wallQuickScenesProvider(wall.id));
      expect(
        scenes.map((s) => s.id).toList(),
        ['focus', 'candle', 'breathe', 'forest', 'sakura', 'twinkle'],
      );
      // Sanity: square's list should be entirely universal.
      expect(
        scenes.every((s) => s.compatibility == SceneCompatibility.universal),
        isTrue,
      );
    });

    test('missing wall falls back to square (all-universal) list', () async {
      final container = ProviderContainer(
        overrides: [
          sceneCatalogProvider.overrideWith((_) async => fullCatalog),
          wallByIdProvider('missing').overrideWith((_) async => null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sceneCatalogProvider.future);
      await container.read(wallByIdProvider('missing').future);

      final ids = container
          .read(wallQuickScenesProvider('missing'))
          .map((s) => s.id)
          .toList();
      expect(ids, ['focus', 'candle', 'breathe', 'forest', 'sakura', 'twinkle']);
    });

    test('empty catalog yields empty list (no crash on first launch)', () {
      final container = ProviderContainer(
        overrides: [
          sceneCatalogProvider.overrideWith((_) async => const <Scene>[]),
        ],
      );
      addTearDown(container.dispose);

      final scenes = container.read(wallQuickScenesProvider('any'));
      expect(scenes, isEmpty);
    });
  });
}
