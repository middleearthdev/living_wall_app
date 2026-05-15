import 'package:freezed_annotation/freezed_annotation.dart';

part 'wled_info.freezed.dart';
part 'wled_info.g.dart';

/// Subset of WLED /json/info we actually consume.
/// `brand` is what we probe during subnet discovery; `mac` is our stable wall identity.
@freezed
class WledInfo with _$WledInfo {
  const factory WledInfo({
    required String brand,
    required String ver,
    required String mac,
    required String name,
    Map<String, dynamic>? leds,
  }) = _WledInfo;

  factory WledInfo.fromJson(Map<String, dynamic> json) =>
      _$WledInfoFromJson(json);
}
