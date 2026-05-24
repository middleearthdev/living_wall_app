import 'scene.dart';

/// Spatial aspect classification for a wall's 2D grid.
///
/// Derived from the ratio of [gridWidth] / [gridHeight] at wall registration.
/// Used by the scene gallery to sort scenes by compatibility match and by the
/// wall settings UI to show the configured orientation.
enum AspectClass { landscape, portrait, square }

/// Classify a grid by its width/height ratio.
///
/// Thresholds match the scene catalog's compatibility design:
/// - ratio >= 1.2 → landscape
/// - ratio <= 1 / 1.2 ≈ 0.833 → portrait
/// - otherwise → square (between 0.833 and 1.2)
AspectClass aspectClassFor(int gridWidth, int gridHeight) {
  if (gridHeight <= 0) {
    throw ArgumentError.value(gridHeight, 'gridHeight', 'must be positive');
  }
  final ratio = gridWidth / gridHeight;
  if (ratio >= 1.2) return AspectClass.landscape;
  if (ratio <= 1 / 1.2) return AspectClass.portrait;
  return AspectClass.square;
}

/// True if [scene] renders coherently at a wall of the given [wall] aspect.
/// Universal scenes always match; orientation-specific scenes only at walls
/// of that orientation. Square walls match only universal — landscape and
/// portrait scenes are both "kurang optimal" for square.
bool sceneMatchesAspect(SceneCompatibility scene, AspectClass wall) {
  if (scene == SceneCompatibility.universal) return true;
  return (scene == SceneCompatibility.landscape &&
          wall == AspectClass.landscape) ||
      (scene == SceneCompatibility.portrait && wall == AspectClass.portrait);
}

/// Sort priority for the scene gallery, lower = shown first:
/// - 0 = scene's orientation matches wall exactly
/// - 1 = universal (works anywhere)
/// - 2 = mismatched (rendered with "kurang optimal" badge, never hidden)
int sceneAspectPriority(SceneCompatibility scene, AspectClass wall) {
  if (scene == SceneCompatibility.universal) return 1;
  return sceneMatchesAspect(scene, wall) ? 0 : 2;
}
