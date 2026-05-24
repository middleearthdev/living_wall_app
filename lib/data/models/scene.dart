import 'package:freezed_annotation/freezed_annotation.dart';

part 'scene.freezed.dart';
part 'scene.g.dart';

enum SceneCategory {
  @JsonValue('tenang')
  tenang,
  @JsonValue('fokus')
  fokus,
  @JsonValue('sosial')
  sosial,
  @JsonValue('dinamis')
  dinamis,
}

/// Spatial compatibility class for a scene. Used by the scene gallery to sort
/// by match with the wall's [AspectClass]:
/// - matching scenes first
/// - universal scenes second
/// - mismatched scenes last with a "kurang optimal" badge
///
/// Never hides scenes — the user can still apply a mismatched scene.
enum SceneCompatibility {
  @JsonValue('universal')
  universal,
  @JsonValue('landscape')
  landscape,
  @JsonValue('portrait')
  portrait,
}

@freezed
class Scene with _$Scene {
  const factory Scene({
    required String id,
    required String name,
    required SceneCategory category,
    required SceneCompatibility compatibility,
    required String description,
    required String useCase,
    required String thumbnailAsset,
    required int defaultBri,
    required int fx,
    required int pal,
    int? defaultSx,
    int? defaultIx,
    List<int>? rgb,
    @Default(14) int transition,
  }) = _Scene;

  factory Scene.fromJson(Map<String, dynamic> json) => _$SceneFromJson(json);
}
