import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/core/utils/speed_label.dart';

void main() {
  group('speedLabelFor', () {
    test('low values read as Lambat', () {
      expect(speedLabelFor(0), 'Lambat');
      expect(speedLabelFor(50), 'Lambat');
      expect(speedLabelFor(85), 'Lambat');
    });

    test('mid range reads as Sedang', () {
      expect(speedLabelFor(86), 'Sedang');
      expect(speedLabelFor(128), 'Sedang');
      expect(speedLabelFor(170), 'Sedang');
    });

    test('high values read as Cepat', () {
      expect(speedLabelFor(171), 'Cepat');
      expect(speedLabelFor(220), 'Cepat');
      expect(speedLabelFor(255), 'Cepat');
    });
  });
}
