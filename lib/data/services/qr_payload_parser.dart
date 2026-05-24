import '../models/provision_payload.dart';

/// Parses and validates a QR payload from a wall's label into a
/// [ProvisionPayload].
///
/// Canonical format (URL scheme, versioned):
/// ```
/// livingwall://provision?v=1&serial=LW-2026-00342&gw=72&gh=48
///   &lw=1200&lh=800&wp=zigzag-bl-rm&tier=M
/// ```
///
/// All validation happens here rather than at the UI — the screen just
/// reports the error message verbatim. There is **no HMAC / signing** in
/// Phase 1: provisioning runs on the local network, and the worst-case
/// spoofed payload is ugly rendering, not a security issue.
class QrPayloadParser {
  const QrPayloadParser();

  static const _supportedVersion = 1;
  static const _supportedWiringPattern = 'zigzag-bl-rm';

  // Envelope per CLAUDE.md "Product model" section.
  static const _minWidthMm = 600;
  static const _maxWidthMm = 2400;
  static const _minHeightMm = 400;
  static const _maxHeightMm = 1600;
  static const _dimensionStepMm = 200;

  // Aspect ratio band 1:3 to 3:1 — anything outside is bespoke / B2B and
  // gets rejected at the QR scan, not silently accepted.
  static const _minAspectRatio = 1 / 3;
  static const _maxAspectRatio = 3.0;

  /// Parse [raw] (the string decoded from the QR image) into a
  /// [ProvisionPayload], or throw [QrPayloadException] with a user-facing
  /// reason if the payload is malformed or out-of-envelope.
  ProvisionPayload parse(String raw) {
    final uri = _parseUri(raw);
    _requireScheme(uri);
    final params = uri.queryParameters;

    final version = _requireInt(params, 'v');
    if (version != _supportedVersion) {
      throw QrPayloadException(
        'Versi QR tidak didukung: v=$version. App ini hanya mendukung v=$_supportedVersion.',
      );
    }

    final serial = _requireString(params, 'serial');
    final gridWidth = _requirePositiveInt(params, 'gw');
    final gridHeight = _requirePositiveInt(params, 'gh');
    final lengthMm = _requirePositiveInt(params, 'lw');
    final heightMm = _requirePositiveInt(params, 'lh');
    final wiringPattern = _requireString(params, 'wp');

    _validateWiringPattern(wiringPattern);
    _validateDimensions(lengthMm, heightMm);
    _validateAspectRatio(gridWidth, gridHeight);

    return ProvisionPayload(
      version: version,
      serialNumber: serial,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      lengthMm: lengthMm,
      heightMm: heightMm,
      wiringPattern: wiringPattern,
      tier: params['tier'],
    );
  }

  Uri _parseUri(String raw) {
    try {
      return Uri.parse(raw.trim());
    } on FormatException {
      throw const QrPayloadException(
        'QR code tidak valid: format URL tidak dapat dibaca.',
      );
    }
  }

  void _requireScheme(Uri uri) {
    if (uri.scheme != 'livingwall' || uri.host != 'provision') {
      throw const QrPayloadException(
        'QR code ini bukan dari Living Wall. Pastikan memindai label di belakang panel.',
      );
    }
  }

  String _requireString(Map<String, String> params, String key) {
    final value = params[key];
    if (value == null || value.isEmpty) {
      throw QrPayloadException(
        'QR code tidak lengkap: field "$key" tidak ada.',
      );
    }
    return value;
  }

  int _requireInt(Map<String, String> params, String key) {
    final raw = _requireString(params, key);
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw QrPayloadException(
        'QR code rusak: field "$key" harus angka, dapat "$raw".',
      );
    }
    return parsed;
  }

  int _requirePositiveInt(Map<String, String> params, String key) {
    final value = _requireInt(params, key);
    if (value <= 0) {
      throw QrPayloadException(
        'QR code rusak: field "$key" harus lebih dari 0, dapat $value.',
      );
    }
    return value;
  }

  void _validateWiringPattern(String pattern) {
    if (pattern != _supportedWiringPattern) {
      throw QrPayloadException(
        'Pola wiring "$pattern" tidak didukung. Phase 1 hanya mendukung "$_supportedWiringPattern".',
      );
    }
  }

  void _validateDimensions(int lengthMm, int heightMm) {
    _validateDimension('width', lengthMm, _minWidthMm, _maxWidthMm);
    _validateDimension('height', heightMm, _minHeightMm, _maxHeightMm);
  }

  void _validateDimension(String label, int value, int min, int max) {
    if (value < min || value > max) {
      throw QrPayloadException(
        'Dimensi $label ${value}mm di luar batas ($min–${max}mm).',
      );
    }
    if (value % _dimensionStepMm != 0) {
      throw QrPayloadException(
        'Dimensi $label ${value}mm bukan kelipatan ${_dimensionStepMm}mm.',
      );
    }
  }

  void _validateAspectRatio(int gridWidth, int gridHeight) {
    final ratio = gridWidth / gridHeight;
    if (ratio < _minAspectRatio || ratio > _maxAspectRatio) {
      final formatted = ratio.toStringAsFixed(2);
      throw QrPayloadException(
        'Aspect ratio $formatted di luar batas (1:3 sampai 3:1). Ukuran ini perlu jalur bespoke.',
      );
    }
  }
}

/// Thrown by [QrPayloadParser.parse] when a QR payload fails to parse or
/// validate. The [message] is user-facing — bahasa Indonesia, concrete enough
/// for someone to know what went wrong and what to do.
class QrPayloadException implements Exception {
  const QrPayloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
