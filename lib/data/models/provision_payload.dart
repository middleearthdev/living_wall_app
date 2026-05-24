import 'package:freezed_annotation/freezed_annotation.dart';

part 'provision_payload.freezed.dart';

/// Data parsed from the QR code on a wall's label, used to provision the
/// wall during onboarding and add-wall flows.
///
/// The payload is encoded as a `livingwall://provision` URL with versioned
/// query parameters — see [QrPayloadParser] for the canonical format. This
/// model represents the validated result; callers can trust every field is
/// within the allowed envelope.
///
/// [tier] is informational only ("M" / "L" / "custom"). App code must not
/// branch on tier — every wall is treated identically via the grid fields.
@freezed
class ProvisionPayload with _$ProvisionPayload {
  const factory ProvisionPayload({
    required int version,
    required String serialNumber,
    required int gridWidth,
    required int gridHeight,
    required int lengthMm,
    required int heightMm,
    required String wiringPattern,
    String? tier,
  }) = _ProvisionPayload;
}
