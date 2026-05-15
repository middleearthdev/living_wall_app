import 'package:freezed_annotation/freezed_annotation.dart';

part 'wall_state.freezed.dart';

/// Live wall state derived from WLED WebSocket. Not persisted —
/// recomputed on each reconnect. `fromWledJson` mirrors the `/json/state` payload.
@freezed
class WallState with _$WallState {
  const factory WallState({
    required bool on,
    required int brightness,
    String? activeSceneId,
    int? fx,
    int? pal,
  }) = _WallState;

  factory WallState.fromWledJson(Map<String, dynamic> json) {
    final segments = json['seg'] as List<dynamic>?;
    final seg = (segments != null && segments.isNotEmpty)
        ? segments.first as Map<String, dynamic>
        : const <String, dynamic>{};
    return WallState(
      on: json['on'] as bool? ?? false,
      brightness: json['bri'] as int? ?? 0,
      fx: seg['fx'] as int?,
      pal: seg['pal'] as int?,
    );
  }
}
