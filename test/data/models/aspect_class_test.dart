import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/data/models/aspect_class.dart';
import 'package:living_wall_app/data/models/scene.dart';

void main() {
  group('aspectClassFor (always with physical mm)', () {
    test('M-tier 1200×800mm is landscape (3:2)', () {
      expect(aspectClassFor(1200, 800), AspectClass.landscape);
    });

    test('L-tier 1800×1200mm is landscape (3:2)', () {
      expect(aspectClassFor(1800, 1200), AspectClass.landscape);
    });

    test('400×400mm sample is square (1:1)', () {
      expect(aspectClassFor(400, 400), AspectClass.square);
    });

    test('800×1200mm portrait wall', () {
      expect(aspectClassFor(800, 1200), AspectClass.portrait);
    });

    test('exactly 1.2 ratio is landscape (inclusive lower bound)', () {
      expect(aspectClassFor(600, 500), AspectClass.landscape);
    });

    test('just below 1.2 ratio is square', () {
      expect(aspectClassFor(590, 500), AspectClass.square);
    });

    test('exactly 1/1.2 ratio is portrait (inclusive upper bound)', () {
      expect(aspectClassFor(500, 600), AspectClass.portrait);
    });

    test('just above 1/1.2 ratio is square', () {
      expect(aspectClassFor(510, 600), AspectClass.square);
    });

    test('rejects zero height to avoid divide-by-zero', () {
      expect(() => aspectClassFor(1200, 0), throwsArgumentError);
    });

    test('rejects negative height', () {
      expect(() => aspectClassFor(1200, -1), throwsArgumentError);
    });
  });

  // Regression coverage for the non-square-pixel bug: production wires the
  // strip at 60 LED/m horizontal but mounts rows at 5cm pitch (20 LED/m
  // vertical). Calling aspectClassFor with grid LED counts gives the wrong
  // class because grid ratio diverges from physical ratio.
  group('aspectClassFor — grid vs physical (non-square pixel)', () {
    test(
      'M tier 1200×800 landscape: grid 72×16 ratio 4.5 vs physical ratio 1.5',
      () {
        // Both end up landscape here, but only by coincidence — see next
        // test for a case where grid lies.
        expect(aspectClassFor(1200, 800), AspectClass.landscape);
        expect(
          aspectClassFor(72, 16),
          AspectClass.landscape,
          reason: 'function is ratio-classifier; bug is in the caller',
        );
      },
    );

    test(
      'Portrait 800×1200: grid 48×24 ratio 2.0 says landscape — WRONG class',
      () {
        // Physical aspect is portrait (0.67), but the strip wraps 48 LEDs
        // wide × 24 rows tall = grid ratio 2.0 which classifier reads as
        // landscape. Documents the bug: never feed grid counts in.
        expect(aspectClassFor(800, 1200), AspectClass.portrait);
        expect(
          aspectClassFor(48, 24),
          AspectClass.landscape,
          reason: 'grid ratio misleads — call sites must use physical mm',
        );
      },
    );

    test(
      'Square wall 400×400: grid 24×8 ratio 3.0 says landscape — WRONG class',
      () {
        expect(aspectClassFor(400, 400), AspectClass.square);
        expect(
          aspectClassFor(24, 8),
          AspectClass.landscape,
          reason: 'grid ratio misleads — call sites must use physical mm',
        );
      },
    );
  });

  group('sceneMatchesAspect', () {
    test('universal matches every aspect', () {
      for (final wall in AspectClass.values) {
        expect(
          sceneMatchesAspect(SceneCompatibility.universal, wall),
          isTrue,
          reason: 'universal should match $wall',
        );
      }
    });

    test('landscape scene matches landscape wall only', () {
      expect(
        sceneMatchesAspect(SceneCompatibility.landscape, AspectClass.landscape),
        isTrue,
      );
      expect(
        sceneMatchesAspect(SceneCompatibility.landscape, AspectClass.portrait),
        isFalse,
      );
      expect(
        sceneMatchesAspect(SceneCompatibility.landscape, AspectClass.square),
        isFalse,
      );
    });

    test('portrait scene matches portrait wall only', () {
      expect(
        sceneMatchesAspect(SceneCompatibility.portrait, AspectClass.portrait),
        isTrue,
      );
      expect(
        sceneMatchesAspect(SceneCompatibility.portrait, AspectClass.landscape),
        isFalse,
      );
      expect(
        sceneMatchesAspect(SceneCompatibility.portrait, AspectClass.square),
        isFalse,
      );
    });
  });

  group('sceneAspectPriority', () {
    test('match-aspect scene gets priority 0 (shown first)', () {
      expect(
        sceneAspectPriority(
          SceneCompatibility.landscape,
          AspectClass.landscape,
        ),
        0,
      );
      expect(
        sceneAspectPriority(SceneCompatibility.portrait, AspectClass.portrait),
        0,
      );
    });

    test('universal scene gets priority 1 (shown second)', () {
      for (final wall in AspectClass.values) {
        expect(
          sceneAspectPriority(SceneCompatibility.universal, wall),
          1,
          reason: 'universal at $wall should be priority 1',
        );
      }
    });

    test('mismatched scene gets priority 2 (shown last with badge)', () {
      expect(
        sceneAspectPriority(SceneCompatibility.landscape, AspectClass.portrait),
        2,
      );
      expect(
        sceneAspectPriority(SceneCompatibility.portrait, AspectClass.landscape),
        2,
      );
      // Square walls have no exact-match orientation scenes — both go to bottom.
      expect(
        sceneAspectPriority(SceneCompatibility.landscape, AspectClass.square),
        2,
      );
      expect(
        sceneAspectPriority(SceneCompatibility.portrait, AspectClass.square),
        2,
      );
    });
  });
}
