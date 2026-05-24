import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/data/models/aspect_class.dart';
import 'package:living_wall_app/data/models/scene.dart';

void main() {
  group('aspectClassFor', () {
    test('M-tier 72x48 is landscape (ratio 1.5)', () {
      expect(aspectClassFor(72, 48), AspectClass.landscape);
    });

    test('L-tier 108x72 is landscape (ratio 1.5)', () {
      expect(aspectClassFor(108, 72), AspectClass.landscape);
    });

    test('48x48 is square (ratio 1.0)', () {
      expect(aspectClassFor(48, 48), AspectClass.square);
    });

    test('48x72 is portrait (ratio ~0.67)', () {
      expect(aspectClassFor(48, 72), AspectClass.portrait);
    });

    test('exactly 1.2 ratio is landscape (inclusive lower bound)', () {
      expect(aspectClassFor(60, 50), AspectClass.landscape);
    });

    test('just below 1.2 ratio is square', () {
      expect(aspectClassFor(59, 50), AspectClass.square);
    });

    test('exactly 1/1.2 ratio is portrait (inclusive upper bound)', () {
      expect(aspectClassFor(50, 60), AspectClass.portrait);
    });

    test('just above 1/1.2 ratio is square', () {
      expect(aspectClassFor(51, 60), AspectClass.square);
    });

    test('extreme landscape 144x48 still landscape', () {
      expect(aspectClassFor(144, 48), AspectClass.landscape);
    });

    test('extreme portrait 48x144 still portrait', () {
      expect(aspectClassFor(48, 144), AspectClass.portrait);
    });

    test('rejects zero gridHeight to avoid divide-by-zero', () {
      expect(() => aspectClassFor(72, 0), throwsArgumentError);
    });

    test('rejects negative gridHeight', () {
      expect(() => aspectClassFor(72, -1), throwsArgumentError);
    });
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
