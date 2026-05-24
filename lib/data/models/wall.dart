import 'package:freezed_annotation/freezed_annotation.dart';

import 'aspect_class.dart';

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

    // 2D matrix spec — populated from the QR code on the wall's label at
    // add-wall time. WLED is configured with these dims via
    // [WledClient.configureMatrix] so 2D effects render coherently across
    // wall sizes. App code never branches on tier (M / L / custom); the grid
    // dims here are the single source of truth.
    required String serialNumber,
    required int gridWidth,
    required int gridHeight,
    required int lengthMm,
    required int heightMm,
    required AspectClass aspectClass,

    DateTime? lastSeen,
    @Default(false) bool online,
  }) = _Wall;

  factory Wall.fromJson(Map<String, dynamic> json) => _$WallFromJson(json);
}
