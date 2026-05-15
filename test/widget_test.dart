import 'package:flutter_test/flutter_test.dart';

// Smoke test for the app shell is deferred: MaterialApp.router boots the
// database (via FutureProvider chains) and that needs a platform binding for
// path_provider, which isn't available in pure unit tests. Replace with an
// integration test once we add the hardware-aware flow.
void main() {
  test('placeholder — see discovery_service_test for real coverage', () {
    expect(true, isTrue);
  });
}
