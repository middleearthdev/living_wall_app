/// Three-bucket label for a WLED `sx` speed value (0–255). The boundaries
/// were tuned against the design spec's "Lambat / Sedang / Cepat" wording
/// — five buckets felt over-precise for what's essentially a vibe choice.
///
/// Used by the adjustment sheet's Speed row trailing label.
String speedLabelFor(int value) {
  if (value < 86) return 'Lambat';
  if (value < 171) return 'Sedang';
  return 'Cepat';
}
