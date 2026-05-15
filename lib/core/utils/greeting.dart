/// Time-of-day greeting used by the dashboard header. Bands match common
/// Indonesian usage rather than astronomical sun position — "siang" runs
/// past noon, "sore" covers late afternoon, "malam" wraps midnight.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 10) return 'Selamat pagi';
  if (h >= 10 && h < 15) return 'Selamat siang';
  if (h >= 15 && h < 18) return 'Selamat sore';
  return 'Selamat malam';
}
