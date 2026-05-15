import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/core/utils/throttler.dart';

void main() {
  group('Throttler', () {
    test('fires the first value immediately', () async {
      final fired = <int>[];
      final t = Throttler<int>(
        cooldown: const Duration(milliseconds: 30),
        onFire: (v) async => fired.add(v),
      );

      t.submit(7);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(fired, [7]);
      t.dispose();
    });

    test('coalesces bursts and honors the trailing value', () async {
      final fired = <int>[];
      final t = Throttler<int>(
        cooldown: const Duration(milliseconds: 30),
        onFire: (v) async {
          fired.add(v);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        },
      );

      // Burst: first lands, middle drops, last waits for cooldown.
      t.submit(1);
      t.submit(2);
      t.submit(3);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(fired.first, 1, reason: 'leading edge always fires');
      expect(fired.last, 3, reason: 'trailing value must land');
      expect(fired, isNot(contains(2)), reason: 'middle values get dropped');
      t.dispose();
    });

    test('dispose stops future submissions from firing', () async {
      final fired = <int>[];
      final t = Throttler<int>(
        cooldown: const Duration(milliseconds: 20),
        onFire: (v) async => fired.add(v),
      );

      t.submit(1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      t.dispose();
      t.submit(2);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(fired, [1]);
    });
  });
}
