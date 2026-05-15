import 'package:freezed_annotation/freezed_annotation.dart';

part 'wall.freezed.dart';
part 'wall.g.dart';

@freezed
class Wall with _$Wall {
  const factory Wall({
    required String id,
    required String roomId,
    required String name,
    required String deviceId,
    required String ipAddress,
    DateTime? lastSeen,
    @Default(false) bool online,
  }) = _Wall;

  factory Wall.fromJson(Map<String, dynamic> json) => _$WallFromJson(json);
}
