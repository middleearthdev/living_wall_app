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

@freezed
class Scene with _$Scene {
  const factory Scene({
    required String id,
    required String name,
    required SceneCategory category,
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
