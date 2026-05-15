/// Marks an add-wall flow as targeting a specific existing room. When this
/// is non-null, the WiFi → Discovery → Name screens render in "add-wall"
/// mode: top bar with close button, context banner ("akan masuk ke {room}"),
/// locked room picker, and discovery filters out walls already registered.
///
/// When null, those same screens render as onboarding (first-launch flow).
class AddWallContext {
  const AddWallContext({required this.roomId});

  final String roomId;
}
