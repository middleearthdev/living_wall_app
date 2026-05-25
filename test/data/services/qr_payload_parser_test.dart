import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/data/services/qr_payload_parser.dart';

void main() {
  const parser = QrPayloadParser();

  // Canonical valid payload — every other test mutates one field.
  String valid({
    int v = 1,
    String serial = 'LW-2026-00342',
    int gw = 72,
    int gh = 48,
    int lw = 1200,
    int lh = 800,
    String wp = 'zigzag-bl-rm',
    String? tier = 'M',
  }) =>
      'livingwall://provision?v=$v&serial=$serial&gw=$gw&gh=$gh'
      '&lw=$lw&lh=$lh&wp=$wp${tier == null ? '' : '&tier=$tier'}';

  group('happy path', () {
    test('parses an M-tier landscape payload', () {
      final p = parser.parse(valid());
      expect(p.version, 1);
      expect(p.serialNumber, 'LW-2026-00342');
      expect(p.gridWidth, 72);
      expect(p.gridHeight, 48);
      expect(p.lengthMm, 1200);
      expect(p.heightMm, 800);
      expect(p.wiringPattern, 'zigzag-bl-rm');
      expect(p.tier, 'M');
    });

    test('parses an L-tier payload', () {
      final p = parser.parse(valid(gw: 108, gh: 72, lw: 1800, lh: 1200, tier: 'L'));
      expect(p.gridWidth, 108);
      expect(p.gridHeight, 72);
      expect(p.tier, 'L');
    });

    test('parses a portrait custom payload', () {
      final p = parser.parse(
        valid(gw: 48, gh: 72, lw: 800, lh: 1200, tier: 'custom'),
      );
      expect(p.gridWidth, 48);
      expect(p.gridHeight, 72);
      expect(p.tier, 'custom');
    });

    test('tier is optional', () {
      final p = parser.parse(valid(tier: null));
      expect(p.tier, isNull);
    });

    test('trims surrounding whitespace in QR text', () {
      final p = parser.parse('  ${valid()}\n');
      expect(p.serialNumber, 'LW-2026-00342');
    });
  });

  group('scheme validation', () {
    test('rejects non-livingwall scheme', () {
      expect(
        () => parser.parse('https://provision?v=1&serial=X'),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects livingwall scheme with wrong host', () {
      expect(
        () => parser.parse('livingwall://something-else?v=1'),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects garbage that does not parse as URL', () {
      // Use control characters that even Uri.parse should reject.
      expect(
        () => parser.parse('not a url \u{1F600} <broken>'),
        throwsA(isA<QrPayloadException>()),
      );
    });
  });

  group('version validation', () {
    test('rejects v=2', () {
      expect(() => parser.parse(valid(v: 2)), throwsA(isA<QrPayloadException>()));
    });

    test('rejects missing v field', () {
      expect(
        () => parser.parse(
          'livingwall://provision?serial=X&gw=72&gh=48&lw=1200&lh=800&wp=zigzag-bl-rm',
        ),
        throwsA(isA<QrPayloadException>()),
      );
    });
  });

  group('required fields', () {
    test('rejects missing serial', () {
      expect(
        () => parser.parse(
          'livingwall://provision?v=1&gw=72&gh=48&lw=1200&lh=800&wp=zigzag-bl-rm',
        ),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects empty serial', () {
      expect(
        () => parser.parse(valid(serial: '')),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects non-numeric gw', () {
      expect(
        () => parser.parse(
          'livingwall://provision?v=1&serial=X&gw=abc&gh=48&lw=1200&lh=800&wp=zigzag-bl-rm',
        ),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects zero gridWidth', () {
      expect(() => parser.parse(valid(gw: 0)), throwsA(isA<QrPayloadException>()));
    });

    test('rejects negative gridHeight', () {
      expect(
        () => parser.parse(valid(gh: -1)),
        throwsA(isA<QrPayloadException>()),
      );
    });
  });

  group('dimension envelope', () {
    test('rejects width below 400mm', () {
      expect(() => parser.parse(valid(lw: 200)), throwsA(isA<QrPayloadException>()));
    });

    test('rejects width above 2400mm', () {
      expect(
        () => parser.parse(valid(lw: 2600)),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects height below 400mm', () {
      expect(() => parser.parse(valid(lh: 200)), throwsA(isA<QrPayloadException>()));
    });

    test('rejects height above 1600mm', () {
      expect(
        () => parser.parse(valid(lh: 1800)),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects width not in 200mm increments', () {
      expect(() => parser.parse(valid(lw: 1100)), throwsA(isA<QrPayloadException>()));
    });

    test('rejects height not in 200mm increments', () {
      expect(() => parser.parse(valid(lh: 850)), throwsA(isA<QrPayloadException>()));
    });

    test('accepts envelope boundaries (400x400 sample, 2400x1600 max)', () {
      // 1:1 square sample matches ID's 40cm validation panel.
      // Grid for 400x400 at 5cm vertical pitch: 24×8.
      expect(
        () => parser.parse(valid(gw: 24, gh: 8, lw: 400, lh: 400)),
        returnsNormally,
      );
      // Large end — L tier ceiling.
      expect(
        () => parser.parse(valid(gw: 144, gh: 32, lw: 2400, lh: 1600)),
        returnsNormally,
      );
    });
  });

  group('aspect ratio envelope (derived from physical mm)', () {
    test('rejects 4:1 ultra-wide (physical lw/lh = 4)', () {
      // Grid 144×12 at 5cm vertical pitch.
      expect(
        () => parser.parse(valid(gw: 144, gh: 12, lw: 2400, lh: 600)),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects 1:4 ultra-tall (physical lw/lh = 0.25)', () {
      expect(
        () => parser.parse(valid(gw: 24, gh: 32, lw: 400, lh: 1600)),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('accepts exactly 3:1 physical (upper boundary)', () {
      // Grid 144×16 — grid ratio is 9, but physical is 3.
      expect(
        () => parser.parse(valid(gw: 144, gh: 16, lw: 2400, lh: 800)),
        returnsNormally,
      );
    });

    test('accepts exactly 1:3 physical (lower boundary)', () {
      // Grid 24×24 — square grid, but physical is 1:3 portrait.
      expect(
        () => parser.parse(valid(gw: 24, gh: 24, lw: 400, lh: 1200)),
        returnsNormally,
      );
    });

    test(
      'M tier (1200×800 landscape) accepted despite grid 72×16 looking 4.5:1',
      () {
        // Non-square pixels: validating from grid would reject this wrongly.
        // Physical 3:2 must pass the 3:1 envelope.
        expect(
          () => parser.parse(valid(gw: 72, gh: 16, lw: 1200, lh: 800)),
          returnsNormally,
        );
      },
    );
  });

  group('wiring pattern validation', () {
    test('rejects unsupported wiring pattern', () {
      expect(
        () => parser.parse(valid(wp: 'straight-tl-rm')),
        throwsA(isA<QrPayloadException>()),
      );
    });

    test('rejects empty wiring pattern', () {
      expect(
        () => parser.parse(valid(wp: '')),
        throwsA(isA<QrPayloadException>()),
      );
    });
  });

  group('error messages are user-friendly Indonesian', () {
    test('out-of-envelope width includes the value and the range', () {
      try {
        parser.parse(valid(lw: 200));
        fail('expected exception');
      } on QrPayloadException catch (e) {
        expect(e.message, contains('200mm'));
        expect(e.message, contains('400'));
        expect(e.message, contains('2400'));
      }
    });

    test('wrong version mentions the supplied version', () {
      try {
        parser.parse(valid(v: 7));
        fail('expected exception');
      } on QrPayloadException catch (e) {
        expect(e.message, contains('v=7'));
      }
    });
  });
}
